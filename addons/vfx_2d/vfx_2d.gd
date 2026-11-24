extends Node
## Global spawner and recycler for the 2D VFX Kit.
##
## Registered as the [code]VFX2D[/code] autoload. Every effect scene is
## instantiated once and then reused from a per-scene pool, so fireworks-heavy
## gameplay does not churn the scene tree.
##
## [codeblock]
## VFX2D.hit_spark(enemy.global_position, Vector2.UP)
## VFX2D.explosion(boss.global_position, {"radius": 120.0})
## VFX2D.lightning(caster.global_position, target.global_position, {"branches": 4})
## VFX2D.cooldown_ring(ability_icon_node, 2.5)
## [/codeblock]
##
## Effects are parented to a dedicated [code]VFX2D_Layer[/code] node under the
## current scene, so they are never batched into gameplay containers and are
## cleaned up automatically on scene changes.

## Emitted right after an effect has been placed and started.
signal effect_spawned(effect: VFXEffect)
## Emitted when an effect finishes, whether it ran to completion or was stopped.
signal effect_finished(effect: VFXEffect)

@export_group("Pooling")
## Maximum number of idle instances kept per effect scene. Finished effects
## beyond this budget are freed instead of pooled.
@export_range(0, 256, 1) var pool_size_per_effect: int = 24
## Hard cap on simultaneously running effects. When exceeded, the oldest effect
## is stopped to keep frame times predictable during bursts.
@export_range(1, 1024, 1) var max_active_effects: int = 160
## Name of the node that hosts spawned effects under the current scene.
@export var container_node_name: String = "VFX2D_Layer"

var _scenes: Dictionary = {}
var _free_instances: Dictionary = {}
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


## Adds a cooldown ring as a child of [param target] and starts it immediately.
## Returns the ring so callers can inspect [member CooldownRing.progress],
## restart it, or cancel it.
func cooldown_ring(target: Node2D, seconds: float = 1.0, options: Dictionary = {}) -> CooldownRing:
	if not is_instance_valid(target):
		push_error("VFX2D.cooldown_ring(): target node is not valid")
		return null
	var scene: PackedScene = _effect_scene("cooldown_ring")
	if scene == null:
		return null
	var ring := scene.instantiate() as CooldownRing
	if ring == null:
		push_error("VFX2D.cooldown_ring(): the root of cooldown_ring.tscn must be a CooldownRing")
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
			push_error("VFX2D.spawn(): the root of '%s' must extend VFXEffect" % scene.resource_path)
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


## Number of effects currently running.
func get_active_count() -> int:
	return _active.size()

#endregion


#region Internals

func _effect_scene(effect_name: String) -> PackedScene:
	if _scenes.has(effect_name):
		return _scenes[effect_name]
	var path := _effects_dir().path_join(effect_name + ".tscn")
	if not ResourceLoader.exists(path):
		push_error("VFX2D: could not find the '%s' effect scene (looked for %s)" % [effect_name, path])
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("VFX2D: '%s' is not a PackedScene" % path)
		return null
	_scenes[effect_name] = scene
	return scene


func _effects_dir() -> String:
	var script := get_script() as Script
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_base_dir().path_join("effects")
	return "res://addons/vfx_2d/effects"


func _get_layer() -> Node2D:
	if is_instance_valid(_layer) and _layer.is_inside_tree():
		return _layer
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	_layer = Node2D.new()
	_layer.name = container_node_name
	_layer.z_index = 100
	host.add_child(_layer)
	return _layer


func _take_free_instance(scene: PackedScene) -> VFXEffect:
	var pool: Array = _free_instances.get(scene, [])
	while pool.size() > 0:
		var candidate: VFXEffect = pool.pop_back()
		if is_instance_valid(candidate):
			_free_instances[scene] = pool
			return candidate
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
	while _active.size() > max_active_effects:
		var oldest: VFXEffect = _active[0]
		_active.remove_at(0)
		if is_instance_valid(oldest):
			oldest.stop()


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
			push_warning("VFX2D: '%s' is not a property of %s" % [key_name, object.get_class()])

#endregion
