class_name ChainLightningEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## A bolt that hops between several points: each hop is its own jagged segment,
## revealed one after another, dimmer than the last. Use it for chained hits,
## fork attacks and multi-target shocks.
##
## Spawn it with [code]Sparkform.chain(from, [enemy_a.global_position, ...])[/code].

@export_group("Chain")
## Hops in this node's local space. The first entry is where the chain starts;
## [code]Sparkform.chain()[/code] builds this from the spawn point and the targets.
@export var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO,
		Vector2(160.0, -40.0)])
@export_range(3, 64, 1) var segments: int = 13
## Seconds between one hop appearing and the next.
@export_range(0.0, 0.5, 0.01, "suffix:s") var hop_delay: float = 0.06
## Brightness of each hop relative to the one before it.
@export_range(0.2, 1.0, 0.01) var falloff: float = 0.78
## Sideways wobble of the bolt, in pixels.
@export_range(0.0, 64.0, 0.5, "suffix:px") var jaggedness: float = 14.0
## How often the bolt re-jags itself, in seconds ([code]0[/code] freezes it).
@export_range(0.0, 0.5, 0.01, "suffix:s") var flicker: float = 0.05
@export_range(1.0, 12.0, 0.5, "suffix:px") var width: float = 3.0
@export var bolt_color: Color = Color(0.62, 0.78, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Chaos")
## Per-hop jaggedness, hop timing and flash scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.5

var _rng := RandomNumberGenerator.new()
var _progress: float = 0.0
var _bolts: Array[PackedVector2Array] = []
var _jag_clock: float = 0.0


func _on_play() -> void:
	_rng.randomize()
	_progress = 0.0
	_jag_clock = 0.0
	_rebuild()


func _on_update(progress_value: float, delta: float) -> void:
	_progress = progress_value
	if flicker <= 0.0:
		return
	_jag_clock += delta
	if _jag_clock >= flicker:
		_jag_clock = 0.0
		_rebuild()


func _on_stop() -> void:
	_progress = 1.0


## Number of hops in the chain; exposed for tests.
func get_hop_count() -> int:
	return maxi(points.size() - 1, 0)


## Points of the first hop; exposed for tests.
func get_first_hop() -> PackedVector2Array:
	return _bolts[0] if not _bolts.is_empty() else PackedVector2Array()


func _rebuild() -> void:
	_bolts.clear()
	for hop in range(get_hop_count()):
		_bolts.append(_build_hop(points[hop], points[hop + 1]))


func _build_hop(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps: int = maxi(segments, 3)
	out.resize(steps + 1)
	var axis: Vector2 = to - from
	var normal := Vector2(-axis.y, axis.x).normalized()
	var amplitude: float = jaggedness * (0.75 + chaos * 0.6)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var offset: float = 0.0
		if i > 0 and i < steps:
			offset = _rng.randf_range(-amplitude, amplitude) * sin(PI * t)
		out[i] = from + axis * t + normal * offset
	return out


func _draw() -> void:
	if _progress >= 1.0:
		return
	var fade: float = 1.0 - smoothstep(0.72, 1.0, _progress)
	if fade <= 0.01:
		return
	var hop_time: float = maxf(hop_delay, 0.001)
	for hop in range(_bolts.size()):
		var local: float = clampf((_progress * duration - float(hop) * hop_time) / 0.06,
				0.0, 1.0)
		if local <= 0.0:
			continue
		var strength: float = pow(falloff, float(hop)) * fade
		var bolt: PackedVector2Array = _bolts[hop]
		var shown: int = clampi(int(local * float(bolt.size())), 2, bolt.size())
		var slice := PackedVector2Array()
		for i in range(shown):
			slice.append(bolt[i])
		draw_polyline(slice, Color(bolt_color, 0.35 * strength), width * 3.4, true)
		draw_polyline(slice, Color(core_color, 0.95 * strength), width, true)
		var tip: Vector2 = slice[slice.size() - 1]
		draw_circle(tip, width * 2.2, Color(core_color, 0.7 * strength))
		draw_circle(tip, width * 4.0, Color(bolt_color, 0.25 * strength))
		if local >= 0.999:
			draw_circle(points[hop], width * 1.6, Color(core_color, 0.6 * strength))
