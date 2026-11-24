class_name HitSparkEffect
extends VFXEffect
## Impact spark: a bright flash plus a short directional burst of sparks.
##
## Use it for melee hits, bullet impacts and pickups. Spawn it with
## [code]VFX2D.hit_spark(position, direction)[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Sparks")
## Direction the sparks travel. Set through the convenience method argument.
@export var direction: Vector2 = Vector2.UP
@export_range(1, 64, 1) var spark_count: int = 14
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var spark_speed: float = 340.0
@export_range(0.0, 180.0, 1.0, "suffix:deg") var spread_degrees: float = 32.0
@export_range(0.5, 32.0, 0.5, "suffix:px") var spark_size: float = 3.0
@export_range(0.0, 2000.0, 10.0, "suffix:px/s²") var spark_gravity: float = 420.0
@export var spark_color: Color = Color(1.0, 0.95, 0.72)

@export_group("Flash")
@export_range(0.0, 128.0, 0.5, "suffix:px") var flash_radius: float = 12.0
@export_range(0.0, 128.0, 0.5, "suffix:px") var streak_length: float = 26.0
@export var flash_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Chaos")
## How torn the flash and how uneven the spray is: [code]0[/code] reads as a tidy
## symmetric hit, [code]1[/code] as an asymmetric, splintered one.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.65

@export_group("Streaks (C++)")
## Add the C++ streak layer when the optional GDExtension is built. Silently
## skipped (and the effect still plays) when it is not.
@export var use_streaks: bool = true
@export_range(0, 4096, 1) var streak_count: int = 60
@export_range(0.0, 2.0, 0.01) var streak_turbulence: float = 0.15

var _flash_alpha: float = 0.0
var _particles: CPUParticles2D = null
var _streaks: Node2D = null
var _rng := RandomNumberGenerator.new()
var _star: PackedVector2Array = PackedVector2Array()
var _splinters: Array[Dictionary] = []
var _flash_offset := Vector2.ZERO


func _on_play() -> void:
	_flash_alpha = 1.0
	_rng.randomize()
	_flash_offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
			* flash_radius * 0.22 * chaos
	_star = VFXShapes.star_burst(flash_radius * 0.35, flash_radius * (1.15 + chaos * 0.9),
			_rng.randi_range(5, 8), _rng.randf_range(-PI, PI), _rng)
	_splinters.clear()
	for _i in range(2 + roundi(chaos * 4.0)):
		_splinters.append({
			"direction": Vector2.from_angle(_rng.randf_range(-PI, PI)),
			"length": streak_length * _rng.randf_range(0.6, 1.9) * (0.6 + chaos),
			"width": _rng.randf_range(0.8, 1.9),
		})
	_particles = get_node_or_null("Sparks") as CPUParticles2D
	if _particles == null:
		return
	var travel: Vector2 = direction
	if travel.length_squared() < 0.0001:
		travel = Vector2.UP
	travel = travel.rotated(_rng.randf_range(-0.35, 0.35) * chaos)
	_particles.amount = maxi(spark_count, 1)
	_particles.lifetime = maxf(duration, 0.05)
	_particles.direction = travel.normalized()
	_particles.spread = deg_to_rad(spread_degrees) * (1.0 + chaos * 0.9)
	_particles.gravity = Vector2(0.0, spark_gravity)
	_particles.initial_velocity_min = spark_speed * 0.45
	_particles.initial_velocity_max = spark_speed
	_particles.damping_min = spark_speed * 0.6
	_particles.damping_max = spark_speed * 1.1
	_particles.scale_amount_min = spark_size * 0.5
	_particles.scale_amount_max = spark_size
	_particles.color = spark_color
	var ramp := Gradient.new()
	ramp.set_color(0, spark_color)
	ramp.set_color(1, Color(spark_color, 0.0))
	_particles.color_ramp = ramp
	_particles.restart()
	_particles.emitting = true
	_emit_streaks()


func _on_update(progress_value: float, _delta: float) -> void:
	_flash_alpha = pow(1.0 - progress_value, 2.0)


func _on_stop() -> void:
	_flash_alpha = 0.0
	if _particles != null:
		_particles.emitting = false
	VFXStreaks.clear(_streaks)

func _emit_streaks() -> void:
	if not use_streaks or not VFXStreaks.is_available():
		return
	if _streaks == null or not is_instance_valid(_streaks):
		_streaks = VFXStreaks.create(self, {
			"head_color": spark_color,
			"tail_color": Color(spark_color, 0.0),
			"base_width": maxf(1.0, spark_size * 0.7),
			"turbulence": streak_turbulence * (1.0 + chaos),
			"drag": 2.4,
			"gravity": spark_gravity,
			"streak_scale": 0.03,
		})
	if _streaks == null:
		return
	VFXStreaks.burst(_streaks, {
		"origin": Vector2.ZERO,
		"count": streak_count,
		"direction": direction,
		"spread": deg_to_rad(spread_degrees) * (1.4 + chaos * 0.9),
		"speed_min": spark_speed * 0.5,
		"speed_max": spark_speed * 1.35,
		"lifetime_min": duration * 0.45,
		"lifetime_max": duration * 0.9,
	})


func _draw() -> void:
	if _flash_alpha <= 0.01:
		return
	var travel: Vector2 = direction
	if travel.length_squared() < 0.0001:
		travel = Vector2.UP
	travel = travel.normalized()
	# Torn star behind the hot core: the same flash, but never twice the same shape.
	if _star.size() >= 6:
		var star := PackedVector2Array()
		star.resize(_star.size())
		var star_scale: float = 1.0 + (1.0 - _flash_alpha) * 0.25
		for i in range(_star.size()):
			star[i] = _flash_offset + _star[i] * star_scale
		draw_colored_polygon(star, Color(flash_color, flash_color.a * 0.45 * _flash_alpha))
	draw_circle(_flash_offset, flash_radius * (0.35 + 0.65 * _flash_alpha),
			Color(flash_color, flash_color.a * _flash_alpha))
	var streak := streak_length * _flash_alpha
	if streak > 0.5:
		draw_line(-travel * streak, travel * streak,
				Color(flash_color, 0.55 * _flash_alpha),
				maxf(1.0, flash_radius * 0.5 * _flash_alpha), true)
	# Splinters: short hot shards flying out of the impact at random angles.
	for splinter in _splinters:
		var unit: Vector2 = splinter["direction"] as Vector2
		var reach: float = float(splinter["length"]) * _flash_alpha
		if reach <= 0.5:
			continue
		draw_line(unit * flash_radius * 0.4, unit * (flash_radius * 0.4 + reach),
				Color(flash_color, 0.4 * _flash_alpha), float(splinter["width"]), true)
