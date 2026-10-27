# Windows 0.19.1 — direct wardrobe toggling and staged block cracks

Windows-only update. No APK export or installation, no database/policy change, and no edits to the old Ambatopia web project.

The first wardrobe click previously expanded the inspector and resized the virtual item grid, freeing the very card needed for the second click. Equipping also requested a complete inventory rebuild. The inspector now reserves its height, and outfit updates refresh the existing card borders/checkmarks and equipment dock without replacing the clicked cards. Two clicks wear an item; the next two remove it. Legacy and source catalog IDs retain their shared equipped-state mapping.

Block cracks now use `game/crack.rttex` from the read-only local installation. The verified sheet is 128×32, containing four 32×32 damage stages. The importer converted only this new asset; 45 existing mapped assets were unchanged. Source and converted SHA-256 hashes are recorded in `assets/reference/manifest.json`. The running build loads the project PNG through a relative resource path. Damage chooses the stage using hits divided by the block's break threshold. Removal or replacement clears damage and its threshold. Protected blocks retain their existing rules; this change does not weaken permissions or increase punch damage.

Validation: exported Windows behavior suite passed 92/92 checks, including real dispatched mouse double-clicks, repeated wear/remove on the same live card, source crack texture dimensions and clearing overlays after removal. The final native regression suite passed 43,560 checks; results are recorded in `evidence/click-cracks-unit.log`. Importer and manifest tests are in `evidence/click-cracks-resources.log`.

The five 600-frame Windows effect scenes averaged 60.07–60.14 FPS with p95 frame times of 16.69–17.36 ms. These short controlled samples do not establish performance for every costume or crowded multiplayer.

Build: `build/windows/Ambatopia-0.19.1.exe`. Final exported report: `evidence/click-cracks-windows.json`. Screenshots: `evidence/render-regression/0191-block-cracks.png` and `0191-inventory.png`. The new Windows instance and the original user session remain open. Android remains at the previously tested 0.19 release.

