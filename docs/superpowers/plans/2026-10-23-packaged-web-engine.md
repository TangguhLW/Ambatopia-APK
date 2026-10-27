# Packaged Ambatopia web engine implementation plan

**SUPERSEDED 2026-10-23:** User explicitly chose Godot simulation, controls and world menus after seeing web performance. The web client is retained as a reference workbench only. Current implementation is `2026-10-23-native-wardrobe-hybrid.md`.

**Goal:** Reuse the existing Ambatopia web renderer/UI in an Android APK with packaged assets, dedicated ambatopia-godot account/world services and no old-web modification.
**Architecture:** Read-only import of existing frontend modules and verified simulator assets; explicit Supabase schema adapter; Android WebView serves only packaged HTTPS-origin resources. Keep the Godot 0.14 builds available separately.
**Execution:** Inline, no subagents. User authorized the engine choice by asking for the best visual match.

- [ ] Import pinned frontend/renderer assets and offline tool HTML; compare source hashes and prohibit old database addresses.
- [ ] Add account/world/ID adapter and private Realtime transport, with mapping/auth/isolation tests.
- [ ] Verify menu, in-world, wardrobe, animations, input and effects in a Windows browser against the shared renderer.
- [ ] Build signed Android package with local resources, safe navigation and download handling; test on the detected Xiaomi.
- [ ] Run real synthetic-account online integration, remove only fixtures, record measured results and any incomplete semantics.
- [ ] Deliver current APK and Windows preview instructions; preserve original web and original player session.
