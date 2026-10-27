# Source review — 2026-10-23

| Source | Pinned revision | Reviewed implementation | Decision and proof |
|---|---|---|---|
| Growtopian-Bot/growtopia-api, JavaScript 1.3.2 | 5d502d5725a555acebc97ac1860c0483e1f7ee04 | README, MIT LICENSE, package.json, all four src exports and Jest tests | Network wiki/status helper; not a texture or items.dat decoder. itemInfo/getImage select the first suggestion. No runtime dependency added. |
| H-pun/growtopia-api, Python >=3.10 | 0b377b0763ed7cef7e1148fa7c7bf4e4a55a8c3e | README, MIT LICENSE, requirements, docs/wiki, itemsdat_parser, rttex_converter, dataminer; implementations and tests | RTTEX decoder independently agrees on 38 core PNGs. Parser fails v27 at record 1; retain bounded project parser. Offline comparison script only. |
| User-provided Python wheel/sdist 0.2.3 | SHA256s in package-inventory.json | Archive inventory, parser/template and converter; compare modules after newline normalization | Wheel template ends at v21; reviewed repository adds v22. Do not treat release and HEAD as identical. No install hooks or bundled 7z executed. |
| H-pun/growtopia-docs 0.0.49 | c34f6b4142113cc458a38c49842e1c180ea7b0bb | src/lib/source.ts, content/docs/items-dat and character-rendering, packet overview | Actual content lives under content/docs, not README's old root paths. Native avatar composition, limb targets, visual types, seed colors implemented and tested. |

The documentation distinguishes traced facts from fitted anchors and unknown
branches. Its macOS binary observations are not automatically facts about every
Windows version. The repository has no root license file in this snapshot;
technical facts are referenced, not redistributed as a documentation bundle.
Both API toolkit MIT licenses remain in their source review checkouts.

Documentation mismatches: rttex_unpack requires bytes and returns BytesIO, whereas
one example passes a file object and writes the result directly. Its crop x/y
are tile indices multiplied by 32. JS getImage returns a URL string, despite an
example describing an array. Python wiki false-partial search still selects the
first suggestion. The old /items_dat documentation path is superseded by
content/docs/items-dat. Dataminer downloads a DMG and invokes bundled 7z via shell;
these paths were inspected but not run. Candidate strings are not imported as IDs.

Trace: source character-rendering/index.mdx + animation-engine.mdx → native body,
single facing transform, limb targets → avatar_view.gd → render_regression suite,
equipment matrix and animation video. Seed-rendering and special-outfits →
little-endian color/two-layer/blink/armless rules → clothing_layers + catalogue
classification → tests and Fashionable Dress/Hot Head captures.
