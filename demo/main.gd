extends Node2D
## Interactive sandbox for the 2D VFX Kit.
##
## Left click anywhere to pop a hit spark, use the buttons (or keys 1-8) to fire
## the one-shots, and press Space to toggle the idle auto-demo. Keys 9 and 0 add
## the slash arc and debris burst, R/I the ripple and implosion, and B/P/U/T
## toggle the persistent modifiers: beam, portal, rune circle and trail. Press G
## (or the "Effect gallery" button) for demo/gallery.tscn, which shows all sixteen
## side by side on a labelled grid.

const GRID_STEP: float = 64.0
const TARGET_POSITION := Vector2(930.0, 460.0)
const TARGET_RADIUS: float = 46.0
const SPARK_SPOT := Vector2(380.0, 300.0)
const EXPLOSION_SPOT := Vector2(620.0, 300.0)
const LIGHTNING_FROM := Vector2(280.0, 120.0)
const SMOKE_FEET := Vector2(160.0, 560.0)
const SHOCKWAVE_SPOT := Vector2(760.0, 300.0)
const MUZZLE_ORIGIN := Vector2(520.0, 560.0)
const HEAL_SPOT := Vector2(930.0, 460.0)
const SLASH_SPOT := Vector2(380.0, 470.0)
const DEBRIS_SPOT := Vector2(620.0, 470.0)
const RIPPLE_SPOT := Vector2(760.0, 470.0)
const IMPLOSION_SPOT := Vector2(480.0, 180.0)
const AUTO_DEMO_INTERVAL: float = 1.2
const GALLERY_SCENE: String = "res://demo/gallery.tscn"

var _rng := RandomNumberGenerator.new()
var _mouse_position := Vector2.ZERO
var _status_label: Label = null
var _ring_target: Node2D = null
var _ring: CooldownRing = null
var _auto_demo: bool = true
var _auto_demo_clock: float = 0.0
var _flyer: Node2D = null
var _beam: BeamEffect = null
var _portal: PortalEffect = null
var _rune: RuneCircle = null
var _trail: TrailEffect = null
var _cast_clock: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_mouse_position = get_viewport_rect().size * 0.5
	_ring_target = Node2D.new()
	_ring_target.name = "CooldownTarget"
	_ring_target.position = TARGET_POSITION
	add_child(_ring_target)
	_flyer = Node2D.new()
	_flyer.name = "Flyer"
	_flyer.position = Vector2(280.0, 420.0)
	add_child(_flyer)
	_build_hud()


func _process(delta: float) -> void:
	if _auto_demo:
		_auto_demo_clock += delta
		if _auto_demo_clock >= AUTO_DEMO_INTERVAL:
			_auto_demo_clock = 0.0
			var spot := Vector2(_rng.randf_range(280.0, 1020.0), _rng.randf_range(220.0, 560.0))
			VFX2D.hit_spark(spot, Vector2.from_angle(_rng.randf_range(-PI, PI)))
	_update_persistent(delta)
	if _status_label != null:
		_status_label.text = ("FPS %d   ·   active %d   ·   persistent %d"
				+ "   ·   auto demo %s   ·   C++ streaks %s") % [
			Engine.get_frames_per_second(),
			VFX2D.get_active_count(),
			VFX2D.get_persistent_count(),
			"on" if _auto_demo else "off",
			"on" if VFXStreaks.is_available() else "off",
		]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		queue_redraw()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_spark_at(event.position)
		return
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		match event.keycode:
			KEY_1:
				_on_spawn_hit_spark()
			KEY_2:
				_on_spawn_explosion()
			KEY_3:
				_on_spawn_lightning()
			KEY_4:
				_on_start_cooldown_ring()
			KEY_5:
				_on_smoke_puff()
			KEY_6:
				_on_shockwave()
			KEY_7:
				_on_muzzle_flash()
			KEY_8:
				_on_heal_sparkle()
			KEY_9:
				_on_slash_arc()
			KEY_0:
				_on_debris_burst()
			KEY_R:
				_on_ripple()
			KEY_I:
				_on_implosion()
			KEY_B:
				_on_toggle_beam()
			KEY_P:
				_on_toggle_portal()
			KEY_U:
				_on_toggle_rune()
			KEY_T:
				_on_toggle_trail()
			KEY_C:
				VFX2D.stop_all()
			KEY_G:
				_open_gallery()
			KEY_SPACE:
				_auto_demo = not _auto_demo
				_auto_demo_clock = 0.0


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.045, 0.055, 0.075), true)
	var grid_color := Color(0.09, 0.11, 0.15)
	var x: float = 0.0
	while x <= view.x:
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), grid_color, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y <= view.y:
		draw_line(Vector2(0.0, y), Vector2(view.x, y), grid_color, 1.0)
		y += GRID_STEP
	draw_circle(TARGET_POSITION, TARGET_RADIUS, Color(0.09, 0.12, 0.16))
	draw_arc(TARGET_POSITION, TARGET_RADIUS, 0.0, TAU, 64, Color(0.25, 0.35, 0.45), 2.0, true)
	draw_circle(TARGET_POSITION, 6.0, Color(0.3, 0.45, 0.55))
	_draw_crosshair(_mouse_position)


func _draw_crosshair(at: Vector2) -> void:
	var color := Color(0.8, 0.9, 1.0, 0.7)
	draw_line(at - Vector2(14.0, 0.0), at - Vector2(5.0, 0.0), color, 1.0)
	draw_line(at + Vector2(5.0, 0.0), at + Vector2(14.0, 0.0), color, 1.0)
	draw_line(at - Vector2(0.0, 14.0), at - Vector2(0.0, 5.0), color, 1.0)
	draw_line(at + Vector2(0.0, 5.0), at + Vector2(0.0, 14.0), color, 1.0)


func _spark_at(at: Vector2) -> void:
	var direction: Vector2 = at - get_viewport_rect().size * 0.5
	VFX2D.hit_spark(at, direction)


func _on_spawn_hit_spark() -> void:
	var direction := Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 0.2))
	VFX2D.hit_spark(SPARK_SPOT, direction)


func _on_spawn_explosion() -> void:
	VFX2D.explosion(EXPLOSION_SPOT)


func _on_spawn_lightning() -> void:
	var target: Vector2 = _mouse_position
	if target.y < 150.0:
		target = EXPLOSION_SPOT
	VFX2D.lightning(LIGHTNING_FROM, target, {"branches": 3, "duration": 0.35})


func _on_smoke_puff() -> void:
	VFX2D.smoke_puff(SMOKE_FEET + Vector2(_rng.randf_range(-40.0, 40.0), 0.0))


func _on_shockwave() -> void:
	VFX2D.shockwave(SHOCKWAVE_SPOT, {"radius": 90.0})


func _on_muzzle_flash() -> void:
	var aim: Vector2 = _mouse_position - MUZZLE_ORIGIN
	VFX2D.muzzle_flash(MUZZLE_ORIGIN, aim)


func _on_heal_sparkle() -> void:
	VFX2D.heal_sparkle(HEAL_SPOT)


func _on_slash_arc() -> void:
	var aim: Vector2 = _mouse_position - SLASH_SPOT
	VFX2D.slash_arc(SLASH_SPOT, aim)


func _on_debris_burst() -> void:
	VFX2D.debris_burst(DEBRIS_SPOT)


func _on_ripple() -> void:
	VFX2D.ripple(RIPPLE_SPOT)


func _on_implosion() -> void:
	VFX2D.implosion(IMPLOSION_SPOT)


func _on_toggle_beam() -> void:
	if is_instance_valid(_beam):
		_beam.stop()
		_beam = null
		return
	_beam = VFX2D.beam(MUZZLE_ORIGIN, _mouse_position, {"width": 7.0})


func _on_toggle_portal() -> void:
	if is_instance_valid(_portal):
		_portal.stop()
		_portal = null
		return
	_portal = VFX2D.portal(TARGET_POSITION, {"width": 70.0, "height": 94.0})


func _on_toggle_rune() -> void:
	if is_instance_valid(_rune):
		_rune.stop()
		_rune = null
		return
	_cast_clock = 0.0
	_rune = VFX2D.rune_circle(_ring_target, 0.0, {"radius": 62.0, "segments": 14})


func _on_toggle_trail() -> void:
	if is_instance_valid(_trail):
		_trail.stop()
		_trail = null
		return
	if is_instance_valid(_flyer):
		_trail = VFX2D.trail(_flyer, {"history": 0.4})


## Keeps the live persistent modifiers pointed at the right places.
func _update_persistent(delta: float) -> void:
	if is_instance_valid(_beam):
		_beam.end_at(_mouse_position - _beam.global_position)
	if is_instance_valid(_rune):
		_cast_clock += delta
		_rune.set_fill(clampf(_cast_clock / 2.5, 0.0, 1.0))
	if is_instance_valid(_flyer):
		var t: float = float(Time.get_ticks_msec()) * 0.001
		_flyer.position = Vector2(300.0, 430.0) \
				+ Vector2(sin(t * 1.7) * 150.0, cos(t * 2.3) * 90.0)


func _open_gallery() -> void:
	if ResourceLoader.exists(GALLERY_SCENE):
		get_tree().change_scene_to_file(GALLERY_SCENE)


func _on_start_cooldown_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = VFX2D.cooldown_ring(_ring_target, 2.5, {"radius": 56.0, "width": 10.0})


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "Controls"
	panel.position = Vector2(20.0, 16.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.88)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "2D VFX Kit — v0.4 demo"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var hint := Label.new()
	hint.text = ("Click: hit spark   ·   1-0, R, I: one-shots"
			+ "   ·   B P U T: beam, portal, rune, trail"
			+ "   ·   Space: auto demo   ·   C: clear")
	if ResourceLoader.exists(GALLERY_SCENE):
		hint.text += "   ·   G: effect gallery"
	hint.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	column.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	buttons.add_child(_make_button("Hit spark", _on_spawn_hit_spark))
	buttons.add_child(_make_button("Explosion", _on_spawn_explosion))
	buttons.add_child(_make_button("Lightning", _on_spawn_lightning))
	buttons.add_child(_make_button("Cooldown ring", _on_start_cooldown_ring))

	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", 8)
	column.add_child(more)
	more.add_child(_make_button("Smoke", _on_smoke_puff))
	more.add_child(_make_button("Shockwave", _on_shockwave))
	more.add_child(_make_button("Muzzle flash", _on_muzzle_flash))
	more.add_child(_make_button("Heal sparkle", _on_heal_sparkle))

	var one_shots := HBoxContainer.new()
	one_shots.add_theme_constant_override("separation", 8)
	column.add_child(one_shots)
	one_shots.add_child(_make_button("Slash arc", _on_slash_arc))
	one_shots.add_child(_make_button("Debris burst", _on_debris_burst))
	one_shots.add_child(_make_button("Ripple", _on_ripple))
	one_shots.add_child(_make_button("Implosion", _on_implosion))

	var persistent := HBoxContainer.new()
	persistent.add_theme_constant_override("separation", 8)
	column.add_child(persistent)
	persistent.add_child(_make_button("Beam", _on_toggle_beam))
	persistent.add_child(_make_button("Portal", _on_toggle_portal))
	persistent.add_child(_make_button("Rune circle", _on_toggle_rune))
	persistent.add_child(_make_button("Trail", _on_toggle_trail))
	if ResourceLoader.exists(GALLERY_SCENE):
		buttons.add_child(_make_button("Effect gallery", _open_gallery))

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.52, 0.64, 0.78))
	column.add_child(_status_label)
