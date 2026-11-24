class_name HitSparkEffect
extends VFXEffect
## Impact spark: a bright flash plus a short directional burst of sparks.
##
## Use it for melee hits, bullet impacts and pickups. Spawn it with
## [code]VFX2D.hit_spark(position, direction)[/code].

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

var _flash_alpha: float = 0.0
var _particles: CPUParticles2D = null


func _on_play() -> void:
	_flash_alpha = 1.0
	_particles = get_node_or_null("Sparks") as CPUParticles2D
	if _particles == null:
		return
	var travel: Vector2 = direction
	if travel.length_squared() < 0.0001:
		travel = Vector2.UP
	_particles.amount = maxi(spark_count, 1)
	_particles.lifetime = maxf(duration, 0.05)
	_particles.direction = travel.normalized()
	_particles.spread = deg_to_rad(spread_degrees)
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


func _on_update(progress_value: float, _delta: float) -> void:
	_flash_alpha = pow(1.0 - progress_value, 2.0)


func _on_stop() -> void:
	_flash_alpha = 0.0
	if _particles != null:
		_particles.emitting = false


func _draw() -> void:
	if _flash_alpha <= 0.01:
		return
	var travel: Vector2 = direction
	if travel.length_squared() < 0.0001:
		travel = Vector2.UP
	travel = travel.normalized()
	draw_circle(Vector2.ZERO, flash_radius * (0.35 + 0.65 * _flash_alpha),
			Color(flash_color, flash_color.a * _flash_alpha))
	var streak := streak_length * _flash_alpha
	if streak > 0.5:
		draw_line(-travel * streak, travel * streak,
				Color(flash_color, 0.55 * _flash_alpha),
				maxf(1.0, flash_radius * 0.5 * _flash_alpha), true)
