class_name DebrisBurstEffect
extends VFXEffect
## Solid chunks instead of sparks: drawn shards with their own shape, spin and
## weight, so a broken crate or defeated enemy throws pieces rather than dust.
##
## Spawn it with [code]VFX2D.debris_burst(at, {"chunk_count": 18})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Chunks")
@export_range(1, 128, 1) var chunk_count: int = 14
@export_range(1.0, 64.0, 0.5, "suffix:px") var chunk_size: float = 6.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s") var speed: float = 380.0
@export_range(0.0, 4000.0, 10.0) var gravity: float = 900.0
@export_range(0.0, 8.0, 0.05) var drag: float = 1.2
@export_range(-24.0, 24.0, 0.5, "suffix:rad/s") var spin_speed: float = 7.0
@export var chunk_color: Color = Color(0.78, 0.74, 0.66)
@export var chunk_color_dark: Color = Color(0.38, 0.35, 0.32)
## Upward bias of the burst, in radians around straight up.
@export_range(0.0, 3.14, 0.01) var upward_bias: float = 1.2

@export_group("Chaos")
## Size and shape variance between chunks.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.55

var _rng := RandomNumberGenerator.new()
var _chunks: Array[Dictionary] = []
var _progress: float = 0.0


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_chunks.clear()
	for i in range(maxi(chunk_count, 1)):
		var angle: float = _rng.randf_range(-PI, PI)
		# Bias the spawn towards the upper half so the burst arcs instead of
		# spilling straight down.
		var bias: float = _rng.randf_range(0.0, upward_bias)
		var travel := Vector2(cos(angle), sin(angle)).rotated(-bias * 0.5)
		var size: float = chunk_size * _rng.randf_range(1.0 - chaos * 0.6, 1.0 + chaos * 0.9)
		var sides: int = _rng.randi_range(4, 7)
		var offset := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
				* chunk_size * 0.6
		_chunks.append({
			"position": offset,
			"velocity": travel * speed * _rng.randf_range(0.45, 1.25),
			"angle": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-1.0, 1.0) * spin_speed,
			"outline": VFXShapes.irregular_ring(size, 0.18 + chaos * 0.2, sides,
					_rng.randf_range(0.0, TAU), _rng),
			"tint": _rng.randf(),
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	var damping: float = maxf(1.0 - drag * delta, 0.0)
	for chunk in _chunks:
		var velocity: Vector2 = chunk["velocity"] as Vector2
		velocity.y += gravity * delta
		velocity *= damping
		chunk["velocity"] = velocity
		chunk["position"] = (chunk["position"] as Vector2) + velocity * delta
		chunk["angle"] = float(chunk["angle"]) + float(chunk["spin"]) * delta


func _on_stop() -> void:
	_progress = 1.0


## Live chunk count; exposed for tests.
func get_chunk_count() -> int:
	return _chunks.size()


func _draw() -> void:
	if _progress >= 1.0:
		return
	var fade: float = pow(1.0 - _progress, 0.6)
	if _progress < 0.25:
		var burst: float = pow(1.0 - _progress / 0.25, 2.0)
		draw_circle(Vector2.ZERO, chunk_size * 3.0 * burst, Color(chunk_color, 0.5 * burst))
	for chunk in _chunks:
		var position: Vector2 = chunk["position"] as Vector2
		var rotation: float = float(chunk["angle"])
		var outline: PackedVector2Array = chunk["outline"]
		var rotated := PackedVector2Array()
		rotated.resize(outline.size())
		var cos_a: float = cos(rotation)
		var sin_a: float = sin(rotation)
		for i in range(outline.size()):
			var point: Vector2 = outline[i]
			rotated[i] = position + Vector2(point.x * cos_a - point.y * sin_a,
					point.x * sin_a + point.y * cos_a)
		var tint: float = clampf(float(chunk["tint"]), 0.0, 1.0)
		var color: Color = chunk_color_dark.lerp(chunk_color, tint)
		color.a = fade
		draw_colored_polygon(rotated, color)
		# A darker rim keeps the chunk readable against bright effects.
		rotated.append(rotated[0])
		draw_polyline(rotated, Color(0.0, 0.0, 0.0, 0.25 * fade), 1.0, true)
