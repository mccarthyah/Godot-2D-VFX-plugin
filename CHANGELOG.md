# Changelog

All notable changes to the 2D VFX Kit are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
