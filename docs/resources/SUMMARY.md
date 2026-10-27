# Resource integration summary

Local read-only resources now drive verified menu panels, controls, terrain,
audio and thousands of catalogue sprites. Imports are staged, hash-checked and
committed with the manifest last. Runtime loads packaged relative assets and
does not require the source installation. Provenance and conflicts are explicit.

Supabase signup and basic shared-world transport are enabled in the separate
Godot project. The older Ambatopia web project is outside this change. Exact
behavior for every special item, large-world capacity, automated reconnect and
event retention remain separate work; catalogue availability is not evidence of
complete behavior. See the conflict list and multiplayer deployment document.
