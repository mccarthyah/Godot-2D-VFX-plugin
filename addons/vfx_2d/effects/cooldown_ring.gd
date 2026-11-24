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
## var ring := VFX2D.cooldown_ring(icon, 2.5)
##
## # drains from full (classic cooldown)
## VFX2D.cooldown_ring(icon, 2.5, {"reverse": true})
## [/codeblock]
##
## The ring previews in the editor: tweak [member progress] to see the arc.

## Emitted once the ring reaches the end of its duration.
signal completed

@export_group("Shape")
@export_range(4.0, 512.0, 1.0, "suffix:px") var radius: float = 42.0
@export_range(0.5, 64.0, 0.5, "suffix:px") var width: float = 8.0
## Where the arc starts, in radians. The default starts at 12 o'clock.
@export_range(-6.2832, 6.2832, 0.01, "suffix:rad") var start_angle: float = -1.5708
## Draw the filled arc clockwise instead of counter-clockwise.
@export var clockwise: bool = true
@export_range(0, 64, 1) var tick_count: int = 0
@export var tick_color: Color = Color(1.0, 1.0, 1.0, 0.35)

@export_group("Colors")
@export var fill_color: Color = Color(0.42, 0.9, 1.0)
@export var track_color: Color = Color(0.06, 0.09, 0.14, 0.6)
@export var show_track: bool = true

@export_group("Timing")
@export_range(0.01, 60.0, 0.01, "suffix:s") var duration: float = 1.0
## Start at full and drain to empty instead of filling up.
@export var reverse: bool = false
## Free the node once the cooldown completes. Disable it if you want to reuse
## the same ring for several cooldowns.
@export var free_on_complete: bool = true

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


func _ready() -> void:
	set_process(false)
	queue_redraw()


## Starts the cooldown. [param seconds] overrides [member duration] when it is
## greater than zero.
func start(seconds: float = -1.0) -> void:
	if seconds > 0.0:
		duration = seconds
	_elapsed = 0.0
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


func _draw() -> void:
	var point_count: int = 96
	if show_track:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, point_count, track_color, width, true)
	for i in range(tick_count):
		var angle: float = start_angle + TAU * float(i) / float(tick_count)
		var unit := Vector2(cos(angle), sin(angle))
		draw_line(unit * (radius - width * 0.5), unit * (radius + width * 0.5),
				tick_color, 1.0, true)
	var sweep: float = TAU * progress
	if sweep <= 0.0005:
		return
	if clockwise:
		draw_arc(Vector2.ZERO, radius, start_angle, start_angle + sweep, point_count,
				fill_color, width, true)
	else:
		draw_arc(Vector2.ZERO, radius, start_angle - sweep, start_angle, point_count,
				fill_color, width, true)
