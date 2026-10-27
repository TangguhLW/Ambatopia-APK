# Ambatopia web becomes the visual reference

User direction, 2026-10-23: prefer the existing Ambatopia web in-world appearance, wardrobe positioning, item UI and effects for the APK. Preserve the old website. The earlier official-client visual reconstruction is no longer the overriding visual target.

## Findings from the existing source

- The web calls the original simulator renderer through `AmbatopiaNative.renderAvatar`, `wear`, `pose`, `punch` and `impact`. Outfit changes update all worn slots before one rebuild. Its coordinates, animation time and color controls belong to that renderer; recreating only its item thumbnails in Godot will not reproduce the same result.
- Web chrome is defined by `tool-layout`, `tool-sidebar`, `tool-chrome`, `ui.css` and `sky-theme.css`; it includes the approved clothing sidebar and compact icon controls.
- A renderer-oriented Set bundle and its cached resources are present locally: 118 Set files, about 19 MiB. This is a scoped inventory, not proof that every lazily loaded effect resource is cached.
- The deployed Set index is deliberately a login redirect. The actual authenticated tool HTML is generated from the verified original cache; copying the redirect HTML alone into an APK would fail.
- The existing web server and the Godot database have different RPCs, user-role values, world identities and block IDs. Reusing the frontend must include an explicit adapter to the dedicated Godot database; substituting its public URL alone is not valid. Never connect the new build to the old website database by accident.
- The web online editor accepts a restricted set of network block IDs; its wardrobe renderer being comprehensive does not establish that every official-game machine or consumable behavior is implemented online.

## Work independent of the engine decision

13 source files were hashed in `evidence/web-reference/source-baseline.json`; `scripts/audit-web-reference.mjs` reproduces this inventory without writing to the web project. No old-web source, deployment, accounts or database policy were modified. Existing Windows/APK 0.14 remains available while the architecture choice is pending.

## Implementation acceptance criteria

1. Match the same outfit, colors, facing and pose against the web; compare head, face, neck, body, pants, shoes and back layers.
2. Compare animated/effect items during idle, walk, jump, punch and equip/unequip, not just static catalogue previews.
3. Preserve the chosen web in-world layout and input behavior, including mobile inventory, clothing controls, chat and zoom.
4. If using the web engine in Android, package the required assets; do not ship only a URL launcher. Check renderer assets with networking disabled and keep online account traffic separate.
5. Use only the dedicated ambatopia-godot project for new account/world integration. Keep role checks, world-lock checks and authenticated private channels enforced server-side.
6. Test the selected build in Windows preview and on the physical Xiaomi. Record which effects and online operations were actually exercised; do not label all official item semantics as complete.
