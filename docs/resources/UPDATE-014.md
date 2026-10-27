# Update 0.14 — 2026-10-23

The current Windows and Android game retains the approved main-menu and in-world UI direction. The old Ambatopia website and its database were not changed. No subagents, billing changes, email or SMS were used.

- Eight source-backed XML costumes are wearable: Fireworks Mohawk, Mobile Suit Wings, Golden Mobile Suit Wings, Hair of Fionn, Captain Lazerhawk's Eye, Angelic Circlet, Constellation Wings and Barong Dance Costume Shirt.
- Fixed XML `frame` attributes being ignored, native alignment, back-hat render ordering, state-specific wing frames, non-looping final frames and stored alpha/float curves. Idle motion broadcasts are suppressed until a five-second keepalive; movement stops and punches still send updates.
- Fixed hotbar clipping on wide screens: obsolete scaled minimum heights no longer push the actual container below the screen. Regression checks cover 1280x720, 1560x720, 568x320 and 390x844.
- Full Godot suite: **40,844 checks / 0 failures**. Node: **27 passed / 0 skipped**.
- Exported Windows and physical Xiaomi M2003J15SC (Android 12, Mali-G52): **71 checks each / 0 failures**, including eight special costumes. A real Android OS swipe opened the backpack, with screenshot evidence.
- Live dedicated Supabase: **9 simultaneous accounts**, eight protocol clients plus the real Godot world client. **448/448 protocol motion deliveries**, 8 distinct remote avatars in Godot, chat/block replication and lock denial. Median delivery ~52 ms, p95 ~221 ms. All nine temporary accounts and the temporary world were removed.

Crowd traffic was bounded at eight aggregate motion broadcasts/second (one update per sender/second); this is NOT proof that nine continuously moving players at ten updates/second fit the Free tier. The current transport still fans out motion to each subscriber. Official limit documentation: https://supabase.com/docs/guides/realtime/limits and https://supabase.com/docs/guides/realtime/settings . No project limits or RLS were relaxed for testing.

Physical Android validation covers local gameplay, actual GPU rendering and OS backpack swipe. The live crowd test ran on Windows; simultaneous online play between Windows and the phone, actual IME/autofill and every screen/cutout remain unverified. Automated touch-routing checks are distinguished from human finger testing.

Current files: `build/windows/Ambatopia-0.14-final.exe`, `build/android/Ambatopia-0.14.apk`. The phone uses a separate `org.thaney.ambatopia.qa` package with identical game code/assets; the original package and its data were not overwritten. The APK download alias is refreshed. The old locked Windows EXE alias is NOT the current build; use the versioned file directly.

Evidence: `evidence/render-regression/tests-current.log`, `node-current.log`, `windows-014-qa.json`, `apk-014-source-verification.json`, `private-014-builds.json`; `evidence/android-physical/014/`; `evidence/supabase-online/crowd.json`, `crowd-cleanup.json`; `evidence/special-rules/native-pixel-audit.json`. See `MISSING-AND-UNVERIFIED.md` for the tracked remainder.


Final timing sample: Windows entry 446 ms, frame p50/p95 16.66/17.609 ms. Xiaomi entry 1569 ms, frame p50/p95 28.623/37.559 ms. These are this device/run's measurements, not universal latency or 60-FPS guarantees. Final source revision: 19dc694d0d098acebe0f7ffaaf07bcc2f844a30ba4ef0cb6a2f0ddc57d5e81c8.
