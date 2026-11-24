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
	}
	for effect_name in effects:
		await _test_lifecycle(effect_name, effects[effect_name])
	await _test_cooldown_ring()
	await _test_autoload()


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

	var bolt: LightningEffect = VFX2D.lightning(Vector2(10.0, 10.0), Vector2(210.0, 60.0),
			{"duration": 0.1, "flicker": 0.0}) as LightningEffect
	_check(bolt != null, "VFX2D.lightning(): returns a LightningEffect")
	if bolt != null:
		var points: PackedVector2Array = bolt.get_bolt_points()
		_check(points.size() >= 2, "lightning: generated bolt geometry (%d points)" % points.size())
		if points.size() >= 2:
			_check(points[0].is_equal_approx(Vector2.ZERO), "lightning: bolt starts at the origin")
			_check(points[points.size() - 1].is_equal_approx(Vector2(200.0, 50.0)),
					"lightning: bolt ends at the requested endpoint")
		_check(bolt.get_branch_points().size() == 2,
				"lightning: default branch count honoured (%d)" % bolt.get_branch_points().size())
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
