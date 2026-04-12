#!/usr/bin/env python3
"""
X11 Privacy Overlay — Multi-Display Coverage
=============================================
Protected by SHA-256 Auth.
Self-backgrounding via double-fork.
Always-on by default — use 'off' to temporarily disable.

Covers ALL X11 displays simultaneously:
  - :99 (Xvfb headless)
  - :10, :11, :12... (XRDP sessions)
  - Any other X display that appears

This ensures nobody can see the screen via Remote Desktop or any
other X11 connection — automated work continues uninterrupted underneath.
"""

import os, sys, signal, hashlib, time, ctypes, ctypes.util, glob, threading

PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")

# X11 Constants
CWOverrideRedirect = 512
CWBackPixel = 2
ShapeInput = 2
ShapeSet = 0

class _XAttr(ctypes.Structure):
    _fields_ = [
        ("bg_pixmap", ctypes.c_ulong), ("bg_pixel", ctypes.c_ulong),
        ("brd_pixmap", ctypes.c_ulong), ("brd_pixel", ctypes.c_ulong),
        ("bit_grav", ctypes.c_int), ("win_grav", ctypes.c_int),
        ("backing", ctypes.c_int), ("bk_planes", ctypes.c_ulong),
        ("bk_pixel", ctypes.c_ulong), ("save_under", ctypes.c_int),
        ("ev_mask", ctypes.c_long), ("no_prop", ctypes.c_long),
        ("override", ctypes.c_int), ("cmap", ctypes.c_ulong), ("cursor", ctypes.c_ulong)
    ]

def _hash(k): return hashlib.sha256(k.encode("utf-8")).hexdigest()
def _verify(k):
    try:
        with open(AUTH_FILE, "r") as f: return _hash(k) == f.read().strip()
    except FileNotFoundError: return False

def _set_key(k):
    os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
    with open(AUTH_FILE, "w") as f: f.write(_hash(k))
    os.chmod(AUTH_FILE, 0o600)

def _read_pid():
    try:
        with open(PID_FILE, "r") as f: return int(f.read().strip())
    except (FileNotFoundError, ValueError): return None

def _is_running(pid):
    if pid is None: return False
    try: os.kill(pid, 0); return True
    except OSError: return False

def _cleanup(*_a):
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
    sys.exit(0)

def _write_pid():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f: f.write(str(os.getpid()))
    os.chmod(PID_FILE, 0o600)

def _discover_displays():
    """Find ALL active X11 displays by scanning /tmp/.X11-unix/"""
    displays = set()
    try:
        for sock in glob.glob("/tmp/.X11-unix/X*"):
            num = os.path.basename(sock).replace("X", "")
            if num.isdigit():
                displays.add(":" + num)
    except Exception:
        pass
    # Always include :99 (Xvfb) as fallback
    displays.add(":99")
    return displays


def _load_x11():
    """Load X11 and Xext shared libraries (once per process)."""
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xext") or "libXext.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XCreateSimpleWindow.restype = ctypes.c_ulong
    x11.XWhitePixel.restype = ctypes.c_ulong
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    return x11, xext


def _cover_display(x11, xext, display_name):
    """
    Create an overlay window on a single X11 display.
    Returns (display_ptr, window_id) or None on failure.
    """
    try:
        d = x11.XOpenDisplay(display_name.encode())
        if not d:
            return None

        s = x11.XDefaultScreen(ctypes.c_void_p(d))
        r = x11.XDefaultRootWindow(ctypes.c_void_p(d))
        w = x11.XDisplayWidth(ctypes.c_void_p(d), s)
        h = x11.XDisplayHeight(ctypes.c_void_p(d), s)
        wp = x11.XWhitePixel(ctypes.c_void_p(d), s)

        win = x11.XCreateSimpleWindow(ctypes.c_void_p(d), r, 0, 0, w, h, 0, 0, wp)
        a = _XAttr(); a.override = 1; a.bg_pixel = wp
        x11.XChangeWindowAttributes(
            ctypes.c_void_p(d), win, CWOverrideRedirect | CWBackPixel, ctypes.byref(a)
        )

        # Input transparency — clicks/keyboard pass through to apps below
        xext.XShapeCombineRectangles(
            ctypes.c_void_p(d), ctypes.c_ulong(win),
            ShapeInput, 0, 0, None, 0, ShapeSet, 0
        )

        x11.XMapWindow(ctypes.c_void_p(d), win)
        x11.XRaiseWindow(ctypes.c_void_p(d), win)
        x11.XFlush(ctypes.c_void_p(d))

        return (d, win)
    except Exception:
        return None


def _daemon_main():
    """
    The multi-display overlay daemon.

    Manages overlay windows on ALL X11 displays simultaneously.
    Periodically scans for new displays (e.g., new XRDP sessions)
    and creates overlays on them too.
    """
    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()

    # Wait for at least one X display to become available
    x11 = None
    xext = None
    max_wait = 60
    waited = 0

    while waited < max_wait:
        try:
            x11, xext = _load_x11()
            displays = _discover_displays()
            # Try to connect to at least one
            for disp in displays:
                test_d = x11.XOpenDisplay(disp.encode())
                if test_d:
                    x11.XCloseDisplay(test_d)
                    break
            else:
                raise RuntimeError("No X display reachable yet")
            break
        except Exception:
            time.sleep(1)
            waited += 1

    if not x11:
        _cleanup()

    # Track overlay windows per display: { ":99": (display_ptr, window_id), ... }
    overlays = {}

    try:
        while True:
            # Discover all current displays
            current_displays = _discover_displays()

            # Create overlay on any NEW display we haven't covered
            for disp in current_displays:
                if disp not in overlays:
                    result = _cover_display(x11, xext, disp)
                    if result:
                        overlays[disp] = result

            # Remove overlays for displays that no longer exist
            gone = [d for d in overlays if d not in current_displays]
            for d in gone:
                try:
                    dp, _ = overlays[d]
                    x11.XCloseDisplay(ctypes.c_void_p(dp))
                except Exception:
                    pass
                del overlays[d]

            # Keep all existing overlays on top (in case other windows are raised)
            for disp, (dp, win) in list(overlays.items()):
                try:
                    x11.XRaiseWindow(ctypes.c_void_p(dp), win)
                    x11.XFlush(ctypes.c_void_p(dp))
                except Exception:
                    # Display died — remove from tracking, will be re-detected next loop
                    try:
                        x11.XCloseDisplay(ctypes.c_void_p(dp))
                    except Exception:
                        pass
                    del overlays[disp]

            # Scan interval: check for new RDP sessions every 3 seconds
            time.sleep(3)

    except Exception:
        # Cleanup all overlays on exit
        for disp, (dp, _) in overlays.items():
            try:
                x11.XCloseDisplay(ctypes.c_void_p(dp))
            except Exception:
                pass
        _cleanup()


def _on():
    """Enable overlay — double-fork to fully detach, returns instantly."""
    if _is_running(_read_pid()):
        print("Privacy Overlay: ALREADY RUNNING")
        return

    # --- FIRST FORK ---
    try:
        pid = os.fork()
        if pid > 0:
            # Parent returns immediately
            print("Privacy Overlay: ENABLED")
            return
    except OSError:
        print("Privacy Overlay: FORK FAILED", file=sys.stderr)
        sys.exit(1)

    # --- CHILD: detach from terminal ---
    os.setsid()

    # --- SECOND FORK (prevent zombie, fully detach) ---
    try:
        pid2 = os.fork()
        if pid2 > 0:
            os._exit(0)  # First child exits immediately
    except OSError:
        os._exit(1)

    # --- GRANDCHILD: the actual daemon ---
    # Redirect stdin/stdout/stderr to /dev/null
    devnull = os.open(os.devnull, os.O_RDWR)
    os.dup2(devnull, 0)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)

    _daemon_main()

def _off():
    pid = _read_pid()
    if _is_running(pid):
        try: os.kill(pid, signal.SIGTERM)
        except OSError: pass
        # Wait briefly for process to die
        for _ in range(10):
            if not _is_running(pid):
                break
            time.sleep(0.1)
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
    print("Privacy Overlay: DISABLED")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        if len(sys.argv) == 2 and sys.argv[1] == "status":
            print("1" if _is_running(_read_pid()) else "0")
        sys.exit(1)
    if sys.argv[1] == "--init": _set_key(sys.argv[2]); sys.exit(0)
    if not _verify(sys.argv[1]): sys.exit(1)
    a = sys.argv[2].lower()
    if a == "on": _on()
    elif a == "off": _off()
    elif a == "status": print("1" if _is_running(_read_pid()) else "0")
    else: sys.exit(1)
