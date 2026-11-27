@tool
class_name CooldownRing
extends Node2D
## Radial cooldown indicator drawn as an arc around a node.
##
## Unlike the other effects this node is a modifier, not a one-shot: add it as a
## child of whatever it should circle (an ability icon, a turret, a unit) and
## call [method start]. It works in two directions:
## [codeblock]
## # fills up over 2.5 seconds (charge bar)
## var ring := Sparkform.cooldown_ring(icon, 2.5)
##
## # drains from full (classic cooldown)
## Sparkform.cooldown_ring(icon, 2.5, {"reverse": true})
## [/codeblock]
##
## The ring previews in the editor: tweak [member progress] to see the arc.

## Emitted once the ring reaches the end of its duration.
signal completed

@export_group("Shape")
## Ring radius in pixels.
@export_range(4.0, 512.0, 1.0, "suffix:px") var radius: float = 42.0
## Arc thickness in pixels.
@export_range(0.5, 64.0, 0.5, "suffix:px") var width: float = 8.0
## Where the arc starts, in radians. The default starts at 12 o'clock.
@export_range(-6.2832, 6.2832, 0.01, "suffix:rad") var start_angle: float = -1.5708
## Draw the filled arc clockwise instead of counter-clockwise.
@export var clockwise: bool = true
## Tick marks around the ring; 0 draws none.
@export_range(0, 64, 1) var tick_count: int = 0
## Tick mark tint.
@export var tick_color: Color = Color(1.0, 1.0, 1.0, 0.35)

@export_group("Colors")
## Colour of the filling arc.
@export var fill_color: Color = Color(0.42, 0.9, 1.0)
## Colour of the unfilled track.
@export var track_color: Color = Color(0.06, 0.09, 0.14, 0.6)
## Draw the full track behind the fill.
@export var show_track: bool = true

@export_group("Timing")
## Seconds for a full sweep.
@export_range(0.01, 60.0, 0.01, "suffix:s") var duration: float = 1.0
## Start at full and drain to empty instead of filling up.
@export var reverse: bool = false
## Free the node once the cooldown completes. Disable it if you want to reuse
## the same ring for several cooldowns.
@export var free_on_complete: bool = true

@export_group("Chaos")
## Hand-drawn irregularity: the arc and ticks wobble slightly and a soft glow
## pulses. Kept low by default because a cooldown must stay readable.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.25
## Draw a soft glow under the arc.
@export var glow: bool = true

## Normalized fill, [code]0.0[/code] to [code]1.0[/code]. Assigning it updates
## the drawing immediately, so you can also drive the ring manually.
var progress: float = 0.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(progress, clamped):
			return
		progress = clamped
		queue_redraw()

var _running: bool = false
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tick_jitter: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_seed_chaos()
	queue_redraw()


## Starts the cooldown. [param seconds] overrides [member duration] when it is
## greater than zero.
func start(seconds: float = -1.0) -> void:
	if seconds > 0.0:
		duration = seconds
	_elapsed = 0.0
	_seed_chaos()
	_running = true
	visible = true
	progress = 1.0 if reverse else 0.0
	set_process(true)
	queue_redraw()


## Stops the cooldown without emitting [signal completed] and clears the arc.
func cancel() -> void:
	_running = false
	set_process(false)
	progress = 0.0


## Returns [code]true[/code] while the cooldown is running.
func is_running() -> bool:
	return _running


## Seconds left before the cooldown completes.
func get_remaining() -> float:
	if not _running:
		return 0.0
	return maxf(duration - _elapsed, 0.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var ratio: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	progress = 1.0 - ratio if reverse else ratio
	if ratio >= 1.0:
		_finish()


func _finish() -> void:
	_running = false
	set_process(false)
	completed.emit()
	if free_on_complete and not Engine.is_editor_hint():
		queue_free()


func _seed_chaos() -> void:
	_rng.randomize()
	_tick_jitter.clear()
	for i in range(maxi(tick_count, 0)):
		_tick_jitter.append(_rng.randf_range(-1.0, 1.0))


func _draw() -> void:
	var point_count: int = 96
	var pulse: float = 1.0 + 0.05 * sin(_elapsed * 7.0) * chaos
	if show_track:
		draw_polyline(_arc_points(0.0, TAU, point_count), track_color, width, true)
	for i in range(tick_count):
		var jitter: float = 0.0
		if i < _tick_jitter.size():
			jitter = _tick_jitter[i] * chaos * 0.06
		var angle: float = start_angle + TAU * float(i) / float(tick_count) + jitter
		var unit := Vector2(cos(angle), sin(angle))
		var reach: float = radius * (1.0 + jitter * 0.5)
		draw_line(unit * (reach - width * 0.5), unit * (reach + width * 0.5),
				tick_color, 1.0, true)
	var sweep: float = TAU * progress
	if sweep <= 0.0005:
		return
	var from_angle: float = start_angle if clockwise else start_angle - sweep
	if glow:
		draw_polyline(_arc_points(from_angle, sweep, point_count), Color(fill_color, 0.14),
				width * (2.2 + 0.3 * chaos), true)
	draw_polyline(_arc_points(from_angle, sweep, point_count), fill_color, width, true)
	_draw_head(from_angle + sweep if clockwise else from_angle)


## Polyline arc with a little radius wobble, so the fill reads as drawn rather
## than computed. [param phase_offset] keeps the wobble stable across frames.
func _arc_points(from_angle: float, sweep: float, point_count: int) -> PackedVector2Array:
	var steps: int = maxi(int(absf(sweep) / TAU * float(point_count)), 2)
	var out := PackedVector2Array()
	out.resize(steps + 1)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = from_angle + sweep * t
		var wobble: float = chaos * 0.035 * sin(angle * 3.0 + _elapsed * 2.0)
		var reach: float = radius * (1.0 + wobble) * (1.0 + 0.02 * chaos * sin(_elapsed * 5.0))
		out[i] = Vector2(cos(angle), sin(angle)) * reach
	return out


func _draw_head(at_angle: float) -> void:
	if chaos <= 0.0:
		return
	var pulse: float = 0.6 + 0.4 * sin(_elapsed * 12.0)
	var unit := Vector2(cos(at_angle), sin(at_angle))
	var head: Vector2 = unit * radius
	draw_circle(head, width * (0.45 + 0.2 * pulse), Color(fill_color.lightened(0.35),
			(0.5 + 0.3 * pulse) * chaos))
	draw_line(head, head + unit * width * (1.2 + chaos), Color(fill_color, 0.35 * chaos),
			maxf(1.0, width * 0.2), true)
