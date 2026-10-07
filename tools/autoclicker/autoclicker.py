"""Image-detect auto clicker.

Finds a reference image on screen with OpenCV template matching and clicks
its center, over and over, until you press the stop hotkey.

Run `python autoclicker.py --help` for all options.
"""

import argparse
import sys
import threading
import time
from pathlib import Path

import cv2
import numpy as np

MAX_CANDIDATES = 2000
COARSE_MIN_SIDE = 40  # templates this big get the fast half-size search
COARSE_SLACK = 0.15   # the rough pass accepts slightly worse scores
REFINE_MARGIN = 6     # pixels around a rough hit to search again at full size
MAX_REFINE = 50


# ---------------------------------------------------------------------------
# Matching (pure functions, no screen or mouse needed)
# ---------------------------------------------------------------------------

def load_template(path, grayscale=False):
    """Load a reference image. Transparent pixels become a match mask."""
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise FileNotFoundError(f"Could not read image: {path}")

    mask = None
    if image.ndim == 3 and image.shape[2] == 4:
        alpha = image[:, :, 3]
        if alpha.min() < 255:
            mask = cv2.merge([alpha, alpha, alpha]) if not grayscale else alpha
        image = cv2.cvtColor(image, cv2.COLOR_BGRA2BGR)
    elif image.ndim == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)

    if grayscale:
        image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return image, mask


def find_matches(screen, template, confidence, scales=(1.0,), mask=None,
                 find_all=False):
    """Return [(x, y, score), ...] centers of matches in `screen`, best first
    (only the single best one unless `find_all`).

    `screen` and `template` must both be BGR or both grayscale. Each scale
    resizes the template, so the image still matches when the game is shown
    a bit bigger or smaller than when you took the screenshot.

    Big templates are first searched on a half-size copy of the screen (about
    4x faster), and each rough hit is then checked again at full size.
    """
    matches = []
    half_screen = None
    for scale in scales:
        tpl, tpl_mask = _resize(template, mask, scale)
        th, tw = tpl.shape[:2]
        if th < 4 or tw < 4 or th > screen.shape[0] or tw > screen.shape[1]:
            continue

        if min(th, tw) < COARSE_MIN_SIDE:
            matches += _match(screen, tpl, tpl_mask, confidence, find_all)
            continue

        if half_screen is None:
            half_screen = cv2.resize(screen, None, fx=0.5, fy=0.5,
                                     interpolation=cv2.INTER_AREA)
        half_tpl, half_mask = _resize(tpl, tpl_mask, 0.5)
        rough = _suppress_overlaps(
            _match(half_screen, half_tpl, half_mask, confidence - COARSE_SLACK, True))
        for cx, cy, _, _, _ in rough[:MAX_REFINE if find_all else 5]:
            x0 = max(0, cx * 2 - tw // 2 - REFINE_MARGIN)
            y0 = max(0, cy * 2 - th // 2 - REFINE_MARGIN)
            window = screen[y0:y0 + th + 2 * REFINE_MARGIN, x0:x0 + tw + 2 * REFINE_MARGIN]
            if window.shape[0] < th or window.shape[1] < tw:
                continue
            for x, y, score, _, _ in _match(window, tpl, tpl_mask, confidence, False):
                matches.append((x + x0, y + y0, score, tw, th))

    matches.sort(key=lambda m: m[2], reverse=True)
    if not find_all:
        matches = matches[:1]
    return [(cx, cy, score) for cx, cy, score, _, _ in _suppress_overlaps(matches)]


def _resize(template, mask, scale):
    if scale == 1.0:
        return template, mask
    tpl = cv2.resize(template, None, fx=scale, fy=scale,
                     interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_LINEAR)
    if mask is not None:
        mask = cv2.resize(mask, (tpl.shape[1], tpl.shape[0]),
                          interpolation=cv2.INTER_NEAREST)
    return tpl, mask


def _match(screen, tpl, mask, threshold, find_all):
    """Raw matches [(cx, cy, score, tw, th), ...] of one template size."""
    th, tw = tpl.shape[:2]
    result = cv2.matchTemplate(screen, tpl, cv2.TM_CCOEFF_NORMED, mask=mask)
    result = np.nan_to_num(result, nan=0.0, posinf=0.0, neginf=0.0)

    if not find_all:
        _, score, _, (x, y) = cv2.minMaxLoc(result)
        return [(x + tw // 2, y + th // 2, float(score), tw, th)] if score >= threshold else []

    ys, xs = np.where(result >= threshold)
    if len(xs) > MAX_CANDIDATES:  # threshold far too low, keep the best
        best = np.argsort(result[ys, xs])[-MAX_CANDIDATES:]
        ys, xs = ys[best], xs[best]
    found = [(int(x) + tw // 2, int(y) + th // 2, float(result[y, x]), tw, th)
             for x, y in zip(xs, ys)]
    found.sort(key=lambda m: m[2], reverse=True)
    return found


def _suppress_overlaps(matches):
    """Keep the best match in each spot, drop the near-duplicates around it.
    `matches` must be sorted best first."""
    kept = []
    for cx, cy, score, tw, th in matches:
        if all(abs(cx - kx) > max(tw, kw) / 2 or abs(cy - ky) > max(th, kh) / 2
               for kx, ky, _, kw, kh in kept):
            kept.append((cx, cy, score, tw, th))
    return kept


def parse_scales(text):
    """'0.8,1,1.25' -> (0.8, 1.0, 1.25)"""
    scales = tuple(float(s) for s in text.split(",") if s.strip())
    if not scales or any(s <= 0 for s in scales):
        raise argparse.ArgumentTypeError("scales must be positive numbers, e.g. 0.9,1,1.1")
    return scales


def parse_region(text):
    """'x,y,width,height' in screen pixels."""
    parts = [int(p) for p in text.split(",")]
    if len(parts) != 4 or parts[2] <= 0 or parts[3] <= 0:
        raise argparse.ArgumentTypeError("region must be x,y,width,height")
    return dict(zip(("left", "top", "width", "height"), parts))


# ---------------------------------------------------------------------------
# Screen, mouse and hotkeys
# ---------------------------------------------------------------------------

class Controls:
    """Stop / pause hotkeys, read from a background keyboard listener."""

    def __init__(self, stop_key, pause_key):
        self.stop = threading.Event()
        self.paused = False
        self._listener = None
        try:
            from pynput import keyboard
        except ImportError:
            print("pynput is not installed: hotkeys are off, use Ctrl+C to stop.")
            return

        def key_name(key):
            return getattr(key, "name", None) or getattr(key, "char", None)

        def on_press(key):
            name = (key_name(key) or "").lower()
            if name == stop_key:
                print(f"\n[{stop_key.upper()}] stopping.")
                self.stop.set()
                return False
            if name == pause_key:
                self.paused = not self.paused
                print(f"\n[{pause_key.upper()}] {'paused' if self.paused else 'resumed'}.")

        self._listener = keyboard.Listener(on_press=on_press)
        self._listener.daemon = True
        self._listener.start()

    def wait(self, seconds):
        """Sleep, but wake up right away when the stop key is pressed."""
        return self.stop.wait(seconds)


def open_screen():
    """Screen grabber (newer mss renamed mss.mss to mss.MSS)."""
    import mss
    return mss.MSS() if hasattr(mss, "MSS") else mss.mss()


def grab(sct, area):
    """Screenshot `area` as BGR, plus the factor from image pixels to mouse
    coordinates (Retina / HiDPI screens capture more pixels than points)."""
    shot = np.asarray(sct.grab(area))
    bgr = cv2.cvtColor(shot, cv2.COLOR_BGRA2BGR)
    factor = area["width"] / bgr.shape[1]
    return bgr, factor


def click(pyautogui, x, y, button, clicks):
    # Games such as Roblox often ignore a click unless the mouse moved onto
    # the spot first, so move, nudge one pixel, then click.
    pyautogui.moveTo(x, y)
    pyautogui.moveRel(1, 0)
    pyautogui.moveRel(-1, 0)
    pyautogui.click(x=x, y=y, clicks=clicks, button=button)


def run(args):
    import pyautogui

    pyautogui.PAUSE = 0.02
    pyautogui.FAILSAFE = True  # slam the mouse into a screen corner to abort

    templates = []
    for path in args.images:
        tpl, mask = load_template(path, grayscale=args.grayscale)
        templates.append((Path(path).name, tpl, mask))

    controls = Controls(args.stop_key.lower(), args.pause_key.lower())

    with open_screen() as sct:
        if args.region:
            area = args.region
        else:
            if args.monitor >= len(sct.monitors):
                sys.exit(f"Monitor {args.monitor} does not exist "
                         f"(found {len(sct.monitors) - 1}).")
            area = sct.monitors[args.monitor]

        names = ", ".join(name for name, _, _ in templates)
        print(f"Looking for {names} (confidence {args.confidence}, "
              f"every {args.interval}s).")
        print(f"Press {args.stop_key.upper()} to stop, "
              f"{args.pause_key.upper()} to pause/resume.")
        if args.dry_run:
            print("Dry run: matches are printed, nothing is clicked.")

        if controls.wait(args.start_delay):
            return

        total = 0
        last_seen = time.monotonic()
        while not controls.stop.is_set():
            if controls.paused:
                controls.wait(0.2)
                continue

            screen, factor = grab(sct, area)
            if args.grayscale:
                screen = cv2.cvtColor(screen, cv2.COLOR_BGR2GRAY)

            clicked = False
            for name, tpl, mask in templates:
                matches = find_matches(screen, tpl, args.confidence, args.scales,
                                       mask=mask, find_all=args.all)
                if not args.all:
                    matches = matches[:1]
                for cx, cy, score in matches:
                    x = area["left"] + round(cx * factor)
                    y = area["top"] + round(cy * factor)
                    total += 1
                    action = "found" if args.dry_run else "click"
                    print(f"{action} #{total}: {name} at ({x}, {y}) score {score:.2f}")
                    if not args.dry_run:
                        click(pyautogui, x, y, args.button, args.clicks)
                    clicked = True
                    if args.max_clicks and total >= args.max_clicks:
                        print(f"Reached {args.max_clicks} clicks, stopping.")
                        return
                if clicked and args.first_only:
                    break

            if clicked:
                last_seen = time.monotonic()
            elif args.timeout and time.monotonic() - last_seen > args.timeout:
                print(f"Nothing found for {args.timeout}s, stopping.")
                return

            controls.wait(args.interval)


def build_parser():
    p = argparse.ArgumentParser(
        description="Find a picture on screen and click it automatically.")
    p.add_argument("images", nargs="+",
                   help="reference image(s) to look for (PNG/JPG, cropped tightly)")
    p.add_argument("-c", "--confidence", type=float, default=0.85,
                   help="match threshold 0..1, higher is stricter (default 0.85)")
    p.add_argument("-i", "--interval", type=float, default=0.5,
                   help="seconds between screen checks (default 0.5)")
    p.add_argument("--stop-key", default="f8",
                   help="hotkey that stops the clicker (default F8)")
    p.add_argument("--pause-key", default="f7",
                   help="hotkey that pauses/resumes (default F7)")
    p.add_argument("--all", action="store_true",
                   help="click every match on screen, not just the best one")
    p.add_argument("--first-only", action="store_true",
                   help="with several images, stop at the first one found each round")
    p.add_argument("--scales", type=parse_scales, default=(1.0,),
                   help="template sizes to try, e.g. 0.8,0.9,1,1.1,1.25 (default 1)")
    p.add_argument("--grayscale", action="store_true",
                   help="ignore colors (faster, but can confuse similar shapes)")
    p.add_argument("--region", type=parse_region,
                   help="only search x,y,width,height of the screen (faster)")
    p.add_argument("--monitor", type=int, default=1,
                   help="monitor to search: 1 = main, 2 = second..., 0 = all (default 1)")
    p.add_argument("--button", choices=("left", "right", "middle"), default="left")
    p.add_argument("--clicks", type=int, default=1,
                   help="clicks per hit, 2 = double click (default 1)")
    p.add_argument("--max-clicks", type=int, default=0,
                   help="stop after this many clicks (default 0 = never)")
    p.add_argument("--timeout", type=float, default=0,
                   help="stop when nothing is found for this many seconds (default 0 = never)")
    p.add_argument("--start-delay", type=float, default=3,
                   help="seconds to wait before starting, to switch windows (default 3)")
    p.add_argument("--dry-run", action="store_true",
                   help="print matches without clicking, to tune --confidence")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    if not 0 < args.confidence <= 1:
        sys.exit("--confidence must be between 0 and 1")
    if args.interval < 0:
        sys.exit("--interval can't be negative")
    try:
        run(args)
    except KeyboardInterrupt:
        print("\nStopped.")
    except FileNotFoundError as e:
        sys.exit(str(e))


if __name__ == "__main__":
    main()
