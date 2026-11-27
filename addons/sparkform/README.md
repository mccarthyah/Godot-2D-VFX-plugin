# Sparkform

Procedural, asset-free 2D effects for Godot 4.2+. No PNGs, no audio, no import
step: every effect is drawn with `_draw()` and `CPUParticles2D`, so it scales to
any resolution and adds nothing to your resource budget.

This folder is the addon. Everything below works from inside it; you do not need
the rest of the repository (demo, gallery, tests) to use the kit.

## Enable it

1. Copy `addons/sparkform/` into your project (or install the release archive into
   the project root; it already has the `addons/` level).
2. **Project → Project Settings → Plugins**, enable **Sparkform**.
   That registers the `Sparkform` autoload for you.
3. Check the Output panel: `[Sparkform] autoload registered.`

The plugin adds the autoload once and saves it, so it survives restarts and ends
up in your exports. It never removes it again: disable the plugin and the
autoload stays, because it is the runtime API.

Prefer to wire it up yourself? Tick **Advanced Settings** in the plugins tab and
add `res://addons/sparkform/sparkform.gd` as an autoload named `Sparkform` before enabling
the plugin; it then leaves your setting alone.

## Use it

```gdscript
Sparkform.hit_spark(enemy.global_position, Vector2.UP)
Sparkform.explosion(boss.global_position, {"radius": 120.0})
Sparkform.lightning(caster.global_position, target.global_position, {"branches": 4})
Sparkform.slash_arc(hero.global_position, facing)
Sparkform.frost_burst(hit_point)
Sparkform.impact_crack(floor_point, {"surface": Vector2.UP})
Sparkform.chain(caster.global_position, [a.global_position, b.global_position])
Sparkform.cooldown_ring($Icon, 2.5)
```

Persistent modifiers are nodes you keep and stop:

```gdscript
var beam := Sparkform.beam(turret.global_position, aim_point)
beam.end_at(target.global_position)          # re-aim while it is alive
beam.stop()                                  # fade out, then free

var bubble := Sparkform.shield(player, {"radius": 72.0})
bubble.hit(enemy.global_position)            # flash where it was struck

var rune := Sparkform.rune_circle(caster, 2.5)   # fill doubles as a cast bar
rune.set_fill(cast_progress)

var link := Sparkform.tether(player, enemy)      # sagging chain
var pull := Sparkform.vortex(charge_point, {"radius": 120.0})
var ribbon := Sparkform.trail(bullet, {"history": 0.3})
var gate := Sparkform.portal(door.global_position)
```

Every spawner takes an `options` dictionary of exported properties; pass any
property by name, and typos produce a warning instead of a crash. Every effect
carries a `chaos` knob (`0` = tidy and symmetric, `1` = the wildest it gets),
reseeded on every `play()`, so pooled effects never repeat themselves.

## Full reference

This page is the short version. The complete reference lives in the repository
under `docs/`:

- `docs/API.md` - every autoload method and the `VFXEffect` base class
- `docs/EFFECTS.md` - all 24 effects, every exported property with its default
- `docs/COOKBOOK.md` - recipes and the troubleshooting checklist
- `docs/INSTALL.md` - install variants, verification, common errors

Both generated pages are rebuilt from these scripts' doc comments, which are also
the inspector tooltips you see in the editor.

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

- **`Sparkform` is not declared**: the plugin is not enabled, or the autoload was
  removed. Check Project Settings → Autoload for an entry named `Sparkform`.
- **Unknown class `VFXEffect` / parse errors on first open**: let the editor
  finish scanning (the global class cache is built once), or run
  `godot --headless --path . --import` once from a terminal.
- **Effects appear behind your sprites**: one-shots are parented to a
  `Sparkform_Layer` node at `z_index = 100`. Change `container_node_name` /
  edit the layer's `z_index` if your project uses a different convention.
- **Effects appear at the wrong place after a camera move**: spawn with global
  positions; the layer is parented to the current scene, not to the camera.

## License

MIT. See `LICENSE` in this folder.
