# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

Note: the app is native **macOS** (SwiftUI + AppKit). Impeccable has no macOS platform value; `ios` is
recorded so tooling treats the project as Apple-native and skips the web-only detector and live mode.
macOS HIG conventions govern (pointer and keyboard input, hover, menus, window behaviour), not iPhone
patterns such as tab bars, 44 pt touch targets, or edge-swipe navigation.

## Users

Creators, marketers, and presenters who read a script to camera. It is a public tool: someone should be
able to pick it up cold and use it without explanation. They are mid-production or about to go live,
their attention belongs to the lens and their delivery, and they will not read documentation.

## Product Purpose

A small, compact teleprompter window that sits next to the camera so the reader keeps eye contact while
delivering a professional read. Success is a read where the viewer cannot tell a script was used, and
where the reader never had to think about the app while reading.

## Positioning

A compact floating window designed to live beside the camera, rather than a full-screen prompter. It stays
above other apps including full-screen calls, is hidden from screen sharing and recordings by default, and
is fully controllable by global hotkeys while another app has focus.

## Operating Context

Three physical setups must all be served:

- **MacBook, under the notch.** A small window parked directly below the built-in camera; short line
  lengths; eye line is everything.
- **External display with a webcam.** The window sits near a webcam mounted on or above a monitor; more
  room, read from further away.
- **Beam-splitter / mirror rig.** Mirrored output on a display under teleprompter glass in front of a
  lens; read from 1 to 3 m away.

Used for recorded reads and live calls or streams. Often another app (Zoom, QuickTime, OBS, a camera app)
has focus while the prompter runs.

## Capabilities and Constraints

- Auto-scroll with adjustable speed, play/pause, restart, jump back 5 s, countdown before start.
- Reading-line guide; elapsed and total time.
- Font size, line spacing, margins, colour theme, window opacity; horizontal and vertical mirroring.
- Hidden from screen sharing and recordings (default on); always on top (default on).
- Scroll by voice using on-device speech recognition only; audio never leaves the Mac.
- Script editor with paste and `.txt` / `.md` import; script and settings persist automatically.
- Global hotkeys (⌃⌥ Space, ↑, ↓, ←, R, H) via Carbon; no Accessibility permission required.
- Native SwiftUI + AppKit, no dependencies, macOS 14+, built with `swiftc` via `build.sh`.
- Undecided: licence, distribution (signed/notarised build, releases), app icon, custom hotkey bindings.

## Evidence on Hand

Source in `Sources/`, README, and a working build. No app icon, screenshots, testimonials, or usage data
exist; future work must not fabricate them.

## Product Principles

1. **Invisible during the read.** When trade-offs appear, nothing distracts while scrolling: minimal
   chrome, calm motion, controls by hotkey or hover. The interface recedes.
2. **The eye line is the product.** Every decision is judged by whether it keeps the reader's gaze at the
   lens.
3. **Usable cold.** A stranger should get from launch to a first read without instructions.
4. **Private by default.** The script is never shown to viewers and voice audio never leaves the machine.
5. **One window, three distances.** Under-the-notch, beside-a-webcam, and beam-splitter reads are all
   first-class.
