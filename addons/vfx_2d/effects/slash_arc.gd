class_name SlashArcEffect
extends VFXEffect
## Melee crescent: a tapered arc that sweeps through its angle, shedding sparkles
## along the cut. Use it for sword swings, claws and parries.
##
## Spawn it with
## [code]VFX2D.slash_arc(at, aim_direction, {"radius": 96.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Arc")
## Centre of the swing, in this node's local space. The convenience method sets it.
@export var direction: Vector2 = Vector2.RIGHT
@export_range(8.0, 512.0, 1.0, "suffix:px") var radius: float = 82.0
@export_range(10.0, 270.0, 1.0, "suffix:deg") var arc_degrees: float = 120.0
@export_range(1.0, 64.0, 0.5, "suffix:px") var thickness: float = 10.0
## Fraction of the arc that is visible as a crescent at any moment.
@export_range(0.15, 1.0, 0.01) var trail: float = 0.45
## Fraction of [member duration] the blade takes to complete the swing.
@export_range(0.1, 1.0, 0.01) var sweep: float = 0.45
@export var core_color: Color = Color(1.0, 1.0, 1.0)
@export var edge_color: Color = Color(0.62, 0.86, 1.0)
@export_range(0, 64, 1) var sparkle_count: int = 10

@export_group("Chaos")
## Edge tearing and sparkle scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.55

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _band: PackedVector2Array = PackedVector2Array()
var _sparkles: Array[Dictionary] = []


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_band.clear()
	_sparkles.clear()
	for i in range(maxi(sparkle_count, 0)):
		_sparkles.append({
			"offset": _rng.randf_range(-0.12, 0.12),
			"angle_jitter": _rng.randf_range(-1.0, 1.0),
			"size": _rng.randf_range(1.5, 4.0),
			"phase": _rng.randf_range(0.0, TAU),
		})


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0


## Visible crescent outline, in local space. Exposed for tests.
func get_band_points() -> PackedVector2Array:
	return _band


func _draw() -> void:
	if _progress >= 1.0:
		return
	var trail_fraction: float = clampf(trail, 0.05, 1.0)
	var sweep_t: float = clampf(_progress / maxf(sweep, 0.05), 0.0, 1.0)
	var arc: float = deg_to_rad(arc_degrees)
	var center_angle: float = direction.angle() if direction.length_squared() > 0.0001 else 0.0
	var span_total: float = arc * trail_fraction
	var lead: float = center_angle - arc * 0.5 + arc * sweep_t
	var tail: float = lead - span_total
	if lead - tail <= 0.001:
		return
	# The blade fades once the swing is done, not while it is travelling.
	var fade: float = 1.0 - smoothstep(0.75, 1.0, _progress)
	if fade <= 0.01:
		return
	_band = _build_band(tail, lead, 18)
	draw_colored_polygon(_band, Color(edge_color, 0.35 * fade))
	var inner: PackedVector2Array = _build_band(tail, lead, 18, thickness * 0.45)
	draw_colored_polygon(inner, Color(core_color, 0.9 * fade))
	_draw_sparkles(lead, fade)


func _build_band(from_angle: float, to_angle: float, steps: int,
		band_width: float = -1.0) -> PackedVector2Array:
	var width: float = thickness if band_width < 0.0 else band_width
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var count: int = maxi(steps, 3)
	outer.resize(count + 1)
	inner.resize(count + 1)
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var angle: float = lerpf(from_angle, to_angle, t)
		# Taper to nothing at both ends, with a little tearing from chaos.
		var taper: float = pow(sin(PI * clampf(t, 0.0, 1.0)), 0.55)
		var tear: float = 1.0 + chaos * 0.6 * _rng.randf_range(-1.0, 1.0)
		var half_width: float = maxf(width * taper * tear, 0.0) * 0.5
		var unit := Vector2(cos(angle), sin(angle))
		outer[i] = unit * (radius + half_width)
		inner[i] = unit * (radius - half_width)
	# Outer edge forward, inner edge back: one closed ribbon.
	var band := PackedVector2Array()
	band.append_array(outer)
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	return band


func _draw_sparkles(lead: float, fade: float) -> void:
	for sparkle in _sparkles:
		var angle: float = lead + float(sparkle["angle_jitter"]) * 0.16 * chaos
		var distance: float = radius + float(sparkle["offset"]) * radius
		var center: Vector2 = Vector2(cos(angle), sin(angle)) * distance
		var flicker: float = 0.5 + 0.5 * sin(float(sparkle["phase"]) + _progress * 18.0)
		var size: float = float(sparkle["size"]) * (0.6 + flicker * 0.8)
		var color := Color(core_color, 0.7 * fade * flicker)
		draw_line(center - Vector2(size * 2.0, 0.0), center + Vector2(size * 2.0, 0.0),
				color, maxf(1.0, size * 0.5), true)
		draw_line(center - Vector2(0.0, size * 2.0), center + Vector2(0.0, size * 2.0),
				color, maxf(1.0, size * 0.5), true)
