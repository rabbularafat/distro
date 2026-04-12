#!/usr/bin/env python3
"""
Screen Privacy Overlay for Claimation
======================================
Creates a fullscreen white window that is INPUT-TRANSPARENT.
All mouse clicks, moves, and keyboard events pass straight through
to the applications underneath (pyautogui, Chrome, etc.).

Protected by a secret auth key — without the correct key,
the overlay cannot be enabled or disabled.

Usage:
    .x11dpy <AUTH_KEY> on       — Enable the overlay
    .x11dpy <AUTH_KEY> off      — Disable the overlay
    .x11dpy <AUTH_KEY> status   — Check if running

Without the correct key → silent failure (looks like a broken command).
"""

import os
import sys
import signal
import hashlib
import ctypes
import ctypes.util

PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")


# ──────────────────────────────────────────────────────────
# Auth system — secret key required to control overlay
# ──────────────────────────────────────────────────────────
def _hash_key(key):
    """SHA-256 hash of the auth key."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def _verify_auth(provided_key):
    """Verify the provided key against the stored hash."""
    try:
        with open(AUTH_FILE, "r") as f:
            stored_hash = f.read().strip()
        return _hash_key(provided_key) == stored_hash
    except FileNotFoundError:
        return False


def _set_auth_key(key):
    """Store the auth key hash (called during installation)."""
    os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
    with open(AUTH_FILE, "w") as f:
        f.write(_hash_key(key))
    os.chmod(AUTH_FILE, 0o600)  # Owner read/write only


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
# X11 Shape Extension — input transparency
# ──────────────────────────────────────────────────────────
def _make_input_transparent(root):
    """
    X11 XShape: set input region to EMPTY.
    All mouse/keyboard events pass through to windows below.
    pyautogui.moveTo/click/press → XTest events → routed to apps underneath.
    """
    try:
        x11_path = ctypes.util.find_library("X11") or "libX11.so.6"
        xext_path = ctypes.util.find_library("Xext") or "libXext.so.6"

        x11 = ctypes.cdll.LoadLibrary(x11_path)
        xext = ctypes.cdll.LoadLibrary(xext_path)

        display_name = os.environ.get("DISPLAY", ":99")
        display = x11.XOpenDisplay(display_name.encode())
        if not display:
            return False

        wid = root.winfo_id()

        # ShapeInput(2) + 0 rects = empty input region
        # → window receives ZERO input events
        # → all clicks/keys fall through to window below
        xext.XShapeCombineRectangles(
            ctypes.c_void_p(display),
            ctypes.c_ulong(wid),
            ctypes.c_int(2),     # ShapeInput
            ctypes.c_int(0),
            ctypes.c_int(0),
            None,                # NULL = empty region
            ctypes.c_int(0),     # 0 rectangles
            ctypes.c_int(0),     # ShapeSet
            ctypes.c_int(0),     # Unsorted
        )

        x11.XFlush(ctypes.c_void_p(display))
        return True
    except Exception:
        return False


# ──────────────────────────────────────────────────────────
# Overlay control
# ──────────────────────────────────────────────────────────
def _start():
    """Create and show the fullscreen white overlay."""
    existing_pid = _read_pid()
    if _is_running(existing_pid):
        return

    try:
        import tkinter as tk
    except ImportError:
        sys.exit(1)

    if "DISPLAY" not in os.environ:
        os.environ["DISPLAY"] = ":99"

    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()

    try:
        root = tk.Tk()
        root.title("x11dpy")

        # Start HIDDEN → apply XShape → then show (no race condition)
        root.withdraw()
        root.overrideredirect(True)
        root.attributes("-fullscreen", True)
        root.attributes("-topmost", True)
        root.configure(bg="white")
        root.update_idletasks()

        # Apply input transparency BEFORE showing
        _make_input_transparent(root)

        # NOW show — already click-through
        root.deiconify()
        root.update()

        root.mainloop()
    except Exception:
        _cleanup()


def _stop():
    """Stop the running overlay."""
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


def _status():
    """Return whether overlay is running."""
    pid = _read_pid()
    if _is_running(pid):
        print("1")  # Running (minimal output, no hints)
    else:
        print("0")
        try:
            os.remove(PID_FILE)
        except FileNotFoundError:
            pass


# ──────────────────────────────────────────────────────────
# Main entry point
# ──────────────────────────────────────────────────────────
def main():
    # .x11dpy --init <KEY>         → set auth key (first time only)
    # .x11dpy <KEY> on|off|status  → control overlay
    # anything else                → silent exit (looks broken)

    if len(sys.argv) < 3:
        sys.exit(1)  # Silent — no usage hints

    # Special: initialization mode (called by installer only)
    if sys.argv[1] == "--init" and len(sys.argv) == 3:
        _set_auth_key(sys.argv[2])
        sys.exit(0)

    auth_key = sys.argv[1]
    action = sys.argv[2].lower()

    # Verify auth — wrong key = silent exit
    if not _verify_auth(auth_key):
        sys.exit(1)

    if action == "on":
        _start()
    elif action == "off":
        _stop()
    elif action == "status":
        _status()
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
