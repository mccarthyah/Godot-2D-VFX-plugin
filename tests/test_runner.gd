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
const SLASH_ARC_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/slash_arc.tscn")
const DEBRIS_BURST_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/debris_burst.tscn")
const RIPPLE_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/ripple.tscn")
const IMPLOSION_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/implosion.tscn")
const BEAM_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/beam.tscn")
const PORTAL_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/portal.tscn")
const RUNE_CIRCLE_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/rune_circle.tscn")
const TRAIL_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/trail.tscn")
const CHAIN_LIGHTNING_SCENE: PackedScene = \
		preload("res://addons/vfx_2d/effects/chain_lightning.tscn")
const BLINK_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/blink.tscn")
const FROST_BURST_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/frost_burst.tscn")
const ACID_SPLASH_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/acid_splash.tscn")
const IMPACT_CRACK_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/impact_crack.tscn")
const SHIELD_BUBBLE_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/shield_bubble.tscn")
const TETHER_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/tether.tscn")
const VORTEX_SCENE: PackedScene = preload("res://addons/vfx_2d/effects/vortex.tscn")

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("[VFX TESTS] Godot %s" % Engine.get_version_info()["string"])
	await _run_all()
	var summary := "%d checks, %d failure(s)" % [_checks, _failures]
	if _failures == 0:
		print("[VFX TESTS] PASS: " + summary)
		get_tree().quit(0)
	else:
		printerr("[VFX TESTS] FAIL: " + summary)
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
		"slash_arc": SLASH_ARC_SCENE,
		"debris_burst": DEBRIS_BURST_SCENE,
		"ripple": RIPPLE_SCENE,
		"implosion": IMPLOSION_SCENE,
		"frost_burst": FROST_BURST_SCENE,
		"acid_splash": ACID_SPLASH_SCENE,
		"impact_crack": IMPACT_CRACK_SCENE,
		"chain_lightning": CHAIN_LIGHTNING_SCENE,
		"blink": BLINK_SCENE,
	}
	for effect_name in effects:
		await _test_lifecycle(effect_name, effects[effect_name])
	await _test_cooldown_ring()
	await _test_autoload()
	await _test_new_effects()
	await _test_v040_effects()
	await _test_persistent_effects()
	await _test_persistent_chaos()
	await _test_gallery_pages()
	await _test_v050_effects()
	await _test_reactive_modifiers()
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


func _test_v040_effects() -> void:
	var spot := Vector2(-60.0, 18.0)
	var slash: SlashArcEffect = VFX2D.slash_arc(spot, Vector2.LEFT,
			{"duration": 0.12}) as SlashArcEffect
	_check(slash != null, "VFX2D.slash_arc(): returns a SlashArcEffect")
	# The crescent is built while drawing, so give the frame a chance to run.
	await get_tree().process_frame
	if slash != null:
		var aim: Vector2 = slash.get("direction")
		_check(aim.is_equal_approx(Vector2.LEFT),
				"slash_arc: direction applied (%s)" % aim)
		var band: PackedVector2Array = slash.get_band_points()
		_check(band.size() >= 6, "slash_arc: crescent band built (%d points)" % band.size())
		if band.size() >= 3:
			var reach := 0.0
			for offset in band:
				reach = maxf(reach, offset.length())
			_check(reach > 20.0, "slash_arc: band has real reach (%.1f)" % reach)
	await _wait(0.3)

	var debris: DebrisBurstEffect = VFX2D.debris_burst(spot, {"duration": 0.12}) as DebrisBurstEffect
	_check(debris != null, "VFX2D.debris_burst(): returns a DebrisBurstEffect")
	if debris != null:
		_check(debris.get_chunk_count() == 14,
				"debris_burst: default chunk count (got %d)" % debris.get_chunk_count())
		_check(float(debris.get("gravity")) > 0.0, "debris_burst: chunks fall under gravity")
	var chunky: DebrisBurstEffect = VFX2D.debris_burst(spot,
			{"duration": 0.1, "chunk_count": 5, "gravity": 0.0}) as DebrisBurstEffect
	if chunky != null:
		_check(chunky.get_chunk_count() == 5, "debris_burst: honours chunk_count")
	await _wait(0.3)

	var splash: RippleEffect = VFX2D.ripple(spot, {"duration": 0.12}) as RippleEffect
	_check(splash != null, "VFX2D.ripple(): returns a RippleEffect")
	if splash != null:
		_check(splash.get_ring_count() == 3,
				"ripple: default ring count (got %d)" % splash.get_ring_count())
	await _wait(0.3)

	var collapse: ImplosionEffect = VFX2D.implosion(spot, {"duration": 0.12}) as ImplosionEffect
	_check(collapse != null, "VFX2D.implosion(): returns an ImplosionEffect")
	if collapse != null:
		_check(collapse.get_mote_count() > 0,
				"implosion: spawned motes (got %d)" % collapse.get_mote_count())
	await _wait(0.3)
	VFX2D.stop_all()
	await get_tree().process_frame


func _test_persistent_effects() -> void:
	VFX2D.stop_all()
	await get_tree().process_frame
	_check(VFX2D.get_persistent_count() == 0, "persistent: nothing tracked before spawning")

	var target := Node2D.new()
	target.position = Vector2(60.0, 60.0)
	add_child(target)

	var beam: BeamEffect = VFX2D.beam(Vector2.ZERO, Vector2(200.0, 0.0), {"width": 9.0})
	_check(beam != null and beam is BeamEffect, "VFX2D.beam(): returns a BeamEffect")
	if beam != null:
		_check(beam.is_inside_tree(), "beam: added to the VFX layer")
		_check(beam.get_parent() != null and beam.get_parent().name == VFX2D.container_node_name,
				"beam: lives under the VFX2D layer")
		_check(beam.end_offset.is_equal_approx(Vector2(200.0, 0.0)),
				"beam: endpoint from the spawn call")
		_check(is_equal_approx(float(beam.get("width")), 9.0), "beam: options applied")
		_check(is_equal_approx(beam.get_openness(), 0.0), "beam: starts closed")
		await _wait(0.3)
		_check(beam.get_openness() >= 0.99, "beam: opens to full after warmup (%.2f)"
				% beam.get_openness())
		beam.end_at(Vector2(0.0, 140.0))
		_check(beam.end_offset.is_equal_approx(Vector2(0.0, 140.0)), "beam: end_at() re-aims it")
		var closed := [0]
		beam.finished.connect(func() -> void: closed[0] += 1)
		beam.stop()
		await _wait(0.7)
		_check(closed[0] == 1, "beam: emitted finished once on stop() (got %d)" % closed[0])
		_check(not is_instance_valid(beam), "beam: freed itself after fading out")
	_check(VFX2D.get_persistent_count() == 0,
			"persistent: beam dropped after finishing (got %d)" % VFX2D.get_persistent_count())

	var portal: PortalEffect = VFX2D.portal(Vector2(30.0, 30.0),
			{"lifetime": 0.4, "open_time": 0.05, "close_time": 0.1})
	_check(portal != null and portal is PortalEffect, "VFX2D.portal(): returns a PortalEffect")
	if portal != null:
		_check(is_equal_approx(portal.get_openness(), 0.0), "portal: starts closed")
		await _wait(0.4)
		_check(portal.get_openness() > 0.9, "portal: opens to full (%.2f)" % portal.get_openness())
		_check(VFX2D.get_persistent_count() == 1, "portal: tracked as a persistent modifier")
		await _wait(0.9)
		_check(not is_instance_valid(portal), "portal: closes and frees after its lifetime")
	_check(VFX2D.get_persistent_count() == 0, "persistent: portal dropped after closing")

	var rune: RuneCircle = VFX2D.rune_circle(target, 0.2, {"fill": 0.4})
	_check(rune != null and rune is RuneCircle, "VFX2D.rune_circle(): returns a RuneCircle")
	if rune != null:
		_check(rune.get_parent() == target, "rune_circle: parents itself to the target")
		_check(rune.is_running(), "rune_circle: running after start()")
		_check(is_equal_approx(float(rune.get("fill")), 0.4), "rune_circle: fill option applied")
		rune.set_fill(0.85)
		_check(is_equal_approx(float(rune.get("fill")), 0.85), "rune_circle: set_fill() drives the ring")
		await _wait(0.7)
		_check(not is_instance_valid(rune), "rune_circle: closes when its timer runs out")
	_check(VFX2D.get_persistent_count() == 0, "persistent: rune dropped after finishing")

	var ribbon: TrailEffect = VFX2D.trail(target, {"history": 0.3})
	_check(ribbon != null and ribbon is TrailEffect, "VFX2D.trail(): returns a TrailEffect")
	if ribbon != null:
		_check(VFX2D.get_persistent_count() == 1, "trail: tracked as a persistent modifier")
		for i in range(6):
			target.position += Vector2(12.0, -4.0)
			await _wait(0.08)
		_check(ribbon.get_point_count() >= 2,
				"trail: recorded the target's history (%d points)" % ribbon.get_point_count())
		ribbon.stop()
		# queue_free() is processed at the end of the frame, and 4.2/4.3 take a
		# frame longer than 4.7 to get there: wait on time, not on one frame.
		await _wait(0.2)
		_check(not is_instance_valid(ribbon), "trail: stop() frees the ribbon")
	_check(VFX2D.get_persistent_count() == 0,
			"persistent: trail dropped after stop() (got %d)" % VFX2D.get_persistent_count())

	# A beam in flight must go away with stop_all(), like any other effect.
	var held: BeamEffect = VFX2D.beam(Vector2.ZERO, Vector2(90.0, 90.0), {"fade_time": 0.05})
	_check(held != null, "persistent: beam spawns for stop_all()")
	VFX2D.stop_all()
	await _wait(0.4)
	_check(not is_instance_valid(held), "persistent: stop_all() clears a live beam")
	_check(VFX2D.get_persistent_count() == 0, "persistent: nothing tracked after stop_all()")

	# A trail whose target leaves the tree must not linger or error.
	var doomed := Node2D.new()
	add_child(doomed)
	var orphan: TrailEffect = VFX2D.trail(doomed, {"history": 0.2})
	_check(orphan != null, "trail: attaches to a short-lived target")
	doomed.queue_free()
	await _wait(0.3)
	_check(not is_instance_valid(orphan), "trail: frees itself when the target is gone")
	_check(VFX2D.get_persistent_count() == 0, "persistent: orphaned trail dropped")

	if is_instance_valid(target):
		target.queue_free()
	await get_tree().process_frame


func _test_persistent_chaos() -> void:
	var persistent := {
		"beam": BEAM_SCENE,
		"portal": PORTAL_SCENE,
		"rune_circle": RUNE_CIRCLE_SCENE,
		"trail": TRAIL_SCENE,
		"shield_bubble": SHIELD_BUBBLE_SCENE,
		"tether": TETHER_SCENE,
		"vortex": VORTEX_SCENE,
	}
	for effect_name in persistent:
		var node: Node = (persistent[effect_name] as PackedScene).instantiate()
		_check(node != null, "%s: persistent scene instantiates" % effect_name)
		if node == null:
			continue
		var has_chaos: bool = node.get("chaos") != null
		_check(has_chaos, "%s: exposes a chaos knob" % effect_name)
		node.set("chaos", 1.0)
		_check(is_equal_approx(float(node.get("chaos")), 1.0),
				"%s: chaos can be driven to 1.0" % effect_name)
		node.free()


func _test_v050_effects() -> void:
	var spot := Vector2(20.0, 45.0)

	var frost: FrostBurstEffect = VFX2D.frost_burst(spot,
			{"duration": 0.12, "shard_count": 9}) as FrostBurstEffect
	_check(frost != null and frost is FrostBurstEffect, "VFX2D.frost_burst(): returns one")
	if frost != null:
		_check(frost.get_shard_count() == 9,
				"frost_burst: honours shard_count (got %d)" % frost.get_shard_count())
	await _wait(0.3)

	var acid: AcidSplashEffect = VFX2D.acid_splash(spot,
			{"duration": 0.5, "bubble_count": 6, "pop_delay": 0.1}) as AcidSplashEffect
	_check(acid != null and acid is AcidSplashEffect, "VFX2D.acid_splash(): returns one")
	if acid != null:
		_check(acid.get_bubble_count() == 6,
				"acid_splash: honours bubble_count (got %d)" % acid.get_bubble_count())
		await _wait(0.35)
		_check(acid.get_pop_count() > 0,
				"acid_splash: bubbles pop over time (%d)" % acid.get_pop_count())
	await _wait(0.4)

	var crack: ImpactCrackEffect = VFX2D.impact_crack(spot,
			{"duration": 0.12, "crack_count": 7, "surface": Vector2.UP}) as ImpactCrackEffect
	_check(crack != null and crack is ImpactCrackEffect, "VFX2D.impact_crack(): returns one")
	if crack != null:
		_check(crack.get_crack_count() == 7,
				"impact_crack: honours crack_count (got %d)" % crack.get_crack_count())
		_check(crack.get_first_crack().size() >= 3, "impact_crack: crack has geometry")
		_check((crack.get("surface") as Vector2).is_equal_approx(Vector2.UP),
				"impact_crack: surface direction applied")
	await _wait(0.3)

	var chain: ChainLightningEffect = VFX2D.chain(spot,
			[Vector2(140.0, 60.0), Vector2(260.0, 20.0)],
			{"duration": 0.12}) as ChainLightningEffect
	_check(chain != null and chain is ChainLightningEffect, "VFX2D.chain(): returns one")
	if chain != null:
		_check(chain.get_hop_count() == 2,
				"chain_lightning: one hop per target (got %d)" % chain.get_hop_count())
		var hop: PackedVector2Array = chain.get_first_hop()
		_check(hop.size() >= 3, "chain_lightning: first hop has geometry (%d)" % hop.size())
		if hop.size() >= 2:
			_check(hop[0].is_equal_approx(Vector2.ZERO), "chain_lightning: starts at the origin")
			# Points are relative to the spawn position, so the endpoint is the
			# target minus the chain's origin (20, 45).
			_check(hop[hop.size() - 1].is_equal_approx(Vector2(120.0, 15.0)),
					"chain_lightning: first hop ends at the first target (%s)"
							% hop[hop.size() - 1])
	await _wait(0.3)

	var blink: BlinkEffect = VFX2D.blink(spot, Vector2(220.0, 145.0),
			{"duration": 0.12}) as BlinkEffect
	_check(blink != null and blink is BlinkEffect, "VFX2D.blink(): returns one")
	if blink != null:
		_check(blink.get_destination().is_equal_approx(Vector2(200.0, 100.0)),
				"blink: destination is relative to the source (%s)" % blink.get_destination())
	await _wait(0.3)
	VFX2D.stop_all()
	await get_tree().process_frame


func _test_reactive_modifiers() -> void:
	VFX2D.stop_all()
	await get_tree().process_frame
	var holder := Node2D.new()
	holder.position = Vector2(80.0, 80.0)
	add_child(holder)
	var other := Node2D.new()
	other.position = Vector2(260.0, 180.0)
	add_child(other)

	var bubble: ShieldBubble = VFX2D.shield(holder, {"radius": 60.0})
	_check(bubble != null and bubble is ShieldBubble, "VFX2D.shield(): returns a ShieldBubble")
	if bubble != null:
		_check(bubble.get_parent() == holder, "shield: parents itself to the target")
		_check(bubble.get_hex_count() > 0,
				"shield: built its lattice (%d cells)" % bubble.get_hex_count())
		_check(is_equal_approx(bubble.get_openness(), 0.0), "shield: starts closed")
		await _wait(0.3)
		_check(bubble.get_openness() > 0.9, "shield: opens to full (%.2f)" % bubble.get_openness())
		bubble.hit(Vector2(130.0, 80.0))
		_check(bubble.get_hit_count() == 1, "shield: hit() registers an impact")
		_check(is_equal_approx(bubble.get_openness(), 1.0)
				or bubble.get_openness() > 0.9, "shield: stays up while hit")
		var closed := [0]
		bubble.finished.connect(func() -> void: closed[0] += 1)
		bubble.stop()
		await _wait(0.7)
		_check(closed[0] == 1, "shield: emitted finished once (got %d)" % closed[0])
		_check(not is_instance_valid(bubble), "shield: freed itself after closing")
	_check(VFX2D.get_persistent_count() == 0, "shield: dropped from the persistent list")

	var link: Tether = VFX2D.tether(holder, other, {"link_count": 12})
	_check(link != null and link is Tether, "VFX2D.tether(): returns a Tether")
	if link != null:
		_check(link.has_ends(), "tether: keeps both ends")
		var points: PackedVector2Array = link.get_chain_points()
		_check(points.size() >= 4, "tether: sampled the chain (%d points)" % points.size())
		if points.size() >= 2:
			_check(points[0].is_equal_approx(link.to_local(holder.global_position)),
					"tether: chain starts at the first node (%s)" % points[0])
		_check(link.get_link_count() == 12, "tether: honours link_count")
		await _wait(0.3)
		_check(link.get_openness() > 0.9, "tether: opens to full")
		link.stop()
		await _wait(0.7)
		_check(not is_instance_valid(link), "tether: stop() frees the chain")
	_check(VFX2D.get_persistent_count() == 0, "tether: dropped from the persistent list")

	var field: Vortex = VFX2D.vortex(Vector2(200.0, 120.0),
			{"radius": 80.0, "mote_count": 18})
	_check(field != null and field is Vortex, "VFX2D.vortex(): returns a Vortex")
	if field != null:
		_check(field.get_mote_count() == 18,
				"vortex: honours mote_count (got %d)" % field.get_mote_count())
		await _wait(0.35)
		_check(field.get_openness() > 0.9, "vortex: opens to full")
		field.stop()
		await _wait(0.8)
		_check(not is_instance_valid(field), "vortex: stop() frees the field")
	_check(VFX2D.get_persistent_count() == 0, "vortex: dropped from the persistent list")

	# A tether must let go when one of its ends leaves the tree.
	var doomed := Node2D.new()
	add_child(doomed)
	var doomed_link: Tether = VFX2D.tether(holder, doomed)
	_check(doomed_link != null, "tether: attaches to a second node")
	doomed.queue_free()
	await _wait(0.3)
	_check(not is_instance_valid(doomed_link), "tether: frees itself when an end is gone")

	if is_instance_valid(holder):
		holder.queue_free()
	await get_tree().process_frame


func _test_gallery_pages() -> void:
	# The gallery used to fire all sixteen effects at once, which is a stress
	# test rather than a gallery. It is paged now: a page may only spawn a
	# handful of effects, and switching pages clears what was running.
	var gallery: Node = (load("res://demo/gallery.tscn") as PackedScene).instantiate()
	# Pause before the node enters the tree: otherwise a slow first frame lets a
	# cell tick on its own and the counts below stop meaning anything.
	gallery.call("set_paused", true)
	add_child(gallery)
	await get_tree().process_frame
	var pages := int(gallery.call("get_page_count"))
	_check(pages >= 3, "gallery: split into pages (got %d)" % pages)
	if pages < 3:
		gallery.queue_free()
		await get_tree().process_frame
		return
	_check(int(gallery.call("get_cells_on_page")) <= 6,
			"gallery: a page holds a few cells, not everything (%d)"
					% int(gallery.call("get_cells_on_page")))

	_check(bool(gallery.call("is_paused")), "gallery: timers can be paused for inspection")

	var peak := 0
	for page_index in pages:
		gallery.call("set_page", page_index)
		await get_tree().process_frame
		_check(int(gallery.call("get_page")) == page_index,
				"gallery: set_page(%d) sticks" % page_index)
		var cells := int(gallery.call("get_cells_on_page"))
		for cell in cells:
			gallery.call("_fire", cell)
			await get_tree().process_frame
		peak = maxi(peak, VFX2D.get_active_count())
		_check(VFX2D.get_active_count() <= cells,
				"gallery: page %d keeps at most one effect per cell (active=%d)"
						% [page_index + 1, VFX2D.get_active_count()])
	_check(peak <= 6, "gallery: no page ever runs more than a few effects (peak=%d)" % peak)

	# Firing an index that does not exist on this page must be ignored.
	var before := VFX2D.get_active_count()
	gallery.call("_fire", 99)
	_check(VFX2D.get_active_count() == before, "gallery: out-of-range cells are ignored")

	gallery.call("set_page", 0)
	await get_tree().process_frame
	_check(int(gallery.call("get_page")) == 0, "gallery: wrapping back to the first page works")
	_check(VFX2D.get_persistent_count() == 0,
			"gallery: switching pages clears persistent modifiers (%d)"
					% VFX2D.get_persistent_count())

	gallery.queue_free()
	await _wait(0.1)
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
