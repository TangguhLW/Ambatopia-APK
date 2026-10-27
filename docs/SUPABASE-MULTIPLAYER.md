# Supabase multiplayer migration

The Windows game uses the dedicated `ambatopia-godot` project
(`hbptqogoihmguhdizqcf`), never the earlier web game's database.
No Google Cloud billing account or VM is needed for this design.

Movement remains local at 60 Hz. Authenticated Realtime channels carry compact
movement samples, with remote interpolation and stale-sample rejection. Persistent
world changes must go through database functions that validate identity, ownership,
protected tiles and concurrent updates; a client broadcast cannot grant ownership,
moderation permissions or change a world.

This is a change of network architecture, not merely a different WebSocket URL.
The existing `room_server.gd` executes physics, item automation and moderation on a
local authoritative Godot server. Supabase Broadcast alone does not execute that
server. Its commands must be ported and tested before switching the production
Online button. Do not expose a service-role key in an EXE/APK or elect a player
client as a trusted developer/server.

Rollout gates:

1. Private-channel authorization binds each movement channel to one account.
2. Transactional world commands reject cross-owner writes, duplicate locks,
   protected-tile deletion and simultaneous conflicting placements.
3. Authentication and registration use server-side quotas; account names never
   grant developer permissions.
4. Two isolated test accounts exercise join, reconnect, motion, punch, chat,
   wardrobe and world edits over the deployed service.
5. Retain local creative and the existing server transport until those checks pass.

Free-tier quotas still apply. This design does not promise unlimited connections,
zero network latency or authoritative anti-cheat physics.

## Deployment verified 2026-10-23

Native AmbaID signup is enabled. The Before User Created hook validates the
internal alias, reserves Thaney, and limits signup to two accounts per trusted
Auth request IP. Client profile metadata cannot choose the IP or developer role.
IP buckets use a private salted hash. Deleting an account releases its quota.
Email confirmation is off specifically because these aliases cannot receive mail;
anonymous sign-ins and phone authentication remain off. No mail or SMS was sent.

`data/network.json` enables this transport and contains only the public URL and
publishable key. Never package `server/private/.env` or a secret/service-role key.
Native signup testing passed nine checks and removed both temporary accounts.
Real network testing passed 33 checks; the actual Windows Godot client passed
11 movement, jump, punch, sound, peer interpolation, chat and block checks.
Evidence is under `evidence/supabase-online`.

World mutation events are persisted and fetched by ordered cursor as well as
announced over Realtime. A missed lock broadcast occurred during testing and was
recovered successfully. Local physics does not wait for HTTP round trips.

Limitations: this is a two-client functional test, not a capacity test. Free-tier
quotas apply. Movement is client-simulated, not authoritative anti-cheat physics.
Disconnected clients currently require rejoining. Event retention needs a bounded
cleanup/snapshot policy before sustained production use. Special machine/gacha
commands from the local Godot server are not all ported; unsupported online
commands return an explicit error. The local creative implementation remains.
The old web project and original player accounts were not changed.

References: https://supabase.com/docs/guides/realtime/protocol and
https://supabase.com/docs/guides/realtime/authorization

## Bounded crowd verification — 0.14

Nine simultaneous synthetic accounts passed: eight protocol clients and one actual Godot world client with eight remote avatar states. All 448 expected protocol motion deliveries arrived; Godot also received every sender, punches, chat and the shared block update. World lock denied all seven non-owner protocol peers. Nine accounts/world were cleaned. Evidence: `evidence/supabase-online/crowd.json`, `crowd-cleanup.json`.

Traffic was eight aggregate motion broadcasts/s, below Free's 100 events/s ceiling with nine recipients. This is sparse traffic, not proof of nine simultaneously active players at 10 Hz. At that rate fanout alone would approach 810 events/s, beyond Free. Idle players now send only changed states or a five-second keepalive. Full-rate busy rooms still need a different relay/batching architecture or sufficient service capacity; the test did not change quotas, billing or authorization. References: https://supabase.com/docs/guides/realtime/limits and https://supabase.com/docs/guides/realtime/settings .
