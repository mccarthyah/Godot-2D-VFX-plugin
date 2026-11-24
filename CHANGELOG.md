# Changelog

All notable changes to the 2D VFX Kit are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-11-24

### Added

- **Four more one-shot effects**, each a normal pooled `VFXEffect` scene:
  - `slash_arc` — a tapered melee crescent that sweeps through its arc and sheds
    sparkles (`slash_arc.tscn`).
  - `debris_burst` — solid chunks with their own velocity, spin, gravity and
    drag, drawn without an additive material (`debris_burst.tscn`).
  - `ripple` — flattened, wobbling rings plus droplets (`ripple.tscn`).
  - `implosion` — motes spiral inward, pinch into a flash, then release
    (`implosion.tscn`).
- **`VFX2D.slash_arc()`, `debris_burst()`, `ripple()`, `implosion()`**, so every
  one-shot spawns the same way.
- **Persistent modifiers**, a new category: nodes that live until you stop them,
  returned by the spawner so you can keep driving them.
  - `rune_circle` (`RuneCircle`) — rotating cast circle with a progressive
    `fill` that doubles as a cast bar (`start(seconds)`, `set_fill()`, `stop()`).
  - `portal` (`PortalEffect`) — oval gateway with `open_time` / hold / `close_time`
    and an `lifetime` escape hatch (`get_openness()`).
  - `beam` (`BeamEffect`) — sustained laser: core, glow, travelling pulses and
    flaring ends (`end_at()`, `stop()`).
  - `trail` (`TrailEffect`) — ribbon history emitter for projectiles and dashes,
    recording the target's global positions so it never inherits its rotation
    (`attach_to()`, `stop()`).
- **`VFX2D.beam()`, `portal()`, `rune_circle()`, `trail()`** plus
  `VFX2D.get_persistent_count()`. `stop_all()` now clears modifiers too, and a
  trail frees itself when its target leaves the tree, so despawns leave no
  ribbon behind.
- **`chaos` on every new effect**, one-shots and modifiers alike.

### Changed

- The gallery is now a 4×4 grid with all sixteen effects; keys **1**-**0** and
  **Q W E R T Y** (or a click) fire a single cell, and the trail cell contains a
  small orbiting flyer for the ribbon to follow. The header also reports the
  persistent-modifier count.
- The demo adds keys **9** / **0** (slash arc, debris burst), **R** / **I**
  (ripple, implosion) and **B** / **P** / **U** / **T** to toggle a beam, portal,
  rune circle and trail, with a HUD button for every one of them.
- Tests grew to **216 checks** with the extension and **204** without: lifecycle
  and replay for the new one-shots, per-effect geometry, and start/stop/`finished`
  coverage for all four modifiers.
- Version bumped to `0.4.0`.

## [0.3.0] — 2026-11-24

### Added

- **Four new effects**, each a normal `VFXEffect` scene with its own knobs:
  - `smoke_puff` — billowing, additive-free smoke or dust (`smoke_puff.tscn`).
  - `shockwave` — rings and radial cracks, no fire (`shockwave.tscn`).
  - `muzzle_flash` — directional torn cone, star and spark spray
    (`muzzle_flash.tscn`).
  - `heal_sparkle` — ascending, twinkling motes for pickups and buffs
    (`heal_sparkle.tscn`).
- **`VFX2D.smoke_puff()`, `shockwave()`, `muzzle_flash()`, `heal_sparkle()`**, so
  all eight effects spawn the same way.
- **`chaos` on every effect** (`0.0`–`1.0`, reseeded per `play()`): torn flash
  stars and splinters on the hit spark, lopsided lobes and ghost fronts on the
  explosion, per-flicker branch topology and sub-branches on lightning, arc
  wobble on the ring, and equivalent shape-level irregularity on the new four.
- `core/vfx_shapes.gd` — shared procedural outlines (wobbling rings, jagged
  cones, uneven stars) used by the effects. Loaded with a relative `preload`, so
  effects still parse before the editor's class cache exists.

### Changed

- The gallery is now a 4×2 grid with all eight effects, keys **1**-**8** to fire
  one cell. The demo HUD hint and README list the new effects.
- Tests cover the new effects' lifecycles, their `VFX2D` methods and the `chaos`
  knob on all eight (120 checks with the extension, 108 without).
- `lightning`'s branch count is only exact when `chaos` is `0`; with chaos on it
  varies per flicker by design, and the suite now pins that explicitly.

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
- **`demo/gallery.tscn`** — a labelled 2×2 gallery with one cell per effect, each
  cycling on its own timer (staggered phases), so all four can be compared side by
  side. Space pauses, R refires all, C clears, 1-4 or a click fires one cell, and
  the header reports FPS, active count and whether the C++ streak layer is loaded.
  Reachable from the demo with **G** (Esc goes back).
- **`cpp/build_profile.json`** — trimmed bindings cut the godot-cpp build from
  ~40 minutes to ~1 minute on 2 cores.
- godot-cpp is pinned to a 4.7-era commit (`fba3efa`); newer `master` targets the
  4.8 interface, which 4.7.x rejects.

### Changed

- `tools/package.sh` excludes extension binaries by default (use
  `--with-extension` for a platform-specific archive) and takes `--help`.
- `tools/package.sh` now also writes `vfx_2d-<version>-project.zip`: the complete
  runnable project (demo + gallery + tests), so the demo scenes are not hidden
  behind the repo. The addon-only archive is unchanged (`--addon-only` skips it).
- The test suite gains a C++ section (13 checks) that skips cleanly when the
  library is not built, and prints `cpp-streak-field: available|absent` so CI can
  assert which path was exercised.
- The demo HUD reports whether the C++ streak layer is active.

### Fixed

- Spawning an effect after a scene change no longer raises *"Trying to assign
  invalid previously freed instance"*. Effects are parented to a `VFX2D_Layer`
  that belongs to the current scene, so `change_scene_*` freed the whole pool
  while the autoload still held the instances. The pool now skips freed or
  queued entries, prunes itself when a new layer is built, and `get_active_count()`
  stops reporting effects that died with the scene. Seen when the demo jumped to
  the gallery (`G`) and the gallery spawned lightning.
- The suite grew a scene-change regression test (8 checks) that fails if dead
  pool entries are kept, not just when the engine complains.

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

[0.4.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.4.0
[0.3.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.3.0
[0.2.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.2.0
[0.1.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.1.0
