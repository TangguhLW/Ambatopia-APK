# Reproduce resource and build verification

Run from the project root with Node, bundled Python/Pillow and tools/godot.ps1.

1. Audit the read-only installation: scripts/audit-resources.mjs.
2. Refresh core assets: scripts/import-assets.mjs --source <installation> --out assets/reference --sync.
3. Parse/import native data: scripts/build-catalog.mjs. It stages a content-addressed
   generation and validates before publishing. Existing item IDs are preserved.
4. Map exact simulator/native matches: scripts/map-local-sprites.mjs. Retarget wiki
   enrichment only after validating every retained ID/name against the new index.
5. Independently compare toolkits: scripts/review-toolkit-compatibility.py; verify
   pixels with scripts/verify-local-pixels.py. Neither needs wiki network requests.
6. Run Node tests and Godot tests/run.gd all. Capture with
   tests/render_regression_capture.gd and tests/equipment_matrix_capture.gd.
7. scripts/build.ps1 -Target All -WindowsOutput build/windows/Ambatopia-0.13-final.exe
   -AndroidOutput build/android/Ambatopia-0.13.apk. Build-info hashes are packaged.
8. Verify APK identity with aapt and scan both artifacts with
   scripts/check-private-builds.py. Run scripts/test-windows.ps1 for exported QA.

Project overrides and source metadata remain separate. Texture and catalogue
caches are bounded. Failed import/network enrichment does not replace the active
generation. Python and wiki APIs are tooling only, never APK dependencies. Review
new format versions before changing parser bounds; do not skip bytes speculatively.
Old source generations are excluded from exports, as are research, tests and
server/private. No runtime source path points into the Growtopia installation.
