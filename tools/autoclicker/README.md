# Image-detect auto clicker

Give it a picture of a button (or anything else), and it keeps looking for
that picture on your screen and clicks its center whenever it shows up.

## Easy way: AutoClicker.exe (Windows)

1. Open **AutoClicker.exe**. If Windows says "Windows protected your PC",
   click **More info**, then **Run anyway** (the app isn't signed, that's all).
2. **Step 1:** press **Take from screen**, then drag a box around the button
   you want clicked. You can add more than one picture.
3. **Step 2:** press **START** (or your start/stop key, **F8** unless you
   change it) and open your game. The window hides itself and watches the
   screen nonstop. When the picture shows up it glides the mouse there
   (0.12 s), looks once more in case it moved, and clicks it twice, about
   0.2-0.25 s after it appeared. Games like Roblox ignore a mouse that just
   teleports, which is why it glides.
4. Press the start/stop key again to stop. Pushing the mouse into a screen
   corner also stops it.
5. **Start / stop key:** click the key button and press any key to use that
   one instead of F8 (some keyboards send F8 only with Fn).
6. **Step 3, Anti-AFK (optional):** switch it **ON** and it presses Space
   every N seconds, so games don't kick you for being idle. It runs on its
   own, whether the clicker is started or not.

By default it matches the picture's outline and edge directions, not its
colors, so a button that flashes colors, shakes, tilts up to about 25°, or
gets motion-blurred is still found. "How exact must it match?" (in
**Settings...**) starts at 30%: 0% is what random screen content scores and
100% is a perfect copy. If it clicks wrong things, raise it; if it misses
the picture, lower it. Pictures and settings are kept for next time (in
`%APPDATA%\ImageAutoClicker`).

The .exe is built by the "Build Auto Clicker .exe" GitHub Action on every
change to this folder (download it from the run's artifacts). To run from
source instead: `pip install -r requirements.txt`, then `python gui.py`.

## Command line

Needs Python 3.9+.

```bash
cd tools/autoclicker
pip install -r requirements.txt
```

macOS: allow your terminal under System Settings → Privacy & Security →
**Screen Recording** and **Accessibility**, or it can't see the screen or click.

### 1. Make the reference image

Take a screenshot (Windows: `Win+Shift+S`, macOS: `Cmd+Shift+4`) and crop it
tightly around the thing to click, for example `hatch.png`. Take it at the
same window size / zoom you'll play at. A PNG with a transparent background
is fine: transparent pixels are ignored while matching.

### 2. Run it

```bash
python autoclicker.py hatch.png
```

You get 3 seconds to switch to the game, then it checks the screen every
0.5 s and clicks when it finds the image.

- **F8** stops it, **F7** pauses / resumes.
- Emergency stop: move the mouse into any screen corner (or Ctrl+C in the
  terminal).

### Tuning

First check what it sees without clicking:

```bash
python autoclicker.py hatch.png --dry-run
```

Each line shows the match score. If it clicks the wrong things, raise
`--confidence`; if it misses the button, lower it.

| Option | Default | What it does |
|---|---|---|
| `-c`, `--confidence` | 0.85 | Match threshold 0–1, higher is stricter |
| `-i`, `--interval` | 0 | Pause between screen checks (0 = nonstop) |
| `--stop-key` / `--pause-key` | f8 / f7 | Hotkeys (e.g. `f6`, `esc`, `q`) |
| `--all` | off | Click every copy on screen, not just the best one |
| `--scales` | 1 | Template sizes to try, e.g. `0.8,0.9,1,1.1,1.25` if the window size changes |
| `--any-color` | off | Match the outline, so the picture is found in any color |
| `--grayscale` | off | Ignore colors (faster) |
| `--region` | whole screen | Only search `x,y,width,height` (faster) |
| `--monitor` | 1 | 1 = main screen, 2 = second, 0 = all screens |
| `--button` / `--clicks` | left / 2 | Mouse button, and clicks per hit |
| `--move-time` | 0.12 | Seconds the mouse takes to glide to the target |
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
