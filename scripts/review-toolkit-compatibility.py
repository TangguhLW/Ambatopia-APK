"""Offline comparison only; no package installation, downloads, or binary execution."""
import hashlib, importlib.util, io, json, pathlib, subprocess, sys, types, zipfile, tarfile
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path('C:/Users/user/AppData/Local/Growtopia')
vendor = root / 'research/toolkits/h-pun-api/growtopia'
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod
rttex = load('review_rttex', vendor / 'rttex_converter/__init__.py')
package = types.ModuleType('review_parser')
package.__path__ = [str(vendor / 'itemsdat_parser')]
sys.modules['review_parser'] = package
load('review_parser.template', vendor / 'itemsdat_parser/template.py')
parser = load('review_parser', vendor / 'itemsdat_parser/__init__.py')
manifest = json.loads((root / 'assets/reference/manifest.json').read_text())
comparisons = []
for row in manifest:
    if row['output_file'].endswith('.png'):
        raw = (source / row['source']).read_bytes()
        imported = Image.open(root / 'assets/reference' / row['output_file']).convert('RGBA')
        independent = Image.open(rttex.rttex_unpack(raw)).convert('RGBA')
        assert independent.size == imported.size and independent.tobytes() == imported.tobytes(), row['id']
        comparisons.append(row['id'])
raw = (source / 'cache/items.dat').read_bytes()
header = parser.itemsdat_info(io.BytesIO(raw), calculate=False)
try:
    parsed = parser.parse_itemsdat(io.BytesIO(raw))
    parser_result = {'supported': True, 'items': len(parsed['items'])}
except Exception as error:
    parser_result = {'supported': False, 'error': str(error), 'error_type': type(error).__name__}
archives = []
for name in ['growtopia_api-0.2.3-py3-none-any.whl', 'growtopia_api-0.2.3.tar.gz']:
    path = pathlib.Path('C:/Users/user/Downloads') / name
    archive = zipfile.ZipFile(path) if name.endswith('.whl') else tarfile.open(path)
    matched = []
    names = archive.namelist() if name.endswith('.whl') else archive.getnames()
    for member in names:
        if '/growtopia/' in '/' + member and member.endswith('.py'):
            relative = member[member.index('growtopia/') + len('growtopia/'):]
            local = vendor / relative
            data = archive.read(member) if name.endswith('.whl') else archive.extractfile(member).read()
            matched.append({'module': relative, 'matches_reviewed_source': local.exists() and local.read_bytes() == data,
                            'matches_after_line_end_normalization': local.exists() and local.read_bytes().replace(b'\r\n', b'\n') == data.replace(b'\r\n', b'\n')})
    archives.append({'file': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'modules': matched})
    archive.close()
repos = {}
for name in ['h-pun-api', 'js-api', 'docs']:
    path = root / 'research/toolkits' / name
    repos[name] = {'commit': subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip(),
                   'files': [str(p.relative_to(path)).replace('\\', '/') for p in path.rglob('*') if p.is_file() and '.git' not in p.parts]}
report = {'header': header, 'native_sha256': hashlib.sha256(raw).hexdigest(), 'h_pun_parser': parser_result,
          'rttex_exact_matches': comparisons, 'archives': archives, 'repositories': repos,
          'network_requests': 0, 'vendor_binaries_executed': False}
wheel_path = pathlib.Path('C:/Users/user/Downloads/growtopia_api-0.2.3-py3-none-any.whl')
wheel_workspace = root / 'research/toolkits/wheel-reviewed'
wheel_workspace.mkdir(exist_ok=True)
with zipfile.ZipFile(wheel_path) as archive:
    for relative in ['itemsdat_parser/template.py', 'itemsdat_parser/__init__.py', 'rttex_converter/__init__.py']:
        output = wheel_workspace / relative
        output.parent.mkdir(exist_ok=True)
        output.write_bytes(archive.read('growtopia/' + relative))
wheel_package = types.ModuleType('review_wheel_parser')
wheel_package.__path__ = [str(wheel_workspace / 'itemsdat_parser')]
sys.modules['review_wheel_parser'] = wheel_package
load('review_wheel_parser.template', wheel_workspace / 'itemsdat_parser/template.py')
wheel_parser = load('review_wheel_parser', wheel_workspace / 'itemsdat_parser/__init__.py')
try:
    wheel_parser.parse_itemsdat(io.BytesIO(raw))
    report['wheel_parser'] = {'supported': True}
except Exception as error:
    report['wheel_parser'] = {'supported': False, 'error': str(error), 'error_type': type(error).__name__}
wheel_rttex = load('review_wheel_rttex', wheel_workspace / 'rttex_converter/__init__.py')
wheel_matches = []
for row in manifest:
    if row['output_file'].endswith('.png'):
        converted = Image.open(wheel_rttex.rttex_unpack((source / row['source']).read_bytes())).convert('RGBA')
        expected = Image.open(root / 'assets/reference' / row['output_file']).convert('RGBA')
        assert converted.size == expected.size and converted.tobytes() == expected.tobytes()
        wheel_matches.append(row['id'])
report['wheel_rttex_exact_matches'] = wheel_matches
(root / 'evidence/render-regression/toolkit-compatibility.json').write_text(json.dumps(report, indent=2))
print(json.dumps({'header': header, 'h_pun_parser': parser_result, 'rttex_exact_matches': len(comparisons)}))
