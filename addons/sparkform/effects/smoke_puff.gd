class_name SmokePuffEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Soft smoke or dust cloud: overlapping blobs that billow, drift upward and
## dissipate. Good for landings, footsteps, dashes and anything that needs weight
## without light.
##
## Spawn it with [code]Sparkform.smoke_puff(position, {"radius": 80.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Puff")
## Overall cloud size in pixels.
@export_range(8.0, 512.0, 1.0, "suffix:px") var radius: float = 54.0
## Overlapping smoke blobs.
@export_range(3, 32, 1) var puff_count: int = 9
## Blob centre tint.
@export var inner_color: Color = Color(0.74, 0.77, 0.82, 0.55)
## Edge tint as the smoke drifts.
@export var outer_color: Color = Color(0.33, 0.36, 0.43, 0.0)
## How far the cloud drifts up, as a fraction of [member radius].
@export_range(0.0, 2.0, 0.01) var rise: float = 0.55
## Sideways swirl, in units of one puff radius.
@export_range(0.0, 2.0, 0.01) var turbulence: float = 0.7
## How much the cloud keeps growing while it fades.
@export_range(0.0, 4.0, 0.05) var grow: float = 1.5
## Outline irregularity: [code]0[/code] draws clean discs, [code]1[/code] torn ones.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.65

var _rng := RandomNumberGenerator.new()
var _puffs: Array[Dictionary] = []
var _progress: float = 0.0


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_puffs.clear()
	var count: int = maxi(puff_count, 1)
	for i in range(count):
		var angle: float = _rng.randf_range(-PI, PI)
		var distance: float = _rng.randf_range(0.0, 0.55) * radius
		var shape := PackedFloat32Array()
		var points: int = 18
		for point in range(points):
			shape.append(_rng.randf_range(0.72, 1.3))
		_puffs.append({
			"offset": Vector2(cos(angle), sin(angle)) * distance,
			"size": radius * _rng.randf_range(0.32, 0.8),
			"phase": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(0.4, 1.3),
			"rise": _rng.randf_range(0.6, 1.4),
			"drift": Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.2, 0.2)),
			"shape": shape,
			"points": points,
		})


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0


func _draw() -> void:
	if _progress >= 1.0 or _puffs.is_empty():
		return
	for puff in _puffs:
		var t: float = clampf(_progress * 1.1, 0.0, 1.0)
		var phase: float = float(puff["phase"])
		var spin: float = float(puff["spin"])
		var point_count: int = int(puff["points"])
		var shape: PackedFloat32Array = puff["shape"]
		var center: Vector2 = puff["offset"] as Vector2
		center += Vector2(0.0, -rise * radius * t * float(puff["rise"]))
		center += (puff["drift"] as Vector2) * radius * t * 0.5
		var swirl: float = turbulence * radius * 0.16 * t
		center += Vector2(sin(t * 2.6 + phase + spin), cos(t * 2.1 + phase * 1.7)) * swirl
		var puff_radius: float = float(puff["size"]) * (1.0 + grow * t)
		var fade: float = pow(1.0 - t, 1.5)
		if fade <= 0.01:
			continue
		var color: Color = inner_color.lerp(outer_color, t)
		color.a *= fade
		var outline := PackedVector2Array()
		outline.resize(point_count)
		var wobble: float = chaos * 0.45
		for i in range(point_count):
			var angle: float = TAU * float(i) / float(point_count)
			var reach: float = puff_radius * float(shape[i])
			reach *= 1.0 + wobble * 0.25 * sin(angle * 3.0 + phase + t * 4.0 * spin)
			outline[i] = center + Vector2(cos(angle), sin(angle)) * maxf(reach, 0.5)
		draw_colored_polygon(outline, color)
	# Flash of displaced dust right at the start.
	var flash: float = pow(1.0 - clampf(_progress / 0.22, 0.0, 1.0), 2.0)
	if flash > 0.01:
		draw_circle(Vector2.ZERO, radius * (0.25 + 0.25 * (1.0 - flash)),
				Color(inner_color, inner_color.a * 0.5 * flash))


## Number of blobs currently alive; exposed for tests.
func get_puff_count() -> int:
	return _puffs.size()
