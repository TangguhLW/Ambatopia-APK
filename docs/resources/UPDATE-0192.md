# Windows 0.19.2 — source face composition, gait and material audio

Windows-only change. No APK build/install, old web edits, database changes or account operations.

## Character

The source face renderer draws a skin-tinted upper-lid strip at expression row +128 after the eyes, mouth and pupil layers. This pass was missing, leaving oversized open eyes and the wrong mouth contour. Native drawing now includes that original local strip and the source blink cell at (160,96), with the source four-second blink windows. No generated replacement artwork is used.

Jump and fall select expression cells 1 and 2. The default skin matches source palette entry 3, RGB (195,149,130). Walking uses the source triangular foot curve in [-2,0], driven by horizontal distance /20, rather than the faster fixed foot stepping. Bare feet use whole-pixel source offsets. Falling arms settle toward zero as in the source; punch duration and range are unchanged.

Evidence: `research/web-wardrobe/set.readable.js` lines 32697 (palette), 33148 onward (blink windows), 34459 (walk phase), 42899–42936 (pose), 44111 and 44278–44289 (face/base composition). The original local texture pixels remain unchanged. Live visual reference: https://growtopiasimulator.com/set/ . That live page currently lists 4,103 wardrobe entries, while the packed native catalog snapshot is older; complete latest-item/version parity is not claimed.

## Audio

The source hit routine uses item `hs` (simulator row index 11), matching native metadata `material`, to select a pair of impact and destruction recordings. It does not assign a unique recording to every item name:

| Source material | Impact | Destruction |
| --- | --- | --- |
| 0 / unknown default | wood_damage | wood_break |
| 1 | wood_damage | punch_glass |
| 2 | wood_damage | wood_break |
| 3 | metal_hit | wood_break |

This mapping follows the actual source table, including the shared hit recording for several material groups. It does not invent a rock sound based only on an item name. Empty-air punches use punch_miss; protected spawn blocks use punch_locked. Placement audio remains unchanged. Both ordinary and background break events retain the old item ID so destruction uses the material of the block that was removed. Predicted and remote punch paths use the same resolver. Server permissions and policies are unchanged; this update does not certify live multiplayer audio across old clients.

Source: `research/simulator-current/edit.readable.js` lines 1010 and 1766–1828; corroborated by the cached set renderer at 11990 onward. The importer copied six WAV recordings from the read-only local Growtopia audio folder; all 46 pre-existing mapped resources were unchanged. Source and output hashes are in `assets/reference/manifest.json`. The EXE uses project-relative resources.

## Verification

Native regression: 43,570 checks passed (`evidence/avatar-audio-unit.log`). Importer/resource tests: 8/8 passed (`evidence/avatar-audio-resource.log`). Exported Windows QA passed 102/102 checks. Five 600-frame effect scenes averaged 60.09–60.18 FPS, with p95 frame times of 16.69–17.42 ms and zero sampled frames above 20 ms. Full results: `evidence/avatar-audio-windows.json`. Controlled tests verify glass impact/break events and metal routing as well as audio streams in the export; they are not a human listening assessment.

Visual captures: `evidence/render-regression/avatar-0192-wardrobe.png`, `avatar-0192-punch.png`, and the live browser reference `evidence/player-reference-live.png`. Character captures contain native idle and punch views in both directions, ordinary clothes and selected special costumes. They do not prove every equipment renderer is identical.

Build: `build/windows/Ambatopia-0.19.2.exe`. The latest Windows instance remains open with an isolated QA profile; the original user game is preserved.

