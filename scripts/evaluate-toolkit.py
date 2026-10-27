import json
import sys
from pathlib import Path

# Only the reviewed parser/template modules are imported; no package installation or CLI.
sys.path.insert(0, str(Path('research/catalog/sources/toolkit').resolve()))
from growtopia.itemsdat_parser import parse_itemsdat

result = {'commit': '0b377b0763ed7cef7e1148fa7c7bf4e4a55a8c3e', 'module': 'growtopia/itemsdat_parser', 'network': False}
try:
    with open('C:/Users/user/AppData/Local/Growtopia/cache/items.dat', 'rb') as source:
        data = parse_itemsdat(source)
        result.update({'parsed': len(data['items']), 'version': data['version'], 'consumed': source.tell()})
except Exception as error:
    result.update({'compatible': False, 'error_type': type(error).__name__, 'error': str(error)})
Path('research/catalog/toolkit-parser-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
