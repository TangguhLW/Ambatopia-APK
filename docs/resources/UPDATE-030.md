# Windows 0.30 — saved outfits, source wear audio, machine frames and chest rewards

This update is restricted to the Godot reconstruction and Windows debugging. No subagent, Android installation/export, old Ambatopia web edit, cloud migration or account change is part of this work. Existing EXEs are left open. Final build and test evidence is listed in `evidence/outfits-030-summary.json` after verification.

## Wear audio and three outfit slots

The local read-only installation contains `audio/change_clothes.wav`. The inspected simulator also references that path. The original WAV is included in the existing indexed audio pack, with source identity and SHA-256 in `data/machine-audio-index.json`; no synthesis or pitch substitute is used. Successful backpack equip and unequip play it once. Invalid IDs, repeated equips and removal from an empty slot do not play it. Playback respects the existing master/effects controls and bounded voice pool. Login and automatic outfit restoration stay silent.

The wardrobe footer now opens one **Outfits** panel. It contains three numbered rows, each with **Save** and **Load**. Load is unavailable until the slot contains valid data; an intentionally saved outfit with zero items is valid. Slots retain validated clothing IDs, legacy equipment, skin and pet settings. They do not store permissions, account secrets, world ownership or inventory currency.

Named slots remain separate from the automatic last-worn checkpoint. Editing clothing therefore does not overwrite any numbered slot. Loading a slot updates the checkpoint so the selected outfit survives world changes and restarting the game. Storage is local to the device, isolated by account ID (or normalized local-profile name), and uses the existing atomic local store. Corrupt or cross-slot data is validated into a candidate before mutating the player. A failed checkpoint write leaves the player's current appearance intact. This update does not claim cloud synchronization of numbered outfits between devices.

## Machine animation reconstructed from the actual selector

The editor was fetched again. It still serves `wp.app.js?v=dad4259b31`, SHA-256 `ce06c6ac1056bbfa3dc5e42ff766efedf07facfa2e0042ec4f1324fd4f56c75f`. `research/machines-030/source-check.json` retains the time, URL and byte comparison.

`scripts/capture-tile-animations-030.mjs` extracts only the original frame selector, its frame-sequence helper and arithmetic dictionaries. It runs those isolated functions with controlled clocks and tile flags; it does not run the application entry point or interact with anti-bot mechanisms. The original functions provide **7,140 comparisons across 210 machine/weather/switch definitions**, both enabled states and 17 time samples. All isolated calls execute without missing dependencies.

`machine_animation.gd` implements these source branches: absolute `fr` and disabled `fr2` sequences; source frame periods; the original reflected sequence rule; alternating enabled frames; weather-machine 300 ms frames; the 400 ms magic-lamp cycle; special 800 ms source pulses; spread-dependent row offsets; and item-specific state offsets covered by the fixtures. The source behavior, including its unusual reflected endpoint pattern, is retained rather than replaced with a generic loop.

These tiles now draw in the visible dynamic terrain pass. Static chunk lists remain cached; animation time alone does not rebuild terrain. The animation atlas cache is bounded. Source/native base coordinates and atlas widths were compared: no mismatches among the mapped definitions. The new path uses the existing local texture overrides, nearest filtering and clipped atlas cells. Generic green enabled dots are removed for these machines in favor of their actual sprite states. This does not establish 1:1 behavior for every trap, background animation, particle renderer, special machine interaction or guild mascot.

## Recovered simulator chest probabilities

`scripts/capture-chest-rewards-030.mjs` isolates the actual chest handler and its declared reward arrays from the same editor. It records **504 differential cases** for Treasure Chest (392), Golden Booty Chest (3402) and Super Golden Booty Chest (9350). Cases cover both sides of probability thresholds, final overrides, duplicated table entries and different selected reward positions. Random inputs are retained as IEEE-754 bytes as well as readable decimals, because the engine JSON parser rounds values at a threshold.

The reconstructed handler has these source rules:

- The normal pool has 63 entries. The Super chest appends five source Crimson Thief entries.
- The rare branch tests one draw against 1/800 for 392/3402 and 1/350 for 9350. The rare pool has 18 entries, including deliberate duplicate Angel Wings entries.
- A second independent 1/5000 branch overrides either pool with `[11702, 362]`.
- A third draw selects an entry from the resulting pool. The original amount-five and amount-two item lists are preserved; other rewards have amount one.

These probabilities describe the **inspected simulator**, not proven current official-server RNG. For example, the rare-branch threshold is not the probability of a specific rare item, and its effect is subject to the final override and repeated entries. The inspector states this distinction. The real punch/break path now awards the selected content through the existing drop system.

The historical-calendar weights, Well of Love best-of-five contribution selection and individual epic weights remain unrecovered. The prior explicitly labeled creative selection for those items remains unchanged. The community-reported 96.75% well essence figure must not be conflated with a verified current server table.

## Guild weather and five Starship generators: still not recovered

Further inspection of the current simulator and local `GameData` found:

- Guild weather is item 6280, native weather type 41 (`MASCOT`). Its simulator weather entry has a null recipe key. The native enum establishes its identity, not the mascot geometry, colors or timing.
- The available reconstruction has no verified guild/mascot model. [The public Guild weather description](https://growtopiawiki.com/w/Weather_Machine_-_Guild) requires a Guild-Locked world and rain based on that guild's mascot. A generic falling item or unrelated crest is not a faithful substitute.
- All five Starship consumables exist in the catalog: Imperial 6420, Stellarix 6422, Greezak 6424, HyperTech 6666 and Protostar 12048. The inspected isolated blast generator still contains none of those five layouts.
- `GameData/Configs/Hints.yaml` confirms that a Starship Blast creates a ship world and that its Helm starts a mission. The available `rest.data.star` describes sectors, fuel and equipment ratings. Neither source supplies the five tile maps or generators.
- The native installation includes a Startopia UI banner, not an inspected ship-map resource. Local XML/YAML inspection did not supply the missing generator or Guild renderer.

REA's current session reports Ghidra and IDA unconfigured, with Hopper unsupported on Windows. The provider diagnostics are retained in `research/machines-030/native-analysis-availability.json`. Native decompilation is therefore unverified; this is not evidence that the missing behavior is absent from the executable. No engine installation or client configuration was changed to hide the limitation. The six unsupported paths remain explicit and preserve the current world when invoked. They are not counted as finished.

## Verification

Focused red/green tests precede the implementations. New suites cover profile isolation, all three slots, empty outfits, invalid indices, corrupt slot safety, last-worn restoration, original audio decoding, source frame comparisons, RNG thresholds and real chest breaking. Exported Windows checks exercise the actual UI controls and source audio route, capture the slot panel in a narrow window, verify machine atlas changes and retain the preexisting heavy-effect performance scenarios. Final results and any remaining qualifications belong in the accompanying evidence summary.

Final build: **`build/windows/Ambatopia-0.30.2.exe`**, left running. The broad native regression run recorded **315,230 checks, zero failures**; the final focused outfit run recorded **15 checks, zero failures** after the UI copy adjustment. The final exported EXE recorded **351 checks, zero failures**. All 117 entries in the build provenance manifest match current files. Thirteen old-web source references, two previous APKs and the original Growtopia executable retain their recorded hashes.

The final run paused a render capture while its window was minimized. It continued after the window was restored. Raw FPS measurements are retained rather than discarded; the adjacent `costume_and_rlm` mean of 58.91 FPS is excluded as an uninterrupted baseline. Other measured scenarios were 60.10–60.18 FPS, and all p95 samples were below 18 ms. These are Windows measurements only. The earlier 0.30.1 UI harness clicked before the rebuilt backpack layout had settled; the final harness waits for layout before dispatching real mouse events, completes all numbered slot actions and restores the preceding outfit for the later persistence checks. Final normal/narrow outfit screenshots and source-machine frame screenshots were visually inspected.
