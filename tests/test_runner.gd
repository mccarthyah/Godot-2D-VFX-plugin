extends Node
## Headless test suite for the 2D VFX Kit.
##
## Run it with:
## [codeblock]
## godot --headless --path . res://tests/test_runner.tscn
## [/codeblock]
## Exits with code 0 when every check passes and 1 when anything fails.
##
## Headless Godot still issues draw notifications, so spawning each effect here
## also executes its `_draw()` code (arcs, polylines, particle setup). Any engine
## error raised from drawing makes `grep -E "ERROR:"` fail the CI job.

const HIT_SPARK_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/hit_spark.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/explosion.tscn")
const LIGHTNING_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/lightning.tscn")
const COOLDOWN_RING_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/cooldown_ring.tscn")
const SMOKE_PUFF_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/smoke_puff.tscn")
const SHOCKWAVE_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/shockwave.tscn")
const MUZZLE_FLASH_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/muzzle_flash.tscn")
const HEAL_SPARKLE_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/heal_sparkle.tscn")

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("[VFX TESTS] Godot %s" % Engine.get_version_info()["string"])
	await _run_all()
	var summary := "%d checks, %d failure(s)" % [_checks, _failures]
	if _failures == 0:
		print("[VFX TESTS] PASS — " + summary)
		get_tree().quit(0)
	else:
		printerr("[VFX TESTS] FAIL — " + summary)
		get_tree().quit(1)


func _run_all() -> void:
	var effects := {
		"hit_spark": HIT_SPARK_SCENE,
		"explosion": EXPLOSION_SCENE,
		"lightning": LIGHTNING_SCENE,
		"smoke_puff": SMOKE_PUFF_SCENE,
		"shockwave": SHOCKWAVE_SCENE,
		"muzzle_flash": MUZZLE_FLASH_SCENE,
		"heal_sparkle": HEAL_SPARKLE_SCENE,
	}
	for effect_name in effects:
		await _test_lifecycle(effect_name, effects[effect_name])
	await _test_cooldown_ring()
	await _test_autoload()
	await _test_new_effects()
	await _test_chaos_knob(effects)
	await _test_scene_change_pooling()
	await _test_streak_field()


#region Tests

func _test_lifecycle(effect_name: String, scene: PackedScene) -> void:
	var effect: VFXEffect = scene.instantiate()
	_check(effect != null, "%s: scene instantiates" % effect_name)
	if effect == null:
		return
	_check(effect is VFXEffect, "%s: root extends VFXEffect" % effect_name)
	effect.free_on_finish = false
	effect.duration = 0.12
	add_child(effect)

	var finishes := [0]
	effect.finished.connect(func() -> void: finishes[0] += 1)
	effect.play()
	_check(effect.is_playing(), "%s: reports playing after play()" % effect_name)
	await _wait(0.3)
	_check(finishes[0] == 1, "%s: emitted finished exactly once (got %d)" % [effect_name, finishes[0]])
	_check(not effect.is_playing(), "%s: stopped when the duration elapsed" % effect_name)
	_check(is_equal_approx(effect.progress, 1.0), "%s: progress reached 1.0" % effect_name)

	# Replaying the same instance must work: that is the pooling path.
	effect.play()
	await _wait(0.25)
	_check(finishes[0] == 2, "%s: replays and finishes again (got %d)" % [effect_name, finishes[0]])

	effect.queue_free()
	await get_tree().process_frame


func _test_cooldown_ring() -> void:
	var ring: CooldownRing = COOLDOWN_RING_SCENE.instantiate()
	_check(ring != null and ring is CooldownRing, "cooldown_ring: root is a CooldownRing")
	if ring == null:
		return
	ring.free_on_complete = false
	add_child(ring)

	var completions := [0]
	ring.completed.connect(func() -> void: completions[0] += 1)
	ring.start(0.2)
	_check(ring.is_running(), "cooldown_ring: running after start()")
	_check(is_equal_approx(ring.progress, 0.0), "cooldown_ring: starts empty when filling")
	await _wait(0.4)
	_check(completions[0] == 1, "cooldown_ring: emitted completed once (got %d)" % completions[0])
	_check(is_equal_approx(ring.progress, 1.0), "cooldown_ring: filled to 1.0")
	_check(not ring.is_running(), "cooldown_ring: stopped after completing")

	# Reverse mode starts full and drains.
	ring.reverse = true
	ring.start(0.2)
	_check(is_equal_approx(ring.progress, 1.0), "cooldown_ring: reverse mode starts full")
	await _wait(0.4)
	_check(is_equal_approx(ring.progress, 0.0), "cooldown_ring: reverse mode drains to 0.0")
	_check(completions[0] == 2, "cooldown_ring: reverse mode completes (got %d)" % completions[0])

	ring.queue_free()
	await get_tree().process_frame


func _test_autoload() -> void:
	_check(get_tree().root.get_node_or_null("VFX2D") != null,
			"VFX2D autoload is registered in the project")
	VFX2D.stop_all()
	await get_tree().process_frame
	_check(VFX2D.get_active_count() == 0, "VFX2D: no active effects after stop_all()")

	var spot := Vector2(64.0, 96.0)
	var spark: VFXEffect = VFX2D.hit_spark(spot, Vector2.RIGHT, {"duration": 0.1})
	_check(spark != null, "VFX2D.hit_spark(): returns an effect")
	if spark == null:
		return
	await get_tree().process_frame
	_check(spark.global_position.is_equal_approx(spot),
			"VFX2D.hit_spark(): placed at the requested position")
	_check(VFX2D.get_active_count() == 1, "VFX2D: active count tracks running effects")
	await _wait(0.3)
	_check(VFX2D.get_active_count() == 0,
			"VFX2D: effect retired after finishing (active=%d)" % VFX2D.get_active_count())

	var first_id := spark.get_instance_id()
	var recycled: VFXEffect = VFX2D.hit_spark(spot, Vector2.LEFT, {"duration": 0.1})
	_check(recycled != null and recycled.get_instance_id() == first_id,
			"VFX2D: pool reuses the finished instance")
	await _wait(0.3)

	var blast: VFXEffect = VFX2D.explosion(spot, {"radius": 120.0, "duration": 0.1})
	_check(blast != null, "VFX2D.explosion(): returns an effect")
	if blast != null:
		_check(is_equal_approx(float(blast.get("radius")), 120.0),
				"VFX2D.explosion(): options override exported properties")
	await _wait(0.3)

	# chaos is off here on purpose: with it on, the bolt adds and drops branches
	# per flicker (that is the feature), so only chaos=0 has an exact branch count.
	var bolt: LightningEffect = VFX2D.lightning(Vector2(10.0, 10.0), Vector2(210.0, 60.0),
			{"duration": 0.1, "flicker": 0.0, "chaos": 0.0}) as LightningEffect
	_check(bolt != null, "VFX2D.lightning(): returns a LightningEffect")
	if bolt != null:
		var points: PackedVector2Array = bolt.get_bolt_points()
		_check(points.size() >= 2, "lightning: generated bolt geometry (%d points)" % points.size())
		if points.size() >= 2:
			_check(points[0].is_equal_approx(Vector2.ZERO), "lightning: bolt starts at the origin")
			_check(points[points.size() - 1].is_equal_approx(Vector2(200.0, 50.0)),
					"lightning: bolt ends at the requested endpoint")
		_check(bolt.get_branch_points().size() == 2,
				"lightning: default branch count honoured with chaos off (%d)" \
						% bolt.get_branch_points().size())
		_check(VFX2D.lightning(Vector2(10.0, 10.0), Vector2(210.0, 60.0),
				{"duration": 0.1, "flicker": 0.0, "chaos": 1.0}) != null,
				"lightning: spawns with chaos at 1.0")
	await _wait(0.3)

	# A burst larger than the pool must still be fully recycled.
	for i in range(8):
		VFX2D.explosion(Vector2(float(i) * 20.0, 40.0), {"duration": 0.08})
	_check(VFX2D.get_active_count() == 8,
			"VFX2D: burst of 8 effects tracked (got %d)" % VFX2D.get_active_count())
	VFX2D.stop_all()
	await get_tree().process_frame
	_check(VFX2D.get_active_count() == 0, "VFX2D: stop_all() clears a burst")
#endregion


func _test_new_effects() -> void:
	var spot := Vector2(-40.0, 24.0)
	var smoke: VFXEffect = VFX2D.smoke_puff(spot, {"duration": 0.12})
	_check(smoke != null, "VFX2D.smoke_puff(): returns an effect")
	if smoke != null:
		_check(int(smoke.call("get_puff_count")) == 9,
				"smoke_puff: spawned its blobs (got %d)" % int(smoke.call("get_puff_count")))
	await _wait(0.3)

	var wave: VFXEffect = VFX2D.shockwave(spot, {"duration": 0.12})
	_check(wave != null, "VFX2D.shockwave(): returns an effect")
	if wave != null:
		_check(int(wave.call("get_ring_point_count")) >= 32,
				"shockwave: exposes its ring resolution")
	await _wait(0.3)

	var muzzle: VFXEffect = VFX2D.muzzle_flash(spot, Vector2.LEFT, {"duration": 0.12})
	_check(muzzle != null, "VFX2D.muzzle_flash(): returns an effect")
	if muzzle != null:
		var aim: Vector2 = muzzle.get("direction")
		_check(aim.is_equal_approx(Vector2.LEFT),
				"muzzle_flash: aim direction applied (%s)" % aim)
		var cone: PackedVector2Array = muzzle.call("get_cone_points")
		_check(cone.size() >= 5, "muzzle_flash: cone built (%d points)" % cone.size())
		_check(cone[0].is_equal_approx(Vector2.ZERO), "muzzle_flash: cone apex at the origin")
		if cone.size() >= 3:
			var tip: Vector2 = cone[cone.size() - 2]
			_check(tip.x < 0.0, "muzzle_flash: cone points along the aim (%s)" % tip)
	await _wait(0.3)

	var sparkle: VFXEffect = VFX2D.heal_sparkle(spot, {"duration": 0.12, "mote_count": 12})
	_check(sparkle != null, "VFX2D.heal_sparkle(): returns an effect")
	if sparkle != null:
		_check(int(sparkle.call("get_mote_count")) == 12,
				"heal_sparkle: honours mote_count (%d)" % int(sparkle.call("get_mote_count")))
	await _wait(0.3)
	VFX2D.stop_all()
	await get_tree().process_frame


func _test_chaos_knob(effects: Dictionary) -> void:
	for effect_name in effects:
		var scene: PackedScene = effects[effect_name]
		var effect: VFXEffect = scene.instantiate()
		if effect == null:
			_check(false, "%s: instantiates for the chaos check" % effect_name)
			continue
		var has_chaos: bool = false
		for entry in effect.get_property_list():
			if String(entry["name"]) == "chaos":
				has_chaos = true
				break
		_check(has_chaos, "%s: exposes a chaos knob" % effect_name)
		effect.set("chaos", 1.0)
		_check(is_equal_approx(float(effect.get("chaos")), 1.0),
				"%s: chaos can be driven to 1.0" % effect_name)
		effect.free()


func _test_scene_change_pooling() -> void:
	# Effects sit under a VFX2D_Layer parented to the current scene, so
	# change_scene_* frees the pool. Spawning afterwards used to hit a freed
	# instance in the pool and raise "Trying to assign invalid previously freed
	# instance" (seen when the demo switched to the gallery, which then spawned
	# lightning). The pool has to drop dead entries instead.
	VFX2D.stop_all()
	await get_tree().process_frame
	var first: VFXEffect = VFX2D.hit_spark(Vector2(40.0, 40.0), Vector2.RIGHT,
			{"duration": 0.05})
	_check(first != null, "scene change: spawns before the layer dies")
	if first == null:
		return
	var pooled_id := first.get_instance_id()
	await _wait(0.25)
	_check(VFX2D.get_active_count() == 0, "scene change: finished effect left the active list")

	var host: Node = get_tree().current_scene
	var layer_holder: Node = null
	if host != null:
		layer_holder = host.get_node_or_null(VFX2D.container_node_name)
	_check(layer_holder != null, "scene change: layer lives under the current scene")
	if layer_holder == null:
		return
	layer_holder.free()

	_check(VFX2D.get_active_count() == 0, "scene change: dead actives are pruned")
	var bolt: VFXEffect = VFX2D.lightning(Vector2(10.0, 10.0), Vector2(120.0, 40.0),
			{"duration": 0.05})
	_check(bolt != null, "scene change: spawns again after the pool died")
	if bolt == null:
		return
	_check(bolt.get_instance_id() != pooled_id,
			"scene change: the freed pool entry was not reused")
	_check(bolt.is_inside_tree(), "scene change: the new effect is in the tree")
	# Spawning rebuilds the layer, which is where the pool gets cleaned. Reading
	# the pool directly is what makes this fail if the dead entries are kept: the
	# spurious engine error alone would not fail the suite, only CI's grep.
	var stale: int = 0
	var pools: Dictionary = VFX2D._free_instances
	for scene_key in pools.keys():
		for instance in pools[scene_key]:
			if not is_instance_valid(instance):
				stale += 1
	_check(stale == 0, "scene change: pool holds no freed instances (stale=%d)" % stale)
	await _wait(0.25)
	VFX2D.stop_all()
	await get_tree().process_frame
#endregion


#region C++ streak field (optional)

func _test_streak_field() -> void:
	if not VFXStreaks.is_available():
		print("[VFX TESTS] cpp-streak-field: absent (pure GDScript fallback active)")
		return
	print("[VFX TESTS] cpp-streak-field: available")

	var field := VFXStreaks.create(self, {"seed": 4242, "max_particles": 2048})
	_check(field != null, "cpp: VFXStreakField2D instantiates")
	if field == null:
		return
	_check(field.get_class() == "VFXStreakField2D", "cpp: node reports its native class")
	_check(int(field.call("get_alive_count")) == 0, "cpp: field starts empty")

	VFXStreaks.burst(field, {
		"origin": Vector2(10.0, 20.0),
		"count": 512,
		"direction": Vector2.RIGHT,
		"spread": 0.6,
		"speed_min": 200.0,
		"speed_max": 400.0,
		"lifetime_min": 0.2,
		"lifetime_max": 0.3,
	})
	var spawned := int(field.call("get_alive_count"))
	_check(spawned == 512, "cpp: burst spawned 512 particles (got %d)" % spawned)

	await get_tree().process_frame
	await get_tree().process_frame
	var drawn := int(field.call("get_drawn_segment_count"))
	_check(drawn > 0, "cpp: submitted streak segments to the renderer (%d)" % drawn)
	var alive_after_draw := int(field.call("get_alive_count"))
	_check(drawn == alive_after_draw * 2,
			"cpp: two segments per live particle, head->mid->tail (got %d)" % drawn)

	await _wait(0.6)
	_check(int(field.call("get_alive_count")) == 0, "cpp: particles expire with their lifetime")
	_check(int(field.call("get_drawn_segment_count")) == 0,
			"cpp: nothing drawn once the field is empty")

	field.set("max_particles", 64)
	VFXStreaks.burst(field, {"count": 500, "lifetime_min": 1.0, "lifetime_max": 1.0})
	var capped := int(field.call("get_alive_count"))
	_check(capped <= 64, "cpp: honours max_particles (%d/64)" % capped)
	VFXStreaks.clear(field)
	_check(int(field.call("get_alive_count")) == 0, "cpp: clear() empties the field")
	field.queue_free()
	await get_tree().process_frame

	# The bundled GDScript effects must attach the streak layer by themselves.
	var spark := VFX2D.hit_spark(Vector2(100.0, 100.0), Vector2.UP, {"duration": 0.3})
	await get_tree().process_frame
	var found := false
	if spark != null:
		for child in spark.get_children():
			if child.get_class() == "VFXStreakField2D":
				found = true
				var alive := int(child.call("get_alive_count"))
				_check(alive > 0, "cpp: hit spark emitted streaks (%d particles)" % alive)
	_check(found, "cpp: hit spark attached a streak field")
	VFX2D.stop_all()

#endregion


#region Helpers

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[VFX TESTS] ok   " + message)
	else:
		_failures += 1
		printerr("[VFX TESTS] FAIL " + message)

#endregion
