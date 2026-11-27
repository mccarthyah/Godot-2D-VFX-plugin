class_name VFXEffect
extends Node2D
## Base class for every one-shot effect in Sparkform.
##
## An effect is a short-lived scene that plays for [member duration] seconds and
## then emits [signal finished]. [code]Sparkform[/code] listens for that signal and
## recycles the instance instead of freeing it, so spawning is allocation free
## after warm-up.
##
## Subclasses implement the three virtual callbacks below and draw with
## [method CanvasItem._draw] if they need geometry:
## [codeblock]
## func _on_play() -> void:
##     pass                        # configure particles, reset state
##
## func _on_update(progress: float, delta: float) -> void:
##     pass                        # progress is 0..1 across the lifetime
##
## func _on_stop() -> void:
##     pass                        # tear down / stop emitters
## [/codeblock]

## Emitted exactly once per [method play] call, when the effect reaches the end
## of its lifetime or is stopped early.
signal finished

@export_group("Lifetime")
## How long the effect runs, in seconds.
@export_range(0.01, 10.0, 0.01, "suffix:s") var duration: float = 0.5
## Free the node as soon as the effect finishes. Pooled effects spawned through
## [code]Sparkform[/code] always set this to [code]false[/code].
@export var free_on_finish: bool = true
## Play the effect as soon as it enters the tree (handy for effects dropped
## straight into a scene by hand).
@export var play_on_ready: bool = false

## Normalized lifetime, [code]0.0[/code] at the first frame and [code]1.0[/code]
## when the effect is done. Read it from [method _draw].
var progress: float = 0.0

var _elapsed: float = 0.0
var _playing: bool = false
var _property_names: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if play_on_ready:
		play()


func _process(delta: float) -> void:
	_elapsed += delta
	progress = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	_on_update(progress, delta)
	queue_redraw()
	if progress >= 1.0:
		stop()


## Starts (or restarts) the effect from the beginning.
func play() -> void:
	_elapsed = 0.0
	progress = 0.0
	_playing = true
	visible = true
	set_process(true)
	_on_play()
	_on_update(0.0, 0.0)
	queue_redraw()


## Stops the effect early and emits [signal finished]. Safe to call when the
## effect is already stopped.
func stop() -> void:
	if not _playing:
		return
	_playing = false
	set_process(false)
	progress = 1.0
	_on_stop()
	queue_redraw()
	finished.emit()
	if free_on_finish and is_inside_tree():
		queue_free()


## Returns [code]true[/code] while the effect is running.
func is_playing() -> bool:
	return _playing


## Applies a dictionary of exported properties by name. Unknown keys log a
## warning instead of failing, which keeps the [code]Sparkform[/code] convenience
## methods forgiving.
func configure(options: Dictionary) -> void:
	if options.is_empty():
		return
	if _property_names.is_empty():
		for entry in get_property_list():
			_property_names[entry.name] = true
	for key in options:
		var key_name := String(key)
		if _property_names.has(key_name):
			set(key_name, options[key])
		else:
			push_warning("VFXEffect: '%s' is not a property of %s" % [
				key_name,
				get_script().resource_path.get_file() if get_script() != null else "VFXEffect",
			])


# Virtual callbacks -----------------------------------------------------------

## Called from [method play] before the first update. Configure emitters here.
func _on_play() -> void:
	pass


## Called every frame while playing. [param progress] is [code]0.0[/code] to
## [code]1.0[/code] across [member duration].
func _on_update(_progress: float, _delta: float) -> void:
	pass


## Called from [method stop] when the effect ends, before [signal finished].
func _on_stop() -> void:
	pass
