import hashlib
import io
import json
import os
from functools import lru_cache
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))
digest = lambda data: hashlib.sha256(data).hexdigest()
items = read('data/simulator/items.json')
local = read('data/local-sprite-overrides.json')['items']
catalog = read('data/catalog-index.json')
seeds = read('data/simulator/seed-icons.json')
source_hashes = {}


@lru_cache(maxsize=8)
def image(path):
    raw = Path(path).read_bytes()
    source_hashes[path] = digest(raw)
    return Image.open(io.BytesIO(raw)).convert('RGBA')


def cells(x, y, spread, kind):
    offset = {2: 12, 5: 12, 3: 3, 7: 3, 10: 3, 8: 3, 4: 4, 9: 3}.get(spread, 0)
    x += offset & 7 if spread in (2, 5) else offset
    y += offset >> 3 if spread in (2, 5) else 0
    result = [(x, y)]
    if kind in (20, 22, 27, 38, 39):
        result.append((x + 1, y))
    if kind == 26:
        result.append((x, y + 1))
    return result


def render(path, frames, seed=False):
    sheet = image(path)
    icon = Image.new('RGBA', (32, 32))
    for x, y, size in frames:
        if x < 0 or y < 0 or x + size > sheet.width or y + size > sheet.height:
            raise ValueError(f'Icon outside atlas: {path} {(x, y, size)} / {sheet.size}')
        icon.alpha_composite(sheet.crop((x, y, x + size, y + size)), (8, 8) if seed else (0, 0))
    return icon


entries, pages, chunks, failures, samples, unavailable = {}, [], [], [], {}, {}
page = Image.new('RGBA', (1024, 1024))
used = 0
offset = 0
deduplicated = {}


def flush():
    global page, used, offset
    if not used:
        return
    output = io.BytesIO()
    page.save(output, format='PNG', compress_level=6)
    raw = output.getvalue()
    pages.append({'offset': offset, 'bytes': len(raw), 'sha256': digest(raw), 'size': [1024, 1024]})
    chunks.append(raw)
    offset += len(raw)
    used = 0
    page = Image.new('RGBA', (1024, 1024))


def store(key, path, frames, seed=False):
    global used
    try:
        icon = render(path, frames, seed)
        signature = digest(icon.tobytes())
        if signature in deduplicated:
            entries[key] = deduplicated[signature]
            return
        if used == 1024:
            flush()
        x, y = used % 32 * 32, used // 32 * 32
        page.paste(icon, (x, y))
        entries[key] = [len(pages), x, y]
        deduplicated[signature] = entries[key]
        used += 1
        if key in ('s2', 's4', 's8', 's10', 's242'):
            samples[key] = {'source': path, 'frames': frames, 'rgba_sha256': signature}
    except (OSError, ValueError) as error:
        if key == 's12244' and isinstance(error, ValueError):
            unavailable[key] = {'source': path, 'reason': str(error), 'name': items['12244'][0]}
        else:
            failures.append({'key': key, 'source': path, 'reason': str(error)})


plans = {}
for key, row in items.items():
    if row[7] == 19 and key in seeds:
        plan = ('assets/ambatopia/seed-icons.png', [(*seeds[key], 16)], True)
    else:
        path, frame = local.get(key, [f'assets/simulator/atlas/{row[1]}.png', [row[2]*32, row[3]*32, 32, 32]])
        frames = [(x*32, y*32, 32) for x, y in cells(frame[0]//32, frame[1]//32, int(row[4]), int(row[13]))]
        plan = (path, frames, False)
    plans[key] = plan
    store('s'+key, *plan)


@lru_cache(maxsize=2)
def detail(number):
    return {str(item['original_id']): item for item in read(f'{catalog["details"]}/{number}.json')}


for entry in catalog['entries']:
    key = str(entry['id'])
    if not entry['preview']:
        continue
    if key in local and key in items and entry['name'] == items[key][0]:
        if 's'+key in entries:
            entries['n'+key] = entries['s'+key]
        continue
    record = detail(entry['page'])[key]
    raw = record['raw_metadata']
    frame = entry['frame']
    # Local metadata has renderType, but no verified multi-layer kind for unmatched versions.
    frames = [(x*32, y*32, 32) for x, y in cells(frame[0]//32, frame[1]//32, int(raw['renderType']), 0)]
    store('n'+key, entry['asset'], frames)

flush()
report = {'simulator_items': len(items), 'mapped': len(entries), 'unique_icons': len(deduplicated), 'pages': len(pages), 'failures': failures, 'samples': samples, 'unavailable': unavailable}
Path('evidence/inventory-026-build.json').write_text(json.dumps(report, indent=2))
if failures:
    raise SystemExit(f'Icon generation rejected: {len(failures)} source/atlas errors; previous pack preserved')
pack = b''.join(chunks)
index = {'schema': 1, 'entries': entries, 'pages': pages, 'pack_sha256': digest(pack), 'source_hashes': source_hashes, 'unavailable': unavailable,
         'rules': 'Simulator iconCell + _4b0fc0: isolated spread cell, alpha-over kind layers, centered half-size seed; local verified PNGs preferred'}
Path('assets/inventory').mkdir(parents=True, exist_ok=True)
Path('assets/inventory/icons.bin.new').write_bytes(pack)
Path('data/inventory-icons.json.new').write_text(json.dumps(index, separators=(',', ':')))
os.replace('assets/inventory/icons.bin.new', 'assets/inventory/icons.bin')
os.replace('data/inventory-icons.json.new', 'data/inventory-icons.json')
print(json.dumps({**report, 'samples': None, 'pack_bytes': len(pack)}))
