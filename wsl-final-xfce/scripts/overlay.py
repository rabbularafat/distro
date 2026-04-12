#!/usr/bin/env python3
"""
X11 Privacy Overlay — Multi-Display Coverage (ULTRA-ROBUST)
=============================================
Protected by SHA-256 Auth.
Self-backgrounding via double-fork.
Always-on by default — use 'off' to temporarily disable.
"""

import os, sys, signal, hashlib, time, ctypes, ctypes.util, glob

PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")
LOG_FILE = os.path.expanduser("~/.claimation/overlay.log")

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

def _log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except: pass

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
    _log("Stopping daemon...")
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
    sys.exit(0)

def _write_pid():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f: f.write(str(os.getpid()))
    os.chmod(PID_FILE, 0o600)

def _discover_displays():
    displays = set()
    try:
        for sock in glob.glob("/tmp/.X11-unix/X*"):
            num = os.path.basename(sock).replace("X", "")
            if num.isdigit():
                displays.add(":" + num)
    except Exception: pass
    displays.add(":99")
    return list(displays)

def _load_x11():
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xext") or "libXext.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XCreateSimpleWindow.restype = ctypes.c_ulong
    x11.XWhitePixel.restype = ctypes.c_ulong
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XNoOp.argtypes = [ctypes.c_void_p]
    return x11, xext

def _try_open_display(x11, display_name):
    """Attempt to open display across various potential Xauthority files."""
    # List of places to look for authority
    auth_files = [
        os.environ.get("XAUTHORITY"),
        os.path.expanduser("~/.Xauthority"),
    ]
    # Add any .xauth* files in /tmp owned by current user
    try:
        uid = os.getuid()
        for f in glob.glob("/tmp/.xauth*"):
            try:
                if os.stat(f).st_uid == uid:
                    auth_files.append(f)
            except: pass
    except: pass

    original_auth = os.environ.get("XAUTHORITY")
    
    for auth in filter(None, auth_files):
        try:
            os.environ["XAUTHORITY"] = auth
            d = x11.XOpenDisplay(display_name.encode())
            if d:
                return d
        except: pass
    
    # Final try with nothing
    try:
        if "XAUTHORITY" in os.environ: del os.environ["XAUTHORITY"]
        d = x11.XOpenDisplay(display_name.encode())
        if d: return d
    except: pass

    # Restore
    if original_auth: os.environ["XAUTHORITY"] = original_auth
    return None

def _cover_display(x11, xext, display_name):
    try:
        d = _try_open_display(x11, display_name)
        if not d:
            _log(f"Failed to find authorization for {display_name}")
            return None

        s = x11.XDefaultScreen(ctypes.c_void_p(d))
        r = x11.XDefaultRootWindow(ctypes.c_void_p(d))
        w = x11.XDisplayWidth(ctypes.c_void_p(d), s)
        h = x11.XDisplayHeight(ctypes.c_void_p(d), s)
        wp = x11.XWhitePixel(ctypes.c_void_p(d), s)

        win = x11.XCreateSimpleWindow(ctypes.c_void_p(d), r, 0, 0, w, h, 0, 0, wp)
        a = _XAttr(); a.override = 1; a.bg_pixel = wp
        x11.XChangeWindowAttributes(ctypes.c_void_p(d), win, CWOverrideRedirect | CWBackPixel, ctypes.byref(a))

        # Input transparency
        xext.XShapeCombineRectangles(ctypes.c_void_p(d), ctypes.c_ulong(win), ShapeInput, 0, 0, None, 0, ShapeSet, 0)

        x11.XMapWindow(ctypes.c_void_p(d), win)
        x11.XRaiseWindow(ctypes.c_void_p(d), win)
        x11.XFlush(ctypes.c_void_p(d))

        _log(f"Successfully covered display {display_name}")
        return (d, win)
    except Exception as e:
        _log(f"Error covering {display_name}: {e}")
        return None

def _daemon_main():
    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()
    _log("Daemon started (v3.1)")

    x11 = None
    xext = None
    try:
        x11, xext = _load_x11()
    except Exception as e:
        _log(f"Library load failed: {e}")
        _cleanup()

    overlays = {}
    while True:
        try:
            current_displays = _discover_displays()
            
            # New displays
            for disp in current_displays:
                if disp not in overlays:
                    result = _cover_display(x11, xext, disp)
                    if result: overlays[disp] = result
            
            # Maintenance
            for disp, (dp, win) in list(overlays.items()):
                try:
                    # Keep on top
                    x11.XRaiseWindow(ctypes.c_void_p(dp), win)
                    x11.XFlush(ctypes.c_void_p(dp))
                except:
                    _log(f"Lost display {disp}")
                    try: x11.XCloseDisplay(ctypes.c_void_p(dp))
                    except: pass
                    del overlays[disp]

            # Cleanup gone displays
            stale = [d for d in overlays if d not in current_displays]
            for d in stale:
                try: x11.XCloseDisplay(ctypes.c_void_p(overlays[d][0]))
                except: pass
                del overlays[d]

        except Exception as e:
            _log(f"Loop error: {e}")
        
        time.sleep(3)

def _on():
    if _is_running(_read_pid()):
        print("Privacy Overlay: ALREADY RUNNING")
        return
    try:
        pid = os.fork()
        if pid > 0:
            print("Privacy Overlay: ENABLED")
            return
    except OSError: sys.exit(1)
    os.setsid()
    try:
        pid2 = os.fork()
        if pid2 > 0: os._exit(0)
    except OSError: os._exit(1)
    
    # Fully detach
    sys.stdin.close()
    sys.stdout.close()
    sys.stderr.close()
    os.open(os.devnull, os.O_RDWR) # stdin
    os.dup2(0, 1) # stdout
    os.dup2(0, 2) # stderr
    
    _daemon_main()

def _off():
    pid = _read_pid()
    if _is_running(pid):
        try: os.kill(pid, signal.SIGTERM)
        except OSError: pass
        for _ in range(15):
            if not _is_running(pid): break
            time.sleep(0.2)
    try: os.remove(PID_FILE)
    except: pass
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
