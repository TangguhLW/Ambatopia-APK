# Windows 0.31 — Guild mascot weather and Starship source audit

This work is restricted to the native Godot project and Windows debugging. Existing EXEs remain open. No Android export/install, cloud migration, account change or old Ambatopia web edit is included.

## Verified Guild inputs

The read-only installation supplies Guild Lock (5814), Guild weather (6280), weather enum 41 (`MASCOT`), their atlas cells and descriptions. `research/guild-starship-031/local-item-metadata.json` retains the inspected records. The three local `gd_page*.rttex` atlases were decoded in the research directory and visually inspected. They contain textures, not recovered Starship tile maps. `local-resource-manifest.json` records source/output hashes, dimensions and conversion. These research duplicates are excluded from the application export; the renderer uses the existing indexed local texture/icon pack.

The [Guild description](https://growtopiawiki.com/w/Guilds) describes one foreground item over one background item, with a foreground-only option. The official economy and membership prerequisites described there are not implemented by this creative, world-local mascot configuration. There is no global guild registry, unique-mascot reservation, membership system or gem charge in this update.

The [Guild weather reference](https://growtopiawiki.com/w/Weather_Machine_-_Guild) supplies an 830×830, 151-frame, 5.03-second GIF and a wrench-panel screenshot. Both original reference files and their hashes are retained in `media-manifest.json`; they are research material, not bundled replacement textures. The screenshot establishes **Gravity (default 50)**, **Spin Items** and **Invert Sky Colors**. The GIF shows differently sized mascot images drifting while falling, including images drawn over world blocks. Sample component measurements and the sampled dominant sky color, RGB(254,254,100), are retained in `gif-measurements.json`.

Particle counts, depth distribution, velocity, sideways oscillation and inversion formula in this reconstruction are calibrated approximations, not recovered native code. The fixed sky palette matches this particular recording; a universal native Guild sky-color algorithm has not been recovered. The ±500 gravity limits reuse the existing creative Stuff-weather controls and are not proven original Guild limits. This is a functional source-informed implementation, not a 1:1 native renderer claim.

## Native gameplay and UI

Place a Guild Lock, wrench it, select foreground/background items and save the mascot. Place Guild weather in that world, then punch it or use its wrench switch. The weather inherits the lock's actual item layers; it has no separate falling-item selector. Wrench controls configure gravity, spin and inverse sky. The mascot is stored in the existing world extras and survives world serialization.

Owner/developer permission is checked before mascot changes. Missing, ownerless, stale or invalid Guild Lock records cannot activate Guild weather. Removing the lock or valid mascot deactivates the weather. A second whole-world lock is rejected. Ordinary players cannot punch-break the permanent Guild Lock; the existing creative developer exception remains. Normal offline Guild Lock placement now registers its ownership record, matching the server's existing placement path.

The overlay uses nearest-filtered, clipped source icon textures, background first and foreground second. It is above terrain/avatars and below the HUD; it ignores mouse input. High quality draws 36 image pairs, low quality 20. Shared clock angles stay bounded. It does not rebuild terrain chunks on every weather frame.

## Five Starship layouts: unrecovered

`scripts/inspect-guild-starship-031.mjs` fetches the editor and verifies its current entry against the inspected bundle: `wp.app.js?v=dad4259b31`, SHA-256 `ce06c6ac1056bbfa3dc5e42ff766efedf07facfa2e0042ec4f1324fd4f56c75f`. It extracts and executes only the original blast-generator closure with the required decoder, not the application entry point. Results are retained in `source-check.json`, `isolated-blasts.js` and `starship-findings.json`.

All five calls return **null**: Imperial 6420, Stellarix 6422, Greezak 6424, HyperTech 6666 and Protostar 12048. Local descriptions document three possible variants for each of the first three classes. They do not establish the number of HyperTech or Protostar layouts. They confirm starter equipment: Imperial Helm Mk.I (6428), Reactor Mk.I (6434), Viewscreen Mk.I (6440), plus fuel. Those facts do not establish tile coordinates, map dimensions or variant probabilities.

The inspected `rest.data.star` describes sectors/fuel/equipment. Local configuration hints explain creating a ship world and starting a voyage from its Helm. Neither provides ship-map tiles. Further wiki search found descriptions and gameplay guides, not a complete coordinate map suitable for faithful import. No screenshot-based guessed ship or generic rectangle is substituted. Invoking these unsupported blasts preserves the current world and reports the missing implementation; tests explicitly enforce that behavior.

REA identified the original executable as PE/x86-64 and recorded its hash. Native Ghidra/IDA providers are unconfigured in this session, so native generator decompilation was not established. An unsuccessful byte-string search is not proof that the executable lacks these functions. No native installation file was changed.

## Verification

`tests/suites/guild_weather_031.gd` has 39 focused checks: valid/invalid item layers, ownership, duplicate-lock rejection, activation prerequisites, save/restore, stale lock removal, bounded particle plans, reverse gravity, clock stability and authoritative-room permission checks. The room test respects its existing action cooldown; production cooldowns were not weakened.

The focused native Windows GUI probe passes 21 checks using actual mouse events: lock placement, both pickers, save, machine placement, switch, settings, overlay ordering and persistence. The initial UI test clicked before the container completed layout; it now waits for a rendered frame before calculating the save-button position. Its recorded picker IDs and saved extras confirm both layers. The uninterrupted 240-frame focused sample measured 60.53 FPS with 16.93 ms p95. This is a Windows observation, not an Android or crowded-server performance guarantee.

Final exported EXE, broad test count, runtime checks, provenance and unchanged-source hashes are recorded in `evidence/guild-031-summary.json` after final verification. The five original Starship layouts remain an explicit outstanding task.

Final result: `build/windows/Ambatopia-0.31.0.exe` is running and was visually confirmed open after testing. Broad native regression: **315,525 checks, zero failures**. Exported Windows QA: **363 checks, zero failures**. Its 240-frame Guild scenario measured **60.53 FPS**, **16.812 ms p95**. All **120** build-manifest entries match; the **13** recorded old-web source references, **two** prior APKs, original executable and three inspected Guild atlases retain their expected hashes. Original-source Vorbis comment warnings remain; no script/runtime errors were reported. These checks do not establish live Supabase multiplayer or Android behavior for this revision.
