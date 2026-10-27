# Format compatibility

Local items.dat: v27, 16,434 sequential IDs, SHA256
eff775961cc8d62fd7e523990a0ecbc9421d34fda210c32bf954b2383e31d921.
The project parser consumes every declared record and all bytes. Unknown fields
and v27 variable extensions remain hex, without invented semantics. Tests cover
early, middle, last records, duplicate/truncated IDs and unsupported versions.

The H-pun checkout parser reports ID 65536 instead of 1 on this file. The 0.2.3
wheel is tested separately; its actual error is recorded in
evidence/render-regression/toolkit-compatibility.json. Neither parser replaces the
working project implementation. Both converters agree byte-for-byte on 38 core
PNG outputs, without force_opaque. Full-sheet decode precedes slot-specific crops.
Dimensions, bounds and alpha are validated; UI padding is not an item frame.

Packed colors are little-endian [A,R,G,B]. Visual types 4/7 use adjacent columns at
200 ms; types 20/22/27/38/39 use two frames tinted from the following seed record.
Type 8 shirts suppress ordinary arms. These rules do not implement every custom
costume, ride or shader. Icon thumbnails are not substituted for wearable sheets.
