class_name MuzzleFlashEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Directional gun/muzzle flash: torn cone of light, uneven star and a spray of
## sparks. Fires along [member direction], so it belongs on the weapon, not on
## the target.
##
## Spawn it with
## [code]Sparkform.muzzle_flash(barrel_position, aim_direction, {"length": 90.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")
const VFXStreaks := preload("../core/vfx_streaks.gd")

@export_group("Cone")
## Direction the flash points. The convenience method sets it.
@export var direction: Vector2 = Vector2.RIGHT
@export_range(4.0, 512.0, 1.0, "suffix:px") var length: float = 62.0
@export_range(2.0, 90.0, 0.5, "suffix:deg") var cone_degrees: float = 26.0
@export_range(2, 24, 1) var teeth: int = 7
@export var hot_color: Color = Color(1.0, 0.94, 0.72)
@export var tip_color: Color = Color(1.0, 0.55, 0.16)

@export_group("Sparks")
@export_range(0, 64, 1) var spark_count: int = 12
@export_range(0.0, 4000.0, 10.0, "suffix:px/s") var spark_speed: float = 620.0
@export var spark_color: Color = Color(1.0, 0.86, 0.45)

@export_group("Streaks (C++)")
## Add the C++ streak layer when the optional GDExtension is built.
@export var use_streaks: bool = true
@export_range(0, 4096, 1) var streak_count: int = 120
@export_range(0.0, 2.0, 0.01) var streak_turbulence: float = 0.55

@export_group("Chaos")
## How ragged the cone edge and star are.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.7

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _cone: PackedVector2Array = PackedVector2Array()
var _star: PackedVector2Array = PackedVector2Array()
var _particles: CPUParticles2D = null
var _streaks: Node2D = null


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	var axis: Vector2 = direction
	if axis.length_squared() < 0.0001:
		axis = Vector2.RIGHT
	axis = axis.normalized()
	_cone = VFXShapes.jagged_cone(axis, length, deg_to_rad(cone_degrees) * 0.5, teeth, _rng)
	_star = VFXShapes.star_burst(length * 0.12, length * 0.62, 6,
			axis.angle() + _rng.randf_range(-0.4, 0.4) * chaos, _rng)
	_start_particles(axis)
	_emit_streaks(axis)


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	_progress = 1.0
	if _particles != null:
		_particles.emitting = false
	VFXStreaks.clear(_streaks)


## Current cone outline; exposed for tests.
func get_cone_points() -> PackedVector2Array:
	return _cone


func _start_particles(axis: Vector2) -> void:
	_particles = get_node_or_null("Sparks") as CPUParticles2D
	if _particles == null:
		return
	_particles.amount = maxi(spark_count, 1)
	_particles.lifetime = maxf(duration * 0.8, 0.05)
	_particles.direction = axis
	_particles.spread = cone_degrees * (1.0 + chaos * 0.5)
	_particles.gravity = Vector2(0.0, 320.0)
	_particles.initial_velocity_min = spark_speed * 0.3
	_particles.initial_velocity_max = spark_speed
	_particles.damping_min = spark_speed * 0.9
	_particles.damping_max = spark_speed * 1.6
	_particles.color = spark_color
	var ramp := Gradient.new()
	ramp.set_color(0, spark_color)
	ramp.set_color(1, Color(spark_color, 0.0))
	_particles.color_ramp = ramp
	_particles.restart()
	_particles.emitting = true


func _emit_streaks(axis: Vector2) -> void:
	if not use_streaks or not VFXStreaks.is_available():
		return
	if _streaks == null or not is_instance_valid(_streaks):
		_streaks = VFXStreaks.create(self, {
			"head_color": hot_color,
			"tail_color": Color(tip_color, 0.0),
			"base_width": 1.6,
			"turbulence": streak_turbulence,
			"drag": 3.2,
			"gravity": 420.0,
			"streak_scale": 0.035,
		})
	if _streaks == null:
		return
	VFXStreaks.burst(_streaks, {
		"origin": axis * length * 0.15,
		"count": streak_count,
		"direction": axis,
		"spread": deg_to_rad(cone_degrees) * (0.8 + chaos * 0.8),
		"speed_min": spark_speed * 0.35,
		"speed_max": spark_speed * 1.25,
		"lifetime_min": duration * 0.3,
		"lifetime_max": duration * 0.8,
	})


func _draw() -> void:
	if _progress >= 1.0 or _cone.size() < 3:
		return
	var fade: float = pow(1.0 - clampf(_progress / 0.75, 0.0, 1.0), 2.2)
	if fade <= 0.01:
		return
	# Outer haze, then the hot cone on top of it, then the star core.
	draw_colored_polygon(_cone, Color(tip_color, tip_color.a * 0.35 * fade))
	var scale_back: float = lerpf(1.0, 0.45, _progress)
	var inner := PackedVector2Array()
	inner.resize(_cone.size())
	for i in range(_cone.size()):
		inner[i] = _cone[i] * scale_back
	draw_colored_polygon(inner, Color(hot_color, hot_color.a * 0.7 * fade))
	if _star.size() >= 6:
		draw_colored_polygon(_star, Color(hot_color.lightened(0.2), 0.9 * fade))
	draw_circle(Vector2.ZERO, length * 0.16 * (1.0 - _progress * 0.5), Color(1, 1, 1, fade))
