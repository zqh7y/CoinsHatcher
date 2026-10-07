"""Background mode (Windows): watch and click one window without touching
the real mouse, so you can keep using your PC while the clicker works.

The window is captured with PrintWindow, which still sees it when other
windows are on top (not when it is minimized). Clicks are sent to it as
mouse messages, so the real cursor never moves and focus stays where it is.
"""

import ctypes
import sys
import time

import numpy as np

if sys.platform == "win32":
    from ctypes import wintypes

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)

    HWND, HDC, HBITMAP, HGDIOBJ = wintypes.HWND, wintypes.HDC, wintypes.HBITMAP, wintypes.HGDIOBJ
    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, HWND, wintypes.LPARAM)

    user32.EnumWindows.argtypes = [WNDENUMPROC, wintypes.LPARAM]
    user32.IsWindowVisible.argtypes = [HWND]
    user32.IsWindow.argtypes = [HWND]
    user32.IsIconic.argtypes = [HWND]
    user32.GetWindowTextLengthW.argtypes = [HWND]
    user32.GetWindowTextW.argtypes = [HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetClientRect.argtypes = [HWND, ctypes.POINTER(wintypes.RECT)]
    user32.GetDC.argtypes = [HWND]
    user32.GetDC.restype = HDC
    user32.ReleaseDC.argtypes = [HWND, HDC]
    user32.PrintWindow.argtypes = [HWND, HDC, wintypes.UINT]
    user32.PostMessageW.argtypes = [HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.ChildWindowFromPointEx.argtypes = [HWND, wintypes.POINT, wintypes.UINT]
    user32.ChildWindowFromPointEx.restype = HWND
    user32.ClientToScreen.argtypes = [HWND, ctypes.POINTER(wintypes.POINT)]
    user32.MapWindowPoints.argtypes = [HWND, HWND, ctypes.POINTER(wintypes.POINT), wintypes.UINT]
    gdi32.CreateCompatibleDC.argtypes = [HDC]
    gdi32.CreateCompatibleDC.restype = HDC
    gdi32.CreateCompatibleBitmap.argtypes = [HDC, ctypes.c_int, ctypes.c_int]
    gdi32.CreateCompatibleBitmap.restype = HBITMAP
    gdi32.SelectObject.argtypes = [HDC, HGDIOBJ]
    gdi32.SelectObject.restype = HGDIOBJ
    gdi32.DeleteObject.argtypes = [HGDIOBJ]
    gdi32.DeleteDC.argtypes = [HDC]
    gdi32.GetDIBits.argtypes = [HDC, HBITMAP, wintypes.UINT, wintypes.UINT, ctypes.c_void_p,
                                ctypes.c_void_p, wintypes.UINT]

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG),
                    ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
                    ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                    ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
                    ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
                    ("biClrImportant", wintypes.DWORD)]

WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0200, 0x0201, 0x0202
MK_LBUTTON = 0x0001
PW_CLIENTONLY, PW_RENDERFULLCONTENT = 0x1, 0x2

SUPPORTED = sys.platform == "win32"


def window_title(hwnd):
    n = user32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(n + 1)
    user32.GetWindowTextW(hwnd, buf, n + 1)
    return buf.value


def list_windows(skip_titles=()):
    """Titles of the visible app windows, in Alt-Tab order."""
    if not SUPPORTED:
        return []
    titles = []

    def each(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            title = window_title(hwnd).strip()
            if title and title not in skip_titles and title not in titles \
                    and title != "Program Manager":
                titles.append(title)
        return True

    user32.EnumWindows(WNDENUMPROC(each), 0)
    return titles


def find_window(title):
    """The window with this exact title, or else one whose title contains it."""
    if not SUPPORTED:
        return None
    exact, partial = [], []

    def each(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            text = window_title(hwnd)
            if text == title:
                exact.append(hwnd)
            elif title.lower() in text.lower():
                partial.append(hwnd)
        return True

    user32.EnumWindows(WNDENUMPROC(each), 0)
    found = exact or partial
    return found[0] if found else None


def is_alive(hwnd):
    return bool(user32.IsWindow(hwnd))


def is_minimized(hwnd):
    return bool(user32.IsIconic(hwnd))


def client_area(hwnd):
    """The window's inside as a screen rectangle (mss style dict)."""
    rect = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return {"left": pt.x, "top": pt.y, "width": rect.right, "height": rect.bottom}


def capture(hwnd):
    """The window's inside (no title bar) as a BGR image, even when covered.
    Returns None when it can't be captured (closed, minimized, zero size)."""
    rect = wintypes.RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
        return None
    w, h = rect.right - rect.left, rect.bottom - rect.top
    if w <= 0 or h <= 0:
        return None
    hdc = user32.GetDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    old = gdi32.SelectObject(mem, bmp)
    try:
        ok = user32.PrintWindow(hwnd, mem, PW_CLIENTONLY | PW_RENDERFULLCONTENT)
        gdi32.SelectObject(mem, old)  # GetDIBits needs the bitmap unselected
        old = None
        if not ok:
            return None
        info = BITMAPINFOHEADER(ctypes.sizeof(BITMAPINFOHEADER), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
        pixels = np.empty((h, w, 4), np.uint8)
        if not gdi32.GetDIBits(mem, bmp, 0, h, pixels.ctypes.data, ctypes.byref(info), 0):
            return None
        return np.ascontiguousarray(pixels[:, :, :3])
    finally:
        if old is not None:
            gdi32.SelectObject(mem, old)
        gdi32.DeleteObject(bmp)
        gdi32.DeleteDC(mem)
        user32.ReleaseDC(hwnd, hdc)


def _lparam(x, y):
    return ((int(y) & 0xFFFF) << 16) | (int(x) & 0xFFFF)


def _target(hwnd, x, y):
    """The (child) window under client point (x, y) and the point in its
    coordinates; most games have no children, then it is hwnd itself."""
    pt = wintypes.POINT(int(x), int(y))
    for _ in range(10):  # walk down to the deepest window at that point
        child = user32.ChildWindowFromPointEx(hwnd, pt, 0x1 | 0x2 | 0x4)  # skip hidden/disabled/clear
        if not child or child == hwnd:
            break
        user32.MapWindowPoints(hwnd, child, ctypes.byref(pt), 1)
        hwnd = child
    return hwnd, pt.x, pt.y


def click(hwnd, x, y, clicks=2, move_time=0.12, hold=0.03, gap=0.05):
    """Click client point (x, y) of the window without moving the real mouse.

    The pointer is first 'moved' there with a short trail of mouse-move
    messages (games tend to ignore a click that comes out of nowhere).
    """
    target, tx, ty = _target(hwnd, x, y)
    post = user32.PostMessageW
    steps = max(1, int(move_time / 0.01))
    for i in range(steps + 1):
        k = i / steps
        post(target, WM_MOUSEMOVE, 0, _lparam(tx - 30 * (1 - k), ty - 30 * (1 - k)))
        if move_time:
            time.sleep(move_time / steps)
    for i in range(clicks):
        if i:
            time.sleep(gap)
        post(target, WM_LBUTTONDOWN, MK_LBUTTON, _lparam(tx, ty))
        time.sleep(hold)
        post(target, WM_LBUTTONUP, 0, _lparam(tx, ty))


def make_test_window(title, clicks):
    """A bare window (for the build's self-test) that adds the point of every
    left click it receives to `clicks`. Messages are pumped by Tk's loop."""
    WNDPROC = ctypes.WINFUNCTYPE(ctypes.c_ssize_t, HWND, wintypes.UINT,
                                 wintypes.WPARAM, wintypes.LPARAM)
    user32.DefWindowProcW.argtypes = [HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.DefWindowProcW.restype = ctypes.c_ssize_t

    def proc(hwnd, msg, wparam, lparam):
        if msg == WM_LBUTTONDOWN:
            clicks.append((lparam & 0xFFFF, (lparam >> 16) & 0xFFFF))
        return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

    class WNDCLASS(ctypes.Structure):
        _fields_ = [("style", wintypes.UINT), ("lpfnWndProc", WNDPROC),
                    ("cbClsExtra", ctypes.c_int), ("cbWndExtra", ctypes.c_int),
                    ("hInstance", wintypes.HINSTANCE), ("hIcon", wintypes.HICON),
                    ("hCursor", wintypes.HANDLE), ("hbrBackground", wintypes.HBRUSH),
                    ("lpszMenuName", wintypes.LPCWSTR), ("lpszClassName", wintypes.LPCWSTR)]

    callback = WNDPROC(proc)
    wc = WNDCLASS(lpfnWndProc=callback, lpszClassName="AutoClickerTest")
    user32.RegisterClassW.argtypes = [ctypes.POINTER(WNDCLASS)]
    user32.RegisterClassW(ctypes.byref(wc))
    user32.CreateWindowExW.argtypes = [wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR,
                                       wintypes.DWORD, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                       ctypes.c_int, HWND, wintypes.HMENU, wintypes.HINSTANCE,
                                       ctypes.c_void_p]
    user32.CreateWindowExW.restype = HWND
    hwnd = user32.CreateWindowExW(0, "AutoClickerTest", title, 0x10CF0000,  # visible overlapped
                                  100, 100, 400, 300, None, None, None, None)
    return hwnd, callback  # keep the callback alive while the window exists
