Current status: [0.14 update](UPDATE-014.md) supersedes older availability/build/capacity statements below. Historical evidence is retained.

# Regression implementation — 0.13

| Reported issue | Root cause | Change | Evidence |
|---|---|---|---|
| Jump flips character | Walk/jump video strips have opposite baked facing | Native composed avatar; one facing transform | Before/after animation, 140 airborne facing assertions |
| Equipment alignment | Pre-baked body differs from atlas cell; held anchor at face; front arm below shirts | Shared native cell, dedicated head/held/foot anchors and draw passes | 12-item matrix, both directions and three poses |
| Missing animated/tinted clothes | Only visual type 0 was admitted by canonical catalogue | Known visual classes admitted and rendered from metadata | 1,411 supported canonical wearables; Hot Head/dress captures |
| Punch ignores target visually | Pre-baked horizontal animation lacked target direction | World target direction, source puncharm, held extension, remote direction validation | Cardinal/diagonal tests, real Godot transport test |
| Punch/talk expression missing | Face baked into video; chat never drove expression state | Existing native eyes/face frames, bounded talk timer, punch priority | Pose tests and animation; exact native timing unverified |
| Background cut/seam | Weather logical height forcibly reduced to 55% | Full viewport, proportional portrait tiled layers | Three viewport captures, stable-horizon test |
| Backpack differs/readability | Generic slot frames and translucent busy backing | Native slot atlas/nine-slice, opaque backing, existing virtualized scroll | Inventory captures and exported touch tests |
| About/login overflow | Unbounded root text; form and panel were siblings | One bounded scrolling panel, labels, keyboard/safe-area layout | Short landscape/portrait captures and keyboard-space simulation |
| APK misses recent changes | APK was 0.10 while Windows was 0.12 | Distinct APK/EXE 0.13, packaged source hashes | aapt before/after, build-info and package audit |

No changes to the older Ambatopia web project or original accounts. Source
installation files were never changed. The live EXE is kept open during updates.
No APK was installed because no Android device/emulator is currently detected.
Windows touch simulation is not Android hardware verification. See the missing
list for specialized costume, keyboard and multiplayer scope limits.
