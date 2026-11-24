class_name ShieldBubble
extends Node2D
## Reactive energy bubble: a hex lattice over a dome that flashes where it is
## struck, then fades when you stop it. Unlike the other modifiers this one
## listens to gameplay: call [method hit] with a world position.
##
## [codeblock]
## var bubble := VFX2D.shield(player, {"radius": 72.0})
## bubble.hit(enemy.global_position)        # impact feedback
## bubble.stop()                            # fade out and free
## [/codeblock]

signal finished

@export_group("Shape")
@export_range(8.0, 512.0, 1.0, "suffix:px") var radius: float = 64.0
@export_range(4.0, 64.0, 0.5, "suffix:px") var hex_size: float = 13.0
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.12
@export_range(1.0, 8.0, 0.5, "suffix:px") var rim_width: float = 2.5

@export_group("Timing")
## Close on its own after this many seconds; [code]0[/code] holds until stopped.
@export_range(0.0, 120.0, 0.1, "suffix:s") var lifetime: float = 0.0
@export_range(0.05, 2.0, 0.01, "suffix:s") var fade_time: float = 0.2
## How long a hit flash lasts.
@export_range(0.05, 2.0, 0.01, "suffix:s") var hit_flash: float = 0.3

@export_group("Colors")
@export var rim_color: Color = Color(0.55, 0.85, 1.0)
@export var fill_color: Color = Color(0.4, 0.7, 1.0)
@export var hit_color: Color = Color(1.0, 0.98, 0.9)

@export_group("Chaos")
## Lattice jitter, breathing and hit ripple scatter.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.3
@export var free_on_finish: bool = true

var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _openness: float = 0.0
var _closing: bool = false
var _hexes: Array[Dictionary] = []
var _hits: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)
	_rng.randomize()


## Opens the bubble. Called by [code]VFX2D.shield()[/code].
func start() -> void:
	_elapsed = 0.0
	_openness = 0.0
	_closing = false
	_hits.clear()
	_build_hexes()
	visible = true
	set_process(true)
	queue_redraw()


## Fades the bubble out and frees it when [member free_on_finish] is set.
func stop() -> void:
	if _closing:
		return
	_closing = true
	set_process(true)


func is_running() -> bool:
	return _openness > 0.0 and not _closing


## Current opening amount, [code]0.0[/code] to [code]1.0[/code].
func get_openness() -> float:
	return _openness


## Number of lattice cells; exposed for tests.
func get_hex_count() -> int:
	return _hexes.size()


## Number of recent hits still showing; exposed for tests.
func get_hit_count() -> int:
	return _hits.size()


## Registers an impact at a world-space point. Safe to call every frame.
func hit(world_point: Vector2, strength: float = 1.0) -> void:
	var local: Vector2 = to_local(world_point)
	if local.length() > radius:
		local = local.normalized() * radius
	_hits.append({
		"position": local,
		"age": 0.0,
		"strength": clampf(strength, 0.1, 2.0),
		"phase": _rng.randf_range(-PI, PI),
	})
	while _hits.size() > 6:
		_hits.remove_at(0)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _closing:
		_openness = maxf(0.0, _openness - delta / maxf(fade_time, 0.01))
		if _openness <= 0.0:
			_finish()
			return
	else:
		_openness = minf(1.0, _openness + delta / 0.15)
		if lifetime > 0.0 and _elapsed >= lifetime:
			stop()
	for index in range(_hits.size() - 1, -1, -1):
		_hits[index]["age"] = float(_hits[index]["age"]) + delta
		if float(_hits[index]["age"]) > hit_flash:
			_hits.remove_at(index)
	queue_redraw()


func _finish() -> void:
	set_process(false)
	finished.emit()
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


func _build_hexes() -> void:
	_hexes.clear()
	var spacing: float = hex_size * 1.6
	var step: Vector2 = Vector2(spacing * 1.5, spacing * 0.866)
	var rows: int = int(radius / step.y) + 1
	for row in range(-rows, rows + 1):
		for col in range(-rows, rows + 1):
			var center := Vector2(float(col) * step.x + (step.x * 0.5 if row % 2 != 0 else 0.0),
					float(row) * step.y)
			if center.length() > radius - hex_cell_margin():
				continue
			_hexes.append({
				"center": center,
				"size": hex_size * _rng.randf_range(0.78, 1.0),
				"phase": _rng.randf_range(-PI, PI),
			})


func hex_cell_margin() -> float:
	return hex_size * (0.6 + chaos * 0.4)


func _draw() -> void:
	if _openness <= 0.001:
		return
	var breathe: float = 1.0 + sin(_elapsed * 2.6) * 0.02 * (1.0 + chaos)
	draw_circle(Vector2.ZERO, radius * _openness,
			Color(fill_color, fill_alpha * _openness))
	draw_arc(Vector2.ZERO, radius * _openness * breathe, 0.0, TAU, 72,
			Color(rim_color, 0.55 * _openness), rim_width, true)
	draw_arc(Vector2.ZERO, radius * _openness * breathe * 0.94, -PI * 0.05, PI * 0.55, 40,
			Color(rim_color, 0.35 * _openness), rim_width * 0.6, true)
	_draw_lattice(breathe)
	_draw_hits()


func _draw_lattice(breathe: float) -> void:
	for cell in _hexes:
		var center: Vector2 = cell["center"] * breathe
		var glow: float = hit_glow_at(center)
		var color: Color = rim_color.lerp(hit_color, clampf(glow, 0.0, 1.0))
		var alpha: float = (0.16 + glow * 0.7) * _openness
		draw_polyline(_hexagon(center, float(cell["size"]) * breathe),
				Color(color, alpha), 1.2, true)


func _draw_hits() -> void:
	for entry in _hits:
		var local: float = clampf(float(entry["age"]) / maxf(hit_flash, 0.01), 0.0, 1.0)
		var strength: float = float(entry["strength"])
		var position: Vector2 = entry["position"]
		var ring_radius: float = 6.0 + local * 34.0 * strength
		draw_arc(position, ring_radius, 0.0, TAU, 24,
				Color(hit_color, 0.7 * (1.0 - local) * _openness), 2.2, true)
		for i in range(3):
			var angle: float = float(entry["phase"]) + TAU * float(i) / 3.0
			var unit := Vector2(cos(angle), sin(angle))
			draw_line(position + unit * ring_radius * 0.55,
					position + unit * ring_radius * 1.15,
					Color(hit_color, 0.45 * (1.0 - local)), 1.5, true)


func hit_glow_at(position: Vector2) -> float:
	var best: float = 0.0
	for entry in _hits:
		var local: float = clampf(float(entry["age"]) / maxf(hit_flash, 0.01), 0.0, 1.0)
		var distance: float = position.distance_to(entry["position"])
		var reach: float = 30.0 * float(entry["strength"])
		if distance > reach:
			continue
		best = maxf(best, (1.0 - local) * (1.0 - distance / reach))
	return best


func _hexagon(center: Vector2, size: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(7):
		var angle: float = TAU * float(i) / 6.0
		out.append(center + Vector2(cos(angle), sin(angle)) * size)
	return out
