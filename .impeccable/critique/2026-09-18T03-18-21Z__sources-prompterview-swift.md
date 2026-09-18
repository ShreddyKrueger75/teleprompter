---
target: Teleprompter app UI (PrompterView + SettingsView)
total_score: 26
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
timestamp: 2026-09-18T03-18-21Z
slug: sources-prompterview-swift
---
Method: dual-agent confirming re-critique (A: design verification, B: mechanical verification), isolated.
Scored on the state BEFORE the follow-up fix batch; the fixes listed at the end landed after this score.

## Design Health Score
| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of system status | 3 | Mic state never repaints; notice never clears |
| 2 | Match with real world | 3 | wpm and rig names are strong; "Setup"/"Background" vague |
| 3 | User control and freedom | 3 | Undo is one level and view-scoped, not wired to Cmd-Z |
| 4 | Consistency and standards | 2 | No About item; Help opens Settings; one toggle colour-only |
| 5 | Error prevention | 3 | Confirm + undo + file errors good; countdown race |
| 6 | Recognition over recall | 3 | Scrubbing undiscoverable |
| 7 | Flexibility and efficiency | 3 | No custom bindings; mic indicator shed below 340 pt |
| 8 | Aesthetic and minimalist | 2 | Black bar and invisible hairline on the white theme |
| 9 | Error recovery | 2 | Hotkey failure shows a microphone remedy |
| 10 | Help and documentation | 2 | Help menu opened settings; no About |
| Total | | 26/40 | Up from 19/40 |

## Verified fixed from the first critique
Retake loop (jumpForward, scrubbing, countdown on every start, play-at-end restarts, end mark);
rig presets driving guide position, font range and mirroring; opacity no longer on NSWindow.alphaValue;
accessibility labels on every interactive control; Reduce Motion; adaptive control bar (measured: no
tier overflows, 232 pt at the 320 pt minimum); settings decoded field by field; menu key equivalents
no longer colliding with the editor; guide band 1.14 -> 1.35:1.

## High-severity regressions this round found, all since fixed
1. textHeight included the end-of-script label and VStack spacing, inflating pace by ~12% on a
   40-word script (effective 159 wpm against 140 requested) and desyncing the clock.
2. Enabling voice mid-read still snapped the script to the top and pinned it there.
3. Replacing or clearing the script left offset, voiceTarget and textHeight stale.
4. Mirror toggle used the same symbol for both states (colour-only, 1.86:1).
5. voiceState was not observable, so the listening indicator never repainted.
6. notice was never cleared and rendered a hotkey conflict under Voice with a microphone button.
7. syncVoice() tore down AVAudioEngine on every settings write (~60x/s during a slider drag).
8. apply(rig:) silently discarded a hand-tuned font size and mirroring.
9. scrollWheel had no hasPreciseScrollingDeltas branch (2x too fast on trackpad, ~2 pt per wheel notch).
10. Recognition restarted every 0.3 s forever on a persistent error, never surfacing failure.
11. Text over a translucent background failed AA (2.11:1 over a white desktop).

## Remaining, not addressed
- Undo is one level and view-scoped; not wired to Cmd-Z, and the TextEditor's own undo stack is
  out of sync after a programmatic replace.
- The control bar and progress hairline are hard-coded dark on the "Black on white" theme.
- A hand-edited settings blob with an unknown enum raw value still resets that one field.
- Stepper has no accessibilityValue; error and notice labels are not announced to VoiceOver.
- The 60 Hz timer is not display-linked and keeps running while the window is hidden.
