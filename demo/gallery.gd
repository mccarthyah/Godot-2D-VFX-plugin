extends Node2D
## Visual gallery for every effect in the kit: one labelled cell per effect, each
## firing on its own timer, so all four can be judged side by side.
##
## Run it on its own with [code]godot --path . res://demo/gallery.tscn[/code], or
## open the scene in the editor and press F6. Unlike the interactive demo there is
## nothing to drive: the cells cycle by themselves.
##
## [b]Space[/b] pauses the timers, [b]R[/b] fires all four immediately,
## [b]C[/b] clears running effects, [b]1[/b]-[b]4[/b] or a click inside a cell fires
## just that effect, and [b]Esc[/b] returns to the interactive demo.

const MARGIN: float = 24.0
const GAP: float = 20.0
const HEADER_HEIGHT: float = 104.0
const GRID_STEP: float = 64.0
const DEMO_SCENE: String = "res://demo/main.tscn"

const BACKGROUND := Color(0.045, 0.055, 0.075)
const GRID_COLOR := Color(0.09, 0.11, 0.15)
const PANEL_FILL := Color(0.07, 0.09, 0.13)
const PANEL_EDGE := Color(0.16, 0.22, 0.3)
const TITLE_COLOR := Color(0.84, 0.91, 1.0)
const NOTE_COLOR := Color(0.52, 0.64, 0.78)

## One entry per cell: heading, the knobs in play, accent colour, and its timer.
## [code]phase[/code] staggers the start so the cells do not fire in lockstep.
const CELLS := [
	{
		"title": "1 · Hit spark",
		"note": "18 sparks · 360 px/s · 60 C++ streaks",
		"accent": Color(1.0, 0.86, 0.45),
		"interval": 0.9,
		"phase": 0.0,
	},
	{
		"title": "2 · Explosion",
		"note": "radius 70 · 26 debris · 260 C++ streaks",
		"accent": Color(1.0, 0.52, 0.16),
		"interval": 1.7,
		"phase": 0.45,
	},
	{
		"title": "3 · Lightning",
		"note": "16 segments · 3 branches · 0.35 s",
		"accent": Color(0.45, 0.72, 1.0),
		"interval": 1.3,
		"phase": 0.9,
	},
	{
		"title": "4 · Cooldown ring",
		"note": "1.8 s fill · 12 ticks",
		"accent": Color(0.42, 0.9, 1.0),
		"interval": 2.6,
		"phase": 0.2,
	},
]

var _rng := RandomNumberGenerator.new()
var _timers: PackedFloat32Array = PackedFloat32Array()
var _flashes: PackedFloat32Array = PackedFloat32Array()
var _paused: bool = false
var _ring_target: Node2D = null


func _ready() -> void:
	_rng.randomize()
	for cell in CELLS:
		_timers.append(float(cell["phase"]))
		_flashes.append(0.0)
	_ring_target = Node2D.new()
	_ring_target.name = "RingTarget"
	add_child(_ring_target)


func _process(delta: float) -> void:
	for index in _flashes.size():
		if _flashes[index] > 0.0:
			_flashes[index] = maxf(0.0, _flashes[index] - delta * 2.0)
	if not _paused:
		for index in _timers.size():
			_timers[index] += delta
			if _timers[index] >= float(CELLS[index]["interval"]):
				_timers[index] -= float(CELLS[index]["interval"])
				_fire(index)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for index in CELLS.size():
				if _cell_rect(index).has_point(event.position):
					_fire(index)
					return
		return
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_R:
			for index in CELLS.size():
				_fire(index)
		KEY_C:
			VFX2D.stop_all()
		KEY_1:
			_fire(0)
		KEY_2:
			_fire(1)
		KEY_3:
			_fire(2)
		KEY_4:
			_fire(3)
		KEY_ESCAPE:
			if ResourceLoader.exists(DEMO_SCENE):
				get_tree().change_scene_to_file(DEMO_SCENE)


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), BACKGROUND, true)
	var x: float = 0.0
	while x <= view.x:
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y <= view.y:
		draw_line(Vector2(0.0, y), Vector2(view.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP
	_draw_header()
	for index in CELLS.size():
		_draw_cell(index)
	_draw_status(view)


func _draw_header() -> void:
	_draw_text("2D VFX Kit — effect gallery", Vector2(MARGIN, HEADER_HEIGHT - 54.0),
			26, TITLE_COLOR)
	var hint: String = "Space pause · R refire all · C clear · 1-4 or click: fire one cell"
	hint += "   ·   every cell cycles on its own timer"
	if ResourceLoader.exists(DEMO_SCENE):
		hint += "   ·   Esc: back to the demo"
	_draw_text(hint, Vector2(MARGIN, HEADER_HEIGHT - 24.0), 14, NOTE_COLOR)


func _draw_status(view: Vector2) -> void:
	var streaks: String = "on" if VFXStreaks.is_available() else "off"
	var status := "FPS %d   ·   active %d   ·   C++ streaks %s" % [
			Engine.get_frames_per_second(),
			VFX2D.get_active_count(),
			streaks,
	]
	if _paused:
		status += "   ·   PAUSED"
	var width: float = 460.0
	draw_string(ThemeDB.fallback_font, Vector2(view.x - MARGIN - width, HEADER_HEIGHT - 54.0),
			status, HORIZONTAL_ALIGNMENT_RIGHT, width, 15, NOTE_COLOR)


func _draw_cell(index: int) -> void:
	var rect: Rect2 = _cell_rect(index)
	var cell: Dictionary = CELLS[index]
	var accent: Color = cell["accent"]
	var flash: float = clampf(_flashes[index], 0.0, 1.0)
	draw_rect(rect, PANEL_FILL, true)
	draw_rect(rect, PANEL_EDGE.lerp(accent, flash), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)),
			accent.lerp(Color.WHITE, flash * 0.5), true)
	_draw_text(String(cell["title"]), rect.position + Vector2(18.0, 32.0), 18, TITLE_COLOR)
	_draw_text(String(cell["note"]), rect.position + Vector2(18.0, 54.0), 13, NOTE_COLOR)
	_draw_marker(index, _cell_center(index), accent)


func _draw_marker(index: int, center: Vector2, accent: Color) -> void:
	var faint := Color(accent.r, accent.g, accent.b, 0.3)
	if index == 3:
		draw_circle(center, 46.0, Color(accent.r, accent.g, accent.b, 0.07))
		draw_arc(center, 46.0, 0.0, TAU, 64, faint, 1.0, true)
	draw_line(center - Vector2(12.0, 0.0), center - Vector2(4.0, 0.0), faint, 1.0)
	draw_line(center + Vector2(4.0, 0.0), center + Vector2(12.0, 0.0), faint, 1.0)
	draw_line(center - Vector2(0.0, 12.0), center - Vector2(0.0, 4.0), faint, 1.0)
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(0.0, 12.0), faint, 1.0)


func _draw_text(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _cell_rect(index: int) -> Rect2:
	var view: Vector2 = get_viewport_rect().size
	var size := Vector2(
			maxf((view.x - MARGIN * 2.0 - GAP) * 0.5, 160.0),
			maxf((view.y - HEADER_HEIGHT - MARGIN - GAP) * 0.5, 120.0))
	var col: int = index % 2
	var row: int = int(index / 2.0)
	var origin := Vector2(
			MARGIN + float(col) * (size.x + GAP),
			HEADER_HEIGHT + float(row) * (size.y + GAP))
	return Rect2(origin, size)


func _cell_center(index: int) -> Vector2:
	var rect: Rect2 = _cell_rect(index)
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 26.0)


func _fire(index: int) -> void:
	if index < 0 or index >= CELLS.size():
		return
	_flashes[index] = 1.0
	var center: Vector2 = _cell_center(index)
	match index:
		0:
			var direction := Vector2.from_angle(_rng.randf_range(-PI, PI))
			VFX2D.hit_spark(center, direction, {"spark_count": 18, "spark_speed": 360.0})
		1:
			VFX2D.explosion(center, {"radius": 70.0})
		2:
			VFX2D.lightning(center + Vector2(-170.0, -46.0), center + Vector2(170.0, 34.0),
					{"segments": 16, "branches": 3, "duration": 0.35})
		3:
			if is_instance_valid(_ring_target):
				_ring_target.position = center
				VFX2D.cooldown_ring(_ring_target, 1.8,
						{"radius": 46.0, "width": 9.0, "tick_count": 12})
