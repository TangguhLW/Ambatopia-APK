# Windows 0.21.1 — material edges, heat, crack recovery and ancestral particles

This update fixes the over-connection introduced in 0.20.1. The solid-neighbor seam policy described in UPDATE-0201 is **removed**. Different materials now keep their own source atlas edges; dirt immediately below rock, lava or bedrock has its green top edge. Same-source material and explicit source connect-groups still join. Both placement encodings resolve the same source item. No glue behavior is inferred from collision solidity.

## Crack recovery

World damage has a five-second inactivity timer. Each real damage event refreshes that tile's timer. Expiry clears damage and the required-hit/crack stage, so the next punch starts fresh. Tile replacement, removal, world creation and restore also clear temporary damage. The timer runs once per world, rather than once per player; multiplayer player count cannot accelerate it. Network events lacking explicit hit counts now advance the local stage and start its timeout. The project SQL already resets stale damage after five seconds in `20261023_event_recovery.sql`; no database migration was made.

## Lava

Legacy lava and both catalog placement encodings trigger the same hazard. First contact starts burning, a warm skin flash, original fire particles, the copied local `audio/fire_pop.wav` recording, and upward/sideways knockback. It does not immediately teleport the player. Contact feedback has a 0.65-second cooldown. Heat accumulates while overlapping lava and decays away from it; 1.5 accumulated seconds of exposure causes respawn. Burning lasts 1.2 seconds after the latest contact. God mode and fireproof clear heat/burning. These timings implement the requested creative heat behavior; they are not measured official-game timings.

The local predicted simulation uses this behavior. Remote burn is bounded cosmetic motion metadata; it cannot change account roles or world authorization. This update does not certify the public multiplayer movement authority against modified clients. No account/database permissions were changed.

## Thirty ancestral variants

`ancestral_particles.gd` implements the thirty captured ancestral `anc` emitters from the cached simulator archive. These use native typed emitter/particle data, separately from legacy particle IDs. The supported family has `R`, `lot` and `fr` records and no child, table or curve-array programs. The implementation reads the original little-endian field values for emission interval, initial/target velocity, scale interpolation, alpha oscillation, minimum alpha, color oscillation, lifetime, additive blending, and source sprite cell. Variant selection and horizontal/vertical emission placement follow the source sine/range records. The visible colors differ for Wisdom, Dimensions, Seed of Life, Riches, and Time. All available levels are exercised.

The code is mapped from `research/web-wardrobe/set.readable.js`: typed emitter creation at lines 41701 onward, particle update at 41930 onward, and the particle draw at 34388. `evidence/ancestral-source-coverage.json` lists all thirty item IDs. Source records are read from the existing packed wardrobe data. No new/generated imagery is used.

An additional rendering defect was removed: ancestral items without a source worn-sprite program no longer fall through to an inventory-thumbnail overlay on the face. Higher-level items that have source orbit hooks retain those hooks. The family capture is `evidence/render-regression/ancestral-021.png`.

## Verification and remaining coverage

`terrain_heat_reset` exercises mixed-material edges, cross-encoding joins, crack refresh/expiry, heat before respawn, sustained exposure, god mode, and every captured ancestral variant. The full native test suite and exported Windows QA results are in `evidence/terrain-heat-all.log` and `evidence/terrain-heat-windows-final.json`. The export additionally checks visible source fire, sound dispatch, ancestral emission and crack timeout, with screenshots. Source effects and weather remain subject to measured Windows frame budgets; this is not an Android performance result.

The executable is `build/windows/Ambatopia-0.21.1.exe`, with an isolated QA profile. Old Ambatopia web, its database and APKs are unchanged. Original Growtopia resources remain read-only.

This completes the three reported terrain/heat/crack fixes and the thirty ancestral particle emitters. It does **not** complete every other special emitter, all punch attachment/child programs, XP/drop-rate/economy buffs, or online Rayman charge/triple-hit mechanics. Those limits from UPDATE-0201 remain recorded; they are not covered by the new ancestral renderer and must not be described as 100% native parity.
