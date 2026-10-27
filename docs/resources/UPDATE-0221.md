# Windows 0.22.1 — source death sequence, punch curves and movement buffs

## Lava correction

This supersedes the creative heat behavior in UPDATE-0211. Lava contact now starts death immediately for an ordinary player. God mode, verified fireproof equipment and the short respawn grace period remain exceptions. Movement, jumping, punching and block changes are blocked while dead. At two seconds the player returns to the white door. The body scale completes its recovery at 2.496 seconds.

The body/arm rotations, expression 5, mint tint, scale keyframes, floating angel sprite, sprite frame changes and particle trajectories come from the cached simulator `research/web-wardrobe/archive/respawn.json`. The scream starts at death; the original teleport recording plays at 2.02 seconds. The floating sprite keeps its original world origin when the body respawns and is not shrunk by the body's scale. No generated fire or substitute emoji is used.

The simulator's movement rules normally count lava contacts; immediate lethal contact follows the user's latest requested behavior. This distinction is intentional, rather than a claim that the source uses the same contact rule.

The 36 captured item overrides are selected using equipped source item IDs, chain priority, body overrides, tint/angel suppression and their additional sound/particle schedules. Both referenced particle templates and inline particle records are supported. All 36 are exercised for finite curves and available textures; only the default sequence has been visually compared in this update. Not every special death is certified visually identical.

Five WAV files are copied from the read-only local installation with hashes in `assets/reference/manifest.json`. Runtime assets live inside the project and exported pack. The application does not need the installed Growtopia directory.

## Punch and effects

The captured punch archive has 324 profiles. The renderer now selects the alternate long-target anchors/curves in 239 profiles, resamples inherited curves onto alternate time keys, switches sprite frames, applies the original normal/additive layer, handles signed scale and source alignment, and corrects the missing 16-pixel horizontal anchor offset. Default arm, stretch, hand visibility and face keys come from the source profile. Cosmetic target distance is included in bounded peer motion metadata; it grants no world permission.

The legacy particle compiler now supports 43 source programs across 176 captured rows belonging to 147 items. New support includes safe helper statements, source sheet/frame dimensions, independent X/Y scale, flip and alignment. Scalar scale is no longer incorrectly multiplied into independent scale. The importer includes death sheets and preserves exact RGBA pixels for all 288 available sheets. The source's missing `pets/p_tv` remains explicitly missing.

## Functional buffs

Source worn-item lists now connect ice skates/anti-slip, slippery clothing and paired clothing, floaties, climbing equipment and snowshoes to movement. Ice retains momentum without anti-slip; floaties cap sinking at 40 px/s and pull upward at -320 px/s while jump is held; climbing equipment can latch against a pushed wall; snowshoes remove the captured snow jump penalty. Removing equipment removes the effect. These are tested behavior changes, not catalog-only labels. Baseline Godot movement remains an adaptation.

## Verification

- `evidence/death-punch-all.log`: full native suite, 89,958 checks and no failures or script errors.
- `evidence/death-punch-unit.log`: 17,442 death/punch/buff checks, including all 36 captured death override entries.
- `evidence/source-effects-audit.json`: source/output hashes and atlas bounds, including death templates and inline death frames.
- `evidence/source-effects-pixels.json`: 288 exact RGBA matches with the read-only installation.
- `evidence/death-punch-windows-final.json`: exported Windows interactions and frame-time measurements.
- `evidence/death-unchanged-scope.json`: 13 old-web reference source files and two APKs retain their baseline hashes.

The latest executable is `build/windows/Ambatopia-0.22.1.exe`, using its own isolated QA profile. No Android installation, Supabase migration, account change or old Ambatopia web edit is part of this update.

## Still unfinished

This is not 100% simulator parity. Sixteen captured legacy programs remain unsupported and are listed individually in `data/source-particle-programs.json`. Some typed custom emitters, punch follower/repeated-child/bolt retargeting, XP/drop/economy modifiers and public online Rayman charge/triple-hit authority remain unfinished. Existing ancestral emitters are separate from the legacy count. The remaining work is retained here rather than marked complete or silently replaced with generic effects. Windows frame measurements do not certify Android performance.
