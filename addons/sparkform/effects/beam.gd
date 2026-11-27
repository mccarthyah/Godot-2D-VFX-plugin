class_name BeamEffect
extends Node2D
## Persistent beam: core line, glow, travelling pulses and flaring ends. For
## sustained fire, grapple lines, tractor beams and charge links.
##
## [codeblock]
## var beam := Sparkform.beam(from, to, {"width": 8.0})
## beam.end_at(other.global_position)   # follow a target each frame
## beam.stop()                          # fades out, then frees itself
## [/codeblock]

signal finished

## Endpoint relative to this node's position. Set by [code]Sparkform.beam()[/code].
@export var end_offset: Vector2 = Vector2(320.0, 0.0)
@export_group("Beam")
## Core line width in pixels.
@export_range(1.0, 64.0, 0.5, "suffix:px") var width: float = 6.0
## Soft glow width around the core.
@export_range(1.0, 128.0, 0.5, "suffix:px") var glow_width: float = 20.0
## Travel speed of the pulses in px/s.
@export_range(0.0, 4000.0, 10.0, "suffix:px/s") var pulse_speed: float = 900.0
## Distance between pulses in pixels.
@export_range(16.0, 1024.0, 1.0, "suffix:px") var pulse_spacing: float = 120.0
## Side-to-side jitter of the core line.
@export_range(0.0, 1.0, 0.01) var wobble: float = 0.35

@export_group("Timing")
## Seconds to open from nothing to full width.
@export_range(0.0, 2.0, 0.01, "suffix:s") var warmup: float = 0.12
## Seconds to fade out after stop().
@export_range(0.05, 2.0, 0.01, "suffix:s") var fade_time: float = 0.22
## Close on its own after this many seconds; [code]0[/code] holds until stopped.
@export_range(0.0, 120.0, 0.1, "suffix:s") var lifetime: float = 0.0

@export_group("Colors")
## Colour of the core line.
@export var core_color: Color = Color(1.0, 0.98, 0.9)
## Colour of the surrounding glow.
@export var glow_color: Color = Color(0.55, 0.8, 1.0)
## Colour of the travelling pulses.
@export var pulse_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Chaos")
## Jitter along the beam and pulse spacing variance.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.45
## Free the node once it has faded out.
@export var free_on_finish: bool = true

var _openness: float = 0.0
var _closing: bool = false
var _elapsed: float = 0.0
var _held: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)
	_rng.randomize()


## Points the beam at a new endpoint (local space).
func end_at(endpoint: Vector2) -> void:
	end_offset = endpoint
	queue_redraw()


## Starts the beam. Called by [code]Sparkform.beam()[/code].
func start() -> void:
	_elapsed = 0.0
	_held = 0.0
	_closing = false
	_openness = 0.0
	visible = true
	set_process(true)
	queue_redraw()


## Fades the beam out and frees it when [member free_on_finish] is set.
func stop() -> void:
	if _closing:
		return
	_closing = true
	set_process(true)


## Current opening amount, [code]0.0[/code] to [code]1.0[/code].
func get_openness() -> float:
	return _openness


func _process(delta: float) -> void:
	_elapsed += delta
	if _closing:
		_openness = maxf(0.0, _openness - delta / maxf(fade_time, 0.01))
		if _openness <= 0.0:
			_finish()
			return
	else:
		_openness = minf(1.0, _openness + delta / maxf(warmup, 0.001))
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


func _draw() -> void:
	if _openness <= 0.001:
		return
	var direction: Vector2 = end_offset
	var length: float = direction.length()
	if length < 1.0:
		return
	var unit: Vector2 = direction / length
	var normal := Vector2(-unit.y, unit.x)
	var points := PackedVector2Array()
	var steps: int = 24
	points.resize(steps + 1)
	var amplitude: float = width * wobble * chaos
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var offset: float = 0.0
		if i > 0 and i < steps:
			offset = sin(t * PI) * sin(_elapsed * 22.0 + t * 9.0) * amplitude
		points[i] = unit * (length * t) + normal * offset
	var fade: float = _openness
	draw_polyline(points, Color(glow_color, 0.18 * fade), glow_width * _openness, true)
	draw_polyline(points, Color(glow_color, 0.45 * fade), width * 2.2, true)
	draw_polyline(points, Color(core_color, 0.95 * fade), width, true)
	_draw_pulses(unit, length, fade)
	_draw_flares(unit, length, fade, normal)


func _draw_pulses(unit: Vector2, length: float, fade: float) -> void:
	var spacing: float = maxf(pulse_spacing, 16.0)
	var travel: float = fmod(_elapsed * pulse_speed, spacing)
	var pulse_length: float = width * 3.0
	var position: float = travel
	while position < length:
		var start: float = maxf(position - pulse_length, 0.0)
		draw_line(unit * start, unit * position, Color(pulse_color, 0.75 * fade),
				maxf(1.0, width * 0.9), true)
		position += spacing
	# A short flare at the muzzle keeps the source readable.
	draw_circle(Vector2.ZERO, width * 2.4 * fade, Color(pulse_color, 0.35 * fade))


func _draw_flares(unit: Vector2, length: float, fade: float, normal: Vector2) -> void:
	var tip: Vector2 = unit * length
	draw_circle(Vector2.ZERO, width * 1.8, Color(core_color, 0.9 * fade))
	draw_circle(tip, width * 3.0, Color(glow_color, 0.5 * fade))
	draw_circle(tip, width * 1.2, Color(core_color, 0.95 * fade))
	for i in range(3):
		var angle: float = _elapsed * 6.0 + TAU * float(i) / 3.0
		var ray: Vector2 = unit.rotated(angle) * width * 4.0 * fade
		draw_line(tip, tip + ray, Color(pulse_color, 0.35 * fade), 1.5, true)
	if normal.length_squared() > 0.5:
		draw_circle(Vector2.ZERO, width * 1.2, Color(core_color, 0.7 * fade))
