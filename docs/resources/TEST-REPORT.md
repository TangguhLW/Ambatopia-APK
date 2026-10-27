Current status: [0.14 update](UPDATE-014.md) supersedes older availability/build/capacity statements below. Historical evidence is retained.

# Verification — 0.13, 2026-10-23

| Check | Actual result | Evidence |
|---|---|---|
| Full Godot suite | 40,819 checks, zero failures | evidence/render-regression/tests-godot.log |
| Node data/server/import tests | 27 pass, zero failures/skips | tests-node.log |
| Independent pixel/atlas audit | 144 exact RGBA images; 8,162 valid bounds | evidence/local-resource-update/pixel-audit.json |
| H-pun checkout and wheel decoder | Each matches all 38 core PNGs | toolkit-compatibility.json |
| Exported Windows application | Behavioral QA passes | windows-export-test.log; evidence/windows/qa-report.json |
| Real Supabase session | 33 checks pass including cleanup | live-online.log; evidence/supabase-online/cleanup.json |
| Actual Godot Supabase adapter | 11 checks, no failures | evidence/supabase-online/godot-client.json |
| Packaged APK source identity | Current 0.13 source hash matches | apk-source-verification.json, apk-after.txt |
| Secret leakage scan | Backend credentials absent from EXE and APK | private-builds.json |
| Windows previews | Legacy PID 35296 kept open; fresh 0.13 PID 25832 verified visually | live-013.png |

Final Windows sample: 63 exported checks pass, median frame 40.678 ms, p95 42.652 ms,
local world entry 1809 ms, ready-to-menu 482 ms. Earlier samples were faster;
multiple live previews remained running. This is not an isolated capacity or
Android performance benchmark. No zero-lag claim is made.
Historical QA labels mentioning device or Android Back simulate events on Windows.

Before/after videos and viewport captures are under
evidence/render-regression/{before,after}, using native Windows OpenGL rather than
a browser. The after fixture also includes walk and expression expiry, so video
durations differ. Equipment matrix covers 12 examples, both directions and three
poses; full special-body mapping for Legendbot remains unverified.

Android: old APK was 0.10.0. New signed debug APK is 0.13.0, code 13, minimum API 24,
target API 36, arm64-v8a, Godot 4.7.2 compatibility renderer. Official templates package native
Godot libraries, not a WebView. Build tools 35.0.1 are used; Godot warns that a
build-tools version matching target 36 is absent. Packaging/signing succeed.
No Android device/emulator is attached: GPU, IME/autofill, cutouts and physical
touch performance remain unverified.

Temporary accounts were removed. One older synthetic world NETQAC767280D0A is
retained because Thaney is actively present; its session is not kicked for cleanup.
The old live-window update marker did not prove every script was replaced: a
stale background remained visible. A fresh 0.13 EXE was therefore opened and
inspected while retaining the original window/session. Pack-application counters
are not used as proof of complete code replacement.

Final artifacts: build/android/Ambatopia-0.13.apk and
build/windows/Ambatopia-0.13-final.exe. Source revision:
36093c3e6dae4d3cfe5d237d1a95757e5e7b8a2e3135b22d4f07bda711cec60f.
The older open 0.13 preview predates the last arm-settling correction; use the
versioned final EXE for an exact match to the APK. The original online session
remains open. Private-build audit and APK source verification refer to final files.
