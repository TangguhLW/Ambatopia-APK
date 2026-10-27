# Native special wardrobe and mobile performance

Authorized scope: continue the native Godot game, reuse the existing read-only web renderer evidence, test Windows and the attached Xiaomi, no subagents and no old Ambatopia web/database changes.

Completed implementation:

1. Trace the reference `g` and `xr` render hooks, cropped atlas placement, body/slot masks, sprite frames and motion curves.
2. Add a native interpreter with per-avatar state, cached commands, correct mirroring/rotation and a separate additive layer. Recover missing inventory icons from the reference icon atlas.
3. Profile simulation, avatar, weather and terrain separately. The old ordinary-world benchmark was not a heavy-effect benchmark; add explicit effect/weather scenarios.
4. Retain static terrain in 16-tile chunks. Rebuild only changed chunks and adjacency neighbors; move camera transforms without rebuilding draw lists. Keep seeds, fire, damage and projectiles dynamic.
5. Compile invariant weather expressions once. Render Android weather at a bounded 600-pixel height (480 in the existing low setting), preserving logical geometry and all weather objects. Keep avatar/world/HUD at their existing resolution and verify nearest filtering.
6. Validate native tests, the complete special render dataset, pixel comparisons, exported Windows behavior and the physical Android build. Preserve existing original sessions and use only the isolated Android QA package.

Follow-up scope remains explicit: nested render groups, variable/sequence/procedural animations, specialized pet/transform hooks and all original-game behavior are not certified complete. Dataset compilation and atlas bounds do not prove complete visual parity.
