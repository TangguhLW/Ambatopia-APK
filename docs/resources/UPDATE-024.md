# Windows 0.24.2 — Riding Comet, Riding Meteor, Neptune and Chaos

## Source findings

The earlier importer inspected assignments to the legacy particle registry but missed its initial object literal. Riding Comet's program 112 is defined there, and Riding Meteor's 113 aliases it. Both are now extracted from the captured simulator functions. Their distinct source cells are (2,6) and (3,6), with additive blending, one-second life, initial size 2, rotation at -720 degrees/second, and source random flicker within the shrinking lifetime range. The emitter retains the original direction/speed and tenth-second interval. Selecting wrench suppresses the trail as the source rule specifies.

Neptune's Chariot references programs 36 and 232, which are calls to a source factory rather than ordinary program objects. The importer now records that factory's child count, target program, eight-pixel positional jitter and angle callback. Godot expands it with the same semantics: the first particle and the additional children all run their actual target initializer, then use the corresponding target update/cell functions. This retains child RGB data and does not replace either factory with a generic burst.

- Landing: 10 children of source program 35, triggered by grounded state following airborne state 3.
- Moving on the ground, or moving with wrench selected: 5 children of program 233 per tenth-second source trigger, with original RGB (137,208,255) and the source angle spread.
- Remaining still after a landing does not repeatedly trigger the landing burst. Removing the ride stops new particles, while existing particles expire. The common particle budget remains 96.

The first exported Windows run found that a render frame slightly shorter than 1/60 second could suppress the one-frame landing trigger. Source tick `f` means every rendered frame, so it is no longer passed through the legacy 1/60-second emission throttle. Explicit tenth/third-second intervals remain timed. A 16-ms landing regression test now covers the failure. A second issue was in the QA sequence: it could set grounded again before an avatar update observed airborne state. The final QA waits for the renderer to observe state 3 before grounding. A separate visible-window probe records exactly ten particles before and after the next frame. The first failed export report is retained as `evidence/rides-024-windows-first.json`; the final report belongs to 0.24.2.

The renderer also plays the captured Comet/Meteor landing sequence before returning to idle. Their original atlas and per-state frame timing are preserved.

## Chaos Corruption: preserve what the source actually does

The archived and freshly fetched live simulator both declare wardrobe row `lp:302` for Chaos Corruption, but neither registry defines program 302. The live dispatch condition explicitly returns when the registry lacks a requested particle program. Therefore the source does not emit that row. This is recorded in `evidence/rides-024-source-audit.json`, including both source hashes and the live guard. A public reference tab was opened, Chaos Corruption was selected, and its clothing render was observed.

The visible clothing animation is present: eight original atlas frames at 200 ms each, looping every 1.6 seconds. Godot previously reset the animation clock when walking or jumping, despite those poses falling back to the same `stand` sequence. It now keeps that sequence's continuous clock. No invented smoke, sparkles or substitute program is added. This matches the inspected simulator behavior; it is not a claim that the official game's missing particle 302 was reconstructed.

The live script came from `https://growtopiasimulator.com/set/app.js?v=67acd14fd1`. A separate readable copy is retained under `research/effects-024`; the prior source snapshot and previous reference fixtures were preserved. The local inspection script executed only string-table rotation and decoder functions, not the downloaded application entrypoint. The public application was separately observed in the browser.

## Verification

- `evidence/rides-024-unit.log`: 61 focused checks for trail direction, lifetime, scale, cells, rotation, wrench suppression, Neptune factory counts/tint/trigger/expiry, landing frames, Chaos's continuous clock and the 16-ms landing regression.
- `evidence/rides-024-all.log`: full native test suite, 176,892 checks and zero failures.
- `evidence/rides-024-source-audit.json`: source registry inventory and absent-302 guard.
- `evidence/rides-024-windows-final.json`: 153 exported Windows checks, zero failures, with captures and frame measurements. Ride-scenario frame-time p95 ranges from 16.72 to 17.79 ms. Neptune reaches 55 concurrent particles in the walking scenario and produces exactly ten at landing; both remain within the 96-particle budget.
- `evidence/rides-024-unchanged-scope.json`: baseline verification of old web files and APKs.

The Windows executable is `build/windows/Ambatopia-0.24.2.exe`, using an isolated QA profile, and is left open. No phone installation/debugging, Supabase change, account operation or old Ambatopia web edit is included.

## Limits retained

The legacy registry now contains 65 executable entries, including two dedicated factories. Of 202 captured wardrobe rows, 201 resolve to executable entries; the remaining Chaos row is skipped by the inspected source itself. Other native typed effects, dynamic pet/attachment anchors, economy buffs and online Rayman authority still have the limitations recorded in UPDATE-023. This update does not certify complete official-game parity or phone FPS.
