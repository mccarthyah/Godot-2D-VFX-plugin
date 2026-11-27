class_name Vortex
extends Node2D
## A pull field: motes spawn on the rim, spiral inward and are recycled at the
## centre, inside a faint set of spinning arcs. Charges, black holes, suction,
## and a natural companion to [code]implosion[/code].
##
## [codeblock]
## var field := Sparkform.vortex(at, {"radius": 120.0, "strength": 260.0})
## field.stop()
## [/codeblock]

signal finished

const VFXStreaks := preload("../core/vfx_streaks.gd")

@export_group("Field")
## Field radius in pixels.
@export_range(8.0, 512.0, 1.0, "suffix:px") var radius: float = 96.0
## Inward speed at the rim, in pixels per second.
@export_range(0.0, 1200.0, 5.0, "suffix:px/s") var strength: float = 210.0
## Rotation, in radians per second.
@export_range(0.0, 12.0, 0.1, "suffix:rad/s") var spin: float = 3.4
## Motes spiralling in.
@export_range(0, 96, 1) var mote_count: int = 26
## Length of each mote trail.
@export_range(1.0, 24.0, 0.5, "suffix:px") var mote_length: float = 7.0

@export_group("Timing")
## Close on its own after this many seconds; [code]0[/code] holds until stopped.
@export_range(0.0, 120.0, 0.1, "suffix:s") var lifetime: float = 0.0
## Seconds to fade after stop().
@export_range(0.05, 2.0, 0.01, "suffix:s") var fade_time: float = 0.3

@export_group("Colors")
## Mote tint.
@export var mote_color: Color = Color(0.6, 0.75, 1.0)
## Centre glow tint.
@export var core_color: Color = Color(1.0, 0.95, 0.85)
## Faint arc tint.
@export var field_color: Color = Color(0.32, 0.4, 0.85)

@export_group("Chaos")
## Mote speed, spiral variance and arc wobble.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.45
## Also spray a ring of C++ streaks on start when the extension is loaded.
@export var use_streaks: bool = true
## C++ streak particles when the field opens.
@export_range(0, 600, 10) var streak_count: int = 140
## Free the node once it has faded.
@export var free_on_finish: bool = true

var _rng := RandomNumberGenerator.new()
var _motes: Array[Dictionary] = []
var _elapsed: float = 0.0
var _openness: float = 0.0
var _closing: bool = false
var _streaks: Node2D = null


func _ready() -> void:
	set_process(false)
	_rng.randomize()


## Starts the field. Called by [code]Sparkform.vortex()[/code].
func start() -> void:
	_elapsed = 0.0
	_openness = 0.0
	_closing = false
	_motes.clear()
	for i in range(maxi(mote_count, 1)):
		_motes.append(_new_mote(true))
	visible = true
	set_process(true)
	_attach_streaks()
	queue_redraw()


## Fades the field out and frees it when [member free_on_finish] is set.
func stop() -> void:
	if _closing:
		return
	_closing = true
	set_process(true)


## [code]true[/code] while the field is open and not already closing.
func is_running() -> bool:
	return _openness > 0.0 and not _closing


## Motes currently spiralling; exposed for tests.
func get_mote_count() -> int:
	return _motes.size()


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
		_openness = minf(1.0, _openness + delta / 0.2)
		if lifetime > 0.0 and _elapsed >= lifetime:
			stop()
	for index in range(_motes.size()):
		var mote: Dictionary = _motes[index]
		var distance: float = float(mote["distance"])
		distance -= strength * float(mote["speed"]) * delta
		mote["angle"] = float(mote["angle"]) + spin * delta * float(mote["rate"])
		mote["previous"] = mote["position"]
		if distance <= radius * 0.06:
			_motes[index] = _new_mote(false)
			continue
		mote["distance"] = distance
		var angle: float = float(mote["angle"])
		mote["position"] = Vector2(cos(angle), sin(angle)) * distance
	queue_redraw()


func _finish() -> void:
	set_process(false)
	if _streaks != null and is_instance_valid(_streaks):
		_streaks.queue_free()
		_streaks = null
	finished.emit()
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


func _new_mote(seed_anywhere: bool) -> Dictionary:
	var angle: float = _rng.randf_range(-PI, PI)
	var distance: float = radius * (_rng.randf_range(0.2, 1.0) if seed_anywhere
			else _rng.randf_range(0.9, 1.1))
	return {
		"angle": angle,
		"distance": distance,
		"speed": _rng.randf_range(0.6, 1.4) * (0.7 + chaos * 0.6),
		"rate": _rng.randf_range(0.7, 1.3) * (1.0 if _rng.randf() > chaos * 0.5 else -0.6),
		"size": _rng.randf_range(0.8, 2.2),
		"position": Vector2(cos(angle), sin(angle)) * distance,
		"previous": Vector2(cos(angle), sin(angle)) * distance,
	}


func _attach_streaks() -> void:
	if not use_streaks or not VFXStreaks.is_available() or streak_count <= 0:
		return
	_streaks = VFXStreaks.create(self, {"seed": _rng.randi(), "max_particles": 1024})
	if _streaks == null:
		return
	var ring: Array = []
	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		ring.append(Vector2(cos(angle), sin(angle)) * radius * 1.1)
	VFXStreaks.burst(_streaks, {
		"origin": Vector2.ZERO,
		"count": streak_count,
		"direction": Vector2.LEFT,
		"spread": PI,
		"speed_min": 60.0,
		"speed_max": 220.0,
		"lifetime_min": 0.35,
		"lifetime_max": 0.7,
	})


func _draw() -> void:
	if _openness <= 0.001:
		return
	var scale_amount: float = 0.4 + _openness * 0.6
	draw_circle(Vector2.ZERO, radius * scale_amount,
			Color(field_color, 0.06 * _openness))
	for i in range(3):
		var arc_radius: float = radius * scale_amount * (0.45 + float(i) * 0.26)
		var start: float = _elapsed * (spin * 0.55 + float(i) * 0.4)
		var length: float = PI * (0.7 + chaos * 0.5)
		draw_arc(Vector2.ZERO, arc_radius, start, start + length, 28,
				Color(field_color, 0.22 * _openness), 1.6, true)
	_draw_motes()
	var core: float = radius * 0.1 * scale_amount
	draw_circle(Vector2.ZERO, core, Color(core_color, 0.5 * _openness))
	draw_circle(Vector2.ZERO, core * 1.8, Color(mote_color, 0.18 * _openness))


func _draw_motes() -> void:
	for mote in _motes:
		var position: Vector2 = mote["position"]
		var previous: Vector2 = mote["previous"]
		var heading: Vector2 = position - previous
		if heading.length_squared() < 0.0001:
			heading = position.normalized()
		var tail: Vector2 = position - heading.normalized() * mote_length
		var fade: float = clampf(float(mote["distance"]) / maxf(radius, 1.0), 0.15, 1.0)
		draw_line(tail, position, Color(mote_color, 0.6 * fade * _openness),
				maxf(1.0, float(mote["size"])), true)
