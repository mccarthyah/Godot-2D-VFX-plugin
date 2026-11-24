# gdlint: disable=max-public-methods
extends Node
## Global spawner and recycler for Sparkform.
##
## Registered as the [code]Sparkform[/code] autoload. Every effect scene is
## instantiated once and then reused from a per-scene pool, so fireworks-heavy
## gameplay does not churn the scene tree.
##
## [codeblock]
## Sparkform.hit_spark(enemy.global_position, Vector2.UP)
## Sparkform.explosion(boss.global_position, {"radius": 120.0})
## Sparkform.lightning(caster.global_position, target.global_position, {"branches": 4})
## Sparkform.cooldown_ring(ability_icon_node, 2.5)
## Sparkform.chain(caster.global_position, [a.global_position, b.global_position])
## Sparkform.vortex(charge_point, {"radius": 120.0})
## [/codeblock]
##
## Effects are parented to a dedicated [code]Sparkform_Layer[/code] node under the
## current scene, so they are never batched into gameplay containers and are
## cleaned up automatically on scene changes.

## Emitted right after an effect has been placed and started.
signal effect_spawned(effect: VFXEffect)
## Emitted when an effect finishes, whether it ran to completion or was stopped.
signal effect_finished(effect: VFXEffect)

## Effect base class, preloaded by path. Global class names are not resolvable
## until the project has been scanned once, which breaks a fresh install.
const VFXEffect := preload("res://addons/sparkform/core/vfx_effect.gd")

# Same reason: these are return types on the spawners below.
const ChainLightningEffect := preload("res://addons/sparkform/effects/chain_lightning.gd")
const BlinkEffect := preload("res://addons/sparkform/effects/blink.gd")
const FrostBurstEffect := preload("res://addons/sparkform/effects/frost_burst.gd")
const AcidSplashEffect := preload("res://addons/sparkform/effects/acid_splash.gd")
const ImpactCrackEffect := preload("res://addons/sparkform/effects/impact_crack.gd")
const ShieldBubble := preload("res://addons/sparkform/effects/shield_bubble.gd")
const Tether := preload("res://addons/sparkform/effects/tether.gd")
const Vortex := preload("res://addons/sparkform/effects/vortex.gd")
const BeamEffect := preload("res://addons/sparkform/effects/beam.gd")
const PortalEffect := preload("res://addons/sparkform/effects/portal.gd")
const RuneCircle := preload("res://addons/sparkform/effects/rune_circle.gd")
const TrailEffect := preload("res://addons/sparkform/effects/trail.gd")
const CooldownRing := preload("res://addons/sparkform/effects/cooldown_ring.gd")

@export_group("Pooling")
## Maximum number of idle instances kept per effect scene. Finished effects
## beyond this budget are freed instead of pooled.
@export_range(0, 256, 1) var pool_size_per_effect: int = 24
## Hard cap on simultaneously running effects. When exceeded, the oldest effect
## is stopped to keep frame times predictable during bursts.
@export_range(1, 1024, 1) var max_active_effects: int = 160
## Name of the node that hosts spawned effects under the current scene.
@export var container_node_name: String = "Sparkform_Layer"

var _scenes: Dictionary = {}
var _free_instances: Dictionary = {}
var _persistent: Array[Node] = []
var _active: Array[VFXEffect] = []
var _layer: Node2D = null


#region Public API

## Spawns the hit spark effect. [param direction] is the direction the sparks
## travel; [param options] overrides any exported property of
## [code]hit_spark.gd[/code].
func hit_spark(at: Vector2, direction: Vector2 = Vector2.UP, options: Dictionary = {}) -> VFXEffect:
	var opts: Dictionary = options.duplicate()
	opts["direction"] = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP
	return spawn(_effect_scene("hit_spark"), at, opts)


## Spawns the explosion effect centred on [param at].
func explosion(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("explosion"), at, options)


## Spawns a lightning bolt running from [param from] to [param to].
func lightning(from: Vector2, to: Vector2, options: Dictionary = {}) -> VFXEffect:
	var opts: Dictionary = options.duplicate()
	opts["end_offset"] = to - from
	return spawn(_effect_scene("lightning"), from, opts)


## Spawns a soft smoke or dust cloud at [param at].
func smoke_puff(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("smoke_puff"), at, options)


## Spawns an expanding shockwave centred on [param at]: rings and cracks, no fire.
func shockwave(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("shockwave"), at, options)


## Spawns a muzzle flash at [param at] pointing along [param direction].
func muzzle_flash(at: Vector2, direction: Vector2 = Vector2.RIGHT,
		options: Dictionary = {}) -> VFXEffect:
	var opts: Dictionary = options.duplicate()
	opts["direction"] = direction.normalized() if direction.length_squared() > 0.0001 \
			else Vector2.RIGHT
	return spawn(_effect_scene("muzzle_flash"), at, opts)


## Spawns ascending sparkles at [param at], for pickups, heals and buffs.
func heal_sparkle(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("heal_sparkle"), at, options)


## Spawns a melee crescent at [param at] centred on [param direction].
func slash_arc(at: Vector2, direction: Vector2 = Vector2.RIGHT,
		options: Dictionary = {}) -> VFXEffect:
	var opts: Dictionary = options.duplicate()
	if direction.length_squared() > 0.0001:
		opts["direction"] = direction.normalized()
	return spawn(_effect_scene("slash_arc"), at, opts)


## Spawns solid debris chunks at [param at].
func debris_burst(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("debris_burst"), at, options)


## Spawns a flattened water/sonar ripple at [param at].
func ripple(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("ripple"), at, options)


## Spawns an inward collapse at [param at], the reverse of an explosion.
func implosion(at: Vector2, options: Dictionary = {}) -> VFXEffect:
	return spawn(_effect_scene("implosion"), at, options)


## Chains a bolt through [param from] and every point in [param targets], one hop
## per target. Order matters: each hop is revealed after the previous one.
func chain(from: Vector2, targets: Array, options: Dictionary = {}) -> ChainLightningEffect:
	if targets.is_empty():
		push_warning("Sparkform.chain(): no targets, falling back to a lightning bolt")
		return null
	var opts: Dictionary = options.duplicate()
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for target in targets:
		var point: Vector2 = target if target is Vector2 else from
		points.append(point - from)
	opts["points"] = points
	return spawn(_effect_scene("chain_lightning"), from, opts) as ChainLightningEffect


## Teleports visually from [param from] to [param to]: collapse, streak, burst.
func blink(from: Vector2, to: Vector2, options: Dictionary = {}) -> BlinkEffect:
	var opts: Dictionary = options.duplicate()
	opts["destination"] = to - from
	return spawn(_effect_scene("blink"), from, opts) as BlinkEffect


## Spawns angular ice shards at [param at].
func frost_burst(at: Vector2, options: Dictionary = {}) -> FrostBurstEffect:
	return spawn(_effect_scene("frost_burst"), at, options) as FrostBurstEffect


## Spawns a sticky acid splat with popping bubbles at [param at].
func acid_splash(at: Vector2, options: Dictionary = {}) -> AcidSplashEffect:
	return spawn(_effect_scene("acid_splash"), at, options) as AcidSplashEffect


## Spawns ground-aligned cracks at [param at]. Pass [code]{"surface": Vector2.UP}[/code]
## for a ceiling hit.
func impact_crack(at: Vector2, options: Dictionary = {}) -> ImpactCrackEffect:
	return spawn(_effect_scene("impact_crack"), at, options) as ImpactCrackEffect


## Wraps [param target] in a reactive bubble. Call [method ShieldBubble.hit] with
## an impact point, or [method ShieldBubble.stop] to drop it.
func shield(target: Node2D, options: Dictionary = {}) -> ShieldBubble:
	if not is_instance_valid(target):
		push_error("Sparkform.shield(): target node is not valid")
		return null
	var scene: PackedScene = _effect_scene("shield_bubble")
	if scene == null:
		return null
	var bubble := scene.instantiate() as ShieldBubble
	if bubble == null:
		push_error("Sparkform.shield(): the root of shield_bubble.tscn must be a ShieldBubble")
		return null
	bubble.position = Vector2.ZERO
	target.add_child(bubble)
	_apply_options(bubble, options)
	_register_persistent(bubble)
	bubble.start()
	return bubble


## Links two nodes with a sagging energy chain.
func tether(from: Node2D, to: Node2D, options: Dictionary = {}) -> Tether:
	if not is_instance_valid(from) or not is_instance_valid(to):
		push_error("Sparkform.tether(): both nodes must be valid")
		return null
	var scene: PackedScene = _effect_scene("tether")
	if scene == null:
		return null
	var link := scene.instantiate() as Tether
	if link == null:
		push_error("Sparkform.tether(): the root of tether.tscn must be a Tether")
		return null
	_attach_persistent(link, options)
	link.set_targets(from, to)
	link.start()
	return link


## Opens a pull field at [param at]: motes spiral in and recycle at the centre.
func vortex(at: Vector2, options: Dictionary = {}) -> Vortex:
	var scene: PackedScene = _effect_scene("vortex")
	if scene == null:
		return null
	var field := scene.instantiate() as Vortex
	if field == null:
		push_error("Sparkform.vortex(): the root of vortex.tscn must be a Vortex")
		return null
	field.position = at
	_attach_persistent(field, options)
	field.start()
	return field


## Creates a persistent beam from [param from] to [param to]. Keep the returned
## node to re-aim it with [method BeamEffect.end_at] or end it with
## [method BeamEffect.stop].
func beam(from: Vector2, to: Vector2, options: Dictionary = {}) -> BeamEffect:
	var scene: PackedScene = _effect_scene("beam")
	if scene == null:
		return null
	var effect := scene.instantiate() as BeamEffect
	if effect == null:
		push_error("Sparkform.beam(): the root of beam.tscn must be a BeamEffect")
		return null
	effect.position = from
	effect.end_offset = to - from
	_attach_persistent(effect, options)
	effect.start()
	return effect


## Opens a persistent portal at [param at]. Call [method PortalEffect.stop] on the
## returned node to play the closing animation.
func portal(at: Vector2, options: Dictionary = {}) -> PortalEffect:
	var scene: PackedScene = _effect_scene("portal")
	if scene == null:
		return null
	var effect := scene.instantiate() as PortalEffect
	if effect == null:
		push_error("Sparkform.portal(): the root of portal.tscn must be a PortalEffect")
		return null
	effect.position = at
	_attach_persistent(effect, options)
	effect.start()
	return effect


## Adds a cast circle as a child of [param target]. [param seconds] sets how long
## it runs before closing on its own ([code]0[/code] runs until stopped).
func rune_circle(target: Node2D, seconds: float = 0.0,
		options: Dictionary = {}) -> RuneCircle:
	if not is_instance_valid(target):
		push_error("Sparkform.rune_circle(): target node is not valid")
		return null
	var scene: PackedScene = _effect_scene("rune_circle")
	if scene == null:
		return null
	var rune := scene.instantiate() as RuneCircle
	if rune == null:
		push_error("Sparkform.rune_circle(): the root of rune_circle.tscn must be a RuneCircle")
		return null
	rune.position = Vector2.ZERO
	target.add_child(rune)
	_apply_options(rune, options)
	_register_persistent(rune)
	rune.start(seconds)
	return rune


## Attaches a ribbon trail to [param target]. It frees itself when the target
## leaves the tree, or earlier with [method TrailEffect.stop].
func trail(target: Node2D, options: Dictionary = {}) -> TrailEffect:
	if not is_instance_valid(target):
		push_error("Sparkform.trail(): target node is not valid")
		return null
	var scene: PackedScene = _effect_scene("trail")
	if scene == null:
		return null
	var ribbon := scene.instantiate() as TrailEffect
	if ribbon == null:
		push_error("Sparkform.trail(): the root of trail.tscn must be a TrailEffect")
		return null
	_get_layer().add_child(ribbon)
	_apply_options(ribbon, options)
	_register_persistent(ribbon)
	ribbon.attach_to(target)
	return ribbon


## Adds a cooldown ring as a child of [param target] and starts it immediately.
## Returns the ring so callers can inspect [member CooldownRing.progress],
## restart it, or cancel it.
func cooldown_ring(target: Node2D, seconds: float = 1.0, options: Dictionary = {}) -> CooldownRing:
	if not is_instance_valid(target):
		push_error("Sparkform.cooldown_ring(): target node is not valid")
		return null
	var scene: PackedScene = _effect_scene("cooldown_ring")
	if scene == null:
		return null
	var ring := scene.instantiate() as CooldownRing
	if ring == null:
		push_error("Sparkform.cooldown_ring(): the root of cooldown_ring.tscn must be a CooldownRing")
		return null
	ring.position = Vector2.ZERO
	target.add_child(ring)
	_apply_options(ring, options)
	ring.start(seconds)
	return ring


## Spawns an arbitrary effect scene at [param at]. Returns [code]null[/code] if
## the scene's root does not extend [VFXEffect].
func spawn(scene: PackedScene, at: Vector2, options: Dictionary = {}) -> VFXEffect:
	if scene == null:
		return null
	var effect := _take_free_instance(scene)
	if effect == null:
		var instance: Node = scene.instantiate()
		if not (instance is VFXEffect):
			push_error("Sparkform.spawn(): the root of '%s' must extend VFXEffect" % scene.resource_path)
			instance.free()
			return null
		effect = instance
		effect.free_on_finish = false
		effect.set_meta(&"vfx_scene", scene)
		effect.finished.connect(_on_effect_finished.bind(effect))
	var layer := _get_layer()
	if effect.get_parent() == null:
		layer.add_child(effect)
	elif effect.get_parent() != layer:
		effect.reparent(layer)
	effect.global_position = at
	effect.rotation = 0.0
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE
	effect.visible = true
	effect.configure(options)
	_active.append(effect)
	_trim_active()
	effect.play()
	effect_spawned.emit(effect)
	return effect


## Stops every running effect, returning instances to their pools.
func stop_all() -> void:
	var running := _active.duplicate()
	_active.clear()
	for effect in running:
		if is_instance_valid(effect):
			effect.stop()
	_prune_persistent()
	var persistent: Array = _persistent.duplicate()
	_persistent.clear()
	for node in persistent:
		if is_instance_valid(node) and node.has_method("stop"):
			node.stop()


## Number of persistent modifiers (beams, portals, runes, trails) still live.
func get_persistent_count() -> int:
	_prune_persistent()
	return _persistent.size()


## Number of effects currently running.
func get_active_count() -> int:
	_prune_active()
	return _active.size()

#endregion


#region Internals

func _effect_scene(effect_name: String) -> PackedScene:
	if _scenes.has(effect_name):
		return _scenes[effect_name]
	var path := _effects_dir().path_join(effect_name + ".tscn")
	if not ResourceLoader.exists(path):
		push_error("Sparkform: no '%s' effect scene (looked for %s)"
				% [effect_name, path])
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Sparkform: '%s' is not a PackedScene" % path)
		return null
	_scenes[effect_name] = scene
	return scene


func _effects_dir() -> String:
	var script := get_script() as Script
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_base_dir().path_join("effects")
	return "res://addons/sparkform/effects"


func _get_layer() -> Node2D:
	if is_instance_valid(_layer) and _layer.is_inside_tree():
		return _layer
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	# A previous layer was freed with its scene, taking every pooled and active
	# effect with it. Drop those dead references before building a new layer.
	_prune_active()
	_prune_pools()
	_prune_persistent()
	_layer = Node2D.new()
	_layer.name = container_node_name
	_layer.z_index = 100
	host.add_child(_layer)
	return _layer


func _take_free_instance(scene: PackedScene) -> VFXEffect:
	var pool: Array = _free_instances.get(scene, [])
	while not pool.is_empty():
		# Pool entries can be freed objects: effects are parented to the Sparkform
		# layer, which belongs to the current scene, so change_scene_* frees the
		# whole pool at once. Popping into an untyped variable is deliberate:
		# assigning a freed instance to a typed one raises an engine error before
		# is_instance_valid() ever runs.
		var candidate: Variant = pool.pop_back()
		if not is_instance_valid(candidate):
			continue
		var effect: Node = candidate
		if effect.is_queued_for_deletion() or not effect.is_inside_tree():
			continue
		var reusable: VFXEffect = effect as VFXEffect
		if reusable == null:
			continue
		_free_instances[scene] = pool
		return reusable
	_free_instances[scene] = pool
	return null


func _on_effect_finished(effect: VFXEffect) -> void:
	_active.erase(effect)
	effect_finished.emit(effect)
	if not is_instance_valid(effect):
		return
	effect.visible = false
	effect.modulate = Color.WHITE
	var scene: Variant = effect.get_meta(&"vfx_scene", null)
	if scene is PackedScene:
		var pool: Array = _free_instances.get(scene, [])
		if pool.size() < pool_size_per_effect and not pool.has(effect):
			pool.append(effect)
			_free_instances[scene] = pool
			return
	effect.queue_free()


func _trim_active() -> void:
	_prune_active()
	while _active.size() > max_active_effects:
		var oldest: Variant = _active.pop_front()
		if not is_instance_valid(oldest):
			continue
		var effect: VFXEffect = oldest as VFXEffect
		if effect != null:
			effect.stop()


func _attach_persistent(effect: Node, options: Dictionary) -> void:
	_get_layer().add_child(effect)
	_apply_options(effect, options)
	_register_persistent(effect)


func _register_persistent(effect: Node) -> void:
	_prune_persistent()
	_persistent.append(effect)


## Forgets persistent modifiers that were freed with their scene.
func _prune_persistent() -> void:
	for index in range(_persistent.size() - 1, -1, -1):
		if not is_instance_valid(_persistent[index]):
			_persistent.remove_at(index)


## Forgets active effects that were freed with their scene.
func _prune_active() -> void:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)


## Forgets pooled instances that were freed with their scene.
func _prune_pools() -> void:
	for scene in _free_instances.keys():
		var kept: Array = []
		for instance in _free_instances[scene]:
			if is_instance_valid(instance):
				kept.append(instance)
		_free_instances[scene] = kept


func _apply_options(object: Object, options: Dictionary) -> void:
	if options.is_empty():
		return
	var names: Dictionary = {}
	for entry in object.get_property_list():
		names[entry.name] = true
	for key in options:
		var key_name := String(key)
		if names.has(key_name):
			object.set(key_name, options[key])
		else:
			push_warning("Sparkform: '%s' is not a property of %s" % [key_name, object.get_class()])

#endregion
