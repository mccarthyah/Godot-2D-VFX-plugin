# Cookbook

Recipes for the situations that actually come up in a game: hit feedback, aiming,
bosses, persistent modifiers, frame budgets and custom effects. Everything here
uses only the public API — [`API.md`](API.md) has the signatures,
[`EFFECTS.md`](EFFECTS.md) has every property, [`INSTALL.md`](INSTALL.md) gets the
addon into a project, and [`ASSETLIB.md`](ASSETLIB.md) covers the release
archives. (This page is hand-written; the other two references are generated from
the source, so they cannot drift.)

## 1. Hit feedback from a signal

The common case: something took damage, play a spark where it was hit.

```gdscript
func _on_enemy_damaged(enemy: Node2D, hit_point: Vector2, source: Node2D) -> void:
    var away := (hit_point - source.global_position).normalized()
    Sparkform.hit_spark(hit_point, away)
```

`hit_spark` points its sparks along the second argument and biases the flash the
same way, so passing the knock-back direction costs nothing and reads correctly.

## 2. Aiming the directional effects

Five effects take a direction rather than a point:

```gdscript
Sparkform.hit_spark(point, outward)                 # sparks + flash
Sparkform.muzzle_flash(muzzle.global_position, aim)  # cone, star, sparks
Sparkform.slash_arc(hero.global_position, facing)    # melee crescent
Sparkform.lightning(from, to)                        # procedural bolt
Sparkform.blink(from, to)                            # collapse, streak, burst
```

Directions are **not** normalised for you in the scene; pass a normalized vector
if you want the effect to keep its designed proportions. For a projectile, the
velocity is already the direction you want:

```gdscript
func _physics_process(_delta: float) -> void:
    if just_fired:
        Sparkform.muzzle_flash($Muzzle.global_position, velocity.normalized())
```

## 3. Tuning one spawn without touching the scene

Every spawner takes an `options` dictionary of exported property names:

```gdscript
Sparkform.explosion(boss.global_position, {"radius": 140.0, "fireball_layers": 10})
Sparkform.frost_burst(point, {"shard_count": 28, "shimmer": 0.9})
Sparkform.smoke_puff(point, {"puff_count": 14, "outer_color": Color(0.2, 0.2, 0.24)})
```

Unknown keys log `Sparkform: '<name>' is not a property of <class>` and are
otherwise ignored, so a typo is loud in the debugger but never crashes gameplay.
The property list per effect is in [`EFFECTS.md`](EFFECTS.md) — copy the names
straight out of the tables.

`scale`, `rotation` and `modulate` are ordinary node properties, so they work in
the dictionary too (a fresh spawn resets them before the dictionary is applied):

```gdscript
Sparkform.explosion(point, {"scale": Vector2(1.6, 1.6)})   # a bigger blast
```

## 4. One effect, three sizes

Scaling in the options dictionary is the cheap way to make a family of effects
share one scene — a grunt hit, an elite hit and a boss slam:

```gdscript
const SIZES := {
    "grunt": {"scale": Vector2(0.8, 0.8), "duration": 0.45, "streak_count": 60},
    "elite": {"scale": Vector2(1.2, 1.2), "duration": 0.6, "streak_count": 150},
    "boss": {"scale": Vector2(2.2, 2.2), "duration": 0.9, "streak_count": 512},
}

func play_hit(point: Vector2, tier: String) -> void:
    Sparkform.hit_spark(point, Vector2.UP, SIZES.get(tier, SIZES["grunt"]))
```

Longer `duration` stretches the fade, so a boss hit reads heavier without any
second scene. Remember that `chaos` is re-seeded on every play, so two hits at the
same size still look different.

## 5. Persistent modifiers: keep the node, then stop it

Beams, portals, runes, trails, shields, tethers and vortexes are **nodes you
hold**. They open, stay open, and close when you stop them:

```gdscript
var beam: BeamEffect

func begin_charge(from: Vector2, to: Vector2) -> void:
    beam = Sparkform.beam(from, to)

func retarget(to: Vector2) -> void:
    if is_instance_valid(beam):
        beam.end_at(to)

func end_charge() -> void:
    if is_instance_valid(beam):
        beam.stop()          # plays the closing animation, then frees itself
    beam = null
```

Rules of thumb:

- `is_instance_valid()` before every call: the node frees itself when its scene
  changes, when `lifetime` runs out, or after `stop()`.
- `stop()` starts a fade; the node is gone a moment later. To reuse one node for
  repeated casts, pass `{"free_on_finish": false}` and call `start()` again.
- Timing knobs: `beam` opens instantly and fades over `fade_time`; `portal` uses
  `open_time` / `close_time`; `shield_bubble`, `tether`, `vortex` and
  `rune_circle` take `lifetime` (`0` = until stopped).

## 6. Effects that live on a node

`cooldown_ring` and `rune_circle` are added as children of the target node and sit
at its origin, so they follow it for free:

```gdscript
func start_cooldown(icon: Node2D, seconds: float) -> void:
    Sparkform.cooldown_ring(icon, seconds, {"tick_count": 8, "glow": true})

func begin_cast(caster: Node2D, seconds: float) -> RuneCircle:
    var rune := Sparkform.rune_circle(caster, seconds, {"radius": 64.0})
    return rune

func update_cast(rune: RuneCircle, progress: float) -> void:
    if is_instance_valid(rune):
        rune.set_fill(progress)   # the fill doubles as a cast bar
```

`cooldown_ring` returns a node with `progress`; `rune_circle` returns one with
`set_fill()` / `get_openness()`. `shield(target)` also parents the bubble to the
target; `trail(target)` does not — the ribbon lives in the effect layer and
records the target's global positions, so it never inherits the target's rotation
or scale.

## 7. Chaining a bolt through a group

`chain()` reveals one hop at a time, in array order, so the order you build the
list is the order the bolt travels:

```gdscript
func zap(caster: Node2D, enemies: Array[Node2D]) -> void:
    var ordered := enemies.duplicate()
    ordered.sort_custom(func(a, b):
        return caster.global_position.distance_to(a.global_position) \
            < caster.global_position.distance_to(b.global_position))
    var points: Array[Vector2] = []
    for enemy in ordered:
        points.append(enemy.global_position)
    Sparkform.chain(caster.global_position, points, {"segments": 16, "hop_delay": 0.08})
```

## 8. Keeping the frame budget

Two exported limits on the autoload do the heavy lifting:

| Setting | Default | Effect |
|---|---|---|
| `pool_size_per_effect` | 24 | Idle instances kept per effect scene; the rest are freed when they finish |
| `max_active_effects` | 160 | When exceeded, the **oldest** running effect is stopped |

```gdscript
func _on_quality_changed(low_end: bool) -> void:
    Sparkform.max_active_effects = 60 if low_end else 160
    Sparkform.pool_size_per_effect = 8 if low_end else 24
```

Counting live effects is cheap and makes a decent debug overlay:

```gdscript
$Debug/Label.text = "%d active, %d persistent" % [
    Sparkform.get_active_count(), Sparkform.get_persistent_count()
]
```

Room transitions and death screens should clear both lists:

```gdscript
func _on_scene_closing() -> void:
    Sparkform.stop_all()
```

Because the layer lives under the current scene, a `change_scene_to_file()` also
takes every pooled instance with it; the autoload drops the dead references on
the next spawn. `stop_all()` is still the polite way to finish effects before a
cutscene.

## 9. Boss-scale and cinematic settings

The effects are drawn in world space, so big set pieces are mostly a matter of
scale, colour and a couple of extra layers:

```gdscript
func arena_impact(point: Vector2) -> void:
    Sparkform.explosion(point, {"scale": Vector2(3.0, 3.0), "duration": 1.1,
        "core_color": Color(1.0, 0.85, 0.6), "streak_count": 512})
    Sparkform.shockwave(point, {"scale": Vector2(3.0, 3.0), "rings": 3,
        "cracks": 20})
    Sparkform.smoke_puff(point + Vector2(0, 24), {"scale": Vector2(2.0, 2.0)})
```

`streak_count` only does something when the optional C++ extension is loaded;
without it the effect still plays, just with fewer particles (see §11).

## 10. Writing your own effect

Subclass `VFXEffect`, implement the three callbacks, and spawn it like a built-in
one. This gets you pooling, the `options` dictionary, and `stop_all()` for free.

```gdscript
# res://effects/confetti.gd
extends VFXEffect

@export var piece_count: int = 40
@export var piece_color: Color = Color(1.0, 0.85, 0.3)

var _pieces: Array[Dictionary] = []

func _on_play() -> void:
    _pieces.clear()
    for i in piece_count:
        _pieces.append({
            "angle": randf() * TAU,
            "speed": randf_range(120.0, 320.0),
        })

func _on_update(progress: float, _delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    for piece in _pieces:
        var angle: float = piece["angle"]
        var speed: float = piece["speed"]
        var travel: Vector2 = Vector2.from_angle(angle) * speed * progress
        draw_circle(travel + Vector2(0, 60.0 * progress * progress), 3.0, piece_color)

func _on_stop() -> void:
    _pieces.clear()
```

Give the scene a `VFXEffect`-extending root, then:

```gdscript
const CONFETTI := preload("res://effects/confetti.tscn")
Sparkform.spawn(CONFETTI, point, {"piece_count": 80})
```

`Sparkform.spawn()` returns `null` and pushes an error if the scene root does not
extend `VFXEffect`.

## 11. The optional C++ streak layer

The extension in `bin/` draws thousands of velocity-aligned sparks in one
multiline draw call. It is entirely optional: when `bin/` is missing, the effects
fall back to their GDScript layers and print nothing.

```gdscript
Sparkform.explosion(point, {"use_streaks": false})       # skip it for this spawn
Sparkform.hit_spark(point, outward, {"streak_count": 0}) # or just use none
```

Build it with `tools/build_extension.sh` (details in `cpp/README.md`); ship
`-cpp` archives only to platforms you built for.

## 12. When an effect does not appear

Checklist, in the order these actually happen:

1. **`Sparkform` is unknown** — the plugin is not enabled and the autoload was
   never registered. Enable **Sparkform** in *Project → Project Settings →
   Plugins*; the autoload appears under *Project Settings → Globals*.
2. **Nothing on screen** — spawn with *global* positions. Effects are parented to
   `Sparkform_Layer` (a `z_index = 100` node under the current scene), not to
   your camera or container, so local coordinates from another transform point
   somewhere else.
3. **Hidden by another canvas layer** — raise `container_node_name`'s layer
   `z_index`, or spawn under a `CanvasLayer` of your own with
   `Sparkform.spawn(scene, position, {})` if you manage layers manually.
4. **A typo in `options`** — the Output panel prints
   `Sparkform: 'raduis' is not a property of …` and keeps the default.
5. **The effect stops early** — you hit `max_active_effects` and the oldest
   effect was retired. Raise the cap or lower the spawn rate.
6. **`null` from a persistent spawner** — its target argument was not a valid
   node; every persistent spawner validates and pushes an error instead of
   crashing.
