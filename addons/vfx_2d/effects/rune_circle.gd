class_name RuneCircle
extends Node2D
## Persistent cast circle: a rotating ring of ticks and glyphs under a caster,
## with an optional progressive fill that doubles as a cast bar.
##
## Unlike the one-shot effects this node stays until you stop it:
## [codeblock]
## var rune := VFX2D.rune_circle(caster, 1.5, {"fill": 0.0})
## rune.set_fill(cast_progress)   # drive it yourself
## rune.stop()
## [/codeblock]

signal finished

## Seconds until it closes on its own; [code]0[/code] means it runs until stopped.
@export_range(0.0, 60.0, 0.01, "suffix:s") var lifetime: float = 0.0
@export_range(4.0, 512.0, 1.0, "suffix:px") var radius: float = 54.0
@export_range(3, 64, 1) var segments: int = 12
@export_range(-8.0, 8.0, 0.05, "suffix:rad/s") var spin_speed: float = 0.7
## Progressive fill from 12 o'clock, [code]0.0[/code] to [code]1.0[/code].
@export_range(0.0, 1.0, 0.01) var fill: float = 0.0
@export var rune_color: Color = Color(0.72, 0.62, 1.0)
@export var fill_color: Color = Color(0.92, 0.86, 1.0)
@export_range(0.0, 64.0, 0.5, "suffix:px") var tick_length: float = 9.0
@export_range(0.0, 1.0, 0.01) var pulse: float = 0.35
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.25
@export var free_on_finish: bool = true

var _running: bool = false
var _elapsed: float = 0.0
var _spin: float = 0.0
var _rng := RandomNumberGenerator.new()
var _jitter: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	set_process(false)
	_rng.randomize()
	_reseed_jitter()
	queue_redraw()


## Starts (or restarts) the circle. [param seconds] overrides [member lifetime]
## when it is greater than zero.
func start(seconds: float = -1.0) -> void:
	if seconds > 0.0:
		lifetime = seconds
	_elapsed = 0.0
	_spin = 0.0
	_running = true
	visible = true
	set_process(true)
	queue_redraw()


## Stops the circle and emits [signal finished].
func stop() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	finished.emit()
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


## Returns [code]true[/code] while the circle is running.
func is_running() -> bool:
	return _running


## Sets the progressive fill, clamped to [code]0..1[/code].
func set_fill(value: float) -> void:
	fill = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_spin += spin_speed * delta
	if lifetime > 0.0 and _elapsed >= lifetime:
		stop()
		return
	queue_redraw()


func _reseed_jitter() -> void:
	_jitter.clear()
	for i in range(maxi(segments, 1) * 2):
		_jitter.append(_rng.randf_range(-1.0, 1.0))


func _draw() -> void:
	var breathe: float = 1.0 + pulse * 0.08 * sin(_elapsed * 5.0)
	var glow_alpha: float = 0.12 + 0.08 * pulse * sin(_elapsed * 3.0)
	draw_circle(Vector2.ZERO, radius * 0.85, Color(rune_color, glow_alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(rune_color, 0.55), 1.5, true)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(rune_color, 0.25), 1.0, true)
	_draw_ticks(breathe)
	if fill > 0.001:
		var sweep: float = TAU * clampf(fill, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + sweep, 72,
				Color(fill_color, 0.9), 3.0, true)
		var head: Vector2 = Vector2.from_angle(-PI * 0.5 + sweep) * radius
		draw_circle(head, 3.5, Color(fill_color, 0.95))


func _draw_ticks(breathe: float) -> void:
	var count: int = maxi(segments, 1)
	for i in range(count):
		var jitter: float = 0.0
		if i < _jitter.size():
			jitter = _jitter[i] * chaos * 0.05
		var angle: float = _spin + TAU * float(i) / float(count) + jitter
		var unit := Vector2(cos(angle), sin(angle))
		var inner: float = radius - tick_length * (0.4 + breathe * 0.6)
		draw_line(unit * inner, unit * radius, Color(rune_color, 0.8), 1.5, true)
		# Every other tick gets a small glyph dash across the ring.
		if i % 2 != 0:
			continue
		var glyph_center: float = radius * 0.86
		var tangent := Vector2(-unit.y, unit.x)
		draw_line(unit * glyph_center - tangent * 4.0, unit * glyph_center + tangent * 4.0,
				Color(rune_color, 0.6), 1.5, true)
