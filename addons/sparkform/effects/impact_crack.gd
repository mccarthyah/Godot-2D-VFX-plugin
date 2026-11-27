class_name ImpactCrackEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Ground-aligned slam: jagged cracks race outward along the surface, dust puffs
## up between them and a flat flash marks the hit. Rotate it to the surface
## normal so it lies on the floor instead of floating.
##
## Spawn it with [code]Sparkform.impact_crack(at, {"radius": 140.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Cracks")
## How far the cracks reach.
@export_range(16.0, 900.0, 1.0, "suffix:px") var radius: float = 150.0
## Cracks radiating from the hit.
@export_range(2, 24, 1) var crack_count: int = 9
## kinks per crack; more segments read as rougher ground.
@export_range(2, 16, 1) var segment_count: int = 6
## Crack line width.
@export_range(0.5, 12.0, 0.5, "suffix:px") var crack_width: float = 3.5
## How much the crack path wanders as it runs out.
@export_range(0.0, 1.0, 0.01) var wander: float = 0.45
## Surface direction: the cracks spread around this axis (up is a ceiling hit).
@export var surface: Vector2 = Vector2.RIGHT

@export_group("Dust")
## Dust puffs thrown up by the impact.
@export_range(0, 32, 1) var dust_count: int = 8
## How far the dust climbs, in pixels.
@export_range(0.0, 260.0, 5.0, "suffix:px") var dust_rise: float = 70.0
## Dust tint.
@export var dust_color: Color = Color(0.42, 0.4, 0.38)
## Crack tint.
@export var crack_color: Color = Color(0.15, 0.13, 0.12)
## Tint of the flat flash.
@export var flash_color: Color = Color(1.0, 0.86, 0.55)

@export_group("Chaos")
## Crack paths, branch kinks, dust scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.5

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _cracks: Array[PackedVector2Array] = []
var _dust: Array[Dictionary] = []


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_cracks.clear()
	_dust.clear()
	var axis: Vector2 = surface.normalized()
	if axis.length_squared() < 0.0001:
		axis = Vector2.RIGHT
	var base_angle: float = axis.angle()
	for i in range(maxi(crack_count, 2)):
		var spread: float = lerpf(-PI * 0.5, PI * 0.5, float(i) / float(maxi(crack_count - 1, 1)))
		var angle: float = base_angle + spread + _rng.randf_range(-0.18, 0.18) * chaos
		_cracks.append(_build_crack(angle))
	for i in range(maxi(dust_count, 0)):
		var offset: Vector2 = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3))
		_dust.append({
			"origin": offset * radius * 0.55,
			"delay": _rng.randf_range(0.0, 0.25),
			"size": _rng.randf_range(4.0, 11.0),
			"drift": Vector2(_rng.randf_range(-20.0, 20.0), -dust_rise * _rng.randf_range(0.5, 1.3)),
		})


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0


## Number of crack lines; exposed for tests.
func get_crack_count() -> int:
	return _cracks.size()


## Points of the first crack; exposed for tests.
func get_first_crack() -> PackedVector2Array:
	return _cracks[0] if not _cracks.is_empty() else PackedVector2Array()


func _build_crack(angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps: int = maxi(segment_count, 2)
	out.append(Vector2.ZERO)
	var position := Vector2.ZERO
	var heading: float = angle
	for i in range(steps):
		var step_length: float = radius / float(steps) * _rng.randf_range(0.7, 1.3)
		heading += _rng.randf_range(-wander, wander) * (0.4 + chaos * 0.8) * 0.5
		position += Vector2(cos(heading), sin(heading)) * step_length
		out.append(position)
		# Occasional short offshoot: ground cracks are never a clean fan.
		if i == steps - 2 and chaos > 0.2:
			var offshoot_angle: float = heading + _rng.randf_range(-1.0, 1.0)
			out.append(position + Vector2(cos(offshoot_angle), sin(offshoot_angle))
					* step_length * 0.5)
			out.append(position)
	return out


func _draw() -> void:
	if _progress >= 1.0:
		return
	var fade: float = 1.0 - smoothstep(0.7, 1.0, _progress)
	if fade <= 0.01:
		return
	_draw_flash(fade)
	var reveal: float = clampf(_progress / 0.35, 0.0, 1.0)
	var grow: float = 0.25 + 0.75 * pow(reveal, 0.7)
	for crack in _cracks:
		var shown := PackedVector2Array()
		for i in range(crack.size()):
			shown.append(crack[i] * grow)
		draw_polyline(shown, Color(crack_color, 0.85 * fade), crack_width + 1.5, true)
		draw_polyline(shown, Color(flash_color, 0.28 * fade * (1.0 - reveal)),
				maxf(1.0, crack_width * 0.5), true)
	_draw_dust(fade)


func _draw_flash(fade: float) -> void:
	var local: float = clampf(_progress / 0.4, 0.0, 1.0)
	if local >= 1.0:
		return
	var squash := Vector2(1.0, 0.42)
	for i in range(3):
		var ring_radius: float = radius * (0.25 + local * 0.55) * (1.0 + float(i) * 0.18)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40,
				Color(flash_color, 0.22 * (1.0 - local) * fade), 2.0, true)
	if fade > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.12 * (1.0 - local),
				Color(flash_color, 0.45 * (1.0 - local)))
	if squash.y <= 0.0:
		return


func _draw_dust(fade: float) -> void:
	for puff in _dust:
		var local: float = clampf((_progress - float(puff["delay"])) / 0.5, 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var center: Vector2 = Vector2(puff["origin"]) + Vector2(puff["drift"]) * local
		var size: float = float(puff["size"]) * (0.6 + local * 0.9)
		draw_circle(center, size, Color(dust_color, 0.3 * (1.0 - local) * fade))
		draw_circle(center, size * 0.6, Color(dust_color, 0.22 * (1.0 - local) * fade))
