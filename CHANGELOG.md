# Changelog

All notable changes to the 2D VFX Kit are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-11-24

### Added

- **Optional C++ streak field** (`VFXStreakField2D`, GDExtension): a
  data-oriented spark system that integrates gravity, drag and turbulence in
  C++ and submits every streak as a single `canvas_item_add_multiline` call.
  Thousands of velocity-aligned streaks per burst, flat memory, ring-recycled
  pool capped by `max_particles`.
- **`VFXStreaks`** GDScript bridge with `is_available()` / `create()` /
  `burst()` / `clear()`. Degrades to a no-op when the library is absent, so the
  addon keeps working as pure GDScript.
- **Effect integration**: `HitSparkEffect` and `ExplosionEffect` gain
  `use_streaks`, `streak_count` and `streak_turbulence`. They attach the streak
  layer automatically when the extension is loaded.
- **`cpp/`** — extension sources, `SConstruct`, `cpp/README.md` with the full
  node API, tuning notes and troubleshooting.
- **`tools/build_extension.sh`** — fetches godot-cpp, builds debug/release
  libraries into `addons/vfx_2d/bin/`, generates the `.gdextension` descriptor,
  and can bind a specific engine build's API (`--godot`).
- **`GDExtension` workflow** — builds the extension against stock Godot 4.7.2,
  then runs the suite and fails if the extension silently failed to load.
- **`cpp/build_profile.json`** — trimmed bindings cut the godot-cpp build from
  ~40 minutes to ~1 minute on 2 cores.
- godot-cpp is pinned to a 4.7-era commit (`fba3efa`); newer `master` targets the
  4.8 interface, which 4.7.x rejects.

### Changed

- `tools/package.sh` excludes extension binaries by default (use
  `--with-extension` for a platform-specific archive) and takes `--help`.
- The test suite gains a C++ section (13 checks) that skips cleanly when the
  library is not built, and prints `cpp-streak-field: available|absent` so CI can
  assert which path was exercised.
- The demo HUD reports whether the C++ streak layer is active.

## [0.1.0] — 2026-11-24

First working baseline: a plugin you can drop into a project and get game-feel
out of in a few lines.

### Added

- **`VFX2D` autoload** — spawn API (`hit_spark`, `explosion`, `lightning`,
  `cooldown_ring`, `spawn`), per-scene instance pooling, an active-effect cap,
  `stop_all()`, and `effect_spawned` / `effect_finished` signals.
- **`VFXEffect` base class** — duration-driven one-shot effects with
  `play()` / `stop()`, `progress`, dictionary-based `configure()`, and
  `_on_play` / `_on_update` / `_on_stop` virtuals.
- **Hit spark** — directional flash + spark burst, additive blending.
- **Explosion** — layered fireball, expanding shockwave ring, radial debris.
- **Lightning** — procedural midpoint-displacement bolt with branches, glow
  layers, and flicker.
- **Cooldown ring** — fill or drain arc, clockwise or counter-clockwise, optional
  tick marks; previews in the editor.
- **Editor plugin** — registers the `VFX2D` autoload when enabled, without
  overriding a hand-registered one.
- **Demo project** — interactive sandbox scene with buttons, hotkeys, and an
  idle auto-demo.
- **Headless test suite** — `tests/test_runner.tscn` covering effect lifecycles,
  pooling, option overrides, cooldown behaviour, and lightning geometry.
- **CI** — GitHub Actions matrix against stock Godot 4.3/4.4 Linux builds:
  import, headless tests, demo smoke run on Godot 4.2, 4.3 and 4.7.2.
- **Packaging** — `tools/package.sh` builds `dist/vfx_2d-<version>.zip`.

[0.1.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.1.0
