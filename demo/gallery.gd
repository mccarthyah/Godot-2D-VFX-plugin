extends Node2D
## Visual gallery for every effect in the kit: one labelled cell per effect, each
## firing on its own timer, so all sixteen can be judged side by side: the eleven
## one-shots, the cooldown ring, and the four persistent modifiers (rune circle,
## portal, beam, trail).
##
## Run it on its own with [code]godot --path . res://demo/gallery.tscn[/code], or
## open the scene in the editor and press F6. Unlike the interactive demo there is
## nothing to drive: the cells cycle by themselves.
##
## [b]Space[/b] pauses the timers, [b]R[/b] fires everything immediately,
## [b]C[/b] clears running effects, [b]1[/b]-[b]0[/b] or a click inside a cell
## fires just that effect ([b]Q W E R T Y[/b] cover cells 11-16), and [b]Esc[/b]
## returns to the interactive demo.

const MARGIN: float = 20.0
const GAP: float = 16.0
const HEADER_HEIGHT: float = 96.0
const GRID_STEP: float = 64.0
const COLUMNS: int = 4
const ROWS: int = 4
const DEMO_SCENE: String = "res://demo/main.tscn"

const BACKGROUND := Color(0.045, 0.055, 0.075)
const GRID_COLOR := Color(0.09, 0.11, 0.15)
const PANEL_FILL := Color(0.07, 0.09, 0.13)
const PANEL_EDGE := Color(0.16, 0.22, 0.3)
const TITLE_COLOR := Color(0.84, 0.91, 1.0)
const NOTE_COLOR := Color(0.52, 0.64, 0.78)

## One entry per cell: what to spawn, the knobs in play, accent colour and timer.
## [code]phase[/code] staggers the start so the cells do not fire in lockstep.
const CELLS := [
	{
		"effect": "hit_spark",
		"title": "1 · Hit spark",
		"note": "16 sparks · 60 C++ streaks",
		"accent": Color(1.0, 0.86, 0.45),
		"interval": 0.9,
		"phase": 0.0,
	},
	{
		"effect": "explosion",
		"title": "2 · Explosion",
		"note": "radius 52 · 260 C++ streaks",
		"accent": Color(1.0, 0.52, 0.16),
		"interval": 1.7,
		"phase": 0.45,
	},
	{
		"effect": "lightning",
		"title": "3 · Lightning",
		"note": "3 branches · sub-branches · flicker",
		"accent": Color(0.45, 0.72, 1.0),
		"interval": 1.3,
		"phase": 0.9,
	},
	{
		"effect": "cooldown_ring",
		"title": "4 · Cooldown ring",
		"note": "1.8 s fill · 12 ticks",
		"accent": Color(0.42, 0.9, 1.0),
		"interval": 2.6,
		"phase": 0.2,
	},
	{
		"effect": "smoke_puff",
		"title": "5 · Smoke puff",
		"note": "9 blobs · billow + drift",
		"accent": Color(0.78, 0.8, 0.86),
		"interval": 1.5,
		"phase": 0.6,
	},
	{
		"effect": "shockwave",
		"title": "6 · Shockwave",
		"note": "2 rings · 12 cracks",
		"accent": Color(0.72, 0.92, 1.0),
		"interval": 1.1,
		"phase": 1.0,
	},
	{
		"effect": "muzzle_flash",
		"title": "7 · Muzzle flash",
		"note": "torn cone · 120 C++ streaks",
		"accent": Color(1.0, 0.74, 0.35),
		"interval": 0.8,
		"phase": 0.3,
	},
	{
		"effect": "heal_sparkle",
		"title": "8 · Heal sparkle",
		"note": "16 motes · twinkle + rise",
		"accent": Color(0.55, 1.0, 0.72),
		"interval": 1.9,
		"phase": 1.2,
	},
	{
		"effect": "slash_arc",
		"title": "9 · Slash arc",
		"note": "120° crescent · torn edge",
		"accent": Color(0.78, 0.92, 1.0),
		"interval": 1.2,
		"phase": 0.15,
	},
	{
		"effect": "debris_burst",
		"title": "10 · Debris burst",
		"note": "14 chunks · gravity + spin",
		"accent": Color(0.86, 0.74, 0.58),
		"interval": 1.6,
		"phase": 0.55,
	},
	{
		"effect": "ripple",
		"title": "11 · Ripple",
		"note": "3 wobbling rings · droplets",
		"accent": Color(0.5, 0.94, 1.0),
		"interval": 1.4,
		"phase": 0.95,
	},
	{
		"effect": "implosion",
		"title": "12 · Implosion",
		"note": "spiral motes → pinch flash",
		"accent": Color(0.86, 0.6, 1.0),
		"interval": 1.5,
		"phase": 1.35,
	},
	{
		"effect": "rune_circle",
		"title": "13 · Rune circle",
		"note": "rotating · fill = cast bar",
		"accent": Color(0.72, 0.62, 1.0),
		"interval": 2.2,
		"phase": 0.35,
	},
	{
		"effect": "portal",
		"title": "14 · Portal",
		"note": "open · hold · close",
		"accent": Color(0.66, 0.58, 1.0),
		"interval": 2.4,
		"phase": 0.8,
	},
	{
		"effect": "beam",
		"title": "15 · Beam",
		"note": "core + glow · travelling pulses",
		"accent": Color(0.6, 0.85, 1.0),
		"interval": 2.0,
		"phase": 1.1,
	},
	{
		"effect": "trail",
		"title": "16 · Trail",
		"note": "ribbon history · tapered tail",
		"accent": Color(0.68, 0.88, 1.0),
		"interval": 1.6,
		"phase": 1.5,
	},
]

var _rng := RandomNumberGenerator.new()
var _timers: PackedFloat32Array = PackedFloat32Array()
var _flashes: PackedFloat32Array = PackedFloat32Array()
var _paused: bool = false
var _clock: float = 0.0
var _ring_target: Node2D = null
var _rune_target: Node2D = null
var _trail_flyer: Node2D = null
var _persistent: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	for cell in CELLS:
		_timers.append(float(cell["phase"]))
		_flashes.append(0.0)
	_ring_target = Node2D.new()
	_ring_target.name = "RingTarget"
	add_child(_ring_target)
	_rune_target = Node2D.new()
	_rune_target.name = "RuneTarget"
	add_child(_rune_target)
	_trail_flyer = Node2D.new()
	_trail_flyer.name = "TrailFlyer"
	add_child(_trail_flyer)
	_trail_flyer.position = _cell_center(CELLS.size() - 1)


func _process(delta: float) -> void:
	_clock += delta
	_update_trail_flyer()
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
	var digit: int = event.keycode - KEY_1
	if digit >= 0 and digit < CELLS.size():
		_fire(digit)
		return
	if _fire_for_key(event.keycode):
		return
	match event.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_R:
			for index in CELLS.size():
				_fire(index)
		KEY_C:
			VFX2D.stop_all()
		KEY_ESCAPE:
			if ResourceLoader.exists(DEMO_SCENE):
				get_tree().change_scene_to_file(DEMO_SCENE)


## Maps [b]0[/b] and the [b]Q[/b]-[b]Y[/b] row onto cells 10-16.
func _fire_for_key(keycode: int) -> bool:
	var index: int = -1
	if keycode == KEY_0:
		index = 9
	else:
		var letters: Array = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
		var letter_index: int = letters.find(keycode)
		if letter_index >= 0:
			index = 10 + letter_index
	if index < 0 or index >= CELLS.size():
		return false
	_fire(index)
	return true


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
			24, TITLE_COLOR)
	var hint: String = "Space pause · R refire all · C clear · 1-0, Q-Y or click: fire one cell"
	hint += "   ·   every cell cycles on its own timer"
	if ResourceLoader.exists(DEMO_SCENE):
		hint += "   ·   Esc: back to the demo"
	_draw_text(hint, Vector2(MARGIN, HEADER_HEIGHT - 26.0), 13, NOTE_COLOR)


func _draw_status(view: Vector2) -> void:
	var streaks: String = "on" if VFXStreaks.is_available() else "off"
	var status := "FPS %d   ·   active %d   ·   persistent %d   ·   C++ streaks %s" % [
			Engine.get_frames_per_second(),
			VFX2D.get_active_count(),
			VFX2D.get_persistent_count(),
			streaks,
	]
	if _paused:
		status += "   ·   PAUSED"
	var width: float = 560.0
	draw_string(ThemeDB.fallback_font, Vector2(view.x - MARGIN - width, HEADER_HEIGHT - 54.0),
			status, HORIZONTAL_ALIGNMENT_RIGHT, width, 14, NOTE_COLOR)


func _draw_cell(index: int) -> void:
	var rect: Rect2 = _cell_rect(index)
	var cell: Dictionary = CELLS[index]
	var accent: Color = cell["accent"]
	var flash: float = clampf(_flashes[index], 0.0, 1.0)
	draw_rect(rect, PANEL_FILL, true)
	draw_rect(rect, PANEL_EDGE.lerp(accent, flash), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)),
			accent.lerp(Color.WHITE, flash * 0.5), true)
	_draw_text(String(cell["title"]), rect.position + Vector2(12.0, 22.0), 14, TITLE_COLOR)
	_draw_text(String(cell["note"]), rect.position + Vector2(12.0, 38.0), 10, NOTE_COLOR)
	_draw_marker(index, _cell_center(index), accent)


func _draw_marker(index: int, center: Vector2, accent: Color) -> void:
	var faint := Color(accent.r, accent.g, accent.b, 0.3)
	if index == 3:
		draw_circle(center, 40.0, Color(accent.r, accent.g, accent.b, 0.07))
		draw_arc(center, 40.0, 0.0, TAU, 64, faint, 1.0, true)
	draw_line(center - Vector2(12.0, 0.0), center - Vector2(4.0, 0.0), faint, 1.0)
	draw_line(center + Vector2(4.0, 0.0), center + Vector2(12.0, 0.0), faint, 1.0)
	draw_line(center - Vector2(0.0, 12.0), center - Vector2(0.0, 4.0), faint, 1.0)
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(0.0, 12.0), faint, 1.0)


func _draw_text(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _cell_rect(index: int) -> Rect2:
	var view: Vector2 = get_viewport_rect().size
	var size := Vector2(
			maxf((view.x - MARGIN * 2.0 - GAP * float(COLUMNS - 1)) / float(COLUMNS), 120.0),
			maxf((view.y - HEADER_HEIGHT - MARGIN - GAP * float(ROWS - 1)) / float(ROWS),
					104.0))
	var col: int = index % COLUMNS
	var row: int = int(index / float(COLUMNS))
	var offset := Vector2(
			MARGIN + float(col) * (size.x + GAP),
			HEADER_HEIGHT + float(row) * (size.y + GAP))
	return Rect2(offset, size)


func _cell_center(index: int) -> Vector2:
	var rect: Rect2 = _cell_rect(index)
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 22.0)


func _fire(index: int) -> void:
	if index < 0 or index >= CELLS.size():
		return
	_flashes[index] = 1.0
	var center: Vector2 = _cell_center(index)
	var span: float = _cell_rect(index).size.x
	match String(CELLS[index]["effect"]):
		"hit_spark":
			var direction := Vector2.from_angle(_rng.randf_range(-PI, PI))
			VFX2D.hit_spark(center, direction, {"spark_count": 16, "spark_speed": 340.0})
		"explosion":
			VFX2D.explosion(center, {"radius": 52.0})
		"lightning":
			VFX2D.lightning(center + Vector2(-span * 0.3, -38.0),
					center + Vector2(span * 0.3, 26.0),
					{"segments": 14, "branches": 3, "duration": 0.3})
		"cooldown_ring":
			if is_instance_valid(_ring_target):
				_ring_target.position = center
				VFX2D.cooldown_ring(_ring_target, 1.8,
						{"radius": 40.0, "width": 8.0, "tick_count": 12})
		"smoke_puff":
			VFX2D.smoke_puff(center, {"radius": 42.0, "rise": 0.7})
		"shockwave":
			VFX2D.shockwave(center, {"radius": 40.0, "expansion": 2.4})
		"muzzle_flash":
			VFX2D.muzzle_flash(center + Vector2(-span * 0.22, 0.0), Vector2.RIGHT,
					{"length": 68.0, "cone_degrees": 30.0})
		"heal_sparkle":
			VFX2D.heal_sparkle(center, {"radius": 38.0, "mote_count": 16})
		"slash_arc":
			var aim := Vector2.from_angle(_rng.randf_range(-PI, PI))
			VFX2D.slash_arc(center, aim, {"radius": 46.0, "sparkle_count": 8})
		"debris_burst":
			VFX2D.debris_burst(center + Vector2(0.0, 22.0),
					{"chunk_count": 12, "gravity": 780.0, "speed": 210.0})
		"ripple":
			VFX2D.ripple(center + Vector2(0.0, 26.0), {"radius": 62.0, "rings": 3})
		"implosion":
			VFX2D.implosion(center, {"radius": 54.0, "mote_count": 22})
		"rune_circle":
			_stop_persistent(index)
			if is_instance_valid(_rune_target):
				_rune_target.position = center
				_persistent[index] = VFX2D.rune_circle(_rune_target, 1.1,
						{"radius": 34.0, "fill": 0.7, "segments": 10})
		"portal":
			_stop_persistent(index)
			_persistent[index] = VFX2D.portal(center,
					{"width": 42.0, "height": 56.0, "lifetime": 1.2})
		"beam":
			_stop_persistent(index)
			_persistent[index] = VFX2D.beam(center + Vector2(-span * 0.32, 18.0),
					center + Vector2(span * 0.32, -18.0),
					{"width": 5.0, "lifetime": 1.4})
		"trail":
			_stop_persistent(index)
			if is_instance_valid(_trail_flyer):
				_persistent[index] = VFX2D.trail(_trail_flyer,
						{"history": 0.55, "width_start": 7.0, "mote_count": 9})


func _stop_persistent(index: int) -> void:
	# The entry may already have freed itself (a portal closing, a beam timing
	# out), so keep it untyped until it is known to be alive: assigning a freed
	# instance to a typed variable is itself an error.
	var stored: Variant = _persistent.get(index)
	if stored != null and is_instance_valid(stored) and stored.has_method("stop"):
		stored.stop()
	_persistent.erase(index)


func _update_trail_flyer() -> void:
	if not is_instance_valid(_trail_flyer):
		return
	var index: int = CELLS.size() - 1
	var rect: Rect2 = _cell_rect(index)
	var center: Vector2 = _cell_center(index)
	_trail_flyer.position = center + Vector2(
			sin(_clock * 2.2) * rect.size.x * 0.3,
			sin(_clock * 3.3) * minf(rect.size.y * 0.22, 22.0))
