import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
INSTALL = Path("C:/Users/user/AppData/Local/Growtopia")
SELECTED = {"FireworksMohawk.xml", "MobileSuitWings.xml", "GoldenMobileSuitWings.xml",
            "BarongDanceCostumeShirt.xml", "ConstellationWings.xml", "AngelicCirclet.xml",
            "HairOfFionn.xml", "CaptainLazerhawksEye.xml"}


def properties(node):
    result = {}
    for child in list(node) if node is not None else []:
        name = child.get("name")
        if child.tag == "Set":
            result[name] = child.text.strip()
        elif child.tag == "Random":
            result[name] = {"min": child.get("min"), "max": child.get("max")}
        elif child.tag == "Curve":
            result[name] = {"curve": [[float(n) for n in frame.text.split(",")] for frame in child.findall("KeyFrame")]}
        elif child.tag == "Increment":
            result.setdefault("increments", []).append(dict(child.attrib))
    return result


def recover():
    items = json.loads((ROOT / "research/special-rules/wardrobe-native-fields.json").read_text(encoding="utf-8"))
    definitions, textures, evidence = {}, set(), []
    for name in sorted(SELECTED):
        source = INSTALL / "GameData/ItemRenderers" / name
        raw = source.read_bytes()
        xml = ET.fromstring(raw)
        sprites = {}
        for sprite in xml.findall("./Data/Sprite"):
            size = [int(n) for n in sprite.get("textureSize", "32").split(",")]
            if len(size) == 1:
                size *= 2
            filename = sprite.get("fileName")
            textures.add(filename)
            sprites[sprite.get("name")] = {"file": Path(filename).stem, "size": size, "frame": [int(n) for n in (sprite.get("frame") or sprite.findtext("Frame") or "0,0").split(",")]}
        animations = [{**node.attrib,"sprite": node.get("sprite"), "ms": float(node.get("animTime", "1000")), "frames": [[int(n) for n in frame.text.split(",")] for frame in node.findall("Frame")]} for node in xml.findall("./Data/Animations/SpriteAnimation")]
        curves = [{**node.attrib,"ms": float(node.get("animTime", "1000")),"curves": {c.get("name"): [[float(n.strip().removesuffix("f").removesuffix(".")) for n in k.text.split(",")] for k in c.findall("KeyFrame")] for c in node.findall("Curve")}} for node in xml.findall("./Data/Animations/SpriteCurveAnimation")]
        particles = {node.get("name"): {"emitter": properties(node.find("Emitter")), "particle": properties(node.find("Particle"))} for node in xml.findall("./Data/ParticleSystems/ParticleSystem")}
        render, emit = [], []
        for hook in xml.findall("./RenderRules/*"):
            render.extend({"hook": hook.tag, **node.attrib} for node in hook.findall("SpriteRender"))
            emit.extend({"hook": hook.tag, **node.attrib} for node in hook.findall("ParticleSystemUpdate"))
        for item in items:
            if item["renderer"] == name:
                definitions[str(item["id"])] = {"sprites": sprites, "animations": animations, "curves":curves,"particles": particles, "render": render, "emit": emit, "source": name}
        evidence.append({"source": str(source), "sha256": hashlib.sha256(raw).hexdigest()})
    (ROOT / "data/native-renderers.json").write_text(json.dumps(definitions, separators=(",", ":")), encoding="utf-8")
    (ROOT / "research/special-rules/renderer-textures.json").write_text(json.dumps(sorted(textures)), encoding="utf-8")
    (ROOT / "evidence/special-rules/native-renderer-provenance.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    print(f"Recovered {len(definitions)} native item renderers")


if __name__ == "__main__":
    recover()
