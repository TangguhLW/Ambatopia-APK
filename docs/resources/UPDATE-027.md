# Windows 0.27.1 — Wardrobe footer, seed previews and last-used set

## Wardrobe

The wardrobe footer now has one action: **Save set**. Reset, page-arrow shortcuts, Wear and the inspector's unequip cross were removed. Scrolling still reaches the complete catalog, and double-click still toggles wear/unwear; slot controls in the worn dock retain their useful remove/filter actions. The inspector keeps the selected item's information without competing action buttons.

**Save set** writes the current outfit locally. Normal equip, unequip and skin changes also checkpoint it immediately. Pet visibility changes checkpoint their option. A separate outfit store saves canonical clothing IDs, legacy clothing frames, skin and pet options, keyed by account ID or the normalized offline profile name. Files use hashed names inside `user://local-worlds/outfits/`, separate from world saves. They are not world-list entries and contain no password, role, developer permission, position, currency or world state.

Entering another world or starting a fresh session with the same profile restores the last-used outfit after reading the world. This replaces the earlier per-world outfit behavior that could bring back an older set. Existing world saves still migrate naturally when no per-profile checkpoint exists. Restore validates every slot/ID and stages changes on a temporary player before applying them, so invalid data cannot partially overwrite a current outfit or confer privileges. Writes use the existing temporary-file-and-rename local storage. The UI reports explicit save failures. This is device-local storage, not cross-device cloud synchronization.

Online welcome uses a separate account-keyed checkpoint and sends only the existing outfit/skin message. No network schema, server authorization policy, database, original account or Supabase setting changed.

## Seeds

Every source seed card now shows its grown item's thumbnail, and the inspector names that result (`Grows: ...`). This applies to clothing, blocks, consumables and other source item kinds, using the source's seed-ID-minus-one relationship.

The planted-tree drawing previously used generic colored rectangles with a fixed three-fruit arrangement. It now draws source tiles from `tiles_page1`: tree base column `tree[2]` on row 19 and canopy column `tree[3]` on row 18. Tints use the source ABGR decoder. Source growth size is `32 × (progress + 0.2)`, anchored at the tile's bottom centre. A mature tree draws its actual fruit count (up to five), using the corresponding grown-item icon at the source's five positions and 9.6-pixel size; immature trees do not draw ripe fruit. Harvest logic and seed growth duration are unchanged.

The reference is the preserved simulator source at `research/web-wardrobe/set.readable.js:12777`, plus its seed/tree metadata and existing verified local atlas. `seed_visuals.gd` shares a testable render plan with the world draw pass. The previous raw seed texture is no longer loaded unnecessarily when entering a world.

## Verification

- `evidence/wardrobe-027-focused.log`: 33,032 checks, zero failures. Includes set changes across worlds, fresh-session restore, empty-slot persistence, profile isolation, invalid-set rejection, functional footer, and the result/atlas/fruit plan for all 8,254 source seeds.
- `evidence/wardrobe-027-all.log`: 306,832 native checks, zero failures.
- Windows export checks exercise the real Save set signal, read the checkpoint, restore the selected clothing, inspect seed-result previews, and capture the actual mature-tree render pass. Final report and screenshots are copied into evidence after the exported run.

Final exported Windows run: **309 checks, zero failures**, with no script/runtime/build errors in the four saved logs. Footer, seed-result card and mature-tree captures were visually inspected. `evidence/wardrobe-0271-windows-final.json` and `evidence/wardrobe-0271-summary.json` retain the report, build hash and running process. All hashes embedded in the build-info manifest match the current corresponding source/assets. `evidence/wardrobe-0271-unchanged-scope.json` confirms the thirteen old-web baseline files and two previous APKs remain unchanged. The executable is `build/windows/Ambatopia-0.27.1.exe` and remains open.

Tests use isolated local fixture profiles. The final EXE is left open. No phone debugging or APK export is included; the old Ambatopia web and its database remain untouched. Source items with missing/invalid imagery remain subject to the explicit inventory 0.26 limitation; no substitute resource is invented.
