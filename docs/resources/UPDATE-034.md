# 0.34.1 — gui and live multiplayer verification

Godot remains the engine. The existing Ambatopia web application is unchanged.

## Fixes

- Network equipment IDs now normalize from JSON numbers to native integers. Supported slot keys are retained; fractional IDs and privilege keys are rejected. Buff labels sort consistently, so the same outfit produces the same state regardless of JSON key order.
- Death-particle blend modes accept their actual source representations: numeric blend flags and string modes. The full Windows GUI run exposed a mixed-type comparison that headless logic tests did not execute.
- The equipped-item dock detaches old buttons and queues their deletion. It no longer frees a button while that button is emitting its own unequip signal. The Android run exposed this error; a native regression reproduces it and passes after the fix.
- GUI tests preserve legacy clothing, catalog equipment, skin and pet switches across their temporary appearance fixtures. Punch-particle checks observe several rendered frames after warming textures, rather than requiring a short-lived effect to remain alive at one arbitrary timestamp.
- Device tests write progress checkpoints and bounded application logs. Android test deadlines allow the complete suite to finish. These diagnostics use only this application's files and logs.

## Verification evidence

- Native regressions: `evidence/native-0341-all.log`.
- Full Windows GUI: `evidence/windows-0341-final.json`.
- Visible Godot client on deployed Supabase: `evidence/supabase-online/godot-client.json`.
- Nine-player live run: `evidence/supabase-online/crowd.json`.
- Physical Android GUI and live authentication: `evidence/android-0341/qa-report.json`.
- Temporary-account/world cleanup: the corresponding `cleanup.json` files.
- Artifact hashes, measurements and unchanged old-web checks: `evidence/platforms-034-summary.json`.

The live appearance test covers matching wardrobe IDs, skin, renderer, inventory state, Spirit Guide/StarBoard hover, Neon particles, pet visibility, movement, jump, punch audio, chat and block updates. The crowd test uses eight protocol clients plus one real Godot client. It delivers sparse aggregate motion traffic; it does not prove nine players at a full 10 Hz each.

## Current results and remaining deployment

Windows completed 386 checks without failures or runtime errors. The native regression suite completed 315,694 checks without failures. The physical Xiaomi completed 393 checks; 390 passed. Supabase login, world entry and the ordinary player role passed on the phone.

The three failed phone assertions concern shared seed metadata, tree harvesting and provider metadata. These exposed functionality absent from the deployed Supabase RPC, rather than another GUI stall. The initial interpretation of the delayed phone checkpoint as a rendering-cleanup stall was incorrect; the final report shows the suite completed. No shadow-renderer change was made on that unconfirmed hypothesis.

An atomic migration is prepared in `supabase/growth-deploy.sql`. It adds 8,298 source mappings for seeds and providers, server-owned growth timers, creative grow/harvest, source provider reward pools and ordered metadata/drop events. Local database tests pass for ownership, reach, protected access, immature trees, rewards, event recovery and repeat deployment. It has **not** been applied: the available Supabase dashboard is signed out. See `evidence/supabase-online/growth-pending.json`. The deployment requires the user to sign in to the existing `ambatopia-godot` project; it must not target the old web project's database.

The five heavy Android costume/weather scenarios measured approximately 60 FPS, with p95 frame times between 17.0 and 18.5 ms. The separate two-avatar rainbow/shadow scenario measured approximately 48.7 FPS and 22.4 ms p95. The corresponding Windows scenario measured approximately 61.4 FPS and 17.3 ms p95. These are bounded device scenarios, not a blanket mobile 60 FPS guarantee.

All disposable phone, two-player and crowd Auth accounts/worlds were removed after testing. The normal Android app was reopened after fixture cleanup. The Windows executable remains open.

Realtime latency remains variable. The later nine-player run received 448/448 expected peer deliveries, with median approximately 111 ms and p95 approximately 852 ms. This is not a zero-lag claim. No infrastructure billing or production access policy was changed.

The exact Spirit Guide silhouette timing and numeric Speedy increments remain documented adaptations from 0.33.1. This update does not claim completion of every remaining item-specific effect or full online/offline gameplay parity.
