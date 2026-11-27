class_name LightningEffect
extends "res://addons/sparkform/core/vfx_effect.gd"
## Procedural lightning bolt with optional branches and flicker.
##
## The bolt is regenerated a few times per second while it is alive, which reads
## as electrical flicker. Spawn it with
## [code]Sparkform.lightning(from, to, {"branches": 3})[/code].

## Endpoint of the bolt, in this node's local space. The convenience method sets
## it from the [code]to[/code] argument minus [code]from[/code].
@export var end_offset: Vector2 = Vector2(220.0, 0.0)
## Outer bolt tint.
@export var bolt_color: Color = Color(0.55, 0.75, 1.0)
## Hot core tint.
@export var core_color: Color = Color(1.0, 1.0, 1.0)
## Displacement steps; more is more jagged.
@export_range(2, 64, 1) var segments: int = 14
## How far the bolt strays from the straight line between its endpoints.
@export_range(0.0, 2.0, 0.01) var jaggedness: float = 0.45
## Bolt line width in pixels.
@export_range(0.5, 40.0, 0.5, "suffix:px") var width: float = 3.5
## Forked side bolts per strike.
@export_range(0, 8, 1) var branches: int = 2
## [code]0[/code] freezes the bolt in shape, [code]1[/code] reshapes it at the
## fastest flicker rate.
@export_range(0.0, 1.0, 0.01) var flicker: float = 0.6
## Seconds between bolt regenerations.
@export_range(0.01, 0.5, 0.01, "suffix:s") var flicker_interval: float = 0.05

@export_group("Chaos")
## How wild the bolt is: [code]0[/code] keeps the configured branch count and a
## stable silhouette, [code]1[/code] adds and drops branches per flicker, grows
## sub-branches and throws stray arcs.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.65

var _rng := RandomNumberGenerator.new()
var _bolt: PackedVector2Array = PackedVector2Array()
var _branch_bolts: Array[PackedVector2Array] = []
var _sputters: Array[PackedVector2Array] = []
var _flicker_clock: float = 0.0
var _alpha: float = 0.0


func _on_play() -> void:
	_rng.randomize()
	_flicker_clock = 0.0
	_alpha = 1.0
	_regenerate()


func _on_update(progress_value: float, delta: float) -> void:
	if flicker > 0.0:
		_flicker_clock += delta
		if _flicker_clock >= flicker_interval / maxf(flicker, 0.05):
			_flicker_clock = 0.0
			_regenerate()
	_alpha = 1.0 - smoothstep(0.65, 1.0, progress_value)


func _on_stop() -> void:
	_alpha = 0.0


## Current bolt polyline, in local space. Exposed for tests and tooling.
func get_bolt_points() -> PackedVector2Array:
	return _bolt


## Current branch polylines, in local space.
func get_branch_points() -> Array[PackedVector2Array]:
	return _branch_bolts


## Current stray arcs, in local space. Only present with [member chaos] above 0.
func get_sputter_points() -> Array[PackedVector2Array]:
	return _sputters


func _regenerate() -> void:
	_bolt = _make_bolt(Vector2.ZERO, end_offset, segments)
	_branch_bolts.clear()
	_sputters.clear()
	var span: float = end_offset.length()
	if span < 8.0 or _bolt.size() < 4:
		return
	# Chaos wobbles the branch count per flicker instead of pinning it.
	var jitter: int = roundi(_rng.randf_range(-1.0, 1.0) * chaos * 2.0)
	var branch_total: int = maxi(branches + jitter, 0)
	for _i in range(branch_total):
		var anchor: Vector2 = _bolt[_rng.randi_range(1, _bolt.size() - 2)]
		var direction: Vector2 = end_offset.normalized().rotated(_rng.randf_range(-1.1, 1.1))
		var branch_length: float = span * _rng.randf_range(0.12, 0.35)
		var branch := _make_bolt(anchor, anchor + direction * branch_length,
				maxi(segments / 3, 3))
		_branch_bolts.append(branch)
		# Sub-branches hang off the branch itself, which is what makes real bolts
		# look like a tree rather than a comb.
		if branch.size() >= 4 and _rng.randf() < chaos * 0.75:
			var fork_at: Vector2 = branch[_rng.randi_range(1, branch.size() - 2)]
			var fork_direction: Vector2 = direction.rotated(_rng.randf_range(-1.2, 1.2))
			var fork_length: float = branch_length * _rng.randf_range(0.35, 0.7)
			_branch_bolts.append(_make_bolt(fork_at, fork_at + fork_direction * fork_length,
					maxi(segments / 5, 2)))
	if branches <= 0 or _rng.randf() >= chaos * 0.65:
		return
	for _i in range(_rng.randi_range(1, 2)):
		var start: Vector2 = _bolt[_rng.randi_range(1, _bolt.size() - 2)]
		var stray: Vector2 = Vector2.from_angle(_rng.randf_range(-PI, PI)) \
				* span * _rng.randf_range(0.05, 0.16)
		_sputters.append(_make_bolt(start, start + stray, 4))


func _make_bolt(from: Vector2, to: Vector2, seg_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(seg_count, 2)
	var normal: Vector2 = (to - from).orthogonal()
	if normal.length_squared() < 0.0001:
		normal = Vector2.RIGHT
	normal = normal.normalized()
	var amplitude: float = (to - from).length() * jaggedness * 0.18
	points.resize(count + 1)
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var point: Vector2 = from.lerp(to, t)
		if i > 0 and i < count:
			point += normal * _rng.randf_range(-amplitude, amplitude) * sin(t * PI)
		points[i] = point
	return points


func _draw() -> void:
	if _alpha <= 0.01 or _bolt.size() < 2:
		return
	draw_polyline(_bolt, Color(bolt_color, 0.22 * _alpha), maxf(1.0, width * 4.0), true)
	draw_polyline(_bolt, Color(bolt_color, 0.6 * _alpha), maxf(1.0, width * 1.8), true)
	draw_polyline(_bolt, Color(core_color, _alpha), maxf(0.5, width * 0.7), true)
	for branch in _branch_bolts:
		if branch.size() < 2:
			continue
		draw_polyline(branch, Color(bolt_color, 0.35 * _alpha), maxf(0.5, width * 0.6), true)
	for sputter in _sputters:
		if sputter.size() < 2:
			continue
		draw_polyline(sputter, Color(core_color, 0.28 * _alpha), maxf(0.5, width * 0.35), true)
