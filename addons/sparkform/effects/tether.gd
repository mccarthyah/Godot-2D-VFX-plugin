class_name Tether
extends Node2D
## Energy chain between two nodes: a sagging link with pulses travelling along it.
## Works for grapples, leashes, soul drains and boss anchors, and frees itself if
## either end disappears.
##
## [codeblock]
## var link := Sparkform.tether(player, enemy)
## link.set_targets(player, other_enemy)
## link.stop()
## [/codeblock]

signal finished

@export_group("Link")
## How far the chain sags below the straight line between the two ends.
@export_range(0.0, 240.0, 1.0, "suffix:px") var sag: float = 42.0
@export_range(2, 64, 1) var link_count: int = 16
@export_range(0.5, 16.0, 0.5, "suffix:px") var thickness: float = 2.5
## Pulses travelling from the first node to the second per second.
@export_range(0.0, 8.0, 0.05) var pulse_speed: float = 1.4
@export_range(0, 12, 1) var pulse_count: int = 3

@export_group("Timing")
@export_range(0.05, 2.0, 0.01, "suffix:s") var fade_time: float = 0.25

@export_group("Colors")
@export var link_color: Color = Color(0.65, 0.85, 1.0)
@export var core_color: Color = Color(1.0, 0.98, 0.92)
@export var pulse_color: Color = Color(1.0, 0.9, 0.6)

@export_group("Chaos")
## Sag variance, link jitter and pulse spacing.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.4
@export var free_on_finish: bool = true

var _from: Node2D = null
var _to: Node2D = null
var _elapsed: float = 0.0
var _openness: float = 0.0
var _closing: bool = false
var _phase: float = 0.0


func _ready() -> void:
	set_process(false)
	_rng_seed()


## Points the chain at two nodes.
func set_targets(from: Node2D, to: Node2D) -> void:
	_from = from
	_to = to
	queue_redraw()


## Starts the chain. Called by [code]Sparkform.tether()[/code].
func start() -> void:
	_elapsed = 0.0
	_openness = 0.0
	_closing = false
	visible = true
	set_process(true)
	queue_redraw()


## Fades the chain out and frees it when [member free_on_finish] is set.
func stop() -> void:
	if _closing:
		return
	_closing = true
	set_process(true)


func is_running() -> bool:
	return _openness > 0.0 and not _closing


## Current opening amount, [code]0.0[/code] to [code]1.0[/code].
func get_openness() -> float:
	return _openness


## Number of links drawn along the chain; exposed for tests.
func get_link_count() -> int:
	return link_count


## Sampled chain points in local space; exposed for tests.
func get_chain_points() -> PackedVector2Array:
	if not has_ends():
		return PackedVector2Array()
	return _sample()


func has_ends() -> bool:
	return is_instance_valid(_from) and is_instance_valid(_to)


func _process(delta: float) -> void:
	_elapsed += delta
	if not has_ends():
		stop()
	if _closing:
		_openness = maxf(0.0, _openness - delta / maxf(fade_time, 0.01))
		if _openness <= 0.0:
			_finish()
			return
	else:
		_openness = minf(1.0, _openness + delta / 0.12)
	queue_redraw()


func _finish() -> void:
	set_process(false)
	finished.emit()
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


func _rng_seed() -> void:
	var seed_value: int = int(Time.get_ticks_usec() % 100000)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_phase = rng.randf_range(-PI, PI)


func _sample() -> PackedVector2Array:
	var start: Vector2 = to_local(_from.global_position)
	var end: Vector2 = to_local(_to.global_position)
	var axis: Vector2 = end - start
	var normal := Vector2(-axis.y, axis.x).normalized()
	if normal.length_squared() < 0.5:
		normal = Vector2.DOWN
	var wobble: float = sin(_elapsed * 3.0 + _phase) * 4.0 * chaos
	var control: Vector2 = start.lerp(end, 0.5) + normal * (sag + wobble)
	var steps: int = maxi(link_count, 4)
	var out := PackedVector2Array()
	out.resize(steps + 1)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		out[i] = start.lerp(control, t).lerp(control.lerp(end, t), t)
	return out


func _draw() -> void:
	if _openness <= 0.001 or not has_ends():
		return
	var points: PackedVector2Array = _sample()
	if points.size() < 2:
		return
	draw_polyline(points, Color(link_color, 0.22 * _openness), thickness * 4.0, true)
	draw_polyline(points, Color(link_color, 0.75 * _openness), thickness * 1.8, true)
	draw_polyline(points, Color(core_color, 0.85 * _openness), thickness, true)
	_draw_links(points)
	_draw_pulses(points)
	draw_circle(points[0], thickness * 2.4, Color(core_color, 0.8 * _openness))
	draw_circle(points[points.size() - 1], thickness * 2.4,
			Color(core_color, 0.8 * _openness))


func _draw_links(points: PackedVector2Array) -> void:
	var count: int = maxi(link_count, 2)
	for i in range(count):
		var t: float = float(i) / float(count)
		var index: int = clampi(int(t * float(points.size() - 1)), 0, points.size() - 2)
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var heading: Vector2 = (b - a).normalized()
		var normal := Vector2(-heading.y, heading.x)
		var sway: float = sin(_elapsed * 2.0 + float(i) * 0.9) * thickness * chaos
		var center: Vector2 = a.lerp(b, 0.5) + normal * sway
		draw_line(center - normal * thickness * 2.4, center + normal * thickness * 2.4,
				Color(link_color, 0.5 * _openness), maxf(1.0, thickness * 0.6), true)


func _draw_pulses(points: PackedVector2Array) -> void:
	if pulse_count <= 0 or pulse_speed <= 0.0:
		return
	for i in range(pulse_count):
		var t: float = fmod(_elapsed * pulse_speed + float(i) / float(pulse_count), 1.0)
		var index: int = clampi(int(t * float(points.size() - 1)), 0, points.size() - 1)
		var position: Vector2 = points[index]
		var glow: float = sin(PI * t)
		draw_circle(position, thickness * 2.2, Color(pulse_color, 0.55 * glow * _openness))
		draw_circle(position, thickness * 0.9, Color(core_color, 0.9 * glow * _openness))
