import json, pathlib, zipfile, sys
root = pathlib.Path(__file__).resolve().parents[1]
secrets = []
for line in (root / 'server/private/.env').read_text().splitlines():
    name, sep, value = line.partition('=')
    if sep and name in ('SUPABASE_SECRET_KEY', 'GAME_INTERNAL_TOKEN') and value:
        secrets.append(value.strip().strip('"').encode())
assert len(secrets) == 2
results = []
for rel in (sys.argv[2] if len(sys.argv)>2 else 'build/windows/GrowtopiaReconstruction.exe', sys.argv[3] if len(sys.argv)>3 else 'build/android/GrowtopiaReconstruction.apk'):
    path = root / rel
    raw = path.read_bytes()
    assert not any(secret in raw for secret in secrets), 'Private credential found in build'
    if path.suffix == '.apk':
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                assert 'server/private/' not in info.filename, 'Private directory bundled'
                if info.file_size:
                    assert not any(secret in archive.read(info) for secret in secrets), 'Private credential found in APK entry'
    results.append({'artifact':rel, 'private_credentials_absent':True})
(root / (sys.argv[1] if len(sys.argv)>1 else 'evidence/ambatopia-next/private-build-check.json')).write_text(json.dumps(results,indent=2))
print('Private credentials absent from Windows executable and decompressed APK entries.')
