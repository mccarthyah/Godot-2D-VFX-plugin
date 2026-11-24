class_name ShockwaveEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Bare impact wave: irregular rings rushing outward with radial cracks and a
## short core flash. No fire or debris, so it layers cleanly under projectiles,
## heavy landings and parries.
##
## Spawn it with [code]Sparkform.shockwave(position, {"radius": 140.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Wave")
## Radius the outermost ring reaches, in pixels.
@export_range(4.0, 1024.0, 1.0, "suffix:px") var radius: float = 96.0
## Multiplier on [member radius] at full expansion.
@export_range(1.0, 6.0, 0.05) var expansion: float = 3.2
@export_range(1, 4, 1) var rings: int = 2
@export_range(1.0, 64.0, 0.5, "suffix:px") var ring_width: float = 6.0
@export var ring_color: Color = Color(0.82, 0.94, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Cracks")
@export_range(0, 32, 1) var cracks: int = 12
@export_range(0.0, 1.0, 0.01) var crack_length: float = 0.35

@export_group("Chaos")
## Outline irregularity: [code]0[/code] is a clean circle, [code]1[/code] a torn
## shock front.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.6

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _crack_angles: PackedFloat32Array = PackedFloat32Array()
var _crack_lengths: PackedFloat32Array = PackedFloat32Array()


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_crack_angles.clear()
	_crack_lengths.clear()
	for i in range(maxi(cracks, 0)):
		_crack_angles.append(_rng.randf_range(-PI, PI))
		_crack_lengths.append(_rng.randf_range(0.55, 1.35))


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0


## Ring vertex count for the current frame; exposed for tests.
func get_ring_point_count() -> int:
	return 64


func _draw() -> void:
	if _progress >= 1.0:
		return
	_draw_cracks()
	var ring_total: int = maxi(rings, 1)
	for index in range(ring_total):
		var delay: float = 0.1 * float(index)
		var local: float = clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if local <= 0.0:
			continue
		var eased: float = 1.0 - pow(1.0 - local, 2.6)
		var fade: float = pow(1.0 - local, 1.5)
		if fade <= 0.01:
			continue
		var ring_radius: float = radius * lerpf(0.12, expansion, eased)
		ring_radius *= 1.0 - 0.07 * float(index)
		var wobble: float = chaos * 0.22 * (0.35 + 0.65 * (1.0 - eased))
		var outline: PackedVector2Array = VFXShapes.irregular_ring(ring_radius, wobble, 64,
				local * TAU * 0.4 + float(index), _rng)
		outline.append(outline[0])
		var color := Color(ring_color, ring_color.a * fade * (0.9 - 0.25 * float(index)))
		var width: float = maxf(1.0, ring_width * (1.0 - eased * 0.75))
		draw_polyline(outline, color, width, true)
	_draw_core()


func _draw_cracks() -> void:
	var local: float = clampf(_progress / 0.45, 0.0, 1.0)
	if local >= 1.0 or _crack_angles.is_empty():
		return
	var fade: float = pow(1.0 - local, 1.8)
	var inner: float = radius * lerpf(0.18, 0.6, 1.0 - pow(1.0 - local, 2.0)) * expansion * 0.35
	for i in range(_crack_angles.size()):
		var angle: float = _crack_angles[i]
		var unit := Vector2(cos(angle), sin(angle))
		var reach: float = inner + radius * crack_length * float(_crack_lengths[i]) * chaos + \
				radius * 0.25 * (1.0 - local)
		draw_line(unit * inner, unit * reach, Color(ring_color, 0.45 * fade), 1.5, true)


func _draw_core() -> void:
	var local: float = clampf(_progress / 0.3, 0.0, 1.0)
	if local >= 1.0:
		return
	var fade: float = pow(1.0 - local, 2.0)
	var core_radius: float = radius * (0.18 + 0.30 * local)
	draw_circle(Vector2.ZERO, core_radius, Color(ring_color, 0.18 * fade))
	draw_circle(Vector2.ZERO, core_radius * 0.55, Color(core_color, 0.75 * fade))
