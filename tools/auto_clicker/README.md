# Screen auto clicker

Watches your screen for a picture and clicks it whenever it shows up.

## Setup (once)
1. Install Python 3 from https://python.org (tick "Add Python to PATH").
2. In this folder run: `pip install -r requirements.txt`

## Use
1. Screenshot **just** the thing to click (Windows: `Win+Shift+S`, paste into
   Paint, save as PNG) into the `targets` folder, e.g. `targets/button.png`.
   Keep it small and tight around the button, without changing backgrounds.
2. Run: `python auto_clicker.py targets/button.png`
   (or `python auto_clicker.py targets` to watch for every PNG in the folder).
3. Stop: `Ctrl+C` in the window, or move the mouse into a screen corner.

## Useful options
| Option | What it does |
|---|---|
| `--dry-run` | Only prints what it finds; test this first |
| `--confidence 0.75` | Looser match if it never finds it (default 0.85); raise it if it clicks wrong things |
| `--interval 0.2` | Check the screen more often (seconds) |
| `--cooldown 2` | Wait longer after each click |
| `--all` | Click every copy on screen, not just the best one |
| `--once` / `--max-clicks 50` | Stop after 1 / 50 clicks |
| `--clicks 2`, `--button right` | Double click / right click |
| `--offset 0 30` | Click 30 px below the picture instead of on it |
| `--region 0 0 800 600` | Only search part of the screen (left top width height) |
| `--scales 0.8 1 1.25` | Also find the picture if it shows up smaller/bigger |
| `--monitor 2` | Watch the second monitor |

If clicks land in the wrong place, your game window may be in a different
size/zoom than when you took the screenshot: retake it, or use `--scales`.
