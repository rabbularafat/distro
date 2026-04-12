#!/usr/bin/env python3
"""
Screen Privacy Overlay — Pure X11 Implementation
=================================================
Creates a fullscreen white window using raw Xlib calls (no Tkinter).
Works reliably on Xvfb, XRDP, any X11 display.

Architecture:
  - Pure ctypes → Xlib (no Tkinter dependency)
  - Override-redirect window (no window manager decorations)
  - XShape empty input region (all clicks/keys pass through)
  - Periodic XRaiseWindow to stay above all windows (Chrome, etc.)
  - Runs on the CURRENT $DISPLAY (works on :99, :10, :11, etc.)

Auth: SHA-256 key required. Wrong key → silent exit.

Usage:
    .x11dpy <KEY> on       — Enable overlay on current display
    .x11dpy <KEY> off      — Disable overlay
    .x11dpy <KEY> status   — Check if running (1/0)
    .x11dpy --init <KEY>   — Set auth key (installer only)
"""

import os
import sys
import signal
import hashlib
import time
import ctypes
import ctypes.util


PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")

# X11 constants
CWOverrideRedirect = 512          # (1 << 9)
CWBackPixel = 2                   # (1 << 1)
ExposureMask = (1 << 15)
StructureNotifyMask = (1 << 17)
SubstructureNotifyMask = (1 << 19)


# ──────────────────────────────────────────────────────────
# Xlib structures
# ──────────────────────────────────────────────────────────
class XSetWindowAttributes(ctypes.Structure):
    _fields_ = [
        ("background_pixmap", ctypes.c_ulong),
        ("background_pixel", ctypes.c_ulong),
        ("border_pixmap", ctypes.c_ulong),
        ("border_pixel", ctypes.c_ulong),
        ("bit_gravity", ctypes.c_int),
        ("win_gravity", ctypes.c_int),
        ("backing_store", ctypes.c_int),
        ("backing_planes", ctypes.c_ulong),
        ("backing_pixel", ctypes.c_ulong),
        ("save_under", ctypes.c_int),
        ("event_mask", ctypes.c_long),
        ("do_not_propagate_mask", ctypes.c_long),
        ("override_redirect", ctypes.c_int),
        ("colormap", ctypes.c_ulong),
        ("cursor", ctypes.c_ulong),
    ]


# ──────────────────────────────────────────────────────────
# Auth system
# ──────────────────────────────────────────────────────────
def _hash(k):
    return hashlib.sha256(k.encode("utf-8")).hexdigest()

def _verify(k):
    try:
        with open(AUTH_FILE, "r") as f:
            return _hash(k) == f.read().strip()
    except FileNotFoundError:
        return False

def _set_key(k):
    os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
    with open(AUTH_FILE, "w") as f:
        f.write(_hash(k))
    os.chmod(AUTH_FILE, 0o600)


# ──────────────────────────────────────────────────────────
# PID management
# ──────────────────────────────────────────────────────────
def _write_pid():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    os.chmod(PID_FILE, 0o600)

def _read_pid():
    try:
        with open(PID_FILE, "r") as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None

def _is_running(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

def _cleanup(*_args):
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass
    sys.exit(0)


# ──────────────────────────────────────────────────────────
# Pure X11 Overlay
# ──────────────────────────────────────────────────────────
def _on():
    """Create fullscreen white overlay using pure Xlib calls."""
    if _is_running(_read_pid()):
        return

    if "DISPLAY" not in os.environ:
        os.environ["DISPLAY"] = ":99"

    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()

    try:
        # Load X11 libraries
        x11_path = ctypes.util.find_library("X11") or "libX11.so.6"
        xext_path = ctypes.util.find_library("Xext") or "libXext.so.6"

        x11 = ctypes.cdll.LoadLibrary(x11_path)
        xext = ctypes.cdll.LoadLibrary(xext_path)

        # Set return types for Xlib functions
        x11.XOpenDisplay.restype = ctypes.c_void_p
        x11.XDefaultRootWindow.restype = ctypes.c_ulong
        x11.XCreateSimpleWindow.restype = ctypes.c_ulong
        x11.XWhitePixel.restype = ctypes.c_ulong
        x11.XBlackPixel.restype = ctypes.c_ulong
        x11.XCreateWindow.restype = ctypes.c_ulong

        # Open X display
        display_name = os.environ["DISPLAY"].encode()
        display = x11.XOpenDisplay(display_name)
        if not display:
            _cleanup()

        # Get screen info
        screen = x11.XDefaultScreen(ctypes.c_void_p(display))
        root = x11.XDefaultRootWindow(ctypes.c_void_p(display))
        width = x11.XDisplayWidth(ctypes.c_void_p(display), screen)
        height = x11.XDisplayHeight(ctypes.c_void_p(display), screen)
        white = x11.XWhitePixel(ctypes.c_void_p(display), screen)

        # Create a white fullscreen window
        window = x11.XCreateSimpleWindow(
            ctypes.c_void_p(display),
            root,
            0, 0,            # x, y (top-left corner)
            width, height,   # cover entire screen
            0,               # border width
            0,               # border color
            white,           # background = white
        )

        # Set override-redirect (bypass window manager — no titlebar, no taskbar)
        attrs = XSetWindowAttributes()
        attrs.override_redirect = 1
        attrs.background_pixel = white
        x11.XChangeWindowAttributes(
            ctypes.c_void_p(display),
            window,
            CWOverrideRedirect | CWBackPixel,
            ctypes.byref(attrs),
        )

        # Make input-transparent via XShape (empty input region)
        # ShapeInput(2) + 0 rects = no input events reach this window
        # All clicks/keys fall through to windows below
        xext.XShapeCombineRectangles(
            ctypes.c_void_p(display),
            ctypes.c_ulong(window),
            ctypes.c_int(2),     # ShapeInput
            ctypes.c_int(0),     # x_off
            ctypes.c_int(0),     # y_off
            None,                # NULL = empty region
            ctypes.c_int(0),     # 0 rectangles
            ctypes.c_int(0),     # ShapeSet
            ctypes.c_int(0),     # Unsorted
        )

        # Map (show) the window
        x11.XMapWindow(ctypes.c_void_p(display), window)
        x11.XRaiseWindow(ctypes.c_void_p(display), window)
        x11.XFlush(ctypes.c_void_p(display))

        # Keep overlay alive and on top
        # Periodically raise the window so new windows (Chrome, etc.)
        # don't cover it
        while True:
            try:
                x11.XRaiseWindow(ctypes.c_void_p(display), window)
                x11.XFlush(ctypes.c_void_p(display))
            except Exception:
                pass
            time.sleep(2)

    except Exception:
        _cleanup()


def _off():
    """Stop the overlay."""
    pid = _read_pid()
    if not _is_running(pid):
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        pass
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass


def _st():
    """Print 1 if running, 0 if not."""
    pid = _read_pid()
    if _is_running(pid):
        print("1")
    else:
        print("0")
        try:
            os.remove(PID_FILE)
        except FileNotFoundError:
            pass


# ──────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)

    if sys.argv[1] == "--init" and len(sys.argv) == 3:
        _set_key(sys.argv[2])
        sys.exit(0)

    if not _verify(sys.argv[1]):
        sys.exit(1)

    a = sys.argv[2].lower()
    if a == "on":
        _on()
    elif a == "off":
        _off()
    elif a == "status":
        _st()
    else:
        sys.exit(1)
