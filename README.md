# Godot 2D VFX Kit

[![CI](https://github.com/mccarthyah/Godot-2D-VFX-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/mccarthyah/Godot-2D-VFX-plugin/actions/workflows/ci.yml)
[![Godot 4.2+](https://img.shields.io/badge/Godot-4.2%2B-478cbf)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Procedural, asset-free 2D effects for Godot 4. Hit sparks, explosions, lightning
bolts and cooldown rings you can call in one line — pooled, so they stay cheap
when the screen is full of them.

```gdscript
VFX2D.hit_spark(enemy.global_position, Vector2.UP)
VFX2D.explosion(boss.global_position, {"radius": 120.0})
VFX2D.lightning(caster.global_position, target.global_position, {"branches": 4})
VFX2D.cooldown_ring(ability_icon, 2.5)
```

There are no PNGs or audio files in this repo: every effect is drawn with
`_draw()` and `CPUParticles2D`, so it works at any resolution and nothing needs
importing.

---

## Why another VFX addon?

Most 2D effect packs are sprite sheets you have to animate by hand. This one is
built for **game feel plumbing**:

- **One line to spawn**, one dictionary to tune. Every effect exposes its knobs
  as exported properties, and `VFX2D` merges your overrides into them.
- **Pooled by default.** A finished effect is hidden and reused, not freed, so
  bursts of hundreds of sparks do not allocate mid-combat.
- **Tunable in the inspector.** Each effect is a normal scene: open
  `hit_spark.tscn`, change the spark count, hit play.
- **Safe to call from anywhere** — signals, animation callbacks, AI code — with
  an active-effect cap so a pathological loop cannot tank the frame.

## Requirements

- Godot **4.2 or newer** (CI runs against stock 4.2, 4.3 and 4.7.2 Linux builds)
- Any renderer; the demo uses GL Compatibility for the widest support

## Installation

### Option A — drop the folder in

Copy `addons/vfx_2d/` from this repo into your project's `addons/` folder, then
enable **2D VFX Kit** in *Project → Project Settings → Plugins*. The plugin
registers the `VFX2D` autoload for you (unless your project already defines one).

### Option B — release archive

Grab `vfx_2d-<version>.zip` from the releases page and extract it into your
project root. It already contains the `addons/vfx_2d/` path.

### Option C — build the archive yourself

```bash
./tools/package.sh            # -> dist/vfx_2d-0.1.0.zip
```

### Using it without the editor plugin

If you would rather control the autoload yourself, add it manually in
*Project Settings → Autoload*: **name** `VFX2D`, **path**
`res://addons/vfx_2d/vfx_2d.gd`. The plugin detects an existing `VFX2D`
autoload and leaves it alone, so the two approaches never fight.

## Quick start

```gdscript
extends Node2D

func _on_bullet_hit(target: Node2D, impact_direction: Vector2) -> void:
    VFX2D.hit_spark(target.global_position, -impact_direction)

func _on_grenade_explode(at: Vector2) -> void:
    VFX2D.explosion(at, {"radius": 140.0})
    VFX2D.cooldown_ring(self, 0.6)          # optional reaction ring on any node

func _on_chain_lightning(from: Node2D, to: Node2D) -> void:
    VFX2D.lightning(from.global_position, to.global_position, {
        "branches": 3,
        "duration": 0.4,
        "bolt_color": Color(0.7, 0.8, 1.0),
    })
```

React to lifecycle events when you need to drive gameplay from them (camera
shake, hitstop, damage):

```gdscript
func _ready() -> void:
    VFX2D.effect_spawned.connect(func(effect: VFXEffect) -> void:
        if effect is ExplosionEffect:
            $Camera2D.add_trauma(0.4))
```

## Effects

### Hit spark — `effects/hit_spark.tscn`

Bright flash plus a directional burst of sparks. Additive blended.

| Property | Default | Notes |
| --- | --- | --- |
| `direction` | `Vector2.UP` | Travel direction of the sparks |
| `spark_count` | `14` | Particles per burst |
| `spark_speed` | `340` | px/s at emission |
| `spread_degrees` | `32` | Cone width |
| `spark_size` | `3` | Particle scale |
| `spark_gravity` | `420` | Downward pull on sparks |
| `spark_color` | warm white | Tint of the sparks |
| `flash_radius` | `12` | Size of the impact flash |
| `streak_length` | `26` | Length of the directional streak |
| `flash_color` | white | Flash tint |

### Explosion — `effects/explosion.tscn`

Layered fireball, expanding shockwave and flying debris.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` | `76` | Blast size; everything else scales from it |
| `core_color` / `edge_color` | orange | Inner and outer fireball colour |
| `fireball_layers` | `7` | Concentric discs, more = smoother falloff |
| `ring_width` | `10` | Shockwave thickness |
| `ring_expansion` | `1.7` | Shockwave travel as a multiple of `radius` |
| `debris_count` | `26` | Radial debris particles |
| `debris_speed` | `460` | px/s |
| `debris_size` / `debris_color` | `3` / amber | Debris look |

### Lightning — `effects/lightning.tscn`

Procedurally generated bolt with branches and flicker — no two strikes match.

| Property | Default | Notes |
| --- | --- | --- |
| `end_offset` | `Vector2(220, 0)` | Local-space endpoint; set by `VFX2D.lightning()` |
| `segments` | `14` | More segments = more jitter detail |
| `jaggedness` | `0.45` | How far the bolt strays from the straight line |
| `width` | `3.5` | Core stroke width (glow layers scale from it) |
| `branches` | `2` | Fork count |
| `flicker` | `0.6` | `0` = frozen shape, `1` = fastest reshuffling |
| `flicker_interval` | `0.05` | Base interval between reshuffles |
| `bolt_color` / `core_color` | blue / white | Outer glow and hot core |

`get_bolt_points()` and `get_branch_points()` expose the generated geometry if
you want to hit-test or attach effects to the bolt.

### Cooldown ring — `effects/cooldown_ring.tscn`

A modifier node, not a one-shot: it circles whatever it is parented to. Previews
in the editor (change `progress` to see the arc).

| Property | Default | Notes |
| --- | --- | --- |
| `radius` / `width` | `42` / `8` | Ring geometry |
| `duration` | `1.0` | Seconds per cooldown |
| `reverse` | `false` | `true` starts full and drains (classic cooldown) |
| `clockwise` | `true` | Sweep direction |
| `start_angle` | `-1.5708` | Start of the arc (12 o'clock) |
| `tick_count` / `tick_color` | `0` | Optional segment ticks |
| `fill_color` / `track_color` | cyan / dark | Arc and background track |
| `free_on_complete` | `true` | Keep it `false` to reuse one ring |

```gdscript
var ring := VFX2D.cooldown_ring($Icon, 3.0, {"reverse": true, "tick_count": 12})
ring.completed.connect(_on_cooldown_ready)
```

## API reference

### `VFX2D` (autoload)

| Method | Returns | Description |
| --- | --- | --- |
| `hit_spark(at, direction := Vector2.UP, options := {})` | `VFXEffect` | Spawn a hit spark |
| `explosion(at, options := {})` | `VFXEffect` | Spawn an explosion |
| `lightning(from, to, options := {})` | `VFXEffect` | Spawn a bolt between two points |
| `cooldown_ring(target, seconds := 1.0, options := {})` | `CooldownRing` | Parent and start a ring |
| `spawn(scene, at, options := {})` | `VFXEffect` | Spawn any custom `VFXEffect` scene |
| `stop_all()` | `void` | Stop and recycle everything |
| `get_active_count()` | `int` | Effects currently running |

Signals: `effect_spawned(effect)`, `effect_finished(effect)`.

Exported tuning: `pool_size_per_effect` (default `24`), `max_active_effects`
(default `160`), `container_node_name` (default `VFX2D_Layer`).

`options` is applied to the effect with `configure()`, which sets any exported
property by name and warns (instead of crashing) on typos.

### `VFXEffect` (base class)

| Member | Description |
| --- | --- |
| `duration` | Lifetime in seconds |
| `progress` | Normalized `0..1` lifetime, readable from `_draw()` |
| `play()` / `stop()` | Start or end the effect |
| `is_playing()` | Current state |
| `configure(options)` | Apply exported properties from a dictionary |
| `finished` | Signal emitted once per `play()` |
| `_on_play()` / `_on_update(progress, delta)` / `_on_stop()` | Virtual hooks |

Custom effects are just scenes whose root script extends `VFXEffect`; spawn them
with `VFX2D.spawn(preload("res://my_effect.tscn"), position)` and they inherit
pooling for free.

## How pooling works

- Effects are parented to a `VFX2D_Layer` node created under the current scene,
  so they never land inside gameplay containers and are cleaned up on scene
  change.
- When an effect finishes, `VFX2D` hides it, resets its transform and keeps it in
  a per-scene pool (`pool_size_per_effect`). The next spawn of that scene reuses
  the same instance — no `instantiate()` in the hot path.
- If more than `max_active_effects` effects are running, the oldest is stopped to
  keep the frame budget predictable.
- Cooldown rings are not pooled: they are long-lived child nodes, not one-shots.

## Demo project

Open this repository in Godot and press **F5** (the demo scene is the main
scene):

- **Left click** — hit spark at the cursor
- **1 / 2 / 3 / 4** — hit spark, explosion, lightning, cooldown ring
- **Space** — toggle the idle auto-demo
- **C** — clear all running effects

The HUD shows FPS and the live active-effect count.

## Tests and CI

The suite runs the effects for real, in a headless engine:

```bash
godot --headless --path . res://tests/test_runner.tscn
```

It covers: effect lifecycles and replay, `finished` being emitted exactly once,
cooldown fill/drain behaviour, option overrides, pool reuse of the same instance,
burst handling, `stop_all()`, and lightning endpoint geometry. The process exits
non-zero on failure, which is what CI uses.

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) downloads **stock**
Godot 4.2, 4.3 and 4.7.2 Linux builds, imports the project, runs the test scene,
then smoke-runs the demo scene. A run fails on any `SCRIPT ERROR`, parse error or
engine `ERROR:` line.

Headless still issues draw notifications, so `_draw()` really runs for every
effect during the suite — the procedural geometry (arcs, polylines, layered
discs) is exercised, not just the timing and pooling logic. What CI cannot judge
is how it *looks*; that needs the demo on a real display.

## Repository layout

```
addons/vfx_2d/
  plugin.cfg                 # Editor plugin manifest
  plugin.gd                  # Registers the VFX2D autoload
  vfx_2d.gd                  # Autoload: spawn API + pooling
  core/vfx_effect.gd         # VFXEffect base class
  effects/hit_spark.*        # Effect scenes + scripts
  effects/explosion.*
  effects/lightning.*
  effects/cooldown_ring.*
demo/                        # Interactive sandbox scene
tests/test_runner.tscn       # Headless test suite
tools/package.sh             # Builds dist/vfx_2d-<version>.zip
```

## Roadmap

- Emission shapes/curves exposed per effect, plus a small library of presets
  (muzzle flash, heal sparkle, shield ripple)
- Optional camera shake helper and hitstop hook via signals
- `GPUParticles2D` variants for large-scale effects
- Screen-space distortion / bloom-friendly variants for Forward+
- Editor tooling: a spawn-preview dock and an "insert effect" menu item

## License

MIT — see [LICENSE](LICENSE).
