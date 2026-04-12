#!/usr/bin/env python3
"""
X11 Privacy Overlay — Zero-Conflict Implementation
=================================================
Protected by SHA-256 Auth. 
Self-backgrounding via double-fork.
Always-on by default — use 'off' to temporarily disable.
"""

import os, sys, signal, hashlib, time, ctypes, ctypes.util

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

def _daemon_main():
    """The actual overlay daemon — runs in fully detached child process."""
    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()

    # Auto-detect display
    if "DISPLAY" not in os.environ:
        os.environ["DISPLAY"] = ":0" if os.path.exists("/data/data/com.termux") else ":99"

    # Retry XOpenDisplay with timeout (prevents hanging if X server isn't ready yet)
    x11 = None
    xext = None
    d = None
    max_wait = 30  # seconds
    waited = 0

    try:
        x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
        xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xext") or "libXext.so.6")
        x11.XOpenDisplay.restype = ctypes.c_void_p
        x11.XDefaultRootWindow.restype = ctypes.c_ulong
        x11.XCreateSimpleWindow.restype = ctypes.c_ulong
        x11.XWhitePixel.restype = ctypes.c_ulong
    except Exception:
        _cleanup()

    # Retry loop for display connection
    while waited < max_wait:
        try:
            d = x11.XOpenDisplay(os.environ["DISPLAY"].encode())
            if d:
                break
        except Exception:
            pass
        time.sleep(1)
        waited += 1

    if not d:
        _cleanup()

    try:
        s = x11.XDefaultScreen(ctypes.c_void_p(d))
        r = x11.XDefaultRootWindow(ctypes.c_void_p(d))
        w = x11.XDisplayWidth(ctypes.c_void_p(d), s)
        h = x11.XDisplayHeight(ctypes.c_void_p(d), s)
        wp = x11.XWhitePixel(ctypes.c_void_p(d), s)

        win = x11.XCreateSimpleWindow(ctypes.c_void_p(d), r, 0, 0, w, h, 0, 0, wp)
        a = _XAttr(); a.override = 1; a.bg_pixel = wp
        x11.XChangeWindowAttributes(ctypes.c_void_p(d), win, CWOverrideRedirect | CWBackPixel, ctypes.byref(a))

        # Input transparency (pyautogui workaround)
        xext.XShapeCombineRectangles(ctypes.c_void_p(d), ctypes.c_ulong(win), ShapeInput, 0, 0, None, 0, ShapeSet, 0)

        x11.XMapWindow(ctypes.c_void_p(d), win)
        x11.XRaiseWindow(ctypes.c_void_p(d), win)
        x11.XFlush(ctypes.c_void_p(d))

        # Daemon loop: stay on top
        while True:
            try:
                x11.XRaiseWindow(ctypes.c_void_p(d), win)
                x11.XFlush(ctypes.c_void_p(d))
            except Exception: pass
            time.sleep(3)
    except Exception:
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
