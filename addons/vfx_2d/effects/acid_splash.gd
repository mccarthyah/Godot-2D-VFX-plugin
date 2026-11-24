class_name AcidSplashEffect
extends VFXEffect
## Sticky acid: bubbles rise out of a splat and pop on a delay, each pop throwing
## a few droplets, while the puddle drips. Non-additive on purpose — acid is a
## substance, not light.
##
## Spawn it with [code]VFX2D.acid_splash(at, {"bubble_count": 14})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Splat")
## Radius of the puddle left at the spawn point.
@export_range(4.0, 200.0, 1.0, "suffix:px") var splat_radius: float = 26.0
@export_range(0.0, 1.0, 0.01) var splat_squash: float = 0.4
@export_range(0.0, 600.0, 10.0, "suffix:px/s") var splat_spread: float = 210.0
@export_range(0.0, 32.0, 0.5, "suffix:px") var drip_length: float = 9.0

@export_group("Bubbles")
@export_range(0, 48, 1) var bubble_count: int = 12
@export_range(1.0, 24.0, 0.5, "suffix:px") var bubble_size: float = 5.0
@export_range(0.0, 400.0, 5.0, "suffix:px/s") var rise_speed: float = 90.0
## Seconds before a bubble pops, randomised around this value.
@export_range(0.05, 3.0, 0.01, "suffix:s") var pop_delay: float = 0.45
## Droplets thrown by each pop.
@export_range(0, 12, 1) var pop_droplets: int = 3

@export var acid_color: Color = Color(0.52, 0.86, 0.24)
@export var acid_dark: Color = Color(0.24, 0.48, 0.1)
@export var droplet_color: Color = Color(0.72, 0.95, 0.4)

@export_group("Chaos")
## Bubble sizes, pop timing and droplet scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.55

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _bubbles: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _splat: PackedVector2Array = PackedVector2Array()
var _pops: int = 0


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_pops = 0
	_bubbles.clear()
	_drops.clear()
	_splat = VFXShapes.irregular_ring(splat_radius, 0.22 + chaos * 0.25, 14, 0.0, _rng)
	for i in range(maxi(bubble_count, 0)):
		_bubbles.append({
			"origin": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 0.4))
					* splat_radius,
			"size": bubble_size * _rng.randf_range(0.55, 1.6),
			"rise": rise_speed * _rng.randf_range(0.6, 1.4),
			"pop": _rng.randf_range(0.35, 1.25) * pop_delay,
			"wobble": _rng.randf_range(0.5, 2.4),
			"popped": false,
			"y": 0.0,
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	var elapsed: float = _progress * duration
	for bubble in _bubbles:
		var rise: float = float(bubble["rise"])
		bubble["y"] = float(bubble["y"]) - rise * delta
		if bool(bubble["popped"]) or elapsed < float(bubble["pop"]):
			continue
		bubble["popped"] = true
		_pops += 1
		_spawn_droplets(Vector2(bubble["origin"]) + Vector2(0.0, float(bubble["y"])))
	for drop in _drops:
		var velocity: Vector2 = drop["velocity"]
		velocity.y += 520.0 * delta
		drop["velocity"] = velocity
		drop["position"] = Vector2(drop["position"]) + velocity * delta


func _on_stop() -> void:
	_progress = 1.0


## Bubble count; exposed for tests.
func get_bubble_count() -> int:
	return _bubbles.size()


## How many bubbles have popped so far; exposed for tests.
func get_pop_count() -> int:
	return _pops


func _spawn_droplets(at: Vector2) -> void:
	for i in range(maxi(pop_droplets, 0)):
		var angle: float = _rng.randf_range(-PI, 0.1)
		var speed: float = _rng.randf_range(60.0, 160.0) * (0.8 + chaos * 0.5)
		_drops.append({
			"position": at,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"size": _rng.randf_range(1.2, 2.8),
		})


func _draw() -> void:
	if _progress >= 1.0:
		return
	var fade: float = 1.0 - smoothstep(0.72, 1.0, _progress)
	if fade <= 0.01:
		return
	_draw_splat(fade)
	for bubble in _bubbles:
		if bool(bubble["popped"]):
			continue
		_draw_bubble(bubble, fade)
	for drop in _drops:
		draw_circle(drop["position"], float(drop["size"]),
				Color(droplet_color, 0.8 * fade))


func _draw_splat(fade: float) -> void:
	var squash := Vector2(1.0, 1.0 - splat_squash)
	var points := PackedVector2Array()
	for offset in _splat:
		points.append(offset * squash)
	draw_colored_polygon(points, Color(acid_dark, 0.45 * fade))
	draw_polyline(_closed(points), Color(acid_color, 0.55 * fade), 1.5, true)
	for i in range(4):
		var angle: float = PI * 0.5 + _rng.randf_range(-0.6, 0.6)
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * splat_radius * 0.7 * squash
		var length: float = drip_length * _rng.randf_range(0.6, 1.6) * (0.4 + _progress)
		draw_line(start, start + Vector2(0.0, length), Color(acid_color, 0.6 * fade),
				2.0, true)
	if splat_spread >= 0.0:
		for i in range(5):
			var spread: Vector2 = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.2))
			var spot: Vector2 = spread * splat_radius * (1.1 + _progress * 0.8)
			draw_circle(spot * squash, 1.8, Color(acid_color, 0.4 * fade))


func _draw_bubble(bubble: Dictionary, fade: float) -> void:
	var wobble: float = sin(_progress * 18.0 + float(bubble["wobble"])) * 2.0
	var center: Vector2 = Vector2(bubble["origin"]) + Vector2(wobble, float(bubble["y"]))
	var size: float = float(bubble["size"])
	var life: float = clampf(float(bubble["pop"]) / maxf(pop_delay, 0.01), 0.0, 1.0)
	draw_circle(center, size, Color(acid_color, 0.28 * fade))
	draw_arc(center, size, 0.0, TAU, 16, Color(acid_color, 0.75 * fade), 1.3, true)
	draw_circle(center - Vector2(size * 0.3, size * 0.35), maxf(0.8, size * 0.22),
			Color(acid_dark, 0.5 * fade))
	if life > 0.9:
		draw_circle(center, size * 1.4, Color(droplet_color, 0.18 * fade))


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(points)
	if points.size() > 0:
		out.append(points[0])
	return out
