"""Screen auto clicker: finds a picture on your screen and clicks it.

1. Take a small screenshot of the thing you want clicked (Windows: Win+Shift+S,
   then paste into Paint and save as PNG) and put it in the targets folder.
2. Run:  python auto_clicker.py targets/my_button.png
3. Stop: press Ctrl+C in this window, or slam the mouse into a screen corner.

Run "python auto_clicker.py --help" for all options.
"""

import argparse
import ctypes
import random
import sys
import time
from pathlib import Path

import cv2
import mss
import numpy as np
import pyautogui

# Moving the mouse into any screen corner stops the program.
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0


def make_dpi_aware():
    """On Windows with display scaling (125%, 150%...), make screenshot pixels
    and mouse coordinates use the same units so clicks land in the right spot."""
    if sys.platform != "win32":
        return
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


def load_templates(paths):
    templates = []
    for path in paths:
        files = sorted(Path(path).glob("*.png")) if Path(path).is_dir() else [Path(path)]
        for file in files:
            image = cv2.imread(str(file), cv2.IMREAD_COLOR)
            if image is None:
                sys.exit(f"Could not read image: {file}")
            templates.append((file.name, image))
    if not templates:
        sys.exit("No target images found. Put PNG screenshots of what to click in the targets folder.")
    return templates


def find_matches(screen, template, confidence, scales):
    """Return [(score, center_x, center_y)] for every spot where template appears."""
    matches = []
    for scale in scales:
        if scale == 1.0:
            scaled = template
        else:
            scaled = cv2.resize(template, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
        h, w = scaled.shape[:2]
        if h > screen.shape[0] or w > screen.shape[1] or h < 4 or w < 4:
            continue
        result = cv2.matchTemplate(screen, scaled, cv2.TM_CCOEFF_NORMED)
        ys, xs = np.where(result >= confidence)
        for x, y in zip(xs, ys):
            matches.append((float(result[y, x]), int(x + w / 2), int(y + h / 2), max(w, h)))

    # Keep only the best match in each area (drop overlapping duplicates).
    matches.sort(reverse=True)
    kept = []
    for score, x, y, size in matches:
        if all(abs(x - kx) > size / 2 or abs(y - ky) > size / 2 for _, kx, ky, _ in kept):
            kept.append((score, x, y, size))
    return [(score, x, y) for score, x, y, _ in kept]


def main():
    parser = argparse.ArgumentParser(description="Find a picture on screen and click it automatically.")
    parser.add_argument("targets", nargs="+", help="PNG image(s) of what to click, or a folder of PNGs")
    parser.add_argument("--confidence", type=float, default=0.85,
                        help="how close the match must be, 0-1 (default 0.85; lower = looser)")
    parser.add_argument("--interval", type=float, default=0.5, help="seconds between screen checks (default 0.5)")
    parser.add_argument("--cooldown", type=float, default=1.0,
                        help="seconds to wait after a click before looking again (default 1.0)")
    parser.add_argument("--all", action="store_true", help="click every match on screen, not just the best one")
    parser.add_argument("--button", choices=["left", "right", "middle"], default="left")
    parser.add_argument("--clicks", type=int, default=1, help="clicks per match (2 = double click)")
    parser.add_argument("--offset", type=int, nargs=2, default=(0, 0), metavar=("X", "Y"),
                        help="click this many pixels away from the match center")
    parser.add_argument("--region", type=int, nargs=4, metavar=("LEFT", "TOP", "WIDTH", "HEIGHT"),
                        help="only search this part of the screen (faster)")
    parser.add_argument("--monitor", type=int, default=1, help="which monitor to watch (1 = main)")
    parser.add_argument("--scales", type=float, nargs="+", default=[1.0],
                        help="also try the image at these sizes, e.g. --scales 0.8 1 1.25")
    parser.add_argument("--once", action="store_true", help="stop after the first click")
    parser.add_argument("--max-clicks", type=int, default=0, help="stop after this many clicks (0 = no limit)")
    parser.add_argument("--no-return", action="store_true",
                        help="leave the mouse where it clicked instead of moving it back")
    parser.add_argument("--dry-run", action="store_true", help="only print what would be clicked")
    args = parser.parse_args()

    make_dpi_aware()
    templates = load_templates(args.targets)

    with mss.mss() as sct:
        if args.region:
            left, top, width, height = args.region
            area = {"left": left, "top": top, "width": width, "height": height}
        else:
            if args.monitor >= len(sct.monitors):
                sys.exit(f"Monitor {args.monitor} not found ({len(sct.monitors) - 1} monitor(s) connected).")
            area = sct.monitors[args.monitor]

        names = ", ".join(name for name, _ in templates)
        print(f"Watching for: {names}")
        print("Stop with Ctrl+C, or move the mouse into a screen corner.")

        total = 0
        try:
            while True:
                screen = cv2.cvtColor(np.array(sct.grab(area)), cv2.COLOR_BGRA2BGR)
                clicked = False
                for name, template in templates:
                    matches = find_matches(screen, template, args.confidence, args.scales)
                    if not matches:
                        continue
                    for score, x, y in matches if args.all else matches[:1]:
                        sx = area["left"] + x + args.offset[0]
                        sy = area["top"] + y + args.offset[1]
                        print(f"[{time.strftime('%H:%M:%S')}] {name} at ({sx}, {sy}) match {score:.2f}"
                              + (" (dry run)" if args.dry_run else ""))
                        if not args.dry_run:
                            before = pyautogui.position()
                            pyautogui.click(sx, sy, clicks=args.clicks, interval=0.05, button=args.button)
                            if not args.no_return:
                                pyautogui.moveTo(before)
                        clicked = True
                        total += 1
                        if args.once or (args.max_clicks and total >= args.max_clicks):
                            print(f"Done after {total} click(s).")
                            return
                # A little randomness so the timing doesn't look robotic.
                time.sleep((args.cooldown if clicked else args.interval) * random.uniform(0.9, 1.1))
        except KeyboardInterrupt:
            print(f"\nStopped. Clicked {total} time(s).")
        except pyautogui.FailSafeException:
            print(f"\nStopped by moving the mouse into a corner. Clicked {total} time(s).")


if __name__ == "__main__":
    main()
