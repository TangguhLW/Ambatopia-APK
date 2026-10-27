# Windows 0.29.4 — further machine and resource reconstruction

## Scope

Native Godot only, Windows debugging, no subagents. No Android export, Supabase migration, account change or old Ambatopia web edit. The Windows executable is `build/windows/Ambatopia-0.29.4.exe`. The final exported QA report and process identity are retained in `evidence/machines-0294-summary.json` after verification.

## What further source inspection established

The live editor now serves `wp.app.js?v=dad4259b31`, SHA-256 `ce06c6ac1056bbfa3dc5e42ff766efedf07facfa2e0042ec4f1324fd4f56c75f`. The bundle and decoded data are retained in `research/machines-029/`. Its provider metadata is byte-for-byte equivalent as JSON to the earlier table: 44 provider entries but only 32 ordinary drop tables. All eleven previously missing entries remain absent. Its isolated `blastWorld` still has ten generators; the five Starship blasts, Harvest Moon and Thermonuclear are absent. The weather dataset still has 77 recipes, without Frozen Cliffs or Celebrity Hills. Decoding executes only the string decoder/resource transformation and isolated generator closure, never the browser application's entry point or its integrity checks.

Local `GameData/Configs/WeatherTypes.yaml` confirms distinct native weather types, including Custom Haze (28), Custom Items (29), Background (34), Mascot (41), Treasure (44) and Growtopia Sign (51). Selected local textures were decoded and visually inspected: `mtn_1/2/3` are icy cliffs, `mtn_sky` is their sky, and `hills1/2/3_growtopia` contain the Celebrity Hills scenery and Growtopia sign. Alpha, original image dimensions and atlas padding are recorded in `data/native-weather-029.json`. Only eight selected textures are copied into the bundle. Runtime paths are relative, and original installation files remain read-only.

REA identified the installed native executable and its hash. Native decompilation/search could not run because no Ghidra/IDA provider is configured and Hopper does not support this Windows host. A separate read-only byte string scan recovered no matching clear-text machine definitions. This does not prove those behaviors are absent from the executable; native function reconstruction remains unverified.

## Provider implementations

**Gumball Machine (16104)** now produces 1–2 Bubble Gum (1772), and **Ice Cream Truck (16238)** produces 1–2 Deep-Fried Tropical Ice Cream (6316). Both reset their timer to 79,200 seconds (22 hours), reject premature harvest and return the permanent item on destruction. A restored/imported provider without a timer initializes one safely. Harvest actions now also emit the material punch sound event, which the previous provider early-return path omitted. Sources: [Gumball Machine](https://growtopiawiki.com/w/Gumball_Machine), [Ice Cream Truck](https://growtopiawiki.com/w/Ice_Cream_Truck).

**Eight Winterfest calendars** have distinct published reward pools, original item identities/quantities, daily release boundaries, a 25-gift limit and the correct used-calendar transformation. Later calendars have their specific day groups and separate day-15/day-25 pools. Claims persist in world state. Owner/world-lock checks, unreleased-day rejection, malformed-choice rejection and spent-state rejection apply. Historical gifts accumulate; Creative unlock exposes all historical days without manufacturing a new reward table.

The server's complete random distribution is **not** in the simulator or local resource metadata. Calendar collection therefore explicitly asks the player to choose from that day's published candidates. The UI calls this **creative reward replay** and says original odds are unavailable. It is a functional item-specific adaptation, not a claim of recovered random odds. Punching opens that selection rather than silently damaging a calendar or granting unrelated loot.

Calendar sources: [2017](https://growtopiawiki.com/w/Winterfest_Calendar_-_2017), [2018](https://growtopiawiki.com/w/Winterfest_Calendar_-_2018), [2019](https://growtopiawiki.com/w/Winterfest_Calendar_-_2019), [2020](https://growtopiawiki.com/w/Winterfest_Calendar_-_2020), [2022](https://growtopiawiki.com/w/Winterfest_Calendar_-_2022), [2023](https://growtopiawiki.com/w/Winterfest_Calendar_-_2023), [2024](https://growtopiawiki.com/w/Winterfest_Calendar_-_2024), [2025](https://growtopiawiki.com/w/Winterfest_Calendar_-_2025). Saved HTML snapshots and item-ID/name validation accompany `data/machine-recovered-029.json`. The wiki is community documentation, not authoritative server code; unpublished probabilities are deliberately not inferred from list order or rarity labels.

**Well of Love** has a five-chest contribution action, persistent progress to 200 chests, rejection of overfilling, final harvest and conversion to Dry Well of Love. Contributions use the free creative inventory and let the player choose a documented Golden Booty Chest reward. The original best-of-five chest RNG is not fabricated. Final harvest uses the documented 96.75% Pure Love Essence / 3.25% epic split; the user selects an epic preview because individual epic weights are not published. The interface explicitly describes these differences. Sources: [Well of Love](https://growtopiawiki.com/w/Well_of_Love), [Golden Booty Chest](https://growtopiawiki.com/w/Golden_Booty_Chest).

All eleven previously nonfunctional provider entries now have an executable path, but nine use the clearly identified creative reward replay. They must not be reported as eleven recovered native RNG implementations. The total is 35 ordinary harvest providers including ATM, plus eight calendars and the well.

## Weather

Five previously refused machine entries now have dedicated rendering/control paths:

- **Heatwave:** source RGB controls, integer validation, 0–255 range and the requirement that at least one channel is 40 or brighter. Rendering uses the actual local `haze.rttex` texture tinted by the saved values.
- **Stuff:** selected source item icon, gravity from −500 through 500, spin and invert controls. Falling images are the actual inventory icons rather than substituted dots or emoji.
- **Background:** selected background-block texture; foreground items are rejected.
- **Frozen Cliffs:** actual local icy-cliff/sky layers. This also supplies the missing visual path for the existing Treasure blast.
- **Celebrity Hills:** actual local hills and Growtopia-sign layers.

Controls, persistence and source asset identities are verified. The simulator does not ship corresponding custom/frozen/celebrity render recipes. Layer geometry, fog/rain timing and density are therefore native-asset adaptations, **not measured 1:1 render programs**. No unsupported animation frame is claimed as recovered.

Infinity is corrected to four slots, gains its source random-order switch, and uses the source 1–240 minute interval range. Epoch uses its source 1–60 minute range. Previous five-slot behavior was an adaptation, not the inspected source rule.

**Guild weather remains unavailable:** it requires an actual Guild-Locked world and guild mascot metadata. There is no guild model in this reconstruction or corresponding simulator renderer data. Its activation continues to report the missing capability rather than displaying an unrelated crest. Source: [Weather Machine – Guild](https://growtopiawiki.com/w/Weather_Machine_-_Guild).

Coverage is now 51 usable machine paths of 52, with the adaptation qualifications above. This is not 51 proven pixel-identical effects.

## Blasts

Two additional generators implement documented behavior:

- **Thermonuclear:** cleared foreground/background, bottom bedrock and a door at the left or right edge, without special weather.
- **Harvest Moon:** a regular terrain world, harvest weather and 99 mature source trees. Each tree has an actual seed, fruit count and growth state; harvesting works through the normal seed implementation.

These are marked `documented reconstruction` in world state and in the resulting message. The precise server RNG, terrain parameters and tree selection distribution are not recovered. The reconstruction uses one bottom bedrock row for Thermonuclear and a surface tree layout for Harvest Moon; these choices are adaptations, not source facts. Sources: [Thermonuclear Blast](https://growtopiawiki.com/w/Thermonuclear_Blast), [Harvest Moon Blast](https://growtopiawiki.com/w/Harvest_Moon_Blast).

The ten earlier source-generated templates remain intact. **Five Starship generators remain unavailable:** Imperial, Stellarix, Greezak, HyperTech and Protostar. Their public pages and local Startopia metadata were examined, but no tile layouts/generators were found. `rest.data.star` describes sectors, fuel and equipment ratings, not ship layouts. No invented ship is substituted as an original map.

## Jammers and permissions

- **Zombie Jammer** blocks player-to-player g-Virus infection in the local authoritative room server. Direct g-Virus application still works, matching its documented exception. Existing infection uses the simulator's `Infected!` modifier and 60-second duration. The pandemic exception is represented by the server's world-effect flag; no full pandemic event system is claimed.
- **Balloon Jammer** now has a five-second on/off countdown, retained until the server/local game tick applies the new state, and blocks War Balloon use while active. The complete Balloon Warz scoring/projectile minigame is not implemented by this patch.
- **Public switching** lets guests toggle an explicitly public machine without damaging its protected tile or acquiring configuration rights. Public permission is checked separately from owner-only settings. Protected-world player punching also follows the same Punch/Zombie Jammer policy as an unlocked room.
- Known permanent jammers, the generator and weather machines return their item when broken.

Sources: [Zombie Jammer](https://growtopiawiki.com/w/Zombie_Jammer), [Balloon Jammer](https://growtopiawiki.com/w/Balloon_Jammer), and the inspected simulator switch handlers. All multiplayer checks in this update concern the native local RoomServer; Supabase online policies, discovery and RPC handlers are unchanged and are not claimed as tested here.

## Verification and remaining work

`tests/suites/machines_029.gd` covers every calendar day across eight calendars, exact provider identities/quantity limits/cooldowns, 200-chest well progression, spent-state behavior, dedicated weather activation/configuration validation, documented blast structures, jammer countdown/infection exceptions and public-switch lock safety. It first failed against the previous implementation. The exported Windows harness additionally presses real native panel signals, renders/captures each new weather and waits for the five-second jammer transition.

Pending work remains explicit: one guild weather, five Starship layouts/generators, undisclosed calendar/chest/epic RNG distributions, exact visual timing/anchors for the newly adapted weather/blasts, remaining machine-specific animation programs, the full Balloon Warz minigame, the original global one-second weather punch throttle, and Supabase multiplayer integration for these new rules. Existing earlier wardrobe/effect limitations are not erased by this machine update.

Community wiki data is credited above under the license displayed on the referenced pages. Cached source pages, machine rule references and local asset hashes are retained for comparison; only selected project assets/data are bundled.

Final verification: **307771 native checks and 330 exported Windows checks, zero failures**. Five existing heavy costume/weather scenarios measured 59.99–60.19 FPS on this Windows machine, p95 at most 17.611 ms. No script/runtime/build errors were found in the saved final logs. Build-manifest hashes match every current corresponding source/asset. Thirteen old-web files, two previous APKs, the original executable and selected native assets retain their hashes.

The initial exported run's fixed-duration countdown assertion failed; a focused probe showed the machine deadline completing correctly. The final harness waits for the actual state transition with a seven-second ceiling and records before/after wall-clock evidence. Calendar choices refresh immediately after collection. Final Heatwave inspection removed visible texture end/join edges using off-screen overscan; this remains a layout adaptation. The final screenshots were visually inspected. The EXE remains open; no other game process was closed by this update.
