class_name PortalEffect
extends Node2D
## Persistent gateway: an oval portal that opens, swirls while it is held, and
## closes when you stop it. Spawn pads, teleports, summoning.
##
## [codeblock]
## var gate := Sparkform.portal(at, {"width": 70.0, "height": 96.0})
## gate.stop()   # plays the closing animation, then frees itself
## [/codeblock]

signal finished

@export_group("Shape")
## Portal width in pixels.
@export_range(8.0, 512.0, 1.0, "suffix:px") var width: float = 58.0
## Portal height in pixels.
@export_range(8.0, 512.0, 1.0, "suffix:px") var height: float = 78.0
## Thickness of the rim in pixels.
@export_range(1.0, 32.0, 0.5, "suffix:px") var rim_width: float = 4.0
## Rim rotation in rad/s.
@export_range(-8.0, 8.0, 0.05, "suffix:rad/s") var spin_speed: float = 1.8
## Shimmer motes inside the portal.
@export_range(0, 48, 1) var shimmer_count: int = 14

@export_group("Timing")
## Seconds to open.
@export_range(0.01, 5.0, 0.01, "suffix:s") var open_time: float = 0.3
## Seconds to close after stop().
@export_range(0.01, 5.0, 0.01, "suffix:s") var close_time: float = 0.35
## Close on its own after this many seconds; [code]0[/code] holds until stopped.
@export_range(0.0, 120.0, 0.1, "suffix:s") var lifetime: float = 0.0

@export_group("Colors")
## Rim tint.
@export var rim_color: Color = Color(0.62, 0.55, 1.0)
## Interior tint.
@export var core_color: Color = Color(0.18, 0.12, 0.42)
## Shimmer mote tint.
@export var shimmer_color: Color = Color(0.85, 0.8, 1.0)

@export_group("Chaos")
## Rim waver and shimmer scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.45
## Free the node once it has closed.
@export var free_on_finish: bool = true

var _openness: float = 0.0
var _closing: bool = false
var _elapsed: float = 0.0
var _held: float = 0.0
var _rng := RandomNumberGenerator.new()
var _shimmer: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)
	_rng.randomize()
	_build_shimmer()
	queue_redraw()


## Opens the portal. Called by [code]Sparkform.portal()[/code].
func start() -> void:
	_elapsed = 0.0
	_held = 0.0
	_closing = false
	visible = true
	set_process(true)
	queue_redraw()


## Plays the closing animation; the node frees itself when
## [member free_on_finish] is set.
func stop() -> void:
	if _closing:
		return
	_closing = true
	set_process(true)


## Returns the opening amount, [code]0.0[/code] closed to [code]1.0[/code] open.
func get_openness() -> float:
	return _openness


func _build_shimmer() -> void:
	_shimmer.clear()
	for i in range(maxi(shimmer_count, 0)):
		_shimmer.append({
			"angle": _rng.randf_range(0.0, TAU),
			"phase": _rng.randf_range(0.0, 1.0),
			"speed": _rng.randf_range(0.6, 1.7),
			"length": _rng.randf_range(0.12, 0.3),
		})


func _process(delta: float) -> void:
	_elapsed += delta
	if _closing:
		_openness = maxf(0.0, _openness - delta / maxf(close_time, 0.01))
		if _openness <= 0.0:
			_finish()
			return
	else:
		_openness = minf(1.0, _openness + delta / maxf(open_time, 0.01))
		if _openness >= 1.0 and lifetime > 0.0:
			_held += delta
			if _held >= lifetime:
				stop()
	queue_redraw()


func _finish() -> void:
	set_process(false)
	finished.emit()
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


func _ellipse(fraction: float, wobble: float, points: int, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = maxi(points, 8)
	out.resize(count)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var waver: float = 1.0 + wobble * sin(angle * 3.0 + phase) \
				+ wobble * 0.4 * sin(angle * 7.0 - phase * 1.6)
		var reach: float = fraction * waver
		out[i] = Vector2(cos(angle) * width * 0.5 * reach, sin(angle) * height * 0.5 * reach)
	return out


func _draw() -> void:
	if _openness <= 0.001:
		return
	var scale_amount: float = _openness
	var spin: float = _elapsed * spin_speed
	var wobble: float = chaos * 0.12
	# Surface first, so the rims read as edges rather than outline.
	draw_colored_polygon(_ellipse(scale_amount * 0.92, wobble, 40, spin),
			Color(core_color, 0.85 * _openness))
	var outer: PackedVector2Array = _ellipse(scale_amount, wobble, 48, -spin * 0.6)
	outer.append(outer[0])
	draw_polyline(outer, Color(rim_color, 0.9 * _openness), maxf(1.0, rim_width), true)
	var inner: PackedVector2Array = _ellipse(scale_amount * 0.78, wobble * 1.6, 40, spin * 1.4)
	inner.append(inner[0])
	draw_polyline(inner, Color(rim_color, 0.45 * _openness), maxf(1.0, rim_width * 0.6), true)
	_draw_shimmer(scale_amount, spin)


func _draw_shimmer(scale_amount: float, spin: float) -> void:
	for shimmer in _shimmer:
		var angle: float = float(shimmer["angle"]) + spin * float(shimmer["speed"]) * 0.5
		var phase: float = float(shimmer["phase"])
		var cycle: float = fmod(_elapsed * float(shimmer["speed"]) * 0.8 + phase, 1.0)
		var outer_distance: float = 0.95 - cycle * 0.35
		var inner_distance: float = outer_distance - float(shimmer["length"])
		var outer_point := Vector2(cos(angle) * width * 0.5 * outer_distance,
				sin(angle) * height * 0.5 * outer_distance) * scale_amount
		var inner_point := Vector2(cos(angle) * width * 0.5 * maxf(inner_distance, 0.05),
				sin(angle) * height * 0.5 * maxf(inner_distance, 0.05)) * scale_amount
		var fade: float = sin(PI * cycle) * _openness
		draw_line(inner_point, outer_point, Color(shimmer_color, 0.55 * fade), 1.5, true)
