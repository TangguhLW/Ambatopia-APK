import hashlib
import io
import json
from pathlib import Path
import zipfile
from PIL import Image, ImageChops, ImageStat

root = Path(__file__).resolve().parents[1]
source = root / "assets/ambatopia/app-icon.png"
original = Path("C:/Users/user/Pictures/Growtopia/Ambatopia-logo")
assert source.read_bytes() == original.read_bytes(), "Source icon bytes changed"
results = []
with zipfile.ZipFile(root / "build/android/GrowtopiaReconstruction.apk") as archive:
    for name in ["res/mipmap-xxxhdpi-v4/icon.webp", "res/mipmap-xxxhdpi-v4/icon_foreground.webp", "res/mipmap-xxxhdpi-v4/icon_background.webp"]:
        rendered = Image.open(io.BytesIO(archive.read(name))).convert("RGB")
        expected = Image.open(source).convert("RGB").resize(rendered.size, Image.Resampling.LANCZOS)
        error = sum(ImageStat.Stat(ImageChops.difference(rendered, expected)).mean) / 3
        assert error < 15, f"Launcher image differs from supplied icon: {name}"
        results.append({"resource": name, "size": list(rendered.size), "mean_channel_error_against_source_resize": round(error, 4)})
        if "foreground" in name:
            rendered.save(root / "evidence/automation-rules/apk-icon.png")
report = {"source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "source_bytes_preserved": True, "verified_launcher_resources": results}
(root / "evidence/automation-rules/icon-verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("Verified launcher icon matches supplied image:", len(results), "resources")
