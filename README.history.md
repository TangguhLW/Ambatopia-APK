# Growtopia Reconstruction — local reference and item catalog

Current Windows build: **0.19.2 native Godot** - [Windows EXE](build/windows/Ambatopia-0.19.2.exe), [results](docs/resources/UPDATE-0192.md). Source face/lid layers, jump/fall expressions and distance-driven gait corrected; material-specific hit/break recordings imported. 102/102 exported Windows checks passed. Android remains the previously tested [0.19 APK](build/android/Ambatopia-0.19.apk), unchanged by this Windows-only update. Old Ambatopia web remains separate. Older sections below are historical.



Independent Godot 4.7.2 project. Windows x64 first, with an Android arm64 debug APK. This project does not modify or connect to Ambatopia, official game servers or official accounts.

## Current build: 0.10.0 — backpack, mobile controls and wardrobe alignment

Weather layout now has a stable viewport horizon, independent of player jumping and vertical camera motion. The inventory drawer follows the finger continuously, snaps open/closed, and opens with a tap. HUD controls no longer steal touches from inventory/menu overlays. Mobile movement/action targets are larger and separate from the quick slots.

The source collection has 16,508 searchable records, including all 4,071 wardrobe entries (the previous category filter omitted 47 artifacts). Blocks filters building items; All items exposes the entire collection. A virtual scrolling grid creates only visible rows. Native special wearables use their runtime equip capability. Headwear has a separate head anchor; torso/lower clothing preserve the body cell origin; standard shoes render both native foot frames. Complex body replacement and item-specific animation fidelity remain incomplete.

Windows: `build/windows/Ambatopia-0.10.exe`. Android: `build/android/GrowtopiaReconstruction.apk` (in-place package update). The Windows executable has a new name so the older QA server executable need not be stopped or overwritten.

Verification: `evidence/ui-revision/result.json` and `evidence/ui-revision/progress.md`. Hosting research: `docs/free-vps-2026-10-23.md`. No VPS was provisioned, public server deployed, or old Ambatopia web modified.

## Previous build: 0.9.0 — Crystal Chi, Xenonite and automation

Crystal clusters hold up to five colored crystals, choose the highest-rarity recovered matching recipe, retain their randomized elemental requirement, and only shatter into that output when 3x3 foreground/background/water/fire Chi matches. Wrench the cluster to inspect the counts and requirement.

Xenonite exposes Normal/Force/Block for nine world powers and blocks powerup use when configured. Rules affect every player's abilities, preserve their outfit, clear on crystal break, persist in world data and synchronize online. Host physics strengths use this project's existing movement model, not a newly verified official-server physics implementation.

MAGPLANT 5000, Gaia's Beacon and Unstable Tesseract collect a chosen compatible floating item every 0.5 seconds, respect 5000/1500 capacities, and preserve overflow. MAGPLANT Remote builds from that stock and only subtracts on success. Heart of Gaia, Tesseract Manipulator and Techno-Organic Engine have target selection, a free creative fuel allowance capped at 8000, and 1.5-second source action timing. Automated effects respect other players' area locks.

The Android launcher now uses the user's Ambatopia-logo, with app label Ambatopia and APK version 0.9.0. This is an in-place update using the existing app identifier.

Final evidence: `evidence/automation-rules/result.json`; source/rulings: `evidence/automation-rules/progress.md`. This remains an independent local PC/USB project. The old Ambatopia web and its database are not modified. Other unrecovered machine minigames and native effects remain unfinished; official-server parity and WAN performance are not claimed.

## Previous build: 0.8.0 — recovered special machines and native wardrobe effects

Silkworm care, color and silk harvesting; three-bolt sewing; hammer/chisel fossil extraction; floating-fossil brushing; Phone Booth outfit exchange; shared Howler/Trickster projectiles; Solar Collector charge and growth boost; and grinder input quantities now use recovered source-specific rules. Their panels expose the relevant controls instead of unrelated generic actions.

Fireworks Mohawk and both Mobile Suit Wings use locally recovered XML/sprite animations and action-dependent particles. These three items now equip normally and replicate online.

Verification and limits: `evidence/special-rules/result.json` and `evidence/special-rules/progress.md`. Windows executable and Android debug APK are in `build/`. APK testing uses the connected physical Android phone. The local account/game services and dedicated game database remain separate from the old web project. Other unique machine minigames, native body replacements and unrecovered item effects remain unfinished creative adaptations; complete official-game parity is not claimed.

## Previous build: 0.7.0 — playable creative items

Open **Clothes** to double-tap any of the 4,071 source wardrobe entries. Source clothing slots, description-based movement/jump/digging abilities, visible aura/trail/pet effects and timed consumable modifiers work locally and synchronize online. Unique native body replacements and every bespoke shader/ability are not reproduced.

Open **Simulator**, search an item, select it and tap a nearby world tile to use it. Plant seeds in empty space above a solid block. Mature trees can be punched to harvest; wrench a tree/provider for **Creative grow** and **Harvest**. There are 8,251 ordinary-player seeds (protected Fist/Main Door/Bedrock seed IDs stay excluded), real growth clocks and splicing, 44 provider cycles, and 571 consumable definitions with implemented or creative-adapted actions. Rewards become collectible world drops.

Wrench a placed machine to add free stock, dispense items, label it, activate it or use a recipe. DNA processing, cooking, clothing recycling and grinding expose 544 recovered recipe outputs. Dice, roulette and slot-style machines work without real money; creative slots use deposited stock or a free reward pool. Original pack/rarity tables, complex special-machine minigames and all original input quantities are not claimed identical. Unrecovered special machines remain explicitly creative configurable props.

All 80 weather choices render without script errors, including 27 layered complex scene ports; bespoke motion functions are approximations and three backgrounds use image-plus-animation adaptation. Item extras, clocks, stocks, wardrobe and collected items persist locally and in the dedicated game database.

Verified: 40,168 Godot checks; 22 Node tests; 43 checks each on exported Windows and physical Xiaomi Android; 12 item-network checks; six real Supabase item-persistence checks; 64 software clients. Portrait/landscape UI and all 80 weather captures are in `evidence/item-gameplay/`. Final short-sample entry times: Windows 252 ms, Android 775 ms. Android frame p95 21.798 ms is above a 60 FPS frame budget. Synthetic accounts were cleaned; Thaney remains the only developer; normal authenticated local/USB services are running. APK signature/private-key exclusion verified.

`evidence/item-gameplay/result.json` is the current acceptance report. Previous version sections below are historical. All categories have usable creative behavior; full native Growtopia parity remains a separate unfinished target.

## Previous build: 0.6.0 — 23 October 2026

Reference-video walk, jump and punch playback; the Simulator inventory tab contains 16,508 source entries alongside the separate native catalog. Common blocks/backgrounds, 31 lock types and 80 weather choices are integrated. Complex weather uses image fallbacks, and preview-only items are labelled rather than claiming working effects.

Online commands: `/sb message` broadcasts AmbaID/world/text with a persisted 30-minute cooldown. World owners can use `/kick name`, `/pull name` and `/ban name` (24 hours). Developer controls include Transform Amba, protected-tile breaking and moderator promotion/removal. Small/Big/Huge/Builder locks have 10/48/200/200-tile limits; coverage is a bounded approximation, not confirmed native flood-fill parity.

The local broker permits two new accounts per address. Test quotas are isolated from normal registrations. Existing accounts are not retroactively assigned an IP. USB-connected phones share the PC loopback address for this local setup. In-memory sessions skip credentials while retaining offline/online mode choice and live online count.

Verification: 1,329 Godot checks, 22 Node tests, 12 real synthetic account/RLS checks, 30 authenticated checks each on exported Windows and physical Xiaomi Android, plus a 64-client loopback protocol test. World-entry samples: Windows 198 ms, Android 572 ms. Android frame p95: 20.554 ms; constant 60 FPS is not claimed. APK signature and private-key exclusion verified. Temporary cloud accounts removed; normal authenticated services restored.

Full results and remaining gaps: `evidence/ambatopia-next/result.json`. This is an intermediate release: all-item behavior, special wardrobe/effects, provider harvesting, seeds, blasts, complex machines and gacha remain unfinished. Older evidence sections below are historical.



## Run



- Windows: open `build/windows/GrowtopiaReconstruction.exe`. It contains its PCK; no Godot installation is required to run the exported executable.

- Android: install `build/android/GrowtopiaReconstruction.apk`. This is a debug-signed APK, package `org.thaney.growtopiareconstruction`, Android 7.0+ arm64. Android may require owner approval for USB/sideload installation. Internet permission is enabled for the project's own local multiplayer transport; official servers/accounts are not used.

- Choose **Play Online** to register/login with AmbaID and password, or choose offline creative mode. Accounts and shared worlds use the dedicated Supabase project `ambatopia-godot`; the existing Ambatopia web project is separate.

- Start the account broker with `node --env-file=server/private/.env server/accounts.mjs`, then run `scripts/start-shared-server.ps1`. Private configuration stays on the PC and is excluded from exports. Both services listen on loopback only. Android testing requires USB forwarding for ports 4192 and 4193. Public Internet hosting is still pending.

- Normal multiplayer requires a verified account. `-QA` on the server explicitly enables anonymous isolated tests; never use it as the normal service.





Controls: **A/D** or **Left/Right** move; **Space/Up** jump; **F** always punches. **1** selects punch, **2** dirt placement, **3** wrench inspection. Click a nearby tile to use the selected tool. **E** opens inventory; **Enter** opens local chat; the top-right menu contains Save and Exit World. On Android hold the direction/jump/fist controls; movement and jump support separate simultaneous fingers.



Inventory has **Blocks**, **Clothes** and **Catalog** tabs. The offline version-27 index contains 16,434 original item IDs, 8,188 static inventory previews and **1,080 wearable items** from standard clothing atlases. Search by name/original ID, filter by category/slot and switch pages. **Wear**, **×** and **Reset** change the appearance. Preview-only special renderers cannot be equipped. Fairy Wings, Angel Wings and Golden Angel Wings enable double jump; Pickaxe enables enhanced digging. Ability parameters and native animation timing remain provisional. Shared sessions synchronize players, outfit, punch, blocks and chat; a World Lock prevents duplicate locks and other players' mutations. Authenticated world ownership persists after disconnect; anonymous QA locks clear when their owner disconnects. These are separate support counts, not a full wardrobe/effects/MMO claim.



Worlds/equipment save on exit and every 15 seconds. Exported Windows saves use `%APPDATA%/GTRef`; Android uses this package's private files. The short Windows folder avoids shader-cache path limits in long workspace paths. Failed/corrupt loads are reported and preserved. The repository tool wrapper isolates editor/test data under `tools/profile`; tests use separate fixture folders. Android Back opens/closes the world menu; Windows Close saves an active world before quitting.



## Develop and verify



Use PowerShell 7 and Node 24.21.0. Toolchain downloads stay under `tools/`; original assets remain read-only.



```powershell

./tools/install-toolchain.ps1

./tools/install-android.ps1

node scripts/import-assets.mjs --source C:/Users/user/AppData/Local/Growtopia --out assets/reference

./tools/godot.ps1 --headless --path . --editor --import

./tools/godot.ps1 --headless --path . --script tests/run.gd -- all

node --test tests/import-assets.test.mjs

./scripts/build.ps1

./scripts/verify-build.ps1

```



The complete Godot template archive is 1.2 GB. `tools/fetch-template-subset.mjs` can fetch the four required members from the same official HTTPS archive with ZIP CRC32 validation and record their local SHA256 hashes. This subset procedure does **not** verify the full archive's SHA512; the editor archive itself is verified against the official SHA512 release list. No global Godot/MCP configuration is changed. Android tooling uses the existing research JDK via a recorded local path.



`./scripts/test-android.ps1` installs only this package, resolves its exported launcher and runs instrumented synthetic fixtures. It reads back only this app's QA report/screenshots. It does not change device security settings or inspect other apps. Device installation prompts must be approved on the device.



## Evidence and known gaps



See `evidence/acceptance.json`, `evidence/fidelity-2026-10-22/`, `evidence/catalog-2026-10-22/`, `research/catalog/README.md` and per-platform QA reports. The comparison board is served locally at http://127.0.0.1:4190/ while its server runs. Tests demonstrate implemented local behavior; they do not prove 100% fidelity to native Growtopia.



Reference texture bytes, font and selected sounds come from the read-only installed client whose identity is pinned by the importer. RTTEX rows are reversed into upright PNGs. Native sprite timing, frame assignments, collision constants, background geometry and several UI details remain provisional. Official behavior comparison and full item catalog coverage are incomplete.



Full wardrobe effects, all weather/blasts/providers/machines/gacha/consumables/seed growth, farming/trading/economy, public multiplayer hosting and web export remain unfinished. This is a runnable intermediate build, not a completed MMO. Original resource ownership remains with the respective owners; no public asset redistribution or store release is included.



## Version 0.5 verification — 23 October 2026



New title/fade, chooser music, responsive menus, double-tap wardrobe, swipe backpack, pinch zoom, rocks/lava, account profiles and developer controls are implemented. There are 1,080 standard wearable items and 836 supported static catalog blocks; metadata presence is not equivalent to complete item behavior.



Final build: 1,289 Godot checks, 20 Node tests, 33 checks each on exported Windows and physical Xiaomi Android, 10 account/RLS checks, and 8 protocol checks with 64 loopback clients. Separate authenticated device runs passed 30 checks each. These are local/USB measurements, not public latency guarantees. Evidence: `evidence/ambatopia-2026-10-23/` and per-platform reports. APK signature verified; private service credentials absent from EXE/APK. Synthetic accounts cleaned. Thaney is the sole developer; real-account password login was not retried after automatic approval review rejected that test.

