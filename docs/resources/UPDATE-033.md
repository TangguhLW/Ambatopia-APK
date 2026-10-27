# 0.33.1 — Spirit Guide and multiplayer appearance

Windows Godot only. The old Ambatopia web project, Android builds, original Growtopia installation, accounts and cloud policy are unchanged.

## Behavior implemented

- Spirit Guide now leaves black silhouettes of the equipped avatar during movement. A bounded history clears on teleport, death or unequip. One transparent GPU viewport per active Spirit Guide renders the body and wardrobe once; three echoes reuse its texture. Particle, aura and pet layers are excluded from capture to prevent recursive emission and duplicate effects. Pixel filtering remains nearest.
- Neon Nerves and Speed Medallion share their speed contribution. Neon can combine with up to two additional distinct Speedy items. Encoded catalog IDs are normalized and duplicate IDs cannot manufacture stacks. Swimming and Xenonite suppress land speed as before.
- Online and offline already share WorldView, AvatarView and Inventory. Snapshots no longer overwrite newly equipped local outfits. Pet visibility is validated, transmitted by the local server and authenticated private Supabase motion channel, and applied to remote avatars. Roster refresh preserves cosmetic and death/punch motion state while identity, role, skin and equipment continue to come from SQL.
- The local QA server accepts an alternate port only in explicit QA mode, allowing verification without restarting the existing game server.

## Evidence and limits

The current simulator bundle was fetched again from `https://growtopiasimulator.com/set/app.js?v=67acd14fd1`. SHA256 remains `182e6a79acdb1fda186a9334a66fe72326529abda2bbb022413c5145a0fbe4dc`; see `research/wearable-033/source-check.json`.

Source sprite layout, hover equation, Neon emitter and Medallion lightning remain from the earlier verified records. The simulator's movement configuration does not establish the exact Speedy stacking multiplier. The native increment remains an explicit adaptation: +0.25 per contribution, maximum 1.75 with Neon. The compatibility rule is documented at [Neon Nerves](https://growtopia.fandom.com/wiki/Neon_Nerves).

Spirit Guide's shadow behavior is corroborated by player references, including [the multiple-shadows identification](https://www.reddit.com/r/growtopia/comments/ebxxt6/). Its exact silhouette timing was not recovered from the simulator. The native echo ages (60/120/180 ms), opacity and current-pose capture are adaptations; this is not a claim of measured 1:1 timing. The old ground ellipse is no longer used for Spirit Guide.

## Validation

- Red/green regression: `evidence/wearable-033-red.log` and `evidence/wearable-033-green.log`.
- Full native suite: `evidence/wearable-0331-all-final.log`.
- Twelve real loopback WebSocket clients: `evidence/wearable-033-real-network.json`.
- Targeted exported Windows visual regression: `evidence/wearable-0331-windows-final.json` and screenshots copied beside it by the verification script. The extended Windows run ended with exit code 0 before writing its final report; it is not counted as a completed full GUI pass.
- Final artifact, hashes, preserved old-web/APK checks and measured frame times: `evidence/wearable-033-summary.json`.

Supabase transport validation uses synthetic authenticated-channel packets in the native suite. No production accounts were used, and live Internet Supabase crowd performance has not been measured. This update does not complete every outstanding item effect or every gameplay difference between local and online modes.
