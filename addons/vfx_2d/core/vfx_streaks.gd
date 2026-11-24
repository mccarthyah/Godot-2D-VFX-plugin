class_name VFXStreaks
extends RefCounted
## Bridge to the optional C++ streak field (GDExtension).
##
## The extension is a separate, optional build: [code]tools/build_extension.sh[/code]
## compiles [code]cpp/[/code] against godot-cpp and drops the library into
## [code]addons/vfx_2d/bin/[/code]. When it is present this class instantiates
## [code]VFXStreakField2D[/code]; when it is not, every method here degrades to a
## no-op so the pure-GDScript effects keep working unchanged.
##
## [codeblock]
## if VFXStreaks.is_available():
##     var field := VFXStreaks.create(self, {"head_color": Color.ORANGE})
##     VFXStreaks.burst(field, {"count": 500, "spread": TAU})
## [/codeblock]

const FIELD_CLASS := &"VFXStreakField2D"


## Returns [code]true[/code] when the compiled extension is loaded.
static func is_available() -> bool:
	return ClassDB.class_exists(FIELD_CLASS)


## Creates a streak field under [param parent] and applies [param properties]
## (any exported property of the C++ node). Returns [code]null[/code] when the
## extension is not available.
static func create(parent: Node, properties: Dictionary = {}) -> Node2D:
	if not is_available():
		return null
	var field := ClassDB.instantiate(FIELD_CLASS) as Node2D
	if field == null:
		push_warning("VFXStreaks: could not instantiate %s" % FIELD_CLASS)
		return null
	for key in properties:
		var property := StringName(key)
		if property in field:
			field.set(property, properties[key])
		else:
			push_warning("VFXStreaks: '%s' is not a property of %s" % [key, FIELD_CLASS])
	parent.add_child(field)
	return field


## Emits a burst on [param field]. See the C++ class for the accepted keys:
## origin, count, direction, spread (radians), speed_min, speed_max,
## lifetime_min, lifetime_max.
static func burst(field: Node2D, config: Dictionary) -> void:
	if field == null or not is_instance_valid(field):
		return
	field.call("burst", config)


## Removes every live particle.
static func clear(field: Node2D) -> void:
	if field == null or not is_instance_valid(field):
		return
	field.call("clear")


## Live particle count, or [code]0[/code] when unavailable.
static func alive_count(field: Node2D) -> int:
	if field == null or not is_instance_valid(field):
		return 0
	return int(field.call("get_alive_count"))
