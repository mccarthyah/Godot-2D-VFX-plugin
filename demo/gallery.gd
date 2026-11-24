extends Node2D
## Visual gallery for every effect in the kit, split into themed pages so only a
## few effects run at once. Twenty-four effects firing together is a stress test,
## not a gallery: each page here runs up to four cells on their own timers, which
## keeps the frame rate steady while you compare shapes and colours.
##
## Run it on its own with [code]godot --path . res://demo/gallery.tscn[/code], or
## open the scene in the editor and press F6. Unlike the interactive demo there is
## nothing to drive: the cells cycle by themselves.
##
## [b]Left/Right[/b] (or [b]A/D[/b], [b]Tab[/b], or a click on a page tab) changes
## page, [b]1[/b]-[b]4[/b] or a click inside a cell fires just that effect,
## [b]Space[/b] pauses the timers, [b]R[/b] fires the page immediately, [b]C[/b]
## clears running effects, and [b]Esc[/b] returns to the interactive demo.

const MARGIN: float = 20.0
const GAP: float = 16.0
const HEADER_HEIGHT: float = 136.0
const GRID_STEP: float = 64.0
const COLUMNS: int = 2
const ROWS: int = 2
const TAB_TOP: float = 96.0
const TAB_HEIGHT: float = 26.0
const DEMO_SCENE: String = "res://demo/main.tscn"

const BACKGROUND := Color(0.045, 0.055, 0.075)
const GRID_COLOR := Color(0.09, 0.11, 0.15)
const PANEL_FILL := Color(0.07, 0.09, 0.13)
const PANEL_EDGE := Color(0.16, 0.22, 0.3)
const TITLE_COLOR := Color(0.84, 0.91, 1.0)
const NOTE_COLOR := Color(0.52, 0.64, 0.78)
const TAB_FILL := Color(0.09, 0.12, 0.17)

## Pages of related effects. Each cell holds what to spawn, the knobs in play, an
## accent colour and its timer; [code]phase[/code] staggers the start so cells do
## not fire in lockstep.
const PAGES := [
	{
		"title": "Impacts",
		"note": "solid hits, shards and pressure",
		"cells": [
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
				"effect": "debris_burst",
				"title": "3 · Debris burst",
				"note": "14 chunks · gravity + spin",
				"accent": Color(0.86, 0.74, 0.58),
				"interval": 1.6,
				"phase": 0.9,
			},
			{
				"effect": "shockwave",
				"title": "4 · Shockwave",
				"note": "2 rings · 12 cracks",
				"accent": Color(0.72, 0.92, 1.0),
				"interval": 1.1,
				"phase": 1.25,
			},
		],
	},
	{
		"title": "Combat",
		"note": "blades, barrels and bolts",
		"cells": [
			{
				"effect": "slash_arc",
				"title": "1 · Slash arc",
				"note": "120° crescent · torn edge",
				"accent": Color(0.78, 0.92, 1.0),
				"interval": 1.2,
				"phase": 0.1,
			},
			{
				"effect": "muzzle_flash",
				"title": "2 · Muzzle flash",
				"note": "torn cone · 120 C++ streaks",
				"accent": Color(1.0, 0.74, 0.35),
				"interval": 0.8,
				"phase": 0.5,
			},
			{
				"effect": "lightning",
				"title": "3 · Lightning",
				"note": "3 branches · sub-branches · flicker",
				"accent": Color(0.45, 0.72, 1.0),
				"interval": 1.3,
				"phase": 0.8,
			},
			{
				"effect": "cooldown_ring",
				"title": "4 · Cooldown ring",
				"note": "1.8 s fill · 12 ticks",
				"accent": Color(0.42, 0.9, 1.0),
				"interval": 2.6,
				"phase": 0.3,
			},
		],
	},
	{
		"title": "Magic",
		"note": "buffs, gateways and collapses",
		"cells": [
			{
				"effect": "heal_sparkle",
				"title": "1 · Heal sparkle",
				"note": "16 motes · twinkle + rise",
				"accent": Color(0.55, 1.0, 0.72),
				"interval": 1.9,
				"phase": 0.2,
			},
			{
				"effect": "rune_circle",
				"title": "2 · Rune circle",
				"note": "rotating · fill = cast bar",
				"accent": Color(0.72, 0.62, 1.0),
				"interval": 2.2,
				"phase": 0.7,
			},
			{
				"effect": "portal",
				"title": "3 · Portal",
				"note": "open · hold · close",
				"accent": Color(0.66, 0.58, 1.0),
				"interval": 2.4,
				"phase": 1.0,
			},
			{
				"effect": "implosion",
				"title": "4 · Implosion",
				"note": "spiral motes → pinch flash",
				"accent": Color(0.86, 0.6, 1.0),
				"interval": 1.5,
				"phase": 1.4,
			},
		],
	},
	{
		"title": "Elemental",
		"note": "cold, corrosive and chained damage",
		"cells": [
			{
				"effect": "frost_burst",
				"title": "1 · Frost burst",
				"note": "16 shards · angular ice + glints",
				"accent": Color(0.66, 0.9, 1.0),
				"interval": 1.6,
				"phase": 0.15,
			},
			{
				"effect": "acid_splash",
				"title": "2 · Acid splash",
				"note": "12 bubbles · pop on a delay",
				"accent": Color(0.58, 0.92, 0.32),
				"interval": 1.9,
				"phase": 0.6,
			},
			{
				"effect": "chain_lightning",
				"title": "3 · Chain lightning",
				"note": "3 hops · dims as it chains",
				"accent": Color(0.6, 0.8, 1.0),
				"interval": 1.5,
				"phase": 1.0,
			},
			{
				"effect": "vortex",
				"title": "4 · Vortex",
				"note": "pull field · motes spiral in",
				"accent": Color(0.55, 0.62, 1.0),
				"interval": 2.6,
				"phase": 1.3,
			},
		],
	},
	{
		"title": "Reactive",
		"note": "movement, ground hits and links",
		"cells": [
			{
				"effect": "blink",
				"title": "1 · Blink",
				"note": "collapse · streak · arrival",
				"accent": Color(0.62, 0.88, 1.0),
				"interval": 1.8,
				"phase": 0.2,
			},
			{
				"effect": "impact_crack",
				"title": "2 · Impact crack",
				"note": "9 cracks · dust + flat flash",
				"accent": Color(0.95, 0.78, 0.5),
				"interval": 1.7,
				"phase": 0.7,
			},
			{
				"effect": "shield_bubble",
				"title": "3 · Shield bubble",
				"note": "hex lattice · flashes when hit",
				"accent": Color(0.55, 0.85, 1.0),
				"interval": 3.0,
				"phase": 1.1,
			},
			{
				"effect": "tether",
				"title": "4 · Tether",
				"note": "sagging chain · travelling pulses",
				"accent": Color(0.7, 0.85, 1.0),
				"interval": 2.4,
				"phase": 1.5,
			},
		],
	},
	{
		"title": "Motion",
		"note": "flow, water and sustained shapes",
		"cells": [
			{
				"effect": "smoke_puff",
				"title": "1 · Smoke puff",
				"note": "9 blobs · billow + drift",
				"accent": Color(0.78, 0.8, 0.86),
				"interval": 1.5,
				"phase": 0.15,
			},
			{
				"effect": "ripple",
				"title": "2 · Ripple",
				"note": "3 wobbling rings · droplets",
				"accent": Color(0.5, 0.94, 1.0),
				"interval": 1.4,
				"phase": 0.55,
			},
			{
				"effect": "beam",
				"title": "3 · Beam",
				"note": "core + glow · travelling pulses",
				"accent": Color(0.6, 0.85, 1.0),
				"interval": 2.0,
				"phase": 0.95,
			},
			{
				"effect": "trail",
				"title": "4 · Trail",
				"note": "ribbon history · tapered tail",
				"accent": Color(0.68, 0.88, 1.0),
				"interval": 1.6,
				"phase": 1.3,
			},
		],
	},
]

var _rng := RandomNumberGenerator.new()
var _page: int = 0
var _timers: PackedFloat32Array = PackedFloat32Array()
var _flashes: PackedFloat32Array = PackedFloat32Array()
var _paused: bool = false
var _clock: float = 0.0
var _ring_target: Node2D = null
var _rune_target: Node2D = null
var _trail_flyer: Node2D = null
var _shield_target: Node2D = null
var _tether_a: Node2D = null
var _tether_b: Node2D = null
var _shield: ShieldBubble = null
var _hit_clock: float = 0.0
var _persistent: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_ring_target = Node2D.new()
	_ring_target.name = "RingTarget"
	add_child(_ring_target)
	_rune_target = Node2D.new()
	_rune_target.name = "RuneTarget"
	add_child(_rune_target)
	_trail_flyer = Node2D.new()
	_trail_flyer.name = "TrailFlyer"
	add_child(_trail_flyer)
	_shield_target = Node2D.new()
	_shield_target.name = "ShieldTarget"
	add_child(_shield_target)
	_tether_a = Node2D.new()
	_tether_a.name = "TetherA"
	add_child(_tether_a)
	_tether_b = Node2D.new()
	_tether_b.name = "TetherB"
	add_child(_tether_b)
	_reset_timers()


func _process(delta: float) -> void:
	_clock += delta
	if _trail_flyer != null and is_instance_valid(_trail_flyer):
		_update_trail_flyer()
	for index in _flashes.size():
		if _flashes[index] > 0.0:
			_flashes[index] = maxf(0.0, _flashes[index] - delta * 2.0)
	if not _paused:
		_advance_timers(delta)
	_update_shield_hits(delta)
	queue_redraw()


#region Pages

## Number of pages in the gallery.
func get_page_count() -> int:
	return PAGES.size()


## Index of the page currently shown.
func get_page() -> int:
	return _page


## How many cells the current page holds. Pages keep this small on purpose: a
## page only ever runs a handful of effects at once.
func get_cells_on_page() -> int:
	return _page_cells().size()


## Pauses or resumes the per-cell timers. Cells can still be fired by hand.
func set_paused(value: bool) -> void:
	_paused = value
	queue_redraw()


## Whether the per-cell timers are paused.
func is_paused() -> bool:
	return _paused


## Switches page, wrapping at either end. Running effects are cleared first, so
## leftover beams or portals never bleed into the next page.
func set_page(index: int) -> void:
	var count := get_page_count()
	if count == 0:
		return
	var target: int = wrapi(index, 0, count)
	if target == _page and not _timers.is_empty():
		return
	_clear_effects()
	_page = target
	_reset_timers()
	queue_redraw()

#endregion


#region Input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(event.position)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	_on_key(event.keycode)


func _on_click(position: Vector2) -> void:
	for page_index in get_page_count():
		if _tab_rect(page_index).has_point(position):
			set_page(page_index)
			return
	for index in get_cells_on_page():
		if _cell_rect(index).has_point(position):
			_fire(index)
			return


func _on_key(keycode: int) -> void:
	var digit: int = keycode - KEY_1
	if digit >= 0 and digit < get_cells_on_page():
		_fire(digit)
		return
	match keycode:
		KEY_LEFT, KEY_A, KEY_PAGEUP:
			set_page(_page - 1)
		KEY_RIGHT, KEY_D, KEY_PAGEDOWN, KEY_TAB:
			set_page(_page + 1)
		KEY_R:
			for index in get_cells_on_page():
				_fire(index)
		KEY_C:
			_clear_effects()
		KEY_SPACE:
			set_paused(not _paused)
		KEY_ESCAPE:
			if ResourceLoader.exists(DEMO_SCENE):
				get_tree().change_scene_to_file(DEMO_SCENE)

#endregion


#region Internals

func _page_cells() -> Array:
	if _page < 0 or _page >= PAGES.size():
		return []
	return PAGES[_page]["cells"]


func _reset_timers() -> void:
	_timers.clear()
	_flashes.clear()
	for cell in _page_cells():
		_timers.append(float(cell["phase"]))
		_flashes.append(0.0)


func _advance_timers(delta: float) -> void:
	var cells: Array = _page_cells()
	for index in _timers.size():
		_timers[index] += delta
		if _timers[index] >= float(cells[index]["interval"]):
			_timers[index] -= float(cells[index]["interval"])
			_fire(index)


func _clear_effects() -> void:
	VFX2D.stop_all()
	_persistent.clear()
	_shield = null
	_hit_clock = 0.0
	for index in _flashes.size():
		_flashes[index] = 0.0


func _cell_rect(index: int) -> Rect2:
	var view: Vector2 = get_viewport_rect().size
	var size := Vector2(
			maxf((view.x - MARGIN * 2.0 - GAP * float(COLUMNS - 1)) / float(COLUMNS), 160.0),
			maxf((view.y - HEADER_HEIGHT - MARGIN - GAP * float(ROWS - 1)) / float(ROWS),
					140.0))
	var col: int = index % COLUMNS
	var row: int = int(index / float(COLUMNS))
	var offset := Vector2(
			MARGIN + float(col) * (size.x + GAP),
			HEADER_HEIGHT + float(row) * (size.y + GAP))
	return Rect2(offset, size)


func _cell_center(index: int) -> Vector2:
	var rect: Rect2 = _cell_rect(index)
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 26.0)


func _tab_rect(page_index: int) -> Rect2:
	var view: Vector2 = get_viewport_rect().size
	var count: int = maxi(get_page_count(), 1)
	var width: float = (view.x - MARGIN * 2.0 - GAP * float(count - 1)) / float(count)
	return Rect2(Vector2(MARGIN + float(page_index) * (width + GAP), TAB_TOP),
			Vector2(width, TAB_HEIGHT))

#endregion


#region Firing

func _fire(index: int) -> void:
	if index < 0 or index >= get_cells_on_page():
		return
	var cell: Dictionary = _page_cells()[index]
	_flashes[index] = 1.0
	var center: Vector2 = _cell_center(index)
	var span: float = _cell_rect(index).size.x
	match String(cell["effect"]):
		"hit_spark":
			var direction := Vector2.from_angle(_rng.randf_range(-PI, PI))
			VFX2D.hit_spark(center, direction, {"spark_count": 16, "spark_speed": 340.0})
		"explosion":
			VFX2D.explosion(center, {"radius": 72.0})
		"lightning":
			VFX2D.lightning(center + Vector2(-span * 0.2, -46.0),
					center + Vector2(span * 0.2, 34.0),
					{"segments": 14, "branches": 3, "duration": 0.3})
		"cooldown_ring":
			if is_instance_valid(_ring_target):
				_ring_target.position = center
				VFX2D.cooldown_ring(_ring_target, 1.8,
						{"radius": 56.0, "width": 9.0, "tick_count": 12})
		"smoke_puff":
			VFX2D.smoke_puff(center, {"radius": 58.0, "rise": 0.7})
		"shockwave":
			VFX2D.shockwave(center, {"radius": 60.0, "expansion": 2.4})
		"muzzle_flash":
			VFX2D.muzzle_flash(center + Vector2(-span * 0.18, 0.0), Vector2.RIGHT,
					{"length": 86.0, "cone_degrees": 30.0})
		"heal_sparkle":
			VFX2D.heal_sparkle(center, {"radius": 52.0, "mote_count": 16})
		"slash_arc":
			var aim := Vector2.from_angle(_rng.randf_range(-PI, PI))
			VFX2D.slash_arc(center, aim, {"radius": 68.0, "sparkle_count": 8})
		"debris_burst":
			VFX2D.debris_burst(center + Vector2(0.0, 26.0),
					{"chunk_count": 12, "gravity": 780.0, "speed": 210.0})
		"ripple":
			VFX2D.ripple(center + Vector2(0.0, 30.0), {"radius": 78.0, "rings": 3})
		"implosion":
			VFX2D.implosion(center, {"radius": 66.0, "mote_count": 22})
		"rune_circle":
			_stop_persistent(index)
			if is_instance_valid(_rune_target):
				_rune_target.position = center
				_persistent[index] = VFX2D.rune_circle(_rune_target, 1.1,
						{"radius": 44.0, "fill": 0.7, "segments": 10})
		"portal":
			_stop_persistent(index)
			_persistent[index] = VFX2D.portal(center,
					{"width": 52.0, "height": 68.0, "lifetime": 1.2})
		"beam":
			_stop_persistent(index)
			_persistent[index] = VFX2D.beam(center + Vector2(-span * 0.26, 20.0),
					center + Vector2(span * 0.26, -20.0),
					{"width": 6.0, "lifetime": 1.4})
		"trail":
			_stop_persistent(index)
			if is_instance_valid(_trail_flyer):
				_persistent[index] = VFX2D.trail(_trail_flyer,
						{"history": 0.55, "width_start": 7.0, "mote_count": 9})
		"frost_burst":
			VFX2D.frost_burst(center, {"shard_count": 14, "speed": 260.0})
		"acid_splash":
			VFX2D.acid_splash(center + Vector2(0.0, 30.0),
					{"bubble_count": 10, "splat_radius": 34.0})
		"chain_lightning":
			var first: Vector2 = center + Vector2(-span * 0.26, -30.0)
			VFX2D.chain(first, [
				center + Vector2(span * 0.05, 26.0),
				center + Vector2(span * 0.28, -22.0),
			], {"duration": 0.45})
		"vortex":
			_stop_persistent(index)
			_persistent[index] = VFX2D.vortex(center,
					{"radius": 62.0, "lifetime": 1.6})
		"blink":
			VFX2D.blink(center + Vector2(-span * 0.3, 30.0),
					center + Vector2(span * 0.3, -30.0))
		"impact_crack":
			VFX2D.impact_crack(center + Vector2(0.0, 34.0),
					{"radius": 96.0, "crack_count": 8})
		"shield_bubble":
			_stop_persistent(index)
			_shield = null
			if is_instance_valid(_shield_target):
				_shield_target.position = center
				var bubble: ShieldBubble = VFX2D.shield(_shield_target,
						{"radius": 56.0, "lifetime": 1.8, "hex_size": 11.0})
				if bubble != null:
					_shield = bubble
					bubble.hit(center + Vector2(40.0, -18.0))
					_persistent[index] = bubble
		"tether":
			_stop_persistent(index)
			if is_instance_valid(_tether_a) and is_instance_valid(_tether_b):
				_tether_a.position = center + Vector2(-span * 0.3, 18.0)
				_tether_b.position = center + Vector2(span * 0.3, -18.0)
				_persistent[index] = VFX2D.tether(_tether_a, _tether_b,
						{"sag": 26.0, "link_count": 12})


func _update_shield_hits(delta: float) -> void:
	if _shield == null or not is_instance_valid(_shield):
		return
	_hit_clock += delta
	if _hit_clock < 0.45:
		return
	_hit_clock = 0.0
	var angle: float = _rng.randf_range(-PI, PI)
	_shield.hit(_shield.global_position
			+ Vector2(cos(angle), sin(angle)) * _rng.randf_range(30.0, 52.0))


func _stop_persistent(index: int) -> void:
	# The entry may already have freed itself (a portal closing, a beam timing
	# out), so keep it untyped until it is known to be alive: assigning a freed
	# instance to a typed variable is itself an error.
	var stored: Variant = _persistent.get(index)
	if stored != null and is_instance_valid(stored) and stored.has_method("stop"):
		stored.stop()
	_persistent.erase(index)


func _update_trail_flyer() -> void:
	var trail_index: int = -1
	var cells: Array = _page_cells()
	for index in cells.size():
		if String(cells[index]["effect"]) == "trail":
			trail_index = index
	if trail_index < 0:
		return
	var rect: Rect2 = _cell_rect(trail_index)
	var center: Vector2 = _cell_center(trail_index)
	_trail_flyer.position = center + Vector2(
			sin(_clock * 2.2) * rect.size.x * 0.3,
			sin(_clock * 3.3) * minf(rect.size.y * 0.22, 30.0))

#endregion


#region Drawing

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
	_draw_tabs()
	for index in get_cells_on_page():
		_draw_cell(index)
	_draw_status(view)


func _draw_header() -> void:
	var page: Dictionary = PAGES[_page]
	_draw_text("2D VFX Kit: effect gallery", Vector2(MARGIN, 36.0), 24, TITLE_COLOR)
	_draw_text("%d/%d · %s · %s" % [_page + 1, get_page_count(), page["title"], page["note"]],
			Vector2(MARGIN, 60.0), 14, TITLE_COLOR)
	var hint := "←/→ or Tab: pages · 1-4 or click: fire one cell · Space pause"
	hint += " · R refire page · C clear"
	if ResourceLoader.exists(DEMO_SCENE):
		hint += " · Esc: back to the demo"
	_draw_text(hint, Vector2(MARGIN, 82.0), 12, NOTE_COLOR)


func _draw_tabs() -> void:
	for index in get_page_count():
		var rect: Rect2 = _tab_rect(index)
		var active: bool = index == _page
		var accent: Color = PAGES[index]["cells"][0]["accent"]
		draw_rect(rect, accent if active else TAB_FILL, true)
		if active:
			draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.9), false, 2.0)
		var label := "%d · %s" % [index + 1, PAGES[index]["title"]]
		var color: Color = Color(0.06, 0.07, 0.1) if active else NOTE_COLOR
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12.0, 18.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0, 13, color)


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
	draw_string(ThemeDB.fallback_font, Vector2(view.x - MARGIN - width, 36.0),
			status, HORIZONTAL_ALIGNMENT_RIGHT, width, 13, NOTE_COLOR)


func _draw_cell(index: int) -> void:
	var rect: Rect2 = _cell_rect(index)
	var cell: Dictionary = _page_cells()[index]
	var accent: Color = cell["accent"]
	var flash: float = clampf(_flashes[index], 0.0, 1.0)
	draw_rect(rect, PANEL_FILL, true)
	draw_rect(rect, PANEL_EDGE.lerp(accent, flash), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)),
			accent.lerp(Color.WHITE, flash * 0.5), true)
	_draw_text(String(cell["title"]), rect.position + Vector2(14.0, 28.0), 16, TITLE_COLOR)
	_draw_text(String(cell["note"]), rect.position + Vector2(14.0, 48.0), 12, NOTE_COLOR)
	_draw_marker(index, _cell_center(index), accent)


func _draw_marker(index: int, center: Vector2, accent: Color) -> void:
	var faint := Color(accent.r, accent.g, accent.b, 0.3)
	if String(_page_cells()[index]["effect"]) == "cooldown_ring":
		draw_circle(center, 52.0, Color(accent.r, accent.g, accent.b, 0.07))
		draw_arc(center, 52.0, 0.0, TAU, 64, faint, 1.0, true)
	draw_line(center - Vector2(12.0, 0.0), center - Vector2(4.0, 0.0), faint, 1.0)
	draw_line(center + Vector2(4.0, 0.0), center + Vector2(12.0, 0.0), faint, 1.0)
	draw_line(center - Vector2(0.0, 12.0), center - Vector2(0.0, 4.0), faint, 1.0)
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(0.0, 12.0), faint, 1.0)


func _draw_text(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

#endregion
