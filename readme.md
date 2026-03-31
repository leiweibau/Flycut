# Flycut
<p align="center">
<img src="http://a3.mzstatic.com/us/r1000/047/Purple/fb/53/f2/mzi.mcaxwyjm.175x175-75.png">
</p>

Flycut is a clean and simple clipboard manager for developers. Based on the open source app [Jumpcut](https://github.com/snark/jumpcut).

This is a fork of the [haad/Flycut](https://github.com/haad/Flycut/) fork, which is still being maintained

Every time you copy a code piece, Flycut stores it in history. Later, you can paste it using Shift-Command-V even if you have something different in your current clipboard. You can change the hotkey and other settings in preferences.

## Keyboard Shortcuts

### Global

| Shortcut | Action |
|----------|--------|
| Shift+Command+V | Open clipboard history (bezel) |
| Shift+Command+B | Open search window |

### Bezel Navigation

| Shortcut | Action |
|----------|--------|
| Up/Left Arrow or K | Move to newer item |
| Down/Right Arrow or J | Move to older item |
| Home | Jump to most recent item |
| End | Jump to oldest item |
| Page Up / Page Down | Move 10 items forward/back |
| 1-9, 0 | Jump to position (0 = 10th) |
| Scroll Wheel | Navigate history |

### Bezel Actions

| Shortcut | Action |
|----------|--------|
| Return | Paste selected item |
| Fn+Return | Move item to top of history |
| Backspace/Delete | Delete selected item |
| Escape | Close without pasting |
| Double-Click | Paste item |
| Command+, | Open preferences |
| S | Save item to Desktop |
| Shift+S | Save to Desktop and delete |
| F | Toggle favorites store |
| Shift+F | Move item to favorites |
| Space | Pin bezel open (sticky mode) |
| Right-Click | Pin bezel open (sticky mode) |

### Menu Bar

| Shortcut | Action |
|----------|--------|
| Option+Click menu icon | Toggle clipboard tracking on/off |

## Documentation

See the full [Help File](help.md) for more details.

## Develop

Build a universal Release app bundle into `dist` with:

```bash
bash Scripts/package-app.sh
```

**Contributors:**
Check the list of contributors [here](https://github.com/haad/Flycut/graphs/contributors)

**License:**
MIT
