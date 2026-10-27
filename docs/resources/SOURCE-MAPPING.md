# Source mapping

`scripts/map-local-sprites.mjs` requires agreement on ID, name, sheet filename,
coordinates, render type and action type before selecting a native sprite.
Source and converted sheet hashes are checked. Runtime paths are relative project
paths in `data/local-sprite-overrides.json`; provenance is recorded separately in
`evidence/local-resource-update/sprite-provenance.json`.
Conversion verifies RTPACK/RTTXTR layout, bounded decompression, RGBA8 dimensions
and exact byte length, then reverses native bottom-up rows. Pillow independently
checks PNG pixel bytes. Godot filtering/crop clipping prevents atlas bleeding.
