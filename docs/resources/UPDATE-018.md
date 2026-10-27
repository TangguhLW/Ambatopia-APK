# Native 0.18 — device retest and avatar fidelity

Godot remains the simulation, world, UI and rendering engine. No WebView is introduced. Ambatopia web source/database are not modified. No Supabase policy, credential or production account changes are part of this update.

## What was different

The attached phone initially had the original application package at version 0.10 while the isolated Ambatopia QA package was 0.17. Therefore opening the old main icon did not show the current QA build. A later inventory no longer found the old main package; this work did not issue an uninstall command. No backup of an absent application can be claimed.

Static decoding of the already cached reference set application recovered the base-arm crop, shoulder pivots, source punch column, sleeve passes, face layers and extension/recovery timing. Only its decoder functions ran in an isolated VM; the application itself was not executed by the decoder. Source: `web-client/dist/set/app.js`; readable evidence: `research/web-wardrobe/set.readable.js`.

## Fixes

- Bare arms use a 6×10 crop with the reference shoulder pivots rather than stretching the entire 8×16 storage cell.
- The rear arm performs the punch using source column nine (x=180), including shirt sleeve overlays and the 0.32-second extension/recovery interval. The front arm and its sleeve use the same pose angle.
- Regular wardrobe sleeve layers are split into rear-arm, body and front-arm passes instead of drawing every layer during the shirt pass.
- Ordinary wardrobe body masks now apply too; shoe and leg masks are no longer limited to custom costumes. Base body/foot rows follow the recovered composition.
- The face uses matching eye, face and pupil frames. The missing pupil sheet is decoded from the read-only local installation and included in the resource hash manifest; the angry punch expression replaces the old smile frame.
- Realtime validation accepts the new 0.32-second punch interval and still rejects values above it. Without this update, the start of a punch could drop an otherwise valid motion packet. This is locally tested packet handling, not a new crowded-online certification.
- The main menu displays the native build version to distinguish installed builds.

## Verification

Final result paths: `evidence/android-018-release/qa-report.json`, `evidence/wardrobe-018-release-windows.json`, `evidence/wardrobe-018-final-unit.log`. Each effect scenario measures 600 frames. Physical QA uses `org.thaney.ambatopia.qa` and isolated synthetic saves.

The independent pixel check verified 145 images and 8,162 item frame bounds with zero failures. Crop bounds do not certify every wardrobe animation. Red/green regression evidence covers ordinary shoe masks, sleeve passes, fist crop/pivot/direction, the front sleeve angle, expression choice, and accepted/rejected realtime punch duration.

The bounded weather surface and retained terrain from 0.17 remain in place. FPS measurements describe the attached Xiaomi under short local scenarios. They do not guarantee sustained 60 FPS on all devices, every outfit, thermal conditions or crowded multiplayer.

## Remaining differences

This is not 100% Growtopia Simulator parity. The native menus/controls remain the agreed Godot layout; the browser reference exposes a different desktop set-designer sidebar. The imported snapshot has 4,083 wardrobe definitions; the live reference now lists 4,103. Advanced instructions on 265 special definitions remain partially supported, and the entire web particle/pet/transform interpreter has not been ported. These limits are preserved from UPDATE-017 rather than hidden by successful runtime tests.

Release files: `build/windows/Ambatopia-0.18-release.exe`, `build/android/Ambatopia-0.18.apk`.

## Final exported results

Windows: 84/84 passed. Xiaomi Android: 84/84 passed. Native checks: 43,527 passed. Import/resource contracts: 8/8 passed. Runtime logs contain no SCRIPT ERROR or ERROR entries.

| Android scenario | Average FPS | p95 frame time | Frames above 20 ms / 600 |
|---|---:|---:|---:|
| legendbot | 60.09 | 17.102 ms | 2 |
| native_costume_particles | 60.09 | 18.326 ms | 5 |
| costume_and_iceage | 60.10 | 17.818 ms | 1 |
| costume_and_rlm | 60.12 | 17.848 ms | 3 |

APK signature verification passed v2/v3. Artifact SHA-256 values: `evidence/wardrobe-018-build-hashes.json`. Occasional long frames remain despite approximately 60 FPS average. Original user Windows PID 35296 remains open; final 0.18 release is also open separately.

After the device owner readied the install dialog, the normal main package installation succeeded and its launcher was opened. Package verification confirms versionCode 18 / 0.18.0-ambatopia-native. Installation used an in-place install command, not uninstall. The separate QA package remains available.
