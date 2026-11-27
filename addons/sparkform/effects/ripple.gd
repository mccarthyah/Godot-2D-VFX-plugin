class_name RippleEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Flattened, wobbling rings plus droplets for water splashes, sonar pulses
## and portal footsteps. Reads as a surface rather than a blast.
##
## Spawn it with [code]Sparkform.ripple(at, {"radius": 120.0})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Ripple")
## Radius the last ring reaches, in pixels.
@export_range(4.0, 1024.0, 1.0, "suffix:px") var radius: float = 96.0
## Number of concentric rings.
@export_range(1, 6, 1) var rings: int = 3
## Ring line width.
@export_range(1.0, 24.0, 0.5, "suffix:px") var ring_width: float = 2.5
## Vertical squash: [code]0[/code] draws circles, [code]0.6[/code] a flat puddle.
@export_range(0.0, 0.9, 0.01) var squash: float = 0.45
## How far the outline wavers away from an ellipse.
@export_range(0.0, 1.0, 0.01) var wobble: float = 0.3
## Ring tint.
@export var ring_color: Color = Color(0.6, 0.86, 1.0)

@export_group("Droplets")
## Droplets thrown by the splash.
@export_range(0, 64, 1) var droplets: int = 10
## Droplet speed in px/s.
@export_range(0.0, 1200.0, 10.0, "suffix:px/s") var droplet_speed: float = 320.0
## Droplet tint.
@export var droplet_color: Color = Color(0.82, 0.95, 1.0)

@export_group("Chaos")
## Outline irregularity and droplet spread.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.5

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _droplet_state: Array[Dictionary] = []


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_droplet_state.clear()
	for i in range(maxi(droplets, 0)):
		var angle: float = _rng.randf_range(-PI, PI)
		var speed: float = droplet_speed * _rng.randf_range(0.35, 1.0) * (0.6 + chaos * 0.6)
		_droplet_state.append({
			"position": Vector2(cos(angle), sin(angle)) * radius * 0.12,
			"velocity": Vector2(cos(angle), sin(angle) * 0.45) * speed + Vector2(0.0, -speed * 0.6),
			"size": _rng.randf_range(1.2, 3.0),
			"delay": _rng.randf_range(0.0, 0.25),
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	for droplet in _droplet_state:
		var velocity: Vector2 = droplet["velocity"] as Vector2
		velocity.y += 900.0 * delta
		droplet["velocity"] = velocity
		droplet["position"] = (droplet["position"] as Vector2) + velocity * delta


func _on_stop() -> void:
	_progress = 1.0


## Ring count; exposed for tests.
func get_ring_count() -> int:
	return maxi(rings, 1)


func _draw() -> void:
	if _progress >= 1.0:
		return
	var flat: float = 1.0 - clampf(squash, 0.0, 0.92)
	var total: int = maxi(rings, 1)
	for index in range(total):
		var delay: float = 0.12 * float(index)
		var local: float = clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if local <= 0.0:
			continue
		var eased: float = 1.0 - pow(1.0 - local, 2.2)
		var fade: float = pow(1.0 - local, 1.4)
		if fade <= 0.01:
			continue
		var ring_radius: float = radius * lerpf(0.1, 1.0, eased)
		var outline: PackedVector2Array = VFXShapes.irregular_ring(ring_radius,
				wobble * 0.22 * (1.0 - eased * 0.5), 56, local * 3.0 + float(index), _rng)
		for i in range(outline.size()):
			outline[i].y *= flat
		outline.append(outline[0])
		draw_polyline(outline, Color(ring_color, ring_color.a * fade * (0.85 - 0.2 * float(index))),
				maxf(1.0, ring_width * (1.0 - eased * 0.4)), true)
	_draw_droplets(flat)


func _draw_droplets(flat: float) -> void:
	for droplet in _droplet_state:
		var delay: float = float(droplet["delay"])
		if _progress < delay:
			continue
		var size: float = float(droplet["size"])
		var position: Vector2 = droplet["position"] as Vector2
		position.y *= flat
		var fade: float = 1.0 - clampf((_progress - delay) / maxf(1.0 - delay, 0.05), 0.0, 1.0)
		if fade <= 0.01:
			continue
		draw_circle(position, size, Color(droplet_color, 0.8 * fade))
		draw_line(position, position + Vector2(0.0, size * 2.0 * fade),
				Color(droplet_color, 0.35 * fade), maxf(1.0, size * 0.6), true)
