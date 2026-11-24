class_name ExplosionEffect
extends VFXEffect
## Radial explosion: expanding shockwave, layered fireball and flying debris.
##
## Spawn it with [code]VFX2D.explosion(position, {"radius": 96.0})[/code].

@export_group("Blast")
## Overall blast size in pixels. Every other size is derived from it.
@export_range(4.0, 512.0, 1.0, "suffix:px") var radius: float = 76.0
@export var core_color: Color = Color(1.0, 0.95, 0.62)
@export var edge_color: Color = Color(1.0, 0.32, 0.06)
@export_range(1, 16, 1) var fireball_layers: int = 7

@export_group("Shockwave")
@export_range(1.0, 64.0, 0.5, "suffix:px") var ring_width: float = 10.0
## How far the shockwave travels, as a multiple of [member radius].
@export_range(1.0, 4.0, 0.05) var ring_expansion: float = 1.7

@export_group("Debris")
@export_range(0, 128, 1) var debris_count: int = 26
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var debris_speed: float = 460.0
@export_range(0.5, 32.0, 0.5, "suffix:px") var debris_size: float = 3.0
@export var debris_color: Color = Color(1.0, 0.74, 0.32)

var _progress: float = 0.0
var _debris: CPUParticles2D = null


func _on_play() -> void:
	_progress = 0.0
	_debris = get_node_or_null("Debris") as CPUParticles2D
	if _debris == null:
		return
	_debris.amount = maxi(debris_count, 1)
	_debris.lifetime = maxf(duration, 0.08)
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_debris.emission_sphere_radius = maxf(radius * 0.08, 1.0)
	_debris.direction = Vector2.UP
	_debris.spread = 180.0
	_debris.gravity = Vector2(0.0, 700.0)
	_debris.initial_velocity_min = debris_speed * 0.25
	_debris.initial_velocity_max = debris_speed
	_debris.damping_min = debris_speed * 0.4
	_debris.damping_max = debris_speed * 0.9
	_debris.scale_amount_min = debris_size * 0.4
	_debris.scale_amount_max = debris_size
	_debris.color = debris_color
	var ramp := Gradient.new()
	ramp.set_color(0, debris_color)
	ramp.set_color(1, Color(debris_color, 0.0))
	_debris.color_ramp = ramp
	_debris.restart()
	_debris.emitting = true


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	if _debris != null:
		_debris.emitting = false


func _draw() -> void:
	if _progress >= 1.0:
		return
	# Shockwave ring: expands fast, thins and fades out.
	var wave_t: float = clampf(_progress / 0.9, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - wave_t, 3.0)
	var wave_alpha: float = pow(1.0 - wave_t, 1.6)
	if wave_alpha > 0.01:
		draw_arc(Vector2.ZERO, radius * lerpf(0.25, ring_expansion, eased),
				0.0, TAU, 72, Color(edge_color, wave_alpha * 0.85),
				maxf(1.0, ring_width * (1.0 - eased * 0.8)), true)
	# Fireball: layered discs, hottest in the middle.
	var fire_t: float = clampf(_progress / 0.55, 0.0, 1.0)
	var fire_alpha: float = pow(1.0 - fire_t, 1.4)
	if fire_alpha <= 0.01:
		return
	var fire_radius: float = radius * lerpf(0.15, 1.0, 1.0 - pow(1.0 - fire_t, 2.0))
	var layers: int = maxi(fireball_layers, 1)
	var divisor: float = float(maxi(layers - 1, 1))
	for i in range(layers):
		var t: float = float(i) / divisor
		var layer_color: Color = core_color.lerp(edge_color, t)
		layer_color.a = fire_alpha * lerpf(0.85, 0.25, t)
		draw_circle(Vector2.ZERO, fire_radius * lerpf(1.0, 0.25, t), layer_color)
