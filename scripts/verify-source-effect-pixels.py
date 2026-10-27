import importlib.util
import io
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('local_pixels', root / 'scripts/verify-local-pixels.py')
decoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)
index = json.loads((root / 'data/additional-effects-index.json').read_text())
pack = (root / 'assets/web-wardrobe/additional-effects.bin').read_bytes()
failures = []
verified = 0
for sheet, entry in index.items():
    if entry.get('missing'):
        continue
    try:
        size, rgba = decoder.decode((decoder.SOURCE / entry['source']).read_bytes())
        image = Image.open(io.BytesIO(pack[entry['offset']:entry['offset'] + entry['bytes']])).convert('RGBA')
        if image.size != size or image.tobytes() != rgba:
            raise ValueError('RGBA pixels differ from the read-only local source')
        verified += 1
    except Exception as error:
        failures.append({'sheet': sheet, 'error': str(error)})
report = {'exact_rgba_matches': verified, 'failures': failures}
(root / 'evidence/source-effects-pixels.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
raise SystemExit(1 if failures else 0)
