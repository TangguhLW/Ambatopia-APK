import hashlib
import io
import json
from functools import lru_cache
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: json.loads((ROOT / p).read_text(encoding='utf-8-sig'))
index = read('data/inventory-icons.json')
items = read('data/simulator/items.json')
local = read('data/local-sprite-overrides.json')['items']
fixtures = read('evidence/inventory-026-source-cells.json')['cells']
pack = (ROOT / 'assets/inventory/icons.bin').read_bytes()
seeds = read('data/simulator/seed-icons.json')

@lru_cache(maxsize=8)
def sheet(path):
    return Image.open(ROOT / path).convert('RGBA')

@lru_cache(maxsize=3)
def page(number):
    row = index['pages'][number]
    raw = pack[row['offset']:row['offset']+row['bytes']]
    assert hashlib.sha256(raw).hexdigest() == row['sha256']
    return Image.open(io.BytesIO(raw)).convert('RGBA')

failures = []
verified = 0
for key, row in items.items():
    if 's'+key in index['unavailable']:
        continue
    try:
        number, px, py = index['entries']['s'+key]
        actual = page(number).crop((px, py, px+32, py+32))
        expected = Image.new('RGBA', (32, 32))
        if row[7] == 19 and key in seeds:
            x, y = seeds[key]
            expected.alpha_composite(sheet('assets/ambatopia/seed-icons.png').crop((x,y,x+16,y+16)), (8,8))
        else:
            path = local[key][0] if key in local else f'assets/simulator/atlas/{row[1]}.png'
            image = sheet(path)
            x, y = fixtures[key]
            frames = [(x, y)]
            if row[13] in (20,22,27,38,39): frames.append((x+1,y))
            if row[13] == 26: frames.append((x,y+1))
            for cx, cy in frames: expected.alpha_composite(image.crop((cx*32,cy*32,cx*32+32,cy*32+32)))
        assert actual.tobytes() == expected.tobytes(), 'RGBA differs from source-cell composition'
        if row[7] == 19:
            assert actual.crop((0,0,32,8)).getbbox() is None, 'Seed margin was stretched'
        verified += 1
    except Exception as error:
        failures.append({'id':key,'error':str(error)})
report = {'source_pixel_matches':verified, 'failures':failures, 'unavailable':index['unavailable'], 'pack_hash_matches':hashlib.sha256(pack).hexdigest()==index['pack_sha256']}
(ROOT / 'evidence/inventory-026-pixels.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
raise SystemExit(1 if failures or not report['pack_hash_matches'] else 0)
