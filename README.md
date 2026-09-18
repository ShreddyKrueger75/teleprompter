# Teleprompter

A small, compact teleprompter for macOS. It is a borderless window that floats above everything
(including full-screen video calls), so you can park it right under the camera and read while
keeping eye contact.

Native SwiftUI + AppKit, no dependencies, sandboxed.

## Features

- **Pace in words per minute**, not pixels, so changing the font, margins or window size never
  changes how long your script takes to read
- **Three camera setups** — under the notch, beside a webcam, behind beam-splitter glass — each
  setting the reading line, type size range and mirroring
- Play/pause, restart, jump back and forward 5 s, countdown before the scroll starts
- Scrub through the script with the trackpad while paused
- Reading-line guide, elapsed/total time, progress hairline
- Font size, line spacing, margins, colour theme, background opacity
- Horizontal and vertical mirroring for beam-splitter glass
- Hidden from screen sharing and recordings (on by default)
- Scroll by voice, using on-device speech recognition only — audio never leaves your Mac
- Script editor with clipboard and file import, every replacement undoable
- Global hotkeys that work while another app has focus, with no Accessibility permission
- Readable over a translucent background, so you can see the call behind it

| Hotkey | Action |
| --- | --- |
| ⌃⌥ Space or ⌃⌥ P | Play / pause |
| ⌃⌥ ↑ / ↓ | Faster / slower |
| ⌃⌥ ← / → | Back / forward 5 s |
| ⌃⌥ R | Restart |
| ⌃⌥ H | Show / hide the prompter |

## Build

Requires macOS 14+ and Xcode.

```bash
./build.sh --run
```

That runs the self-check and builds via `xcodebuild`. To open it in Xcode:

```bash
open Teleprompter.xcodeproj
```

The project is generated from `project.yml` by [xcodegen](https://github.com/yonaskolb/XcodeGen);
run `xcodegen generate` after changing it. The app icon is generated from code by
`swift Tools/makeicon.swift`.

## Notes

- Drag the prompter anywhere by its background; resize from the edges. Position is remembered.
- The control bar fades out two seconds into a read and returns when you move the pointer.
- Voice scroll asks for microphone and speech permission when you switch it on, not mid-take.
  If either is refused, the toggle switches back off and tells you why.
