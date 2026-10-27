import hashlib
import io
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
index = json.loads((root / "data/web-wardrobe-index.json").read_text())
pngs = (root / "assets/web-wardrobe/atlas.bin").read_bytes()
records = (root / "assets/web-wardrobe/records.bin").read_bytes()
layers = 0
for key, sheet in index["sheets"].items():
    raw = pngs[sheet["offset"]:sheet["offset"] + sheet["bytes"]]
    assert hashlib.sha256(raw).hexdigest() == sheet["sha256"], key
    image = Image.open(io.BytesIO(raw))
    assert image.size == (sheet["width"], sheet["height"]), key
    image.verify()
for key, (offset, length) in index["items"].items():
    item = json.loads(records[offset:offset + length])
    assert str(item["id"]) == key
    if not item.get("bk"):
        continue
    sheet = index["sheets"][item["bk"]]
    for layer in item.get("L", []):
        width, height, row, columns, count = layer[4:9]
        assert width > 0 and height > 0 and columns > 0 and count > 0
        assert min(columns, count) * width <= sheet["width"], key
        assert row + ((count + columns - 1) // columns) * height <= sheet["height"], key
        layers += 1
result = {"items": len(index["items"]), "verified_pngs": len(index["sheets"]),
          "verified_layer_bounds": layers, "failures": 0}
(root / "evidence/hybrid-assets.json").write_text(json.dumps(result, indent=2))
print(json.dumps(result))
