# Godot 2D VFX Kit

[![CI](https://github.com/mccarthyah/Godot-2D-VFX-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/mccarthyah/Godot-2D-VFX-plugin/actions/workflows/ci.yml)
[![Godot 4.2+](https://img.shields.io/badge/Godot-4.2%2B-478cbf)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Procedural, asset-free 2D effects for Godot 4. Sixteen effects: hit sparks,
explosions, lightning bolts, cooldown rings, smoke, shockwaves, muzzle flashes,
heal sparkles, slash arcs, debris bursts, ripples and implosions — plus four
persistent modifiers (rune circles, portals, beams and trails) that live until
you stop them. One-shots are pooled, so they stay cheap when the screen is full
of them. Every effect carries a `chaos` knob, so nothing looks stamped from a
stencil.

```gdscript
VFX2D.hit_spark(enemy.global_position, Vector2.UP)
VFX2D.explosion(boss.global_position, {"radius": 120.0})
VFX2D.lightning(caster.global_position, target.global_position, {"branches": 4})
VFX2D.cooldown_ring(ability_icon, 2.5)

VFX2D.smoke_puff(feet.global_position, {"radius": 70.0})        # dust, landings
VFX2D.shockwave(impact.global_position, {"radius": 150.0})      # parries, slams
VFX2D.muzzle_flash(barrel.global_position, aim_direction)       # gunfire
VFX2D.heal_sparkle(player.global_position)                      # pickups, buffs

VFX2D.slash_arc(hero.global_position, facing)                   # sword swings
VFX2D.debris_burst(crate.global_position)                       # broken objects
VFX2D.ripple(water_point, {"radius": 130.0})                     # splashes, sonar
VFX2D.implosion(vortex.global_position)                         # charging attacks

var beam := VFX2D.beam(turret.global_position, aim_point)        # sustained laser
var rune := VFX2D.rune_circle(caster, 2.5)                       # cast bar
rune.set_fill(0.6)                                               # driven per frame
beam.stop()
```

There are no PNGs or audio files in this repo: every effect is drawn with
`_draw()` and `CPUParticles2D`, so it works at any resolution and nothing needs
importing.

An **optional C++ extension** (`VFXStreakField2D`) adds thousands of
velocity-aligned spark streaks in a single draw call. It is off by default, the
addon detects it at runtime, and everything above still works without it.

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
project root. It already contains the `addons/vfx_2d/` path. That archive is
addon-only — no demo scenes.

Want the demo and the effect gallery too? Take **`vfx_2d-<version>-project.zip`**:
it is the complete runnable project (`project.godot`, `addons/`, `demo/`,
`tests/`). Open it in Godot, press **F5** for the demo, then **G** for the gallery.

### Option C — build the archives yourself

```bash
./tools/package.sh              # -> dist/vfx_2d-<version>.zip          (addon)
                                # -> dist/vfx_2d-<version>-project.zip  (demo + gallery)
./tools/package.sh --addon-only # skip the project archive
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

func _on_enemy_step(at: Vector2, facing: Vector2) -> void:
    VFX2D.smoke_puff(at, {"radius": 40.0, "rise": 0.3})
    VFX2D.shockwave(at, {"radius": 60.0, "chaos": 0.9})

func _on_shoot(muzzle: Node2D, aim: Vector2) -> void:
    VFX2D.muzzle_flash(muzzle.global_position, aim)

func _on_pickup(player: Node2D) -> void:
    VFX2D.heal_sparkle(player.global_position, {"mote_count": 26})

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
| `chaos` | `0.65` | Torn star, splinter shards, spray variance |

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
| `chaos` | `0.6` | Lopsided lobes, wobbling fronts, secondary pop |

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
| `chaos` | `0.65` | Branch count per flicker, sub-branches, stray arcs |

`get_bolt_points()` and `get_branch_points()` expose the generated geometry if
you want to hit-test or attach effects to the bolt.

### C++ streak field — optional GDExtension

GDScript stops scaling when a burst needs to be hundreds of streaks thick. The
extension integrates particles in C++ and submits them as one
`canvas_item_add_multiline` call:

```bash
pip install scons
./tools/build_extension.sh                    # ~1 min with the bundled build profile
./tools/build_extension.sh --godot <engine>   # bind a specific engine build exactly
```

Hit sparks and explosions pick it up automatically (`use_streaks`,
`streak_count`, `streak_turbulence`), or you can drive it directly:

```gdscript
if VFXStreaks.is_available():
    var field := VFXStreaks.create(self, {"head_color": Color.ORANGE, "turbulence": 0.4})
    VFXStreaks.burst(field, {"count": 800, "spread": TAU, "speed_max": 900.0})
```

Build products are gitignored; delete `addons/vfx_2d/bin/` and the generated
`.gdextension` to return to pure GDScript. Full API, tuning notes and
troubleshooting: [`cpp/README.md`](cpp/README.md).

### Smoke puff — `effects/smoke_puff.tscn`

Billowing, additive-free smoke or dust: overlapping blobs that grow, drift upward
and dissolve. Use it for landings, dashes, footsteps, broken crates.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` | `54` | Cloud size |
| `puff_count` | `9` | Blobs in the cloud |
| `rise` | `0.55` | Upward drift, as a fraction of `radius` |
| `turbulence` | `0.7` | Sideways swirl |
| `grow` | `1.5` | Extra growth while fading |
| `inner_color` / `outer_color` | grey | Colour gradient across the cloud |
| `chaos` | `0.65` | How torn each blob outline is |

### Shockwave — `effects/shockwave.tscn`

Rings and cracks, no fire: an impact wave that layers under projectiles, heavy
landings and parries.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` / `expansion` | `96` / `3.2` | Start size and reach multiplier |
| `rings` | `2` | Staggered wavefronts |
| `ring_width` | `6` | Front thickness, thins as it travels |
| `cracks` / `crack_length` | `12` / `0.35` | Radial cracks around the core |
| `ring_color` / `core_color` | pale blue / white | Tint of the front and the flash |
| `chaos` | `0.6` | How ragged the front is |

### Muzzle flash — `effects/muzzle_flash.tscn`

Directional: torn cone of light, uneven star and a spark spray along `direction`.
Belongs on the weapon, not the target.

| Property | Default | Notes |
| --- | --- | --- |
| `direction` | `Vector2.RIGHT` | Set by the convenience method |
| `length` / `cone_degrees` | `62` / `26` | Cone size and spread |
| `teeth` | `7` | Jaggedness of the cone edge |
| `spark_count` / `spark_speed` | `12` / `620` | Spark spray |
| `use_streaks` / `streak_count` | `true` / `120` | Optional C++ streak layer |
| `chaos` | `0.7` | Ragged edge and spray variance |

### Heal sparkle — `effects/heal_sparkle.tscn`

Ascending, twinkling motes with a soft glow and a couple of accent stars —
pickups, heals, level-ups.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` | `46` | Spawn spread |
| `mote_count` | `20` | Sparkles in the burst |
| `rise` | `76` | Upward travel in pixels |
| `twinkle` | `0.85` | Flicker strength |
| `star_count` | `2` | Larger accent stars |
| `sparkle_color` / `glow_color` | green / deep green | Motes and backing glow |
| `chaos` | `0.55` | Orbit scatter and jitter |

### Slash arc — `effects/slash_arc.tscn`

A tapered melee crescent that sweeps through its arc over `sweep` of the
duration, shedding sparkles along the cut. Point it anywhere with `direction`.

| Property | Default | Notes |
| --- | --- | --- |
| `direction` | `Vector2.RIGHT` | Centre of the swing (set by the spawn call) |
| `radius` | `82` | Reach of the blade |
| `arc_degrees` | `120` | Total swing angle |
| `thickness` | `10` | Crescent width |
| `trail` | `0.45` | Fraction of the arc visible at once |
| `sweep` | `0.45` | Fraction of `duration` the blade takes to travel |
| `sparkle_count` | `10` | Sparks shed along the edge |
| `core_color` / `edge_color` | white / pale blue | Blade and glow |
| `chaos` | `0.55` | Edge tearing and sparkle scatter |

```gdscript
VFX2D.slash_arc(hero.global_position, aim_direction, {"arc_degrees": 160.0, "radius": 96.0})
```

### Debris burst — `effects/debris_burst.tscn`

Solid chunks, not sparks: each one is a drawn polygon with its own velocity,
spin, gravity and drag, so the pieces arc, tumble and fall. Draws without an
additive material — broken things are opaque.

| Property | Default | Notes |
| --- | --- | --- |
| `chunk_count` | `14` | Pieces thrown |
| `chunk_size` | `6` | Base radius of a chunk |
| `speed` | `380` | Launch speed (px/s) |
| `gravity` | `900` | Downward acceleration |
| `drag` | `1.2` | Air resistance |
| `spin_speed` | `7` | Rotation (rad/s) |
| `upward_bias` | `1.2` | How much of the burst goes up |
| `chunk_color` / `chunk_color_dark` | stone / shadow | Chunk shading |
| `chaos` | `0.55` | Size, shape and launch scatter |

### Ripple — `effects/ripple.tscn`

Flattened, wobbling rings plus a few droplets — water splashes, sonar pings,
footsteps in puddles, shield rebounds.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` | `96` | Final ring reach |
| `rings` | `3` | Concentric rings, staggered in time |
| `ring_width` | `2.5` | Stroke width |
| `squash` | `0.45` | Vertical flattening (the 2.5D look) |
| `wobble` | `0.3` | Ring outline irregularity |
| `droplets` | `10` | Flecks thrown outward |
| `droplet_speed` | `320` | Droplet launch speed |
| `ring_color` / `droplet_color` | cyan / white | Water palette |
| `chaos` | `0.5` | Wobble, ring timing and droplet spread |

### Implosion — `effects/implosion.tscn`

The reverse of an explosion: motes spiral inward along streaks, pinch into a
small flash, then release a short outward puff. Charging attacks, black holes,
vacuum pulls.

| Property | Default | Notes |
| --- | --- | --- |
| `radius` | `110` | Where motes start |
| `mote_count` | `26` | Inward motes |
| `spiral` | `1.15` | Radians of swirl on the way in |
| `converge` | `1.8` | Curve of the inward motion (higher = later snap) |
| `streak_length` | `8` | Motion-blur length |
| `pinch_size` | `0.14` | Size of the pinch flash, as a fraction of `radius` |
| `mote_color` / `core_color` | violet / white | Motes and pinch |
| `chaos` | `0.55` | Spiral variance, mote jitter, release scatter |

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
| `chaos` / `glow` | `0.25` / `true` | Arc wobble, tick jitter, pulsing glow |

```gdscript
var ring := VFX2D.cooldown_ring($Icon, 3.0, {"reverse": true, "tick_count": 12})
ring.completed.connect(_on_cooldown_ready)
```

### Persistent modifiers — `rune_circle`, `portal`, `beam`, `trail`

The one-shots are fire-and-forget. These four are *attached*: they stay
alive across frames until you stop them, and they return the node so you can
keep driving it.

```gdscript
var beam := VFX2D.beam(turret.global_position, target.global_position)
beam.end_at(target.global_position)      # re-aim each frame
beam.stop()                              # fade out, then free

var portal := VFX2D.portal(door.global_position, {"lifetime": 8.0})
portal.stop()                            # play the closing animation now

var rune := VFX2D.rune_circle(caster, 2.5)   # child of caster, casts for 2.5 s
rune.set_fill(cast_progress)                  # 0..1 = cast bar

var trail := VFX2D.trail(bullet, {"history": 0.3})
```

Every modifier emits `finished` once and frees itself (unless
`free_on_finish = false`). They are tracked by `VFX2D.get_persistent_count()`
and torn down by `VFX2D.stop_all()`. A trail whose target leaves the tree frees
itself, so a despawned projectile never leaves a ribbon hanging.

| Class | Spawner | Key properties |
| --- | --- | --- |
| `RuneCircle` | `VFX2D.rune_circle(target, seconds, options)` | `radius` `54`, `segments` `12`, `spin_speed` `0.7`, `fill` `0`, `tick_length` `9`, `pulse` `0.35`, `lifetime` `0` (`0` = until stopped) |
| `PortalEffect` | `VFX2D.portal(at, options)` | `width` `58`, `height` `78`, `rim_width` `4`, `spin_speed` `1.8`, `shimmer_count` `14`, `open_time` `0.3`, `close_time` `0.35`, `lifetime` `0` |
| `BeamEffect` | `VFX2D.beam(from, to, options)` | `width` `6`, `glow_width` `20`, `pulse_speed` `900`, `pulse_spacing` `120`, `wobble` `0.35`, `warmup` `0.12`, `fade_time` `0.22`, `lifetime` `0` |
| `TrailEffect` | `VFX2D.trail(target, options)` | `history` `0.35` s, `width_start` `8`, `width_end` `0.8`, `mote_count` `6` |

All four export `chaos` (`rune_circle` `0.25`, `portal` `0.45`, `beam` `0.45`,
`trail` `0.4`) and the usual colour exports.

### Chaos — one knob on every effect

Each effect exports `chaos` (`0.0`–`1.0`, default roughly `0.6`). It is not a
random speed bump: it changes the *shape* of what is drawn, and it is reseeded on
every `play()`, so a pooled effect never repeats itself.

| Effect | What `chaos` moves |
| --- | --- |
| Hit spark | Torn star behind the flash, random splinter shards, spray rotation and spread |
| Explosion | Lopsided fireball lobes, wobbling + ghost shockfront, secondary pop offset |
| Lightning | Branch count per flicker, sub-branches, stray arcs, jaggedness |
| Cooldown ring | Arc wobble, tick jitter, pulsing glow and a spark at the arc head |
| Smoke puff | Blob outline tearing and swirl |
| Shockwave | Front raggedness, crack reach |
| Muzzle flash | Cone edge tearing, star rotation, spray spread |
| Heal sparkle | Orbit scatter, mote jitter |
| Slash arc | Edge tearing, sparkle scatter, arc wobble |
| Debris burst | Chunk shape, size and launch scatter |
| Ripple | Ring wobble, ring timing, droplet spread |
| Implosion | Spiral variance, mote jitter, release scatter |
| Rune circle | Glyph jitter, tick length variance, pulse drift |
| Portal | Rim wobble, shimmer scatter, breathing |
| Beam | Line jitter along the length, pulse spacing |
| Trail | Ribbon jitter, mote scatter |

```gdscript
VFX2D.hit_spark(at, dir, {"chaos": 0.0})   # tidy, symmetric, readable
VFX2D.hit_spark(at, dir, {"chaos": 1.0})   # splintered and lopsided
```

The knob is honest about direction: `0` is a clean shape, `1` is the wildest the
effect gets. Ring defaults to `0.25` on purpose — a cooldown still has to be
readable.

## API reference

### `VFX2D` (autoload)

| Method | Returns | Description |
| --- | --- | --- |
| `hit_spark(at, direction := Vector2.UP, options := {})` | `VFXEffect` | Spawn a hit spark |
| `explosion(at, options := {})` | `VFXEffect` | Spawn an explosion |
| `lightning(from, to, options := {})` | `VFXEffect` | Spawn a bolt between two points |
| `smoke_puff(at, options := {})` | `VFXEffect` | Spawn a smoke/dust cloud |
| `shockwave(at, options := {})` | `VFXEffect` | Spawn an impact wave |
| `muzzle_flash(at, direction := Vector2.RIGHT, options := {})` | `VFXEffect` | Spawn a directional flash |
| `heal_sparkle(at, options := {})` | `VFXEffect` | Spawn ascending sparkles |
| `slash_arc(at, direction := Vector2.RIGHT, options := {})` | `VFXEffect` | Spawn a melee crescent |
| `debris_burst(at, options := {})` | `VFXEffect` | Spawn falling debris chunks |
| `ripple(at, options := {})` | `VFXEffect` | Spawn a flattened ripple |
| `implosion(at, options := {})` | `VFXEffect` | Spawn an inward collapse |
| `cooldown_ring(target, seconds := 1.0, options := {})` | `CooldownRing` | Parent and start a ring |
| `beam(from, to, options := {})` | `BeamEffect` | Start a sustained beam |
| `portal(at, options := {})` | `PortalEffect` | Open a portal |
| `rune_circle(target, seconds := 0.0, options := {})` | `RuneCircle` | Cast circle; `seconds` `0` = until stopped |
| `trail(target, options := {})` | `TrailEffect` | Ribbon that follows a node |
| `spawn(scene, at, options := {})` | `VFXEffect` | Spawn any custom `VFXEffect` scene |
| `stop_all()` | `void` | Stop and recycle everything |
| `get_active_count()` | `int` | One-shots currently running |
| `get_persistent_count()` | `int` | Live beams, portals, runes and trails |

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
- Modifiers are not pooled: cooldown rings, runes, portals, beams and trails are
  long-lived nodes. They are tracked separately so `stop_all()` can clear them
  too, and they drop out of that list when they free themselves.
- The pool follows the scene. Because effects live under the current scene's
  `VFX2D_Layer`, a `change_scene_*` frees them all; the next spawn drops those
  dead references (an earlier build tried to reuse one and raised *"Trying to
  assign invalid previously freed instance"*). The suite covers this.

## Demo project

Open this repository in Godot and press **F5** (the demo scene is the main
scene):

- **Left click** — hit spark at the cursor
- **1 / 2 / 3 / 4** — hit spark, explosion, lightning, cooldown ring
- **5 / 6 / 7 / 8** — smoke puff, shockwave, muzzle flash, heal sparkle
- **9 / 0** — slash arc, debris burst
- **R / I** — ripple, implosion
- **B / P / U / T** — toggle a beam, portal, rune circle or trail
- **Space** — toggle the idle auto-demo
- **C** — clear all running effects
- **G** — the effect gallery

The HUD shows FPS, the live active-effect count and how many persistent modifiers
are attached. Every new effect also has a button in the HUD, so nothing here is
keyboard-only.

### Gallery: every effect at once

`demo/gallery.tscn` is the "just show me all of them" scene: a 4×4 grid with one
labelled cell per effect — all sixteen — each firing on its own timer so you can
judge them side by side while tuning. The trail cell has a small flyer orbiting
inside it, so the ribbon has something to follow.

```bash
godot --path . res://demo/gallery.tscn   # or open demo/gallery.tscn and press F6
```

It is also one key away while the demo is running: press **G** (or the *Effect
gallery* button) to jump to it, and **Esc** to come back. In the editor both live
in the `demo/` folder of the FileSystem dock — if you only ever downloaded the
addon archive, there is no `demo/` in it, which is why the gallery appears
"missing": use the repo or the `-project.zip` archive instead.

- **Space** — pause/resume the timers
- **R** — fire everything immediately
- **C** — clear running effects (one-shots and modifiers)
- **1-0, Q W E R T Y or click a cell** — fire that single cell
- **Esc** — back to the interactive demo

The header shows FPS, the live active count, the persistent-modifier count, and
whether the optional C++ streak layer is loaded, so you can A/B density by raising
`streak_count` on an effect and watching the frame rate. CI smoke-runs the
gallery on every supported engine.

## Tests and CI

The suite runs the effects for real, in a headless engine:

```bash
godot --headless --path . res://tests/test_runner.tscn
```

It covers: effect lifecycles and replay, `finished` being emitted exactly once,
cooldown fill/drain behaviour, option overrides, pool reuse of the same instance,
burst handling, `stop_all()`, lightning endpoint geometry, per-effect geometry for
the newer effects, and the persistent modifiers — `beam()` opening, re-aiming and
fading, `portal()` open → hold → close, `rune_circle()` fill and self-close,
`trail()` history recording and self-cleanup when its target dies. The process
exits non-zero on failure, which is what CI uses.

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) downloads **stock**
Godot 4.2, 4.3 and 4.7.2 Linux builds, imports the project, runs the test scene,
then smoke-runs the demo scene. A run fails on any `SCRIPT ERROR`, parse error or
engine `ERROR:` line.

Headless still issues draw notifications, so `_draw()` really runs for every
effect during the suite — the procedural geometry (arcs, polylines, layered
discs) is exercised, not just the timing and pooling logic. What CI cannot judge
is how it *looks*; that needs the demo on a real display.

The separate [`GDExtension` workflow](.github/workflows/gdextension.yml) builds
the C++ streak field against stock Godot 4.7.2, then runs the same suite and
**fails if the extension silently failed to load** — the C++ tests print
`cpp-streak-field: available|absent`, and the workflow asserts which one ran.
Same suite, both paths: **216 checks** with the extension, **204** without, zero
engine errors either way. Every one-shot — all eleven — is run through its full
lifecycle, and every effect (one-shots and modifiers) has its `chaos` knob
exercised.

## Repository layout

```
addons/vfx_2d/
  plugin.cfg                 # Editor plugin manifest
  plugin.gd                  # Registers the VFX2D autoload
  vfx_2d.gd                  # Autoload: spawn API + pooling
  core/vfx_effect.gd         # VFXEffect base class
  core/vfx_shapes.gd         # Procedural outlines shared by the effects
  effects/hit_spark.*        # Effect scenes + scripts
  effects/explosion.*
  effects/lightning.*
  effects/cooldown_ring.*
  effects/smoke_puff.*
  effects/shockwave.*
  effects/muzzle_flash.*
  effects/heal_sparkle.*
  effects/slash_arc.*        # one-shots added in 0.4.0
  effects/debris_burst.*
  effects/ripple.*
  effects/implosion.*
  effects/rune_circle.*      # persistent modifiers
  effects/portal.*
  effects/beam.*
  effects/trail.*
cpp/                         # Optional C++ streak field (GDExtension)
  src/vfx_streak_field.*     # Particle integration + multiline draw
  src/register_types.cpp     # Class registration / entry point
  SConstruct                 # Builds into addons/vfx_2d/bin/
tools/build_extension.sh     # Fetches godot-cpp, builds, writes .gdextension
demo/                        # Interactive sandbox + effect gallery
  gallery.tscn               # All sixteen effects, side by side, on timers
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
