# Native hybrid 0.16

Godot remains the runtime, physics, world chooser, game menus, touch controls and multiplayer client. The packaged WebView experiment is a reference workbench, not the selected game. Existing Ambatopia web code and its database were not changed; 13 pinned source hashes still match.

The supplied `ambatopia-main-theme` was verified as stereo MP3, 44.1 kHz, 320 kbps, 48.04 seconds. It was copied losslessly to `assets/ambatopia/main-theme.mp3`; SHA256 `52b02f260742e6f92aad5bbb2030814248eb80e85a0fde31fbfb2daac4413c1b`. Menu/login/options/about/download/terms share the theme without restarting when switching among those pages. World selection retains its choir, and music stops on world entry. Button captions are centered horizontally and vertically, including after viewport changes.

The pinned simulator Set archive yields 4,083 wardrobe definitions and 4,058 unique PNG atlases. Metadata and lossless PNGs are stored in indexed packs (8,102,790 and 13,792,057 bytes), with source/converted hashes in `data/web-wardrobe-index.json`. Runtime caches are limited to 64 textures and 64 records. Godot does not load a browser, contact the simulator to equip clothes, or import the reference web workbench. Source install paths are unnecessary on the phone.

2,899 regular wearable definitions now use recovered cropped geometry, body anchors, separate shoe/sleeve layers and reference stand/walk/air/punch frame sequences. Existing eight native XML visual paths remain for selected special equipment. The 848 scripted `g`, 316 `xr`, one `rds`, and remaining body/aura/custom render branches are retained as research data, **not all ported or verified**. Eight selected XML paths are not equivalent to porting all of those definitions. Existing native item effects/abilities remain; this update does not claim all web effects or costumes have complete parity. Atlas packing preserves all frames without implying behavior is implemented.

Verification:

- Godot: 40,878 checks, zero failures; 34 checks cover this update.
- Exported Windows and physical Xiaomi Android 12/Mali-G52: 77 checks each, zero failures. Includes music selection, caption centering, movement/jump/punch, no place-on-punch, stable chat, inventory swipes, equip/remove, reference clothing layers, selected effects and machines.
- World entry: Windows 819 ms, phone 1,168 ms. QA timing begins at ready, so menu-ready timing excludes operating-system/engine startup.
- Frame samples in the effect-heavy QA world: Windows median 16.811 ms / p95 21.828 ms; phone median 28.624 ms / p95 36.659 ms. This is not a stable 60 FPS phone result, and it is not an online latency measurement.
- APK signature v2/v3 verified. Package `org.thaney.ambatopia.qa` updated in place to native version 16; original player package/data untouched. Existing Windows sessions remain open, including the new version 0.16 preview.
- Multiplayer protocol unchanged in this update. The previous nine-account bounded online test remains historical evidence; this build was not retested at full crowded online load.

Artifacts: `build/windows/Ambatopia-0.16.exe`, `build/android/Ambatopia-0.16.apk`. Device QA uses the separate `Ambatopia-0.16-QA.apk`.

Evidence: `hybrid-tests.log`, `hybrid-windows-report.json`, `android-016/qa-report.json`, `hybrid-assets.json`, `hybrid-signature.log`, and `render-regression/hybrid-016-menu.png` / `hybrid-016-wardrobe.png` under `evidence/`.
