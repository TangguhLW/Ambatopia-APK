# Native 0.19 — wardrobe UI and advanced costume programs

Godot remains the engine. This update does not modify Ambatopia web, its database, accounts, hosting or Supabase policies. The old Windows session remains open separately.

## Interface

The backpack now has a navy category rail, a persistent search field, named item cards with the original previews, an equipped-item dock, selection borders and direct unequip controls. Items remain virtualized instead of creating thousands of controls. Category buttons filter the full catalog, and names wrap inside each card. The narrower rail and grid adapt to narrow Windows layouts and mobile landscape dimensions.

An upward drag follows the finger and opens the backpack; a deliberate downward drag closes it without requiring most of the drawer height. Chat history is scrollable rather than limited to six clipped lines. Chat reserves space for its input field and keeps the top drag handle. Colors and card layout follow the cached Growtopia Simulator reference while the agreed native world/menu controls remain Godot.

## Costume interpreter

New shared support includes nested transform groups, branch stop conditions, variable assignments/arithmetic, translated/scaled/rotated groups, target stretch/rotation, source line/tether commands, persistent state machines, timed state exits, variable curves/interpolation, procedural sprite curves, sequence animations, delayed visibility, and pose overrides for arms/feet. Integer action IDs are normalized when compared with JSON numbers; the old comparison silently skipped some source branches. Custom punch callbacks can suppress the default fist instead of drawing two overlapping punch paths.

Examples exercised include Growch Biceps, Lace Parasol, Balloon Backpack, Celestial Belt, Burning Pearl Spinner and Farmer Aura. The Balloon Backpack uses its authored curve, three tether endpoints and vector assignments; Lace Parasol uses its delayed visibility sequence, falling arm pose and its own heart particles. No AI-created wardrobe art is used.

29 source particle sheets were decoded from the read-only local installation into a separate indexed pack, with source/output hashes and relative runtime paths. All 2,172 referenced particle frames fit their source sheets. A bounded native particle pool uses the stored sprite frames, lifetime, offsets, velocity, scale/alpha curves and triggers for supported emitter definitions. Existing native XML emitters retain priority to avoid duplicate effects. Unsupported captured effect programs are not disguised as generic yellow dots or orbiting item thumbnails.

## Evidence and limits

The original group of 265 flagged costumes is exercised over idle, walking, jumping, falling and punching, including a long idle sequence. The timeline audit records 82,150 updates and checks finite coordinates/source atlas bounds. This proves interpreter execution and geometry bounds, not complete visual/behavioral parity with the browser.

Some custom shader/outline instructions, manually triggered particle operations, advanced particle conditions and specialized callbacks still need implementation or visual parity review. Some source items intentionally draw only particles and therefore have no sprite commands. The broader 1,158-item structural audit uses additional review flags and is not numerically comparable with the old 265-item list. No claim that all 265 costumes are now 100% identical is made.

The touch regression originally passed logical viewport coordinates directly into synthetic input on Android, where the screen scale is 1.5×. Converting injected coordinates with the viewport screen transform fixes that test and preserves the app's normal touch handlers. Probe output records touch binding and final drawer position. Reference: [Godot viewport and canvas transforms](https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html).

Final result paths are `evidence/android-019-native/qa-report.json`, `evidence/wardrobe-019-final-windows.json`, `evidence/wardrobe-019-final-unit.log`, and `evidence/wardrobe-019-265-timeline.json`. The first `android-019` run is retained as failed test evidence and must not be represented as the final result.

Release files: `build/windows/Ambatopia-0.19-native.exe` and `build/android/Ambatopia-0.19.apk`.

The inspector now contributes its minimum height when positioning the drawer, keeping Wear/unequip and item details above the bottom edge. Source IDs and older native IDs share the worn-state test for both checkmarks and double-tap removal.


Native regression suite: 43,550 checks passed. A separate focused panel run passed 11 checks before adding the final inspector layout regression. Eight importer/resource checks passed. The timeline audit covered 265 costumes and 82,150 runtime updates with no finite-coordinate or atlas-bounds failures. Device FPS and final exported behavior are reported below, separately from that structural audit.

The inspector requests layout again when its minimum size changes. The terrain cache assertion accounts for newly visible chunks during the repeated-jump scenario and still requires every previously cached chunk to remain valid; this is not a relaxed FPS target.


## Final Windows measurements

The packaged Windows build passed 88/88 behavior checks. Five 600-frame scenes averaged 60.11–60.20 FPS; p95 frame times were 16.74–17.73 ms. The active advanced outfit reached seven source particles. Three frames across 3,000 measured frames exceeded 20 ms. The existing terrain cache rebuilt zero chunks during this Windows run. These are short controlled samples, not a guarantee for every outfit, device or multiplayer population.


## Final Xiaomi measurements

The attached Xiaomi (Android 12, Mali-G52) passed 88/88 exported behavior checks, including actual Godot touch dispatch and the selected-item inspector bottom boundary. Across five 600-frame scenes the mean was 60.20–60.29 FPS, p95 frame times were 17.51–18.53 ms, and 10 of 3,000 sampled frames exceeded 20 ms. Advanced wardrobe effects reached seven simultaneously active source particles. Existing terrain lists were retained (zero rebuilds, zero newly visible chunks in this run). Device report and screenshots: evidence/android-019-native/. This is one physical phone and short synthetic scenes, not evidence of every costume or sustained crowded multiplayer performance.

