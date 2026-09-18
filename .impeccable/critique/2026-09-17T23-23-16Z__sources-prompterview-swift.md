---
target: Teleprompter app UI (PrompterView + SettingsView)
total_score: 19
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 5
timestamp: 2026-09-17T23-23-16Z
slug: sources-prompterview-swift
---
Method: dual-agent (A: design review, B: detector + mechanical evidence, isolated). Evidence caveat: the "playing" screenshot was a countdown frame; the scrolling state was judged from code and a manual test.

## Design Health Score
| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of system status | 2 | No voice listening state, no end-of-script state, privacy toggle shows a slashed eye in both states |
| 2 | Match with real world | 2 | Speed "1.0" = 30 px/s, not pace; "px" margins; opacity "1.0" |
| 3 | User control and freedom | 2 | No forward/scrub; play dead at end; Paste/Clear/Open not undoable |
| 4 | Consistency and standards | 2 | Cmd-arrow menu keys collide with editor caret keys; "Paste" replaces; countdown ignores mirroring |
| 5 | Error prevention | 1 | One click destroys script, saved at once; voice permission prompt fires at start of take |
| 6 | Recognition over recall | 2 | Icon-only bar; hotkey legend below the fold in the other window |
| 7 | Flexibility and efficiency | 3 | Hotkeys, live settings, remembered frame; no scrubbing, no Space to play |
| 8 | Aesthetic and minimalist | 3 | Mid-read bare; paused bar is 11 equal-weight items; slider ticks smear |
| 9 | Error recovery | 0 | No error messages anywhere |
| 10 | Help and documentation | 2 | Tooltips carry hotkeys; no Help menu |
| Total | | 19/40 | Poor band |

## Design Specificity Verdict
Concept is authored for the product (borderless window under the camera, capture-hidden by default, global hotkeys). Execution is generic: reading line fixed at 35% for all three rigs, speed in px/s, 10 pt guide arrow, opacity dims the text, countdown covers the first line.
Detector: `[]`, exit 0; HTML/CSS engine with nothing to scan in Swift. Hand-measured instead: control bar needs ~335 pt vs 240 pt minimum window; opacity 0.3 gives ~2.1:1 script contrast (fails AA below ~0.55); guide band 1.14:1; enabling voice mid-script likely snaps to top (voiceTarget starts at 0, unverified).

## Priority Issues
1. [P1] Speed is pixels, not pace; default ~350 wpm. Fix: words per minute (default ~140, 80-220), derive px/s from script height and word count; bar reads "140 wpm". Command: clarify.
2. [P1] No retake loop: no forward jump, no scrubbing, countdown only from the top, play dead at end, no end mark. Fix: scroll-wheel scrub while paused, jump forward on Ctrl-Opt-Right, countdown on every start, play-at-end restarts, end mark. Command: harden.
3. [P1] One click destroys the script (Paste replaces, Clear, Open overwrite; no undo; non-UTF8 fails silently). Fix: "Replace with clipboard", one undoable replace path, confirm only when a script exists, inline read error. Command: harden.
4. [P1] Voice and privacy status silent; icons mislead (mic stays green on denial/unsupported; eye.slash in both states; colour-only state). Fix: per-state symbols, accessibility labels/values, request permission on toggle, listening indicator, reset toggle with explanation and System Settings link. Command: clarify then harden.
5. [P1] "Three distances" is a slider: guide fixed 0.35, font max 96 pt, 10 pt arrow, countdown unmirrored, opacity dims text, no max line length. Fix: Setup picker (under the notch / beside a webcam / behind glass) setting guide position, font range, mirroring; arrow scales with font and takes theme colour; opacity on background only; countdown inside mirrored group above the guide; clamp measure. Command: adapt then typeset.

## Persona Red Flags
Alex: no Space to play in the prompter window, no forward/scrub, Ctrl-Opt-Space collides with "next input source", hotkey registration failures ignored, Cmd-P toggles the window.
Jordan: nine unlabelled 12 pt glyphs, first read flies past, Paste eats the script, after Ctrl-Opt-H the app seems gone.
Sam: colour-only toggle state, no accessibility labels (plus/minus likely read as Add/Remove), 22x20 pt targets, countdown and end not announced, Reduce Motion ignored.
Maya (creator behind glass at 2 m): reversed countdown digits, 96 pt too small, invisible arrow, no countdown on pickup, sticky hover keeps the bar up all take.

## Minor Observations
Bar does not fit 240 pt minimum width; slider tick smear; "53 words" secondary text 3.95:1; window title "Teleprompter" vs "Script and settings"; "1 words"; 60 Hz timer not display-synced; theme display names double as storage keys; no Help/Window menu or Cmd-W; tooltips, menus, theme names not localisable; .md imports show raw markers; empty-state hint mirrors.

## Questions to Consider
1. If the eye line is the product, why does the app never ask where the camera is?
2. Should the reader set speed at all, when voice could learn their pace?
3. Would a progress hairline and a "hidden from sharing" confirmation at the countdown distract or reassure?
