# Teleprompter

A small, compact teleprompter for macOS. It is a borderless window that floats above everything
(including full-screen video calls), so you can park it right under the camera and read while
keeping eye contact.

Native SwiftUI + AppKit, no dependencies.

## Features

- Smooth auto-scroll with adjustable speed, play/pause, restart, jump back 5 s
- Countdown before the scroll starts
- Reading-line guide, elapsed / total time
- Font size, line spacing, margins, colour theme, window opacity
- Horizontal and vertical mirroring for beam-splitter glass
- Hidden from screen sharing and recordings (on by default)
- Scroll by voice, using on-device speech recognition only
- Script editor with paste and `.txt` / `.md` import; script and settings are saved automatically
- Global hotkeys that work while another app has focus, no Accessibility permission needed

| Hotkey | Action |
| --- | --- |
| ⌃⌥ Space | Play / pause |
| ⌃⌥ ↑ / ↓ | Faster / slower |
| ⌃⌥ ← | Jump back 5 s |
| ⌃⌥ R | Restart |
| ⌃⌥ H | Show / hide the prompter |

## Build

Requires macOS 14+ and the Xcode command line tools.

```bash
./build.sh --run
```

This runs the self-check, compiles `Sources/*.swift` with `swiftc`, and produces an ad-hoc signed
`Teleprompter.app` next to the script.

## Notes

- Drag the prompter anywhere by its background; resize from the edges. Position is remembered.
- The control bar fades out while scrolling and returns on hover.
- Voice scroll asks for microphone and speech recognition permission the first time you turn it on.
