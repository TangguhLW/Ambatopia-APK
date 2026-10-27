import hashlib
import json
import struct
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('C:/Users/user/AppData/Local/Growtopia')
REPORT = ROOT / 'evidence/local-resource-update'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def decode(raw):
    if raw[:6] == b'RTPACK':
        decoder = zlib.decompressobj()
        raw = decoder.decompress(raw[32:], 64 * 1024 * 1024 + 1)
        if len(raw) > 64 * 1024 * 1024 or not decoder.eof:
            raise ValueError('Compressed resource exceeds the verified format limit')
    if len(raw) < 124 or raw[:6] != b'RTTXTR':
        raise ValueError('Not a verified RTTEX texture')
    height, width, kind = struct.unpack_from('<III', raw, 8)
    if kind != 5121 or raw[28] != 1 or not (0 < width <= 4096 and 0 < height <= 4096):
        raise ValueError('Unsupported dimensions or channel layout')
    stride = width * 4
    if len(raw) != 124 + stride * height:
        raise ValueError('Unexpected pixel payload length')
    rows = [raw[124+y*stride:124+(y+1)*stride] for y in range(height)]
    return (width, height), b''.join(reversed(rows))


def main():
    entries = json.loads((ROOT / 'assets/reference/manifest.json').read_text())
    mappings = json.loads((REPORT / 'sprite-provenance.json').read_text())
    images = [dict(source=e['source'], source_sha256=e['sha256'], path='assets/reference/'+e['output_file'], sha256=e['output_sha256']) for e in entries if e['output_file'].endswith('.png')]
    images.extend(mappings['assets'])
    verified, failures, dimensions = [], [], {}
    for entry in images:
        try:
            source = (SOURCE / entry['source']).read_bytes()
            output = (ROOT / entry['path']).read_bytes()
            if sha(source) != entry['source_sha256'] or sha(output) != entry['sha256']:
                raise ValueError('Source or converted file hash differs')
            size, expected = decode(source)
            image = Image.open(ROOT / entry['path']).convert('RGBA')
            if image.size != size or image.tobytes() != expected:
                raise ValueError('Converted PNG does not preserve every RGBA byte')
            dimensions[entry['path']] = size
            verified.append(entry['path'])
        except Exception as error:
            failures.append({'path': entry['path'], 'error': str(error)})
    overrides = json.loads((ROOT / 'data/local-sprite-overrides.json').read_text())
    for item, (path, frame) in overrides['items'].items():
        x, y, width, height = frame
        sheet = dimensions.get(path)
        if not sheet or min(x, y) < 0 or min(width, height) <= 0 or x+width > sheet[0] or y+height > sheet[1]:
            failures.append({'item': item, 'error': 'Frame extends beyond its verified local sheet'})
    result = {'images_checked': len(images), 'exact_rgba_matches': len(verified), 'item_frames_checked': len(overrides['items']), 'failures': failures, 'scope': 'Independent Pillow PNG decoding compared byte-for-byte with verified RGBA8 source rows, including transparent pixels. Frame bounds do not prove every worn animation anchor.'}
    (REPORT / 'pixel-audit.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
    raise SystemExit(1 if failures else 0)


if __name__ == '__main__':
    main()
