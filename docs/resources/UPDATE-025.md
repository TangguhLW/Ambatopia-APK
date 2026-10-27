# Windows 0.25 — Pet movement and pet-anchored punch effects

The generic pet renderer previously put every pet thirty pixels behind the player and flipped it with the player. Captured frames were genuine, but movement was not using the captured simulator's motion logic.

`source_pet_motion.gd` now owns each avatar's cosmetic pet position, velocity, facing, twenty-sample trail, animation clock, idle/perch state, rotation and bounce. The 322 captured generic tracks map to eleven source branches: delayed ground following (196), flying (53), offset flying (13), hovering (39), delayed flight/ground transition (1), hopping (8), random orbit pose (1), perching birds (6), owl perch stages (1), umbrella (1), and ball (3). Ground pets select their walk/jump state from the delayed trail, rather than instantly copying the player. Source animation frames and durations remain unchanged. Pet replacement, toggling and a large teleport reset its private history. A bounded 60 Hz cosmetic step prevents unstable catch-up after suspension; it is an engine adaptation, not a claim of measured official-client scheduling.

The draw pass uses pet facing instead of player facing, source offsets, whole-pet rotation/bob, source rotation centre and the original one-second appearance scale. Perch frames use the captured `pm` table. No new sprites, AI-generated effects, installation edits, network permissions or database migrations were needed.

Punch emission now computes the live `pet` anchor. The source's `mid` alias applies `(1-af)` of that displacement. The existing affine retarget function accepts this delta before calculating projectile direction/stretch. When affine retarget declines, the captured near/far origin receives the delta instead, matching the source fallback. Already emitted non-following particles keep their world origin; `fol` particles continue following the player as the source specifies. Pet ball striking converts Godot's remaining-punch countdown to elapsed time, so it travels outwards rather than backwards.

## Evidence

- Source: preserved `research/web-wardrobe/set.readable.js`, especially `_0x47db38`, pet update at 46669–47080, draw at 47530–47594, and punch anchor functions at 10356 and 34614. This is a captured simulator version; no assumption of universal official-client parity.
- `scripts/build-pet-source-fixtures.mjs` extracts and independently executes only the original follow helper and punch aim functions in an isolated VM. `evidence/pet-source-fixtures.json` contains four numerical flight cases and 752 moving-anchor cases. It does not run the application entrypoint.
- `tests/suites/pets_025.gd` checks those source values, trail delay, both facings, jump/punch states, teleport/reset, pet toggle, ball timing, and all 322 generic track motion branches for bounded/finite state.
- `evidence/pets-025-focused.log` and `evidence/pets-025-all.log` record native test results. The final Windows report and captures are copied into evidence after the exported run.
- `evidence/pets-025-unchanged-scope.json` compares the old web's thirteen reference files and two existing APK hashes with the preserved baseline.

Final run: 97,276 focused checks and 273,659 full-suite checks, zero failures. The exported Windows build passed 175 checks, including ten pet scenarios with frame-time p95 from 16.681 to 17.007 ms on this Windows machine. No script/build/runtime errors were found in the four saved logs. These measurements do not establish phone performance or a many-player load limit. The build `build/windows/Ambatopia-0.25.exe` remains open with isolated profile `tools/profile-pets-025`; see `evidence/pets-025-summary.json` for process and build hash.

## Remaining limits

The 77 class-row pet renderers listed in `pet-tracks.json.by_row` use separate wardrobe programs; this update does not establish their movement fidelity. Headgear-specific perch offsets still need detailed outfit geometry mapping. Punch attachments named `tip`, `ball`, `ld` and `owl` still need their distinct render-object anchors; they are not silently treated as `pet`. Random source motion uses a native random stream, so trajectories do not reproduce a particular browser random sequence. Finite-state coverage across the generic catalog is not a visual 1:1 comparison of every item. Phone testing, multiplayer load testing, APK export, old web and Supabase changes are outside this Windows-only revision.
