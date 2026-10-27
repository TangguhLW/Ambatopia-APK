# Windows 0.23 — sixteen legacy effects, source punch retargeting and material audio

## What changed

The sixteen programs listed as unsupported in 0.22.1 now compile and execute from the captured simulator JavaScript: 70, 91, 95, 117, 126, 130, 152, 233, 236, 238, 253, 256, 257, 294, 365 and 382. This removes that particular unsupported list; it does not mean every item effect in the game is complete.

The importer resolves numeric registry references, inherited object properties, helper calls with multiple statements, array lookup and map, RGB tables, owner references and the source periodic clock. The Godot evaluator preserves JavaScript object/array truthiness. The renderer supplies current equipment slots, jump-effect windows, water state, movement angles and speed, dynamic intervals and owner position/velocity. These inputs were necessary for the translated programs to actually emit when worn. Programs that change their own particle ID, such as Undead Slippers, now switch to the corresponding source update/cell program after initialization.

Examples tested through worn-item emission include Rainbow Wings, Autumn Wings, Shamrock Wings, Ring of Winds, Floating Leaf, Present Goblin Disguise, MightyBOOSH, Ride O Gold, Speed Medallion, jetpack and pants, Space Thruster Boost Boots, Scepter of the Honor Guard, Horns of Infinity, Undead Slippers and Crystal Infused Sword. Program 233 has no direct wardrobe emitter in the captured archive; its supplied-color projectile behavior is tested independently.

## Punch behavior

Punch particles now have their own lifetime, emission position and captured facing instead of being redrawn as if attached to the current player every frame. The `fol` flag explicitly follows the player; ordinary particles remain at their emission origin. The source `pf` repeated emitter, `cone` fan, `sk` ballistic sparkle curve, vertical `bolt`, front/back normal/additive layers, per-frame flip and tint/tint2/rainbow rules have dedicated implementations. They are not replaced by one generic emitter. Budgets remain bounded.

`source_punch_aim.gd` ports the source's conservative affine-retarget algorithm. It accepts a transformed curve only when the near/far captures satisfy the original validation tolerances. An independent Node sandbox runs the original `_22c24f`, `_50c777` and helper functions against all 2,097 captured punch tracks at four aim points. The Godot test compares anchors, durations and every output curve for 3,628 accepted cases and verifies rejection of the other 4,760 cases. The source fixture file is evidence only and is excluded from the game bundle.

The original punch sound schedule now runs with each source profile. All 52 referenced sound names have packaged local WAV bytes, checked against source hashes. `spooky_20` is located under `audio/notes/`; simulator `Flamego` maps to the installed recording `audio/flame_go.wav`. The latter name mapping is explicit in the index: byte identity with the simulator's web recording has not been established. Sound cache loading is bounded; it does not require the installed game at runtime.

## Distinct material sounds

The simulator simplifies several materials to `wood_damage`/`wood_break`. The user's request for distinct material feedback is implemented as a documented native adaptation using original local recordings:

| Material | Hit | Break |
| --- | --- | --- |
| Dirt and grass | punch_organic | wood_break |
| Glass | glass_hit | punch_glass |
| Rock/stone | rock_hit | rock_destroy |
| Metal/locks | metal_hit | metal_destroy |
| Default/wood | wood_damage | wood_break |

Material classification comes from each catalog item's `hs` field, with explicit basic dirt/grass handling. Both placement encodings are checked for every catalog item. Empty-space and protected impacts retain their original miss/locked recordings. Blocks with the same material share a recording; this does not fabricate a unique sound for every item ID. The five added recordings are byte-for-byte copies in the reference manifest.

## Verification and scope

- `evidence/effects-023-all.log`: complete native suite, 174,625 checks, zero failures and no script errors.
- `evidence/effects-023-special-unit.log`: independent punch-source comparison, worn emitter conditions, exact buff/effect numeric cases, audio decoding and all catalog material encodings.
- `evidence/effects-023-windows-final.json`: 146 exported Windows checks, zero failures; fifteen worn effect captures, five specialized punch captures and four distinct material sounds. The five 600-frame heavy-effect scenarios averaged 60.07–60.14 FPS, with frame-time p95 16.69–17.32 ms. Local world entry was 553 ms on this Windows machine.
- `evidence/source-effects-audit.json`: source/output hashes, atlas bounds and 52 original packed recordings.
- `evidence/source-effects-pixels.json`: 288 exact RGBA sheet matches. `pets/p_tv` remains absent.
- `evidence/effects-023-unchanged-scope.json`: thirteen old-web reference files and two existing APKs retain their recorded hashes.

Only the Godot reconstruction and isolated Windows fixtures were changed. No Android install/debug, old Ambatopia web change, Supabase migration or account operation was performed. The newest EXE is `build/windows/Ambatopia-0.23.exe` and is left open.

## Remaining limits

The compiler now has 61 executable program entries and no errors for the requested sixteen. Five other captured wardrobe rows still refer to programs not extracted by this importer: Riding Comet 112, Riding Meteor 113, Chaos Corruption 302, and Neptune's Chariot 36/232. Those are separate from the sixteen completed here and are listed in the audit rather than hidden.

Dynamic pet/attachment anchor movement, several native typed custom emitters, original pet follow physics, XP/drop/economy buffs and public online Rayman charge/triple-hit authority remain outside this Windows revision. The punch affine calculation is independently source-matched; that alone does not certify every final animation, equipment interaction or online action as 100% identical. Windows frame measurements do not certify phone performance.
