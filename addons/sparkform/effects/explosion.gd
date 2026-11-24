class_name ExplosionEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Radial explosion: expanding shockwave, layered fireball and flying debris.
##
## Spawn it with [code]Sparkform.explosion(position, {"radius": 96.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")
const VFXStreaks := preload("../core/vfx_streaks.gd")

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

@export_group("Chaos")
## Irregularity of the whole blast: [code]0[/code] is a round, symmetric
## fireball, [code]1[/code] a lopsided one with torn rings and stray lobes.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.6

@export_group("Streaks (C++)")
## Add the C++ streak layer when the optional GDExtension is built.
@export var use_streaks: bool = true
@export_range(0, 8192, 1) var streak_count: int = 260
@export_range(0.0, 2.0, 0.01) var streak_turbulence: float = 0.35

var _progress: float = 0.0
var _debris: CPUParticles2D = null
var _streaks: Node2D = null
var _rng := RandomNumberGenerator.new()
var _layer_offsets: Array[Vector2] = []
var _layer_scales: PackedFloat32Array = PackedFloat32Array()
var _lobes: Array[Dictionary] = []
var _secondary_offset := Vector2.ZERO
var _secondary_size: float = 0.0
var _secondary_delay: float = 1.0


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
	_debris.spread = 180.0 * (0.85 + chaos * 0.3)
	_debris.restart()
	_debris.emitting = true
	_build_chaos()
	_emit_streaks()


func _build_chaos() -> void:
	_rng.randomize()
	_layer_offsets.clear()
	_layer_scales.clear()
	var layers: int = maxi(fireball_layers, 1)
	for i in range(layers):
		var angle: float = _rng.randf_range(-PI, PI)
		var distance: float = _rng.randf_range(0.0, 0.22) * chaos
		_layer_offsets.append(Vector2(cos(angle), sin(angle)) * distance)
		_layer_scales.append(_rng.randf_range(0.82, 1.18) * (1.0 + chaos * 0.12))
	_lobes.clear()
	for i in range(2 + roundi(chaos * 3.0)):
		var angle: float = _rng.randf_range(-PI, PI)
		_lobes.append({
			"direction": Vector2(cos(angle), sin(angle)),
			"distance": _rng.randf_range(0.55, 1.15),
			"size": _rng.randf_range(0.2, 0.45),
			"delay": _rng.randf_range(0.0, 0.18),
		})
	_secondary_size = radius * _rng.randf_range(0.1, 0.24) * (0.5 + chaos)
	_secondary_offset = Vector2.from_angle(_rng.randf_range(-PI, PI)) * radius \
			* _rng.randf_range(0.5, 1.3) * chaos
	_secondary_delay = _rng.randf_range(0.2, 0.45)


func _on_update(progress_value: float, _delta: float) -> void:
	_progress = progress_value


func _on_stop() -> void:
	if _debris != null:
		_debris.emitting = false
	VFXStreaks.clear(_streaks)

func _emit_streaks() -> void:
	if not use_streaks or not VFXStreaks.is_available():
		return
	if _streaks == null or not is_instance_valid(_streaks):
		_streaks = VFXStreaks.create(self, {
			"head_color": core_color,
			"tail_color": Color(edge_color, 0.0),
			"base_width": maxf(1.0, debris_size * 0.8),
			"turbulence": streak_turbulence,
			"drag": 1.6,
			"gravity": 520.0,
			"streak_scale": 0.045,
			"max_particles": 4096,
		})
	if _streaks == null:
		return
	VFXStreaks.burst(_streaks, {
		"origin": Vector2.ZERO,
		"count": streak_count,
		"direction": Vector2.UP,
		"spread": TAU,
		"speed_min": debris_speed * 0.25,
		"speed_max": debris_speed * 1.15,
		"lifetime_min": duration * 0.35,
		"lifetime_max": duration * 0.85,
	})


func _draw() -> void:
	if _progress >= 1.0:
		return
	_draw_shockwave()
	_draw_secondary()
	_draw_fireball()


func _draw_shockwave() -> void:
	var wave_t: float = clampf(_progress / 0.9, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - wave_t, 3.0)
	var wave_alpha: float = pow(1.0 - wave_t, 1.6)
	if wave_alpha <= 0.01:
		return
	var reach: float = radius * lerpf(0.25, ring_expansion, eased)
	var wobble: float = chaos * 0.26 * (0.4 + 0.6 * (1.0 - eased))
	var outline: PackedVector2Array = VFXShapes.irregular_ring(reach, wobble, 64,
			_progress * 2.4, _rng)
	outline.append(outline[0])
	draw_polyline(outline, Color(edge_color, wave_alpha * 0.85),
			maxf(1.0, ring_width * (1.0 - eased * 0.8)), true)
	# A second, faster ghost front, so the blast never reads as one clean circle.
	var ghost_t: float = clampf((_progress - 0.04) / 0.8, 0.0, 1.0)
	if ghost_t <= 0.0:
		return
	var ghost_alpha: float = pow(1.0 - ghost_t, 2.2) * 0.5
	if ghost_alpha <= 0.01:
		return
	var ghost_radius: float = radius * lerpf(0.2, ring_expansion * 1.12,
			1.0 - pow(1.0 - ghost_t, 2.4))
	var ghost: PackedVector2Array = VFXShapes.irregular_ring(ghost_radius, chaos * 0.4, 48,
			_progress * 3.1 + 1.7, _rng)
	ghost.append(ghost[0])
	draw_polyline(ghost, Color(core_color, ghost_alpha), maxf(1.0, ring_width * 0.45), true)


func _draw_secondary() -> void:
	if _secondary_size <= 0.0 or _progress < _secondary_delay:
		return
	var local: float = clampf((_progress - _secondary_delay) / 0.25, 0.0, 1.0)
	if local <= 0.0 or local >= 1.0:
		return
	var fade: float = pow(1.0 - local, 2.0)
	var pop_radius: float = _secondary_size * (0.4 + local)
	draw_circle(_secondary_offset, pop_radius, Color(core_color, 0.55 * fade))
	draw_circle(_secondary_offset, pop_radius * 1.7, Color(edge_color, 0.18 * fade))


func _draw_fireball() -> void:
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
		var offset: Vector2 = _layer_offsets[i % _layer_offsets.size()] * fire_radius
		var layer_radius: float = fire_radius * lerpf(1.0, 0.25, t) \
				* _layer_scales[i % _layer_scales.size()]
		var outline: PackedVector2Array = VFXShapes.irregular_ring(layer_radius, chaos * 0.3, 22,
				float(i) * 1.3 + fire_t * 3.0, _rng)
		for point in range(outline.size()):
			outline[point] += offset
		draw_colored_polygon(outline, layer_color)
	_draw_lobes(fire_radius, fire_alpha)


func _draw_lobes(fire_radius: float, fire_alpha: float) -> void:
	for lobe in _lobes:
		var local: float = clampf((_progress - float(lobe["delay"])) / 0.5, 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var fade: float = pow(1.0 - local, 1.6) * fire_alpha
		if fade <= 0.01:
			continue
		var center: Vector2 = (lobe["direction"] as Vector2) * fire_radius \
				* float(lobe["distance"])
		var lobe_radius: float = fire_radius * float(lobe["size"]) * (0.6 + local * 0.9)
		var outline: PackedVector2Array = VFXShapes.irregular_ring(lobe_radius, 0.3, 16,
				local * 4.0, _rng)
		for point in range(outline.size()):
			outline[point] += center
		draw_colored_polygon(outline, Color(edge_color, fade * 0.5))
