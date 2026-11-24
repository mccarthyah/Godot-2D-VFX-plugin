# C++ streak field (optional GDExtension)

The GDScript effects are deliberately cheap: a few hundred particles and some
`_draw()` geometry. That is the right cost for gameplay code, but it stops
scaling exactly where sparks start reading as *heat* — hundreds to thousands of
velocity-aligned streaks per burst. Every particle then costs a `_draw()` call
and a script instruction budget.

This extension moves that hot loop to C++:

- particles are plain structs in one `std::vector` (no nodes, no signals, no
  per-particle allocation);
- integration is a tight loop with gravity, linear drag and a cheap turbulence
  field;
- all streaks are submitted as **one** `canvas_item_add_multiline` call, with
  per-vertex colours, so a 3 000-particle burst is one draw command;
- dead particles are swap-removed, and the pool is capped by `max_particles`
  with ring reuse, so memory stays flat under sustained fire.

It is **optional**. The addon checks `ClassDB.class_exists("VFXStreakField2D")`
at runtime (`VFXStreaks.is_available()`): when the library is missing, hit sparks
and explosions run exactly as before, with no errors and no warnings.

## Building

```bash
pip install scons                    # once
./tools/build_extension.sh           # debug build against Godot 4.7 (~1 min)
./tools/build_extension.sh --release # debug + release
./tools/build_extension.sh --godot /path/to/godot   # bind that engine exactly
```

`--godot` is the safest option: it dumps `extension_api.json`, the interface
header and the interface JSON from that binary and builds against all three, so
the library matches the engine that will load it. The script also uses a
**build profile** ([`build_profile.json`](build_profile.json)) listing only the
classes this extension touches — that is the difference between a ~40 minute
full godot-cpp build and a ~1 minute one.

The script clones [godot-cpp](https://github.com/godotengine/godot-cpp) into
`cpp/godot-cpp/` (gitignored, pinned with `GODOT_CPP_REF`, default `master`),
builds the library, drops it in `addons/vfx_2d/bin/` and generates
`addons/vfx_2d/vfx_streaks.gdextension`. Delete both to return to GDScript —
nothing else in the addon needs to change.

Versions: godot-cpp has no 4.7 branch, so the build pins the commit
`fba3efa` (2026-07-29) — the last one whose interface still matches 4.7.x.
Later `master` targets the 4.8 interface and 4.7 rejects it with
`non-existent interface function: get_godot_version`. Override with `--ref` or
`GODOT_CPP_REF`. The generated descriptor sets `compatibility_minimum` to the
targeted API line.

Build products are gitignored, so a fresh clone stays pure GDScript and the main
CI matrix (4.2 / 4.3 / 4.7.2) keeps testing the fallback path. The
`GDExtension` workflow builds the library and tests the loaded path.

## Node API — `VFXStreakField2D`

### Methods

| Method | Description |
| --- | --- |
| `burst(config: Dictionary)` | Emit particles. All keys optional. |
| `clear()` | Remove every live particle. |
| `get_alive_count() -> int` | Live particles. |
| `get_drawn_segment_count() -> int` | Segments submitted in the last `_draw()`. |
| `get_total_spawned() -> int` | Cumulative spawn count (diagnostics). |

### `burst()` keys

| Key | Default | Meaning |
| --- | --- | --- |
| `origin` | `Vector2.ZERO` | Spawn point, in the node's local space |
| `count` | `24` | Particles to emit |
| `direction` | `Vector2.UP` | Cone axis (normalized internally) |
| `spread` | `TAU` | Full cone width in radians (`TAU` = all directions) |
| `speed_min` / `speed_max` | `120` / `420` | Initial speed range, px/s |
| `lifetime_min` / `lifetime_max` | `0.25` / `0.6` | Lifetime range, seconds |

### Properties

| Property | Default | Notes |
| --- | --- | --- |
| `max_particles` | `4096` | Hard capacity; full pools recycle in a ring |
| `gravity` | `900` | px/s², positive pulls down |
| `drag` | `1.8` | Linear velocity damping per second |
| `turbulence` | `0` | `0..2`, cheap sin/cos acceleration field |
| `streak_scale` | `0.035` | Streak length as a fraction of velocity (seconds of travel) |
| `base_width` | `2` | Streak width, px |
| `head_color` / `tail_color` | warm white / amber | Per-vertex gradient; tail alpha should be `0` for a clean fade |
| `additive` | `true` | Uses a `CanvasItemMaterial` in add mode |
| `seed` | `0` | `0` = random stream; non-zero reseeds per burst for repeatable output |

## GDScript bridge

```gdscript
if VFXStreaks.is_available():
    var field := VFXStreaks.create(self, {"head_color": Color.ORANGE, "turbulence": 0.4})
    VFXStreaks.burst(field, {
        "count": 800,
        "direction": Vector2.UP,
        "spread": TAU,
        "speed_min": 200.0,
        "speed_max": 900.0,
        "lifetime_min": 0.3,
        "lifetime_max": 0.8,
    })
```

The built-in effects use it automatically: `HitSparkEffect` and
`ExplosionEffect` each expose `use_streaks`, `streak_count` and
`streak_turbulence`, and attach a `VFXStreakField2D` child on first play.

## Rendering note

`RenderingServer.canvas_item_add_multiline` takes **one colour per segment**
(`colors * 2 == points`), not one per vertex. Each streak is therefore emitted
as two segments — head→mid→tail — which is what produces the gradient in a
single draw call. Passing per-vertex colours trips a
`p_colors.size() * 2 != p_points.size()` engine error.

## Tuning notes

- Streak length reads as speed: `streak_scale` × velocity. Below ~0.02 s the
  burst looks like dots; above ~0.08 s it smears into ribbons.
- `drag` is what sells impact — sparks should decelerate fast, then drift.
- `turbulence` above ~0.6 stops looking like sparks and starts looking like
  embers in a fire, which is useful for burning debris but not for hits.
- Keep `count` proportional to blast size: ~60 for a hit, 200–400 for an
  explosion, 1000+ only for set pieces.

## Verification status

- **Stock Godot 4.7.2**: library loads, suite reports 58 checks / 0 failures with
  the C++ tests active, demo runs clean.
- **Without the library**: the same suite reports 46 checks / 0 failures and the
  C++ section skips itself.
- A `custom_build` headless binary was also tried and **rejected every
  GDExtension** (`non-existent interface function: get_godot_version`), which is
  a property of that build rather than of this library; the addon fell back
  cleanly there too. Use an official build if you need the extension.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `VFXStreaks.is_available()` is `false` | Library not built, or `addons/vfx_2d/vfx_streaks.gdextension` missing |
| Godot prints "Can't open dynamic library" | Built for a different platform, arch or engine version |
| `compatibility_minimum` mismatch | Engine older than the targeted API; rebuild with `--api 4.6` |
| `non-existent interface function: get_godot_version` | godot-cpp and engine interfaces disagree — rebuild with `--godot <that engine>`, or the engine was built without a matching GDExtension interface |
| Nothing visible, no errors | `additive = true` on a light background, or `tail_color` alpha not `0` |
| `godot --headless --path . --import` segfaults (exit 134) *after* importing | Engine bug in 4.7.2: the `--import` teardown crashes as soon as any extension class is registered. The import and `.godot/global_script_class_cache.cfg` are already written, and a normal editor quit is unaffected — treat the exit code as harmless in scripts |
