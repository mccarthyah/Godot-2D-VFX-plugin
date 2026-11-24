class_name HealSparkleEffect
extends "res://addons/vfx_2d/core/vfx_effect.gd"
## Ascending sparkles for pickups, heals, buffs and level-ups: motes drift up and
## outward, twinkle, and fade into a soft glow.
##
## Spawn it with
## [code]VFX2D.heal_sparkle(player.global_position, {"radius": 56.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Sparkles")
## Radius the motes spawn within, in pixels.
@export_range(2.0, 512.0, 1.0, "suffix:px") var radius: float = 46.0
@export_range(1, 96, 1) var mote_count: int = 20
## How far motes rise over their lifetime, in pixels.
@export_range(0.0, 512.0, 1.0, "suffix:px") var rise: float = 76.0
@export var sparkle_color: Color = Color(0.52, 1.0, 0.72)
@export var glow_color: Color = Color(0.16, 0.55, 0.32)
@export_range(0.0, 1.0, 0.01) var twinkle: float = 0.85

@export_group("Stars")
## Larger accent stars layered over the motes.
@export_range(0, 8, 1) var star_count: int = 2

@export_group("Chaos")
## Spread irregularity: [code]0[/code] keeps motes on tidy orbits,
## [code]1[/code] scatters and jitters them.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.55

var _rng := RandomNumberGenerator.new()
var _motes: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _progress: float = 0.0
var _clock: float = 0.0


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_clock = 0.0
	_motes.clear()
	_stars.clear()
	for i in range(maxi(mote_count, 1)):
		var angle: float = _rng.randf_range(-PI, PI)
		_motes.append({
			"angle": angle,
			"distance": _rng.randf_range(0.15, 1.0) * radius,
			"size": _rng.randf_range(1.2, 3.4) * (1.0 + chaos),
			"phase": _rng.randf_range(0.0, TAU),
			"rise": _rng.randf_range(0.55, 1.45),
			"delay": _rng.randf_range(0.0, 0.35),
			"swirl": _rng.randf_range(-1.6, 1.6) * (0.35 + chaos),
		})
	for i in range(maxi(star_count, 0)):
		_stars.append({
			"offset": Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.5, 0.3)) * radius,
			"size": radius * _rng.randf_range(0.18, 0.34),
			"rotation": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-1.2, 1.2),
			"delay": _rng.randf_range(0.0, 0.3),
			"outline": PackedVector2Array(),
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	_clock += delta


func _on_stop() -> void:
	_progress = 1.0


## Number of live motes; exposed for tests.
func get_mote_count() -> int:
	return _motes.size()


func _draw() -> void:
	if _progress >= 1.0 or _motes.is_empty():
		return
	_draw_glow()
	_draw_motes()
	_draw_stars()


func _draw_glow() -> void:
	var fade: float = sin(PI * clampf(_progress, 0.0, 1.0))
	if fade <= 0.01:
		return
	var pulse: float = 1.0 + 0.12 * sin(_clock * 9.0)
	draw_circle(Vector2.ZERO, radius * 0.85 * pulse, Color(glow_color, 0.16 * fade))
	draw_circle(Vector2.ZERO, radius * 0.45 * pulse, Color(sparkle_color, 0.1 * fade))


func _draw_motes() -> void:
	for mote in _motes:
		var delay: float = float(mote["delay"])
		var local: float = clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var angle: float = float(mote["angle"]) + float(mote["swirl"]) * local
		var center: Vector2 = Vector2(cos(angle), sin(angle)) * float(mote["distance"])
		center.y -= rise * float(mote["rise"]) * local
		center += Vector2(sin(_clock * 5.0 + float(mote["phase"])),
				cos(_clock * 4.0 + float(mote["phase"]))) * chaos * 5.0
		var envelope: float = sin(PI * local)
		var flicker: float = 1.0 - twinkle * 0.5 * (0.5 + 0.5 * sin(_clock * 14.0 + float(mote["phase"])))
		var alpha: float = envelope * flicker
		var size: float = float(mote["size"]) * (0.6 + envelope * 0.8)
		var color := Color(sparkle_color, alpha)
		draw_line(center - Vector2(size * 2.0, 0.0), center + Vector2(size * 2.0, 0.0),
				color, maxf(1.0, size * 0.55), true)
		draw_line(center - Vector2(0.0, size * 2.0), center + Vector2(0.0, size * 2.0),
				color, maxf(1.0, size * 0.55), true)
		draw_circle(center, size * 0.7, Color(Color.WHITE, alpha * 0.8))


func _draw_stars() -> void:
	for star in _stars:
		var delay: float = float(star["delay"])
		var local: float = clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var envelope: float = sin(PI * local)
		var size: float = float(star["size"]) * (0.5 + envelope * 0.9)
		var outline: PackedVector2Array = star["outline"]
		if outline.is_empty():
			outline = VFXShapes.star_burst(size * 0.3, size, 4,
					float(star["rotation"]) + float(star["spin"]) * _clock, _rng)
		var shifted := PackedVector2Array()
		shifted.resize(outline.size())
		var anchor: Vector2 = star["offset"] as Vector2 + Vector2(0.0, -rise * 0.35 * local)
		for i in range(outline.size()):
			shifted[i] = anchor + outline[i]
		draw_colored_polygon(shifted, Color(sparkle_color.lightened(0.35), 0.55 * envelope))
