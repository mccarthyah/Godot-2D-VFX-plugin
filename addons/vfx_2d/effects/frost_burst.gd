class_name FrostBurstEffect
extends VFXEffect
## Angular ice: hard-edged shards thrown outward, a cold flash, then a slow
## crystalline shimmer as they fall. Deliberately sharp next to the round
## explosion, so the two read as different damage types.
##
## Spawn it with [code]VFX2D.frost_burst(at, {"shard_count": 20})[/code].

const VFXShapes := preload("../core/vfx_shapes.gd")

@export_group("Shards")
@export_range(1, 96, 1) var shard_count: int = 16
@export_range(4.0, 80.0, 0.5, "suffix:px") var shard_size: float = 15.0
@export_range(0.0, 2400.0, 10.0, "suffix:px/s") var speed: float = 340.0
@export_range(0.0, 2000.0, 10.0) var gravity: float = 420.0
@export_range(0.0, 8.0, 0.05) var drag: float = 1.4
@export_range(-24.0, 24.0, 0.5, "suffix:rad/s") var spin_speed: float = 5.5
@export_range(0.0, 1.0, 0.01) var shimmer: float = 0.6
@export var shard_color: Color = Color(0.72, 0.9, 1.0)
@export var shard_core: Color = Color(0.95, 0.99, 1.0)
@export var flash_color: Color = Color(0.62, 0.86, 1.0)

@export_group("Chaos")
## Shard shape, size and launch scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.5

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _shards: Array[Dictionary] = []
var _flash: PackedVector2Array = PackedVector2Array()


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_shards.clear()
	_flash = VFXShapes.star_burst(shard_size * 0.5, shard_size * 2.2, 7, 0.0, _rng)
	for i in range(maxi(shard_count, 1)):
		var angle: float = _rng.randf_range(-PI, PI)
		var launch: float = speed * _rng.randf_range(0.55, 1.25) * (1.0 + chaos * 0.35)
		_shards.append({
			"position": Vector2.ZERO,
			"velocity": Vector2(cos(angle), sin(angle)) * launch,
			"angle": _rng.randf_range(-PI, PI),
			"spin": _rng.randf_range(-spin_speed, spin_speed),
			"size": shard_size * _rng.randf_range(0.5, 1.5),
			"sides": _rng.randi_range(3, 5),
			"twist": _rng.randf_range(0.6, 1.4),
		})


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	for shard in _shards:
		var velocity: Vector2 = shard["velocity"]
		velocity.y += gravity * delta
		velocity -= velocity * drag * delta
		shard["velocity"] = velocity
		shard["position"] = Vector2(shard["position"]) + velocity * delta
		shard["angle"] = float(shard["angle"]) + float(shard["spin"]) * delta


func _on_stop() -> void:
	_progress = 1.0


## Live shard count; exposed for tests.
func get_shard_count() -> int:
	return _shards.size()


func _draw() -> void:
	if _progress >= 1.0:
		return
	var fade: float = 1.0 - smoothstep(0.55, 1.0, _progress)
	if fade <= 0.01:
		return
	_draw_flash(fade)
	for shard in _shards:
		_draw_shard(shard, fade)


func _draw_flash(fade: float) -> void:
	var local: float = clampf(_progress / 0.3, 0.0, 1.0)
	if local >= 1.0 or _flash.size() < 3:
		return
	var grow: float = 0.5 + local * 0.9
	var points := PackedVector2Array()
	for offset in _flash:
		points.append(offset * grow)
	draw_colored_polygon(points, Color(flash_color, 0.35 * (1.0 - local) * fade))
	draw_circle(Vector2.ZERO, shard_size * 0.7, Color(shard_core, 0.7 * (1.0 - local)))


func _draw_shard(shard: Dictionary, fade: float) -> void:
	var size: float = float(shard["size"]) * (1.0 - _progress * 0.25)
	if size <= 0.5:
		return
	var angle: float = float(shard["angle"])
	var sides: int = int(shard["sides"])
	var twist: float = float(shard["twist"])
	var outline := PackedVector2Array()
	outline.resize(sides)
	for i in range(sides):
		var step: float = TAU * float(i) / float(sides) + angle
		var reach: float = size * (1.0 if i % 2 == 0 else twist * 0.55)
		outline[i] = Vector2(cos(step), sin(step)) * reach
	for i in range(outline.size()):
		outline[i] += Vector2(shard["position"])
	draw_colored_polygon(outline, Color(shard_color, 0.5 * fade))
	draw_polyline(_closed(outline), Color(shard_core, 0.7 * fade), 1.4, true)
	# A short specular line sells "ice" more than any gradient would.
	var glint: Vector2 = outline[0].lerp(outline[mini(1, sides - 1)], 0.4)
	if shimmer > 0.0:
		var flicker: float = 0.5 + 0.5 * sin(_progress * 26.0 + float(shard["twist"]) * 9.0)
		draw_line(glint, glint + Vector2(cos(angle), sin(angle)) * size * 0.7,
				Color(shard_core, shimmer * flicker * fade), 1.2, true)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(points)
	if points.size() > 0:
		out.append(points[0])
	return out
