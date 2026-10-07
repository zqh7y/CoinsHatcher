"""Image Auto Clicker: a small window around autoclicker.py.

Add the picture(s) to look for, press Start (or F8), and it clicks them
whenever they show up on screen. F8 starts / stops from inside the game too.
"""

import json
import queue
import threading
import time
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

import cv2

from autoclicker import click, find_matches, grab, load_template

HERE = Path(__file__).resolve().parent  # picture paths may be relative to here
SETTINGS = HERE / "settings.json"
IMAGES_DIR = HERE / "images"
HOTKEY = "f8"
SIZE_SCALES = (0.9, 1.0, 1.1)


class ClickerThread(threading.Thread):
    """Watches the screen and clicks. Talks to the window through `events`."""

    def __init__(self, images, confidence, interval, click_all, grayscale,
                 any_size, start_delay, events):
        super().__init__(daemon=True)
        self.images = images
        self.confidence = confidence
        self.interval = interval
        self.click_all = click_all
        self.grayscale = grayscale
        self.scales = SIZE_SCALES if any_size else (1.0,)
        self.start_delay = start_delay
        self.events = events
        self.stop_event = threading.Event()

    def stop(self):
        self.stop_event.set()

    def run(self):
        try:
            self._run()
        except Exception as e:  # show the problem instead of dying silently
            self.events.put(("error", str(e)))
        finally:
            self.events.put(("stopped", None))

    def _run(self):
        import mss
        import pyautogui

        pyautogui.PAUSE = 0.02
        pyautogui.FAILSAFE = True  # mouse into a screen corner = emergency stop

        templates = []
        for path in self.images:
            tpl, mask = load_template(HERE / path, grayscale=self.grayscale)
            templates.append((Path(path).name, tpl, mask))

        for left in range(int(self.start_delay), 0, -1):
            self.events.put(("status", f"Starting in {left}... switch to your game"))
            if self.stop_event.wait(1):
                return
        self.events.put(("status", f"Watching the screen. Press {HOTKEY.upper()} to stop."))

        clicks = 0
        with mss.mss() as sct:
            area = sct.monitors[0]  # every screen together
            while not self.stop_event.is_set():
                screen, factor = grab(sct, area)
                if self.grayscale:
                    screen = cv2.cvtColor(screen, cv2.COLOR_BGR2GRAY)
                for name, tpl, mask in templates:
                    matches = find_matches(screen, tpl, self.confidence, self.scales,
                                           mask=mask, find_all=self.click_all)
                    if not self.click_all:
                        matches = matches[:1]
                    for cx, cy, score in matches:
                        if self.stop_event.is_set():
                            return
                        x = area["left"] + round(cx * factor)
                        y = area["top"] + round(cy * factor)
                        click(pyautogui, x, y, "left", 1)
                        clicks += 1
                        self.events.put(("click", (clicks, name, x, y, score)))
                self.stop_event.wait(self.interval)


class App:
    def __init__(self, root):
        self.root = root
        self.worker = None
        self.events = queue.Queue()
        root.title("Image Auto Clicker")
        root.minsize(420, 0)

        pad = {"padx": 10, "pady": 4}

        ttk.Label(root, text="Pictures to click:").grid(row=0, column=0, sticky="w", **pad)
        self.listbox = tk.Listbox(root, height=6, selectmode=tk.SINGLE)
        self.listbox.grid(row=1, column=0, columnspan=3, sticky="nsew", padx=10)

        buttons = ttk.Frame(root)
        buttons.grid(row=2, column=0, columnspan=3, sticky="w", **pad)
        ttk.Button(buttons, text="Add picture...", command=self.add_images).pack(side="left")
        ttk.Button(buttons, text="Crop selected", command=self.crop_selected).pack(side="left", padx=6)
        ttk.Button(buttons, text="Remove", command=self.remove_selected).pack(side="left")

        ttk.Label(root, text="Match strictness:").grid(row=3, column=0, sticky="w", **pad)
        self.confidence = tk.DoubleVar(value=0.8)
        self.conf_label = ttk.Label(root, width=5)
        ttk.Scale(root, from_=0.5, to=0.99, variable=self.confidence,
                  command=lambda _: self._show_confidence()).grid(row=3, column=1, sticky="ew", **pad)
        self.conf_label.grid(row=3, column=2, sticky="w")
        ttk.Label(root, text="lower = finds more, but may click wrong things",
                  foreground="gray").grid(row=4, column=0, columnspan=3, sticky="w", padx=10)

        ttk.Label(root, text="Check every (seconds):").grid(row=5, column=0, sticky="w", **pad)
        self.interval = tk.DoubleVar(value=0.5)
        ttk.Spinbox(root, from_=0.05, to=60, increment=0.1, width=8,
                    textvariable=self.interval).grid(row=5, column=1, sticky="w", **pad)

        self.click_all = tk.BooleanVar(value=False)
        self.grayscale = tk.BooleanVar(value=False)
        self.any_size = tk.BooleanVar(value=True)
        ttk.Checkbutton(root, text="Click every copy on screen, not just the best one",
                        variable=self.click_all).grid(row=6, column=0, columnspan=3, sticky="w", padx=10)
        ttk.Checkbutton(root, text="Also find it a bit bigger or smaller",
                        variable=self.any_size).grid(row=7, column=0, columnspan=3, sticky="w", padx=10)
        ttk.Checkbutton(root, text="Ignore colors",
                        variable=self.grayscale).grid(row=8, column=0, columnspan=3, sticky="w", padx=10)

        self.start_button = ttk.Button(root, text=f"Start ({HOTKEY.upper()})", command=self.toggle)
        self.start_button.grid(row=9, column=0, columnspan=3, sticky="ew", padx=10, pady=10)

        self.status = ttk.Label(root, text="Add a picture, then press Start.", wraplength=400)
        self.status.grid(row=10, column=0, columnspan=3, sticky="w", padx=10)
        self.last_click = ttk.Label(root, text="", foreground="gray")
        self.last_click.grid(row=11, column=0, columnspan=3, sticky="w", padx=10, pady=(0, 10))

        root.columnconfigure(1, weight=1)
        root.rowconfigure(1, weight=1)

        self.load_settings()
        self._show_confidence()
        self.start_hotkey()
        root.protocol("WM_DELETE_WINDOW", self.close)
        root.after(100, self.poll_events)

    # --- pictures -----------------------------------------------------------

    def images(self):
        return list(self.listbox.get(0, tk.END))

    def add_images(self):
        paths = filedialog.askopenfilenames(
            title="Pick the picture(s) to click",
            filetypes=[("Pictures", "*.png *.jpg *.jpeg *.bmp"), ("All files", "*.*")])
        for path in paths:
            if path not in self.images():
                self.listbox.insert(tk.END, path)
        self.save_settings()

    def remove_selected(self):
        for i in reversed(self.listbox.curselection()):
            self.listbox.delete(i)
        self.save_settings()

    def crop_selected(self):
        sel = self.listbox.curselection()
        if not sel:
            messagebox.showinfo("Crop", "Select a picture in the list first.")
            return
        path = self.listbox.get(sel[0])
        image = cv2.imread(str(HERE / path), cv2.IMREAD_UNCHANGED)
        if image is None:
            messagebox.showerror("Crop", f"Could not open {path}")
            return
        title = "Drag a box around the part to click, then press Enter (Esc = cancel)"
        shown = cv2.cvtColor(image, cv2.COLOR_BGRA2BGR) if image.ndim == 3 and image.shape[2] == 4 else image
        x, y, w, h = cv2.selectROI(title, shown, showCrosshair=False)
        cv2.destroyWindow(title)
        if w < 4 or h < 4:
            return
        IMAGES_DIR.mkdir(exist_ok=True)
        out = IMAGES_DIR / f"{Path(path).stem}_crop_{int(time.time())}.png"
        cv2.imwrite(str(out), image[y:y + h, x:x + w])
        self.listbox.delete(sel[0])
        self.listbox.insert(sel[0], str(out))
        self.save_settings()
        self.status.config(text=f"Cropped picture saved to {out.name}.")

    # --- start / stop -------------------------------------------------------

    def toggle(self):
        if self.worker:
            self.worker.stop()
            self.status.config(text="Stopping...")
            return
        images = self.images()
        if not images:
            messagebox.showinfo("Image Auto Clicker", "Add a picture to look for first.")
            return
        try:
            interval = max(0.05, float(self.interval.get()))
        except (tk.TclError, ValueError):
            interval = 0.5
        self.save_settings()
        self.worker = ClickerThread(
            images, round(self.confidence.get(), 2), interval, self.click_all.get(),
            self.grayscale.get(), self.any_size.get(), 3, self.events)
        self.worker.start()
        self.start_button.config(text=f"Stop ({HOTKEY.upper()})")
        self.last_click.config(text="")

    def start_hotkey(self):
        try:
            from pynput import keyboard
        except ImportError:
            return

        def on_press(key):
            if getattr(key, "name", None) == HOTKEY:
                self.root.after(0, self.toggle)

        listener = keyboard.Listener(on_press=on_press)
        listener.daemon = True
        listener.start()

    def poll_events(self):
        while True:
            try:
                kind, data = self.events.get_nowait()
            except queue.Empty:
                break
            if kind == "status":
                self.status.config(text=data)
            elif kind == "click":
                count, name, x, y, score = data
                self.last_click.config(
                    text=f"Clicks: {count}. Last: {name} at ({x}, {y}), match {score:.0%}")
            elif kind == "error":
                if "FailSafe" in data:
                    data = "Emergency stop: the mouse went into a screen corner."
                messagebox.showerror("Image Auto Clicker", data)
            elif kind == "stopped":
                self.worker = None
                self.start_button.config(text=f"Start ({HOTKEY.upper()})")
                self.status.config(text="Stopped.")
        self.root.after(100, self.poll_events)

    # --- settings -----------------------------------------------------------

    def _show_confidence(self):
        self.conf_label.config(text=f"{self.confidence.get():.0%}")

    def load_settings(self):
        try:
            data = json.loads(SETTINGS.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        for path in data.get("images", []):
            self.listbox.insert(tk.END, path)
        self.confidence.set(data.get("confidence", 0.8))
        self.interval.set(data.get("interval", 0.5))
        self.click_all.set(data.get("click_all", False))
        self.grayscale.set(data.get("grayscale", False))
        self.any_size.set(data.get("any_size", True))

    def save_settings(self):
        try:
            interval = float(self.interval.get())
        except (tk.TclError, ValueError):
            interval = 0.5
        data = {
            "images": self.images(),
            "confidence": round(self.confidence.get(), 2),
            "interval": interval,
            "click_all": self.click_all.get(),
            "grayscale": self.grayscale.get(),
            "any_size": self.any_size.get(),
        }
        try:
            SETTINGS.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except OSError:
            pass

    def close(self):
        if self.worker:
            self.worker.stop()
        self.save_settings()
        self.root.destroy()


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
