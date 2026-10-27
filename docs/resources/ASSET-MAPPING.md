# Applied asset mapping

Installation remains read-only. Core manifest now has 44 entries, including 38
PNGs. Added face, extraleg and sleeve source resources for inspection/composition.
Native body/head/eyes/arm/feet replace pre-baked video animation at runtime.
The video jump strip faced the opposite direction to walk; removing that mixed
source convention fixes the visual flip without changing logical facing.

Cell origin is (-16,-32). Verified padded hair/hat frames use (-16,-48). Held
item source art was placed at the face; its cell now starts at (-16,-16).
Feet use independent limb offsets. Front arm is composed after torso clothing.
Punch geometry follows a normalized world-space target, mirrored once; the
existing vertical puncharm source is rotated around the shoulder. Exact original
punch easing/extension is not recovered. Punch overlays existing angry face/mouth
frames, while text chat uses a bounded mouth cycle; this is not voice chat.

equipment-matrix.json and equipment-{idle,jump,punch}.png cover 12 representative
items in both directions. Entry 1780 remains explicitly unverified as a full mech.
8,162 strict native/simulator item matches remain mapped across 106 local sheets;
six version conflicts remain excluded. Pixel bounds alone do not verify anchors.

Inventory uses gui_itembox source cells (40×40) with preserved six-pixel borders.
Non-game pages use the native panel nine-slice with an opaque readability backing.
Weather uses a full viewport; portrait tiled layers preserve aspect ratio with
uniform scaling and a matching tile stride. No jump-derived vertical horizon is
passed to the background. Terrain, tile backgrounds and HUD remain separate.
