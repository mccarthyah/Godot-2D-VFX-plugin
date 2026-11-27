# Changelog

All notable changes to Sparkform are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.1] - 2026-11-24

Documentation release. No behaviour change: every edit here is a doc comment, a
Markdown page or the generator that keeps them in sync.

### Added

- [`docs/API.md`](docs/API.md): the `Sparkform` autoload and the base classes,
  with every method's full signature and doc comment.
- [`docs/EFFECTS.md`](docs/EFFECTS.md): all 24 effects, each with what it is for,
  the spawner that creates it, and every exported property with type, default and
  description.
- [`docs/COOKBOOK.md`](docs/COOKBOOK.md): recipes for hit feedback, aiming,
  boss-scale variants, persistent-modifier lifetimes, frame budgets, custom
  `VFXEffect` scenes, and a checklist for "the effect did not appear".
- [`docs/README.md`](docs/README.md): the documentation index, and the rule that
  pages describing code are generated from it.
- `tools/gen_docs.py`: regenerates the two reference pages from the `##` comments
  in the addon; `--check` fails when they are stale.
- A `docs` CI job that runs `gen_docs.py --check` and `gdlint`, so a renamed
  property cannot ship with a stale reference or a lint error.

### Changed

- Every exported property in `addons/sparkform/effects/` now has a doc comment;
  178 of them were undocumented. Those comments are what the Godot inspector
  shows as tooltips, so the editor and the reference now say the same thing.
- The handful of public helper methods without a doc comment
  (`ShieldBubble.hex_cell_margin` and friends) are documented too.
- `README.md` links the new pages from a Documentation table and from the API and
  effects sections; `addons/sparkform/README.md` points at the full reference
  from inside the addon.

## [0.6.0] - 2026-11-24

Renamed. The kit is now **Sparkform**, and the autoload is `Sparkform` instead of
`VFX2D`.

### Changed

- Addon folder is `addons/sparkform/` (was `addons/vfx_2d/`), plugin name is
  **Sparkform**, and the autoload script is `addons/sparkform/sparkform.gd`.
- The autoload is registered as `Sparkform`. Calls read
  `Sparkform.hit_spark(...)`, `Sparkform.explosion(...)`, and so on; find and
  replace `VFX2D.` with `Sparkform.` when updating.
- Archives are named `sparkform-<version>*.zip`.
- Effect class names (`VFXEffect`, `VFXStreaks`, `HitSparkEffect`, ...) are
  unchanged, as is the optional `VFXStreakField2D` extension.

### Upgrading from 0.5.1

1. Delete `addons/vfx_2d/` and the `VFX2D` entry under *Project Settings →
   Autoload*.
2. Drop in `addons/sparkform/` and enable **Sparkform** in *Project Settings →
   Plugins*; the plugin registers the new autoload itself.
3. Replace `VFX2D.` with `Sparkform.` in your scripts.

### Also in this release

- Comments, printed strings and docs no longer use typographic dashes or
  emphasis italics, a few over-long comments were cut back, and the stray
  `cpp/src/*.os` build output is no longer tracked.

## [0.5.1] - 2026-11-24

### Added

- **`docs/INSTALL.md`**: the full install and usage guide: three ways to install,
  enabling the plugin, a copy-paste verification snippet, the whole effect
  catalogue with calls, options/`chaos`, the optional C++ layer, updating,
  removing, and a troubleshooting table.
- **`docs/ASSETLIB.md`**: how to publish the kit on Godot AssetLib: archive
  layout, the submission form field by field, the preview image, and what must
  not ship.
- **`addons/sparkform/README.md` and `addons/sparkform/LICENSE`**: the addon now
  carries its own instructions and licence, so an installed copy is
  self-explanatory without the repository.
- **`./tools/package.sh --assetlib`**: builds
  `dist/sparkform-<version>-assetlib.zip` (addon + its docs, no demo, no tests, no
  binaries), the shape AssetLib expects.
- **A CI job that installs the packaged plugin into an empty project** on Godot
  4.2 and 4.7.2, enables it, and runs a scene against it, so packaging is
  tested and not assumed.

### Fixed

- **The editor plugin no longer removes the `Sparkform` autoload on exit.** It added
  the autoload and then stripped it again when the editor closed, so a project
  that relied on the plugin had no `Sparkform` at runtime. Enabling the plugin now
  registers the autoload, saves `project.godot` immediately, and leaves it
  alone afterwards. Disable the plugin to drop the editor hooks; delete the
  autoload entry yourself if you want it gone.
- The stored autoload is rewritten to a `res://` path, because Godot 4.4+ records
  new autoloads as `uid://` references that 4.2 and 4.3 cannot resolve.
- **No more "Could not find type `VFXEffect`" on a freshly installed copy.** The
  effects now extend the base class by path and `sparkform.gd` preloads it, instead
  of relying on global `class_name` lookups that are not resolvable until Godot
  has finished scanning the project. Godot 4.2 parses the addon before that
  cache exists and printed a wall of parse errors on the first open of a brand
  new project. Caught by the new packaged-plugin CI job.

## [0.5.0] - 2026-11-24

### Added

- **Five more one-shot effects**, all pooled `VFXEffect` scenes:
  - `frost_burst`: angular ice shards, cold flash and a crystalline shimmer
    (`frost_burst.tscn`).
  - `acid_splash`: bubbles that rise and pop on a delay, each pop throwing
    droplets, over a sticky splat (`acid_splash.tscn`).
  - `impact_crack`: ground-aligned jagged cracks, dust and a flat flash;
    `surface` decides which way they fan (`impact_crack.tscn`).
  - `chain_lightning`: a bolt that hops through an array of targets, one jagged
    segment per hop, dimmer each time (`chain_lightning.tscn`).
  - `blink`: two-point teleport: collapse at the source, streak, burst at the
    destination (`blink.tscn`).
- **Three reactive modifiers**, extending the persistent category:
  - `shield_bubble` (`ShieldBubble`): hex lattice over a dome; `hit(world_point)`
    flashes and ripples where it is struck, `stop()` closes it.
  - `tether` (`Tether`): sagging energy chain between two nodes with pulses
    running along it; `set_targets()` re-aims, and it frees itself when either end
    disappears.
  - `vortex` (`Vortex`): pull field: motes spawn on the rim, spiral in and
    recycle; also sprays a ring of C++ streaks on start when the extension is
    loaded.
- **`Sparkform.frost_burst()`, `acid_splash()`, `impact_crack()`, `chain()`,
  `blink()`, `shield()`, `tether()`, `vortex()`**, plus `chaos` on all eight.

### Changed

- The gallery has **six pages**: Impacts, Combat, Magic, **Elemental**, **Reactive**
  and Motion: twenty-four effects, still only four cells running at a time. The
  shield cell flashes itself on a timer so the reactive part is visible.
- The demo adds keys **F** (frost burst), **L** (chain lightning), **X** (acid
  splash), **K** (impact crack), **M** (blink) and **H / V / N** to toggle the
  shield, tether and vortex, each with a HUD button.
- Tests cover the new effects' lifecycles and geometry plus the reactive hooks:
  shield `hit()`/open/close, tether sampling, target loss and `stop()`, vortex
  mote count and fade. **330 checks** with the extension, **318** without.
- Version bumped to `0.5.0`.

## [0.4.1] - 2026-11-24

### Changed

- **The gallery is paged.** Sixteen effects firing at once made the gallery drop
  frames, and the smaller shapes were hard to read next to explosions. It now
  has four themed pages of four cells each (**Impacts**, **Combat**, **Magic**,
  **Motion**), so only a few effects run at a time and the FPS counter stays
  meaningful.
  - Page tabs in the header, clickable; **←/→**, **A/D**, **Tab** or
    **PageUp/PageDown** also page through. **1-4** fires a single cell, **R**
    refires the page.
  - Switching pages clears running effects, so a beam or portal never bleeds
    into the next page.
  - `set_paused()` / `is_paused()` are public now, and the suite checks that
    pages stay small: one effect per cell fired, and no page exceeds a handful.
- Tests: **231 checks** with the extension, **219** without.

## [0.4.0] - 2026-11-24

### Added

- **Four more one-shot effects**, each a normal pooled `VFXEffect` scene:
  - `slash_arc`: a tapered melee crescent that sweeps through its arc and sheds
    sparkles (`slash_arc.tscn`).
  - `debris_burst`: solid chunks with their own velocity, spin, gravity and
    drag, drawn without an additive material (`debris_burst.tscn`).
  - `ripple`: flattened, wobbling rings plus droplets (`ripple.tscn`).
  - `implosion`: motes spiral inward, pinch into a flash, then release
    (`implosion.tscn`).
- **`Sparkform.slash_arc()`, `debris_burst()`, `ripple()`, `implosion()`**, so every
  one-shot spawns the same way.
- **Persistent modifiers**, a new category: nodes that live until you stop them,
  returned by the spawner so you can keep driving them.
  - `rune_circle` (`RuneCircle`): rotating cast circle with a progressive
    `fill` that doubles as a cast bar (`start(seconds)`, `set_fill()`, `stop()`).
  - `portal` (`PortalEffect`): oval gateway with `open_time` / hold / `close_time`
    and an `lifetime` escape hatch (`get_openness()`).
  - `beam` (`BeamEffect`): sustained laser: core, glow, travelling pulses and
    flaring ends (`end_at()`, `stop()`).
  - `trail` (`TrailEffect`): ribbon history emitter for projectiles and dashes,
    recording the target's global positions so it never inherits its rotation
    (`attach_to()`, `stop()`).
- **`Sparkform.beam()`, `portal()`, `rune_circle()`, `trail()`** plus
  `Sparkform.get_persistent_count()`. `stop_all()` now clears modifiers too, and a
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

## [0.3.0] - 2026-11-24

### Added

- **Four new effects**, each a normal `VFXEffect` scene with its own knobs:
  - `smoke_puff`: billowing, additive-free smoke or dust (`smoke_puff.tscn`).
  - `shockwave`: rings and radial cracks, no fire (`shockwave.tscn`).
  - `muzzle_flash`: directional torn cone, star and spark spray
    (`muzzle_flash.tscn`).
  - `heal_sparkle`: ascending, twinkling motes for pickups and buffs
    (`heal_sparkle.tscn`).
- **`Sparkform.smoke_puff()`, `shockwave()`, `muzzle_flash()`, `heal_sparkle()`**, so
  all eight effects spawn the same way.
- **`chaos` on every effect** (`0.0`–`1.0`, reseeded per `play()`): torn flash
  stars and splinters on the hit spark, lopsided lobes and ghost fronts on the
  explosion, per-flicker branch topology and sub-branches on lightning, arc
  wobble on the ring, and equivalent shape-level irregularity on the new four.
- `core/vfx_shapes.gd`: shared procedural outlines (wobbling rings, jagged
  cones, uneven stars) used by the effects. Loaded with a relative `preload`, so
  effects still parse before the editor's class cache exists.

### Changed

- The gallery is now a 4×2 grid with all eight effects, keys **1**-**8** to fire
  one cell. The demo HUD hint and README list the new effects.
- Tests cover the new effects' lifecycles, their `Sparkform` methods and the `chaos`
  knob on all eight (120 checks with the extension, 108 without).
- `lightning`'s branch count is only exact when `chaos` is `0`; with chaos on it
  varies per flicker by design, and the suite now pins that explicitly.

## [0.2.0] - 2026-11-24

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
- **`cpp/`**: extension sources, `SConstruct`, `cpp/README.md` with the full
  node API, tuning notes and troubleshooting.
- **`tools/build_extension.sh`**: fetches godot-cpp, builds debug/release
  libraries into `addons/sparkform/bin/`, generates the `.gdextension` descriptor,
  and can bind a specific engine build's API (`--godot`).
- **`GDExtension` workflow**: builds the extension against stock Godot 4.7.2,
  then runs the suite and fails if the extension silently failed to load.
- **`demo/gallery.tscn`**: a labelled 2×2 gallery with one cell per effect, each
  cycling on its own timer (staggered phases), so all four can be compared side by
  side. Space pauses, R refires all, C clears, 1-4 or a click fires one cell, and
  the header reports FPS, active count and whether the C++ streak layer is loaded.
  Reachable from the demo with **G** (Esc goes back).
- **`cpp/build_profile.json`**: trimmed bindings cut the godot-cpp build from
  ~40 minutes to ~1 minute on 2 cores.
- godot-cpp is pinned to a 4.7-era commit (`fba3efa`); newer `master` targets the
  4.8 interface, which 4.7.x rejects.

### Changed

- `tools/package.sh` excludes extension binaries by default (use
  `--with-extension` for a platform-specific archive) and takes `--help`.
- `tools/package.sh` now also writes `sparkform-<version>-project.zip`: the complete
  runnable project (demo + gallery + tests), so the demo scenes are not hidden
  behind the repo. The addon-only archive is unchanged (`--addon-only` skips it).
- The test suite gains a C++ section (13 checks) that skips cleanly when the
  library is not built, and prints `cpp-streak-field: available|absent` so CI can
  assert which path was exercised.
- The demo HUD reports whether the C++ streak layer is active.

### Fixed

- Spawning an effect after a scene change no longer raises *"Trying to assign
  invalid previously freed instance"*. Effects are parented to a `Sparkform_Layer`
  that belongs to the current scene, so `change_scene_*` freed the whole pool
  while the autoload still held the instances. The pool now skips freed or
  queued entries, prunes itself when a new layer is built, and `get_active_count()`
  stops reporting effects that died with the scene. Seen when the demo jumped to
  the gallery (`G`) and the gallery spawned lightning.
- The suite grew a scene-change regression test (8 checks) that fails if dead
  pool entries are kept, not just when the engine complains.

## [0.1.0] - 2026-11-24

First working baseline: a plugin you can drop into a project and get game-feel
out of in a few lines.

### Added

- **`Sparkform` autoload**: spawn API (`hit_spark`, `explosion`, `lightning`,
  `cooldown_ring`, `spawn`), per-scene instance pooling, an active-effect cap,
  `stop_all()`, and `effect_spawned` / `effect_finished` signals.
- **`VFXEffect` base class**: duration-driven one-shot effects with
  `play()` / `stop()`, `progress`, dictionary-based `configure()`, and
  `_on_play` / `_on_update` / `_on_stop` virtuals.
- **Hit spark**: directional flash + spark burst, additive blending.
- **Explosion**: layered fireball, expanding shockwave ring, radial debris.
- **Lightning**: procedural midpoint-displacement bolt with branches, glow
  layers, and flicker.
- **Cooldown ring**: fill or drain arc, clockwise or counter-clockwise, optional
  tick marks; previews in the editor.
- **Editor plugin**: registers the `Sparkform` autoload when enabled, without
  overriding a hand-registered one.
- **Demo project**: interactive sandbox scene with buttons, hotkeys, and an
  idle auto-demo.
- **Headless test suite**: `tests/test_runner.tscn` covering effect lifecycles,
  pooling, option overrides, cooldown behaviour, and lightning geometry.
- **CI**: GitHub Actions matrix against stock Godot 4.3/4.4 Linux builds:
  import, headless tests, demo smoke run on Godot 4.2, 4.3 and 4.7.2.
- **Packaging**: `tools/package.sh` builds `dist/sparkform-<version>.zip`.

[0.6.1]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.6.1
[0.6.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.6.0
[0.5.1]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.5.1
[0.5.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.5.0
[0.4.1]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.4.1
[0.4.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.4.0
[0.3.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.3.0
[0.2.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.2.0
[0.1.0]: https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases/tag/v0.1.0
