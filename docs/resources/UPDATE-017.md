# Native 0.17 — special costumes and mobile rendering

Godot remains the engine for physics, world selection, menus and controls. No WebView game is used. The old Ambatopia web source/database and original player accounts are unchanged. The final Windows executable remains open separately from the original user session.

## Special wardrobe

The native renderer now interprets the reference `g` body-component recipes and `xr` sprite hooks. It supports component assembly, body/slot hiding, front/back hooks, cropped anchors, mirroring, rotation, additive layers, basic action/motion selection, frame animation and alpha/position/scale/rotation curves. State is kept per player and cleared on unequip. Separate shoes and original regular clothing remain native.

Examples captured in both directions across idle, jump, fall and punch: Legendbot-009, Battlegrid Helmet, Constellation Wings, Mobile Suit Wings, Barong Dance Costume Shirt and Angelic Circlet. Reference icon-atlas fallback also fixes 20 newly enabled wearables whose native catalog had no preview image. Item identity/name matching prevents borrowing a differently named item from another catalog version.

The dataset audit exercises 1,158 special definitions in four poses and validates 9,597 generated draw commands, with zero script/bounds errors. **This is not complete parity:** 265 records have flagged advanced instructions, including nested groups, variable/procedural/sequence animation or additional custom render operations. Their basic paths may draw, but those advanced paths remain partial. Absence of an audit flag is not a blanket visual-equivalence claim. Existing eight native particle definitions are preserved; all web particle programs are not newly claimed as implemented.

## Performance

The original measured bottleneck was repeated terrain drawing: about 7.3 ms per frame on the Windows reference run. Static terrain now uses retained 16×16-tile chunks. Camera movement updates transforms; tile edits invalidate the affected chunk and adjacency neighbors. Seeds, damage, liquids/fire overlays and projectiles remain dynamic. An unchanged world no longer regenerates its terrain draw lists during the costume benchmarks.

Weather invariant expressions are compiled once. On Android, only weather uses a separate surface capped at 600 pixels high, or 480 with the existing low graphics setting. Logical geometry/aspect ratio and object counts remain unchanged; world, characters, text and controls keep their existing render resolution. This is a weather-resolution tradeoff, not a claim that downsampling preserves every physical screen pixel.

Four RGB comparisons for Ice Age and RLM at two fixed times verify identical pixels after expression compilation and identical pixels through the new render surface at a 1:1 reference resolution. An initial filtering mismatch was fixed by explicitly using nearest sampling. Original atlas pixels and frame bounds remain verified.

The initial Android benchmark after chunking alone still took roughly 31 ms in Ice Age and 27 ms in RLM. The bounded weather surface brought the extended 600-frame runs to approximately 16.64 ms median, with p95 approximately 17.96 ms and 17.08 ms respectively. The same runs retain 64/68 weather models and the native costume particles. These are local synthetic scenarios on the attached Xiaomi Android 12 / Mali-G52, not a guarantee for all devices, all outfits, thermal conditions or a crowded online server.

Final exported-build results and artifact hashes are recorded under `evidence/android-017-final-release/`, `evidence/special-017-windows-release.json`, `evidence/special-017-build-hashes.json` and `evidence/special-017-signature.log`. Intermediate reports are retained separately, including the failed frame-budget runs in `android-017-release` and `android-017-final`; they must not be substituted for final release results. Final scenarios use 600 frames each, and the device runner allows a quiet initial minute rather than launching a new ADB polling process every 500 ms. A separately reproduced duplicate weather redraw was fixed from 120 callbacks/60 main frames to 60/60; see the before/after draw-budget logs.

## Files and remaining work

Release: `build/windows/Ambatopia-0.17-release.exe` and `build/android/Ambatopia-0.17.apk`. Physical testing uses `org.thaney.ambatopia.qa`; the original Android player package/data are untouched.

Evidence includes `special-native-unit.log`, `special-017-catalog-audit.json`, `weather-pixel-equivalence.json`, `weather-surface-equivalence.json`, and `render-regression/special-017-{idle,jump,fall,punch}.png`. The full wardrobe pack remains 4,083 definitions / 4,058 PNGs with 5,513 layer-bound checks.

Open work remains in `MISSING-AND-UNVERIFIED.md`: advanced costume semantics and all item-specific effects, multiplayer reconnect/retention, broader device coverage and crowded online performance. No new Supabase policy, billing, hosting or old-web deployment is part of this update.

## Final release verification

Windows and the isolated physical Android package each passed 82 exported-build checks. Native unit checks: 43,513 passed; Node checks: 27 passed. All four Android scenarios use 600 frames each:

| Scenario | Average FPS | p95 frame time | Frames above 20 ms |
|---|---:|---:|---:|
| legendbot | 60.07 | 18.586 ms | 7 |
| native_costume_particles | 60.09 | 17.047 ms | 0 |
| costume_and_iceage | 60.16 | 16.884 ms | 3 |
| costume_and_rlm | 60.13 | 17.657 ms | 3 |

These short local tests meet the measured budget, but occasional long frames remain and this is not a guarantee of sustained 60 FPS on every phone or in crowded multiplayer. The latest Windows release remains open for inspection.
