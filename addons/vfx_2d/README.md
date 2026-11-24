# 2D VFX Kit — addon

Procedural, asset-free 2D effects for Godot 4.2+. No PNGs, no audio, no import
step: every effect is drawn with `_draw()` and `CPUParticles2D`, so it scales to
any resolution and adds nothing to your resource budget.

This folder is the addon. Everything below works from inside it — you do not need
the rest of the repository (demo, gallery, tests) to use the kit.

## Enable it

1. Copy `addons/vfx_2d/` into your project (or install the release archive into
   the project root — it already has the `addons/` level).
2. **Project → Project Settings → Plugins**, enable **2D VFX Kit**.
   That registers the `VFX2D` autoload for you.
3. Check the Output panel: `[2D VFX Kit] Registered the VFX2D autoload.`

The plugin adds the autoload once and saves it, so it survives restarts and ends
up in your exports. It never removes it again — disable the plugin and the
autoload stays, because it is the runtime API.

Prefer to wire it up yourself? Tick **Advanced Settings** in the plugins tab and
add `res://addons/vfx_2d/vfx_2d.gd` as an autoload named `VFX2D` before enabling
the plugin; it then leaves your setting alone.

## Use it

```gdscript
VFX2D.hit_spark(enemy.global_position, Vector2.UP)
VFX2D.explosion(boss.global_position, {"radius": 120.0})
VFX2D.lightning(caster.global_position, target.global_position, {"branches": 4})
VFX2D.slash_arc(hero.global_position, facing)
VFX2D.frost_burst(hit_point)
VFX2D.impact_crack(floor_point, {"surface": Vector2.UP})
VFX2D.chain(caster.global_position, [a.global_position, b.global_position])
VFX2D.cooldown_ring($Icon, 2.5)
```

Persistent modifiers are nodes you keep and stop:

```gdscript
var beam := VFX2D.beam(turret.global_position, aim_point)
beam.end_at(target.global_position)          # re-aim while it is alive
beam.stop()                                  # fade out, then free

var bubble := VFX2D.shield(player, {"radius": 72.0})
bubble.hit(enemy.global_position)            # flash where it was struck

var rune := VFX2D.rune_circle(caster, 2.5)   # fill doubles as a cast bar
rune.set_fill(cast_progress)

var link := VFX2D.tether(player, enemy)      # sagging chain
var pull := VFX2D.vortex(charge_point, {"radius": 120.0})
var ribbon := VFX2D.trail(bullet, {"history": 0.3})
var gate := VFX2D.portal(door.global_position)
```

Every spawner takes an `options` dictionary of exported properties — pass any
property by name, and typos produce a warning instead of a crash. Every effect
carries a `chaos` knob (`0` = tidy and symmetric, `1` = the wildest it gets),
reseeded on every `play()`, so pooled effects never repeat themselves.

## What is in the box

One-shots (pooled, fire-and-forget): `hit_spark`, `explosion`, `lightning`,
`smoke_puff`, `shockwave`, `muzzle_flash`, `heal_sparkle`, `slash_arc`,
`debris_burst`, `ripple`, `implosion`, `frost_burst`, `acid_splash`,
`impact_crack`, `chain_lightning`, `blink`.

Persistent modifiers (returned as nodes): `cooldown_ring`, `rune_circle`,
`portal`, `beam`, `trail`, `shield_bubble`, `tether`, `vortex`.

Also in here: `core/vfx_effect.gd` (the one-shot base class, for your own
effects), `core/vfx_shapes.gd` (the procedural outlines), `core/vfx_streaks.gd`
(the optional C++ bridge), and `bin/` when you build the extension.

## The optional C++ streak layer

`bin/` holds a GDExtension that draws thousands of velocity-aligned sparks in a
single `canvas_item_add_multiline` call. It is entirely optional and platform
specific: without it the kit runs on plain GDScript and prints nothing. Effect
properties `use_streaks` / `streak_count` are ignored when it is absent. See
`cpp/README.md` in the repository for the build.

## Troubleshooting

- **`VFX2D` is not declared** — the plugin is not enabled, or the autoload was
  removed. Check Project Settings → Autoload for an entry named `VFX2D`.
- **Unknown class `VFXEffect` / parse errors on first open** — let the editor
  finish scanning (the global class cache is built once), or run
  `godot --headless --path . --import` once from a terminal.
- **Effects appear behind your sprites** — one-shots are parented to a
  `VFX2D_Layer` node at `z_index = 100`. Change `container_node_name` /
  edit the layer's `z_index` if your project uses a different convention.
- **Effects appear at the wrong place after a camera move** — spawn with global
  positions; the layer is parented to the current scene, not to the camera.

## License

MIT. See `LICENSE` in this folder.
