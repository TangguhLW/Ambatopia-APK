# Windows 0.20.1: source effects, Rayman and terrain

Scope: the separate Godot reconstruction, Windows debug only. No APK installation, original Growtopia writes, old Ambatopia web edits, database or account changes.

## Implemented

- Face composition now draws white eyes, the **player_eyes** upper-lid strip, mouth, and pupil in that order. The default mouth uses skin minus 60 RGB units; lids use skin plus 2. This corrects the incorrect **player_face** lid overlay introduced in 0.19.2. That older document's face-composition explanation is superseded. Reference: https://github.com/claralaw/GrowtopiaRenderPlayer, `src/Render/render.ts`, lines 294–305. Its README itself warns that some equipment positioning is broken, so this is evidence for face composition, not universal fidelity.
- Legacy `ef.rows[].lp` particle programs are statically extracted from the cached simulator JavaScript into a restricted data interpreter. The extractor folds provably constant obfuscator branches without running the application. Forty-one complete programs are executable; eighteen unresolved programs are listed with reasons. The current catalog has 169 eligible emitter rows across 143 items. This is eligibility coverage, not a claim that every item has been visually compared. Source frame selection, random ranges, velocities, alpha, RGB, rotation, scale, emission conditions, chance gates, and multiple emission points are used. Particles are capped at 96 per avatar. Frosty Hair is exercised in the real export.
- Captured punch profiles now supply their available `P` sprite/curve tracks. The archive contains 324 profiles; not every attachment, child, or `cv80` variant is implemented. This does not mean 324 weapons have complete native behavior.
- Captured pet state/frame tracks use local sprites, including Globox from `blogox`. Idle, walking, rising, falling and punching select their source sequences. Source rectangle, color, flip, pivot and rotation are retained. Following distance/physics are adapted to the native engine. An equipped-pet visibility switch is in the world menu. The archive contains 322 pet tracks; unsupported or missing assets are not replaced with inventory thumbnails.
- **Local/offline Rayman:** holding punch charges at 0.5, 1.0 and 1.5 seconds; releasing fires. Level two and above doubles block damage and affects up to three **collinear** tiles. A short tap affects one. An eleven-second hold releases and waits for key-up. Charge spins the source particle frames; firing uses local `fisticuffs`. Normal hand drawing is suppressed during charge/fire. Every extra tile checks edit authorization; the native room server passes its authorization callback. The existing Supabase online gameplay protocol does **not** yet implement this charge/triple-hit mechanic. No live-online parity is claimed.
- Shifty and other rainbow material-25 tiles use a dynamic retained-terrain pass. Hue changes do not rebuild existing static chunks. A four-second cycle is an unmeasured adaptation; rainbow behavior/material is evidenced, precise native period is not.
- Placement IDs encoded as `100000 + source` now use the same adjacency renderer as the simulator placement IDs. Source dirt/bedrock connect groups are recognized. Common dirt/lava/bedrock tiles treat neighboring solid terrain as covered, preventing false exposed/grass edges beneath bedrock. This solid-neighbor seam policy is an adaptation. Local dirt/lava/bedrock pixels matched the cached simulator atlas, so those source images were retained.

## Asset verification

`data/additional-effects-index.json` records original relative paths, source SHA-256, converted PNG SHA-256, dimensions, pack offsets and lengths. `assets/web-wardrobe/additional-effects.bin` contains only selected effect sheets. All 279 available sheets match the original RGBA pixels byte-for-byte using independent Pillow decoding. All captured pet/punch source rectangles are within sheet bounds. One requested sheet, `game/pets/p_tv.rttex`, was not found and remains explicitly missing.

Runtime assets use project-relative packed paths. The built EXE does not depend on the installation directory; only import/audit tools read it. Research files are excluded from export.

Evidence:

- `evidence/source-effects-audit.json`: program/track coverage, asset hashes, missing files and frame bounds.
- `evidence/source-effects-pixels.json`: independent exact RGBA comparison.
- `evidence/source-effects-unit.log` and `source-effects-all.log`: charge, multi-tile authorization, damage, pet visibility, Shifty, seams, finite particle updates and source-cell output, plus the existing suites.
- `evidence/render-regression/avatar-020-wardrobe.png` and `avatar-020-punch.png`: corrected native character layers, ordinary equipment and selected costumes in both directions.
- Final exported QA report and screenshots are copied to `evidence/source-effects-windows-final.json` and the corresponding QA profile. Windows-only performance results do not certify Android performance.
- `evidence/source-effects-old-web-unchanged.json`: thirteen old web baseline files retain their source hashes. APK hashes were also unchanged.

## Still incomplete — not replaced with generic effects

Native typed `ef.rows[].ty` emitters, including ancestral variants, have a different program format from the legacy `lp` programs and are not automatically mapped by numeric ID. Some items already have native XML/compiled special effects; that does not complete the unsupported typed path. The eighteen unresolved legacy programs are in the audit. Punch attachments/child variants, exact pet following behavior, and the missing pet sheet remain incomplete. Supabase online Rayman mechanics remain unimplemented by this Windows-only update.

Not every wearable in the source has particles or a gameplay buff. Plain items are not assigned invented effects. Full XP, drop-rate and economy modifiers are not certified by this update. This build is an improvement with recorded limits, not a 100% Growtopia reconstruction.
