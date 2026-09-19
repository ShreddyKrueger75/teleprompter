# TestFlight beta

The fastest route to testers. **Internal testing needs no App Review** — no screenshots, no
description, no keywords, no privacy answers. Those are only needed for a public release
(see `SUBMISSION.md`).

## Steps

### 1. Create the app record

<https://appstoreconnect.apple.com> → Apps → **+** → New macOS App.

- **Bundle ID:** `Bloody-Finger-Software.Teleprompter` — already registered, pick it from the list
- **Name:** Teleprompter
- **SKU:** `teleprompter-1`
- **Primary language:** English

Nothing else has to be filled in for internal testing.

### 2. Upload

Xcode → Window → Organizer → Archives → the Teleprompter archive → Distribute App →
**TestFlight & App Store** → Upload.

Processing takes a few minutes. The build then shows up under the TestFlight tab.

### 3. Add testers

- **Internal** (up to 100, no review): TestFlight → Internal Testing → add people who are already
  on your App Store Connect team. They get it within minutes.
- **External** (up to 10,000, needs Beta App Review): TestFlight → External Testing → create a
  group → add emails or use a public link. First build of a version goes through a light review,
  usually a day or less.

macOS testers install the TestFlight app from the Mac App Store and get the build there.

## What to test

Paste this into the "What to Test" field:

```
This is a prompter window that floats next to your camera so you can read while looking at the lens.

Worth hammering on:

1. PACE. Speed is set in words per minute, not scroll speed. Set it to how fast you actually talk,
   then check the clock matches reality when you finish the script. Tell me if the timing is off.

2. YOUR CAMERA SETUP. In settings, pick "Under the notch", "Beside a webcam", or "Behind glass".
   Does the reading line land where your eye naturally goes? Is the type big enough at your distance?

3. RETAKES. Jump back and forward 5 s, scrub with the trackpad while paused, and restart. Does the
   countdown give you enough time to get your eyes up before the first word?

4. HOTKEYS while another app is in front. Control-Option and Space (or P) plays, arrows change pace
   and jump, R restarts, H hides. If a hotkey does nothing, tell me which, and what else you run
   that might own it.

5. SCREEN SHARING. Hidden from capture is ON by default. Share your screen on a call and confirm
   nobody sees the prompter. This is the one I most want confirmed on setups other than mine.

6. VOICE SCROLLING (off by default, in settings). It listens and follows your reading. Recognition
   runs entirely on your Mac; audio is never sent anywhere. This is the least tested feature.

Known rough edges, no need to report:
- Undo after replacing a script is one level and disappears when you close the settings window
- The control bar stays dark on the "Black on white" theme, so it looks like a black strip
- Scrolling may judder slightly on a 120 Hz display
- VoiceOver does not announce the error and warning messages in settings
```

## Notes

- Build numbers cannot repeat. Bump `CURRENT_PROJECT_VERSION` in `project.yml` and run
  `xcodegen generate` before every new upload.
- A TestFlight build expires after 90 days.
- Internal testers need to be on your App Store Connect team; external ones just need an email.
