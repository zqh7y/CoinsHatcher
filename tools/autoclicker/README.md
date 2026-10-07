# Image-detect auto clicker

Give it a picture of a button (or anything else), and it keeps looking for
that picture on your screen and clicks its center whenever it shows up.

## Setup

Needs Python 3.9+.

```bash
cd tools/autoclicker
pip install -r requirements.txt
```

macOS: allow your terminal under System Settings → Privacy & Security →
**Screen Recording** and **Accessibility**, or it can't see the screen or click.

## 1. Make the reference image

Take a screenshot (Windows: `Win+Shift+S`, macOS: `Cmd+Shift+4`) and crop it
tightly around the thing to click, for example `hatch.png`. Take it at the
same window size / zoom you'll play at. A PNG with a transparent background
is fine: transparent pixels are ignored while matching.

## 2. Run it

```bash
python autoclicker.py hatch.png
```

You get 3 seconds to switch to the game, then it checks the screen every
0.5 s and clicks when it finds the image.

- **F8** stops it, **F7** pauses / resumes.
- Emergency stop: move the mouse into any screen corner (or Ctrl+C in the
  terminal).

## Tuning

First check what it sees without clicking:

```bash
python autoclicker.py hatch.png --dry-run
```

Each line shows the match score. If it clicks the wrong things, raise
`--confidence`; if it misses the button, lower it.

| Option | Default | What it does |
|---|---|---|
| `-c`, `--confidence` | 0.85 | Match threshold 0–1, higher is stricter |
| `-i`, `--interval` | 0.5 | Seconds between screen checks |
| `--stop-key` / `--pause-key` | f8 / f7 | Hotkeys (e.g. `f6`, `esc`, `q`) |
| `--all` | off | Click every copy on screen, not just the best one |
| `--scales` | 1 | Template sizes to try, e.g. `0.8,0.9,1,1.1,1.25` if the window size changes |
| `--grayscale` | off | Ignore colors (faster) |
| `--region` | whole screen | Only search `x,y,width,height` (faster) |
| `--monitor` | 1 | 1 = main screen, 2 = second, 0 = all screens |
| `--button` / `--clicks` | left / 1 | Mouse button, and 2 for a double click |
| `--max-clicks` | 0 (never) | Stop after this many clicks |
| `--timeout` | 0 (never) | Stop when nothing was found for this many seconds |
| `--start-delay` | 3 | Seconds before it starts |
| `--dry-run` | off | Print matches, don't click |

Several images at once (each round it clicks every one it finds; add
`--first-only` to click only the first one found):

```bash
python autoclicker.py hatch.png claim.png ok.png -c 0.8 -i 1
```

## Tests

```bash
pip install pytest
python -m pytest
```

The tests cover the image matching on generated pictures; they don't need a
screen.
