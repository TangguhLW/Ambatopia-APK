# Windows 0.26 — Backpack and inventory item shapes

Inventory cards previously used the unconnected atlas base coordinate recorded in item metadata. That coordinate is intended as the base of world adjacency rendering; it is not necessarily the inventory icon. Dirt, lava and bedrock were therefore showing joined/interior tile cells. All thumbnails were also stretched into a 46-pixel-high area, seeds filled that area instead of half a normal item, and special two-layer item kinds lost their second layer.

## Source and implementation

The captured simulator's `iconCell` at `research/web-wardrobe/set.readable.js:12274` selects spread offsets 12 for types 2/5, 3 for types 3/7/8/9/10, and 4 for type 4. Spread 2/5 uses an eight-column layout. `_0x4b0fc0` overlays the adjacent horizontal cell for kinds 20/22/27/38/39, or vertical cell for kind 26. Seeds occupy a centered 16-pixel square inside a 32-pixel icon. The fresh source copy under `research/effects-024` contains the same rules. Its seed color decoder reads red from bits 8–15, green from 16–23, blue from 24–31, and alpha from bits 0–7; the previous seed importer reversed red and blue.

`build-inventory-icons.py` composes these icons from existing verified local PNGs where the simulator and local item identities match; it otherwise uses the existing simulator atlas. It does not read or change the original installation. Native-only catalog entries use their local metadata and spread shape; unverified multi-layer kinds for unmatched native versions are not inferred. Existing icon renderers remain available for native wardrobe entries whose metadata has no static preview.

The portable pack contains 15,211 distinct 32-pixel icons, deduplicated into fifteen 1024-pixel pages (6,672,089 compressed bytes). Its manifest maps 24,695 source/native keys and records input PNG hashes, packed page hashes and output hash. Composition happens at build time; scrolling does not decode/crop full original sheets. Runtime caches are bounded to three decoded pages and 256 atlas entries; visible cards retain only their referenced pages. Staging preserves the preceding pack when an unexpected input fails.

Backpack cards, inspector, wardrobe slot buttons and quickbar now share the icon pipeline. Card pictures use nearest-neighbour filtering at an integer scale, with separate space for the caption. World adjacency textures and worn-character rendering retain their existing sprite paths.

## Verification and limitation

- `evidence/inventory-026-source-cells.json`: all 16,508 icon coordinates independently evaluated using the original simulator `iconCell` function in an isolated JavaScript VM, without running the app.
- `evidence/inventory-026-pixels.json`: 16,507 source catalog icons compared pixel-for-pixel against source-cell compositions; no pixel mismatches. Seeds also retain the transparent margin.
- `tests/suites/inventory_icons_026.gd`: separate world/icon cells, legacy ID consistency, seed size, nearest-filtered integer scaling, card containment at 390×640, 844×350 and 1280×600, and cache limits.
- `evidence/inventory-026-focused.log`: 114 focused checks, zero failures.
- `evidence/inventory-026-all.log`: 274,142 native checks, zero failures.

The exported build passed 303 Windows checks with zero failures (`evidence/inventory-026-windows-final.json`). Five filtered backpack captures cover Dirt, Lava, Bedrock, World Lock and Rayman. The Dirt/Lava captures were visually inspected after the run. All four saved test/build/runtime logs are free of script and error diagnostics. EXE 0.26 remains open using an isolated QA profile. `evidence/inventory-026-unchanged-scope.json` confirms the thirteen old-web baseline files and two existing APKs are unchanged.

One source item is explicitly unavailable: Startopia NPC Character Bad (#12244) requests cell (0,3) in a sheet only one cell high. Both source and local metadata contain that out-of-bounds coordinate. The manifest records this exact reason; no substitute sprite is invented and valid catalog entries remain available. No APK, phone, Supabase, account or old Ambatopia web change is included.
