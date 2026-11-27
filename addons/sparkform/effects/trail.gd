class_name TrailEffect
extends Node2D
## Persistent ribbon that follows a node: tapering tail, per-segment fade and
## optional motes. Attach it to a projectile, a dashing player or a cursor.
##
## [codeblock]
## var trail := Sparkform.trail(bullet, {"history": 0.25, "width_start": 9.0})
## # the trail frees itself when the target leaves the tree
## [/codeblock]
##
## The node lives in Sparkform's layer and records the target's global positions,
## so it never inherits the target's rotation or scale.

signal finished

## Seconds of movement kept in the ribbon.
@export_range(0.05, 3.0, 0.01, "suffix:s") var history: float = 0.35
## Ribbon width at the target, in pixels.
@export_range(0.5, 64.0, 0.5, "suffix:px") var width_start: float = 8.0
## Ribbon width at the tail, in pixels.
@export_range(0.0, 32.0, 0.5, "suffix:px") var width_end: float = 0.8
## Outer ribbon tint.
@export var trail_color: Color = Color(0.62, 0.84, 1.0)
## Inner ribbon tint.
@export var core_color: Color = Color(0.95, 0.98, 1.0)
## Extra motes shed along the ribbon; [code]0[/code] keeps it a pure ribbon.
@export_range(0, 32, 1) var mote_count: int = 6
## Wobble in the recorded path.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.4
## Free the trail when its target leaves the tree.
@export var free_with_target: bool = true

var _target: Node2D = null
var _points: Array[Dictionary] = []
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _motes: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	set_process(true)


## Starts following [param target]. The node is expected to be parented to the
## Sparkform layer, so its own transform stays at the origin.
func attach_to(target: Node2D) -> void:
	_target = target
	_points.clear()
	_motes.clear()
	for i in range(maxi(mote_count, 0)):
		_motes.append({
			"age": _rng.randf_range(0.0, 1.0),
			"side": _rng.randf_range(-1.0, 1.0),
			"size": _rng.randf_range(1.0, 2.6),
		})
	visible = true
	queue_redraw()


## Drops the ribbon and frees the node.
func stop() -> void:
	_target = null
	_points.clear()
	finished.emit()
	if not Engine.is_editor_hint():
		queue_free()


## Number of recorded points; exposed for tests.
func get_point_count() -> int:
	return _points.size()


func _process(delta: float) -> void:
	_elapsed += delta
	if _target != null and not is_instance_valid(_target):
		_target = null
	if _target == null:
		if free_with_target:
			queue_free()
		return
	_points.append({"position": _target.global_position, "time": _elapsed})
	while _points.size() > 2 and _elapsed - float(_points[0]["time"]) > history:
		_points.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var count: int = _points.size()
	for i in range(count - 1):
		var from: Dictionary = _points[i]
		var to: Dictionary = _points[i + 1]
		var age: float = clampf((_elapsed - float(from["time"])) / maxf(history, 0.001),
				0.0, 1.0)
		var t: float = float(i) / float(count - 1)
		var width: float = lerpf(width_end, width_start, t) * (1.0 - age * 0.35)
		var alpha: float = pow(1.0 - age, 1.4) * t
		if alpha <= 0.01:
			continue
		draw_line(from["position"], to["position"], Color(trail_color, 0.55 * alpha),
				maxf(1.0, width), true)
		draw_line(from["position"], to["position"], Color(core_color, 0.8 * alpha),
				maxf(0.5, width * 0.45), true)
	_draw_motes()


func _draw_motes() -> void:
	if _motes.is_empty() or _points.size() < 2:
		return
	for mote in _motes:
		var t: float = fmod(float(mote["age"]) + _elapsed * (0.8 + chaos), 1.0)
		var index: int = clampi(int(t * float(_points.size())), 0, _points.size() - 1)
		var position: Vector2 = _points[index]["position"]
		var jitter := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		position += jitter * (2.0 + chaos * 6.0) * float(mote["side"])
		var fade: float = sin(PI * t)
		draw_circle(position, float(mote["size"]) * (0.6 + fade * 0.6),
				Color(core_color, 0.5 * fade))
