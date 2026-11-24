class_name ImplosionEffect
extends VFXEffect
## The reverse of an explosion: streaks spiral inward, accelerate, and vanish into
## a bright pinch. Use it for charge-ups, absorbs, vacuum pulls and dark magic.
##
## Spawn it with [code]VFX2D.implosion(at, {"radius": 130.0})[/code].

@export_group("Collapse")
## Radius the streaks start on, in pixels.
@export_range(8.0, 1024.0, 1.0, "suffix:px") var radius: float = 110.0
@export_range(1, 128, 1) var mote_count: int = 26
## Full turns each streak makes on its way in.
@export_range(0.0, 3.0, 0.01) var spiral: float = 1.15
## How sharply the streaks accelerate as they close in.
@export_range(0.6, 4.0, 0.05) var converge: float = 1.8
@export_range(0.5, 24.0, 0.5, "suffix:px") var streak_length: float = 8.0
@export var mote_color: Color = Color(0.72, 0.55, 1.0)
@export var core_color: Color = Color(1.0, 0.95, 1.0)

@export_group("Pinch")
## Radius of the flash at the end of the collapse, relative to [member radius].
@export_range(0.0, 0.5, 0.01) var pinch_size: float = 0.14

@export_group("Chaos")
## Streak spacing, length and timing variance.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.55

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _motes: Array[Dictionary] = []


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_motes.clear()
	for i in range(maxi(mote_count, 1)):
		_motes.append({
			"angle": _rng.randf_range(-PI, PI),
			"start_radius": radius * _rng.randf_range(0.7, 1.15),
			"delay": _rng.randf_range(0.0, 0.3) * chaos,
			"turn_offset": _rng.randf_range(-0.5, 0.5),
			"size": _rng.randf_range(1.2, 3.2),
			"position": Vector2.ZERO,
			"previous": Vector2.ZERO,
			"spawned": false,
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	for mote in _motes:
		var delay: float = float(mote["delay"])
		var local: float = clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if local <= 0.0:
			mote["spawned"] = false
			continue
		var angle: float = float(mote["angle"]) \
				+ (spiral + float(mote["turn_offset"])) * TAU * local
		var distance: float = float(mote["start_radius"]) * pow(1.0 - local, converge)
		var position: Vector2 = Vector2(cos(angle), sin(angle)) * distance
		mote["previous"] = mote["position"] if bool(mote["spawned"]) else position
		mote["position"] = position
		mote["spawned"] = true
		# delta is unused for the position maths (progress drives it) but the
		# parameter keeps the virtual signature honest.
	if delta < 0.0:
		return


func _on_stop() -> void:
	_progress = 1.0


## Live mote count; exposed for tests.
func get_mote_count() -> int:
	return _motes.size()


func _draw() -> void:
	if _progress >= 1.0:
		return
	for mote in _motes:
		if not bool(mote["spawned"]):
			continue
		var position: Vector2 = mote["position"]
		var previous: Vector2 = mote["previous"]
		var local: float = clampf((_progress - float(mote["delay"]))
				/ maxf(1.0 - float(mote["delay"]), 0.05), 0.0, 1.0)
		var fade: float = 0.35 + 0.65 * local
		var heading: Vector2 = (position - previous)
		if heading.length_squared() < 0.01:
			heading = position.normalized()
		var tail: Vector2 = position - heading.normalized() * streak_length \
				* (1.0 + chaos * 0.6)
		draw_line(tail, position, Color(mote_color, 0.75 * fade),
				maxf(1.0, float(mote["size"])), true)
		draw_circle(position, float(mote["size"]) * 0.5,
				Color(core_color, 0.8 * fade))
	_draw_pinch()


func _draw_pinch() -> void:
	if pinch_size <= 0.0:
		return
	var local: float = clampf((_progress - 0.55) / 0.45, 0.0, 1.0)
	if local <= 0.0:
		return
	var pinch_radius: float = radius * pinch_size
	var grow: float = 0.35 + 0.65 * local
	draw_circle(Vector2.ZERO, pinch_radius * grow, Color(core_color, 0.85 * sin(PI * local)))
	draw_circle(Vector2.ZERO, pinch_radius * grow * 2.1,
			Color(mote_color, 0.22 * sin(PI * local)))
	# The collapse releases a little outward puff, so it does not read as a cut.
	if local < 0.55:
		return
	var release: float = (local - 0.55) / 0.45
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		var unit := Vector2(cos(angle), sin(angle))
		draw_line(unit * pinch_radius * (1.0 + release * 2.4),
				unit * pinch_radius * (1.4 + release * 3.6),
				Color(core_color, 0.4 * (1.0 - release)), 2.0, true)
