class_name BlinkEffect
extends "res://addons/vfx_2d/core/vfx_effect.gd"
## Two-point teleport: the source collapses inward, a stretched streak snaps
## across the gap, then a ring and spark burst open at the destination.
##
## Spawn it with [code]VFX2D.blink(from, to)[/code].

@export_group("Jump")
## Destination in this node's local space. The spawner sets it from the two
## world points it is given.
@export var destination: Vector2 = Vector2(220.0, 0.0)
## Fraction of the lifetime spent collapsing at the source before the jump.
@export_range(0.05, 0.6, 0.01) var warp: float = 0.22
## Width of the streak that snaps between the two points.
@export_range(1.0, 48.0, 0.5, "suffix:px") var streak_width: float = 9.0
## Points of the spark ring that opens at the destination.
@export_range(0, 32, 1) var spark_count: int = 8
@export var warp_color: Color = Color(0.55, 0.85, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Chaos")
## Streak drift, ring timing and spark scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.5

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _sparks: Array[Vector2] = []


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_sparks.clear()
	for i in range(maxi(spark_count, 0)):
		var angle: float = _rng.randf_range(-PI, PI)
		_sparks.append(Vector2(cos(angle), sin(angle)) * _rng.randf_range(12.0, 26.0))


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0


## Destination in local space; exposed for tests.
func get_destination() -> Vector2:
	return destination


func _draw() -> void:
	if _progress >= 1.0:
		return
	var axis: Vector2 = destination
	var length: float = axis.length()
	if length < 1.0:
		return
	var unit: Vector2 = axis / length
	var normal := Vector2(-unit.y, unit.x)
	_draw_source()
	_draw_streak(unit, normal, length)
	_draw_destination()


func _draw_source() -> void:
	if _progress > warp:
		return
	var local: float = clampf(_progress / maxf(warp, 0.01), 0.0, 1.0)
	var radius: float = lerpf(46.0, 6.0, local)
	draw_circle(Vector2.ZERO, radius * 0.8, Color(warp_color, 0.18 + local * 0.2))
	for i in range(7):
		var angle: float = TAU * float(i) / 7.0 + local * 2.0 * (1.0 + chaos)
		var spot: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		draw_line(spot, spot * 0.35, Color(core_color, 0.5 * local), 2.0, true)
	draw_circle(Vector2.ZERO, 3.0 + local * 3.0, Color(core_color, 0.85 * local))


func _draw_streak(unit: Vector2, normal: Vector2, length: float) -> void:
	if _progress < warp or _progress > warp + 0.24:
		return
	var local: float = clampf((_progress - warp) / 0.24, 0.0, 1.0)
	var reach: float = length * minf(1.0, local * 2.4)
	var width: float = streak_width * (1.0 - local * 0.55)
	draw_line(Vector2.ZERO, unit * reach, Color(warp_color, 0.3 * (1.0 - local)),
			width * 2.6, true)
	draw_line(Vector2.ZERO, unit * reach, Color(core_color, 0.75 * (1.0 - local)),
			width, true)
	for i in range(3):
		var offset: float = _rng.randf_range(-2.0, 2.0) * (1.0 + chaos * 3.0)
		var start: Vector2 = unit * reach * 0.35 + normal * offset
		draw_line(start, start + unit * reach * 0.5,
				Color(core_color, 0.35 * (1.0 - local)), 1.5, true)


func _draw_destination() -> void:
	var local: float = clampf((_progress - warp - 0.12) / 0.5, 0.0, 1.0)
	if local <= 0.0:
		return
	var open: float = 1.0 - pow(1.0 - local, 2.0)
	var ring_radius: float = 14.0 + open * 34.0
	draw_arc(destination, ring_radius, 0.0, TAU, 32,
			Color(warp_color, 0.7 * (1.0 - local)), 2.5, true)
	draw_circle(destination, 10.0 * (1.0 - local * 0.5), Color(core_color, 0.85 * (1.0 - local)))
	for spark in _sparks:
		var travel: Vector2 = destination + spark * (0.4 + open * 1.9)
		draw_line(travel, travel - spark.normalized() * 7.0 * (1.0 - local),
				Color(core_color, 0.6 * (1.0 - local)), 2.0, true)
	draw_circle(destination, 2.0, Color(core_color, 1.0 - local))
