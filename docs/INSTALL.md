# Installing and using Sparkform

The kit is a standard Godot **EditorPlugin** plus an autoload. There is nothing to
compile (unless you want the optional C++ streak layer), nothing to import, and
no assets to keep in sync.

- **Requirements:** Godot **4.2 or newer**. Tested on 4.2, 4.3 and 4.7.2, with and
  without the extension.
- **Footprint:** the addon is a single folder, `addons/sparkform/`, about 76 KB of
  GDScript and scenes.
- **What you get:** 16 one-shot effects, 8 persistent modifiers, pooling, a
  `chaos` knob on every effect, and an optional C++ particle layer.

---

## 1. Install

Pick one. All three end with the same folder at `res://addons/sparkform/`.

### A. Release archive (easiest)

Download `sparkform-<version>.zip` from the
[releases page](https://github.com/mccarthyah/Godot-2D-VFX-plugin/releases), then
in your project root:

```bash
# Linux / macOS, from your Godot project root
unzip ~/Downloads/sparkform-0.6.0.zip
```

```powershell
# Windows PowerShell, from your Godot project root
Expand-Archive -Path "$HOME\Downloads\sparkform-0.6.0.zip" -DestinationPath .
```

The archive already contains the `addons/` level, so extracting it into the
project root is all it takes. Reload the project (**Project → Reload Current
Project**) and the folder appears in the FileSystem dock.

### B. Godot AssetLib (in-editor)

**AssetLib** tab → search for *Sparkform* → **Download** → **Install**. Godot
offers to enable the plugin immediately; accept.

### C. Copy the folder / submodule

```bash
git submodule add https://github.com/mccarthyah/Godot-2D-VFX-plugin.git vendor/vfx
cp -r vendor/vfx/addons/sparkform addons/sparkform
```

Pinning a submodule is the nicest option if you want to review updates before
they land. Keep only `addons/sparkform/` in your project; the rest of the repo
(demo, gallery, tests, `cpp/`) is development material.

---

## 2. Enable it

1. **Project → Project Settings → Plugins**.
2. Tick the **Enable** checkbox next to **Sparkform**.
3. The Output panel prints:

   ```
   [Sparkform] autoload registered.
   ```

That is the editor plugin doing its only job: adding
`res://addons/sparkform/sparkform.gd` as an autoload named `Sparkform` and saving the
setting straight away, so it survives the session and lands in your export.

The plugin never removes the autoload, not when you disable it and not when the
editor closes. It is the runtime API, so pulling it out would break
`godot --path .` runs and exports made with the plugin switched off. Remove the
entry from **Project Settings → Autoload** yourself if you want it gone.

If your project already registers `Sparkform` (a different path, a wrapper, a
subclass), the plugin leaves your setting untouched and says so in the Output
panel.

**Prefer to wire it up by hand?** Tick *Advanced Settings* in the plugins tab,
or go straight to **Project Settings → Autoload** and add:

| Path | Node name |
| --- | --- |
| `res://addons/sparkform/sparkform.gd` | `Sparkform` |

---

## 3. Verify

Create a script anywhere, paste this in, and run the scene (F6). You should see a
spark on the screen and three lines in the Output panel.

```gdscript
extends Node2D

func _ready() -> void:
	print("Sparkform: ", Sparkform)
	Sparkform.hit_spark(Vector2(160, 120), Vector2.UP)
	Sparkform.explosion(Vector2(320, 240), {"radius": 90.0})
	await get_tree().create_timer(0.5).timeout
	print("active: ", Sparkform.get_active_count())
	print("effects dir: ", Sparkform.get_script().resource_path.get_base_dir())
```

If `Sparkform` is reported as an unknown identifier the plugin is not enabled. Go
back to step 2.

---

## 4. Quick start

```gdscript
# One-shots: spawn, play, pooled, gone.
Sparkform.hit_spark(enemy.global_position, Vector2.UP)
Sparkform.explosion(boss.global_position, {"radius": 120.0, "chaos": 0.8})
Sparkform.lightning(caster.global_position, target.global_position, {"branches": 4})
Sparkform.slash_arc(hero.global_position, facing, {"arc_degrees": 150.0})
Sparkform.muzzle_flash(barrel.global_position, aim_direction)
Sparkform.frost_burst(hit_point)
Sparkform.acid_splash(puddle)
Sparkform.impact_crack(floor_point, {"surface": Vector2.UP})
Sparkform.chain(caster.global_position, [a.global_position, b.global_position])
Sparkform.blink(from_point, to_point)

# Persistent modifiers: keep the node, drive it, stop it.
var beam := Sparkform.beam(turret.global_position, aim_point)
beam.end_at(target.global_position)
beam.stop()

var bubble := Sparkform.shield(player, {"radius": 72.0})
bubble.hit(enemy.global_position)

var rune := Sparkform.rune_circle(caster, 2.5)
rune.set_fill(cast_progress)

var leash := Sparkform.tether(player, enemy)
leash.set_targets(player, other_enemy)
```

Housekeeping:

```gdscript
Sparkform.stop_all()                 # clear everything (also clears modifiers)
Sparkform.get_active_count()         # one-shots currently running
Sparkform.get_persistent_count()     # live beams, portals, runes, trails, ...
```

---

## 5. Effect catalogue

### One-shots

| Effect | Call | Use for |
| --- | --- | --- |
| Hit spark | `hit_spark(at, direction)` | Bullet impacts, parry ticks |
| Explosion | `explosion(at)` | Anything that goes boom |
| Lightning | `lightning(from, to)` | Single-target shocks |
| Smoke puff | `smoke_puff(at)` | Dust, landings, muzzle haze |
| Shockwave | `shockwave(at)` | Slams, pressure rings |
| Muzzle flash | `muzzle_flash(at, direction)` | Gunfire |
| Heal sparkle | `heal_sparkle(at)` | Pickups, buffs |
| Slash arc | `slash_arc(at, direction)` | Melee swings |
| Debris burst | `debris_burst(at)` | Broken crates, gibs |
| Ripple | `ripple(at)` | Water, sonar, puddle steps |
| Implosion | `implosion(at)` | Charge-ups, absorbs |
| Frost burst | `frost_burst(at)` | Ice hits, freeze breaks |
| Acid splash | `acid_splash(at)` | Corrosive pools |
| Impact crack | `impact_crack(at, {"surface": ...})` | Ground slams, ceiling hits |
| Chain lightning | `chain(from, [targets...])` | Multi-target shocks |
| Blink | `blink(from, to)` | Teleports, dashes |

### Persistent modifiers

| Modifier | Call | Stop it with |
| --- | --- | --- |
| Cooldown ring | `cooldown_ring(target, seconds)` | `ring.stop()`, or it completes |
| Rune circle | `rune_circle(target, seconds)` | `rune.stop()`; `set_fill()` for a cast bar |
| Portal | `portal(at)` | `portal.stop()` (plays the close animation) |
| Beam | `beam(from, to)` | `beam.stop()` |
| Trail | `trail(target)` | `trail.stop()`, or it frees when the target dies |
| Shield bubble | `shield(target)` | `bubble.stop()`; `hit(world_point)` for impacts |
| Tether | `tether(a, b)` | `link.stop()`; frees if either end disappears |
| Vortex | `vortex(at)` | `vortex.stop()` |

Every spawner accepts an `options` dictionary of exported properties:

```gdscript
Sparkform.explosion(at, {"radius": 160.0, "duration": 0.9, "chaos": 0.9})
Sparkform.beam(from, to, {"width": 10.0, "pulse_speed": 1400.0})
```

Unknown keys warn instead of crashing, so typos are loud but harmless. Every
effect also exports `chaos` (`0.0`–`1.0`), reseeded per play, which changes the
shape of the geometry rather than the speed alone.

---

## 6. Optional C++ streak layer

The GDScript kit is complete on its own. If you want thousands of
velocity-aligned spark streaks per burst in a single draw call, build the
extension:

```bash
./tools/build_extension.sh          # fetches godot-cpp, builds, writes the .gdextension
```

Prebuilt Linux libraries ship in `sparkform-<version>-cpp.zip`. Binaries are
specific to the platform and engine version, so build your own for other targets.
Effects attach the layer automatically when it is present (`use_streaks`,
`streak_count`); nothing changes if it is not.

---

## 7. Updating and removing

**Update:** replace `addons/sparkform/` with the new version, keep the plugin
enabled. Your autoload setting and any code are untouched; check
[CHANGELOG.md](../CHANGELOG.md) for behaviour changes.

**Remove:** disable the plugin (Project Settings → Plugins), delete
`addons/sparkform/`, then delete the `Sparkform` entry from
**Project Settings → Autoload**. Nothing else references the addon.

---

## 8. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Identifier "Sparkform" not declared` | Plugin not enabled, or autoload deleted. Enable the plugin, or add the autoload yourself (step 2) |
| `--headless` run hangs, or parses fail, on a copy you never opened in the editor | Godot needs an import pass before it knows the project's classes: run `godot --headless --path . --import` once, or open the project in the editor first. The editor does this for you |
| `Could not find type "VFXEffect"` on first open | Should not happen from 0.5.1 on: the addon resolves its base class by path. If you see it on an older copy, update; otherwise let the editor finish its initial scan |
| Effects render behind sprites | They live on a `Sparkform_Layer` node at `z_index = 100`; adjust that layer or your own z-indices |
| Nothing appears at all | Spawn positions are global, so check the point is on screen, and that the effect is not culled by a `CanvasLayer`/camera setup |
| Effects vanish after `change_scene_to_file()` | By design: the layer belongs to the scene. Spawn again after the change; the pool self-cleans |
| Demo/gallery "missing" | The addon archive has no `demo/`; grab the `-project.zip` archive or the repo if you want the gallery |
| Extension not loading | Check the version in `bin/` matches your engine; rebuild with `tools/build_extension.sh`. The kit still works without it |
| Warnings about unknown option keys | The key is not an exported property; check the effect's script for the real name |

---

## License

MIT, see [LICENSE](../LICENSE). Bundling it into a commercial game is fine.
