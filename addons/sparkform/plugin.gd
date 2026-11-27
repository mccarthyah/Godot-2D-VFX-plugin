@tool
extends EditorPlugin
## Registers the [code]Sparkform[/code] autoload when the plugin is enabled.
##
## An existing [code]Sparkform[/code] entry is left untouched. Disabling the plugin
## leaves the autoload in place as well: it is the runtime API, so removing it
## would break exports and `godot --path .` runs made with the plugin off.
## Delete the entry in Project Settings → Autoload to get rid of it.

const AUTOLOAD_NAME := "Sparkform"
const AUTOLOAD_PATH := "res://addons/sparkform/sparkform.gd"


func _enter_tree() -> void:
	var setting := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting):
		var existing: String = str(ProjectSettings.get_setting(setting))
		if not existing.ends_with(AUTOLOAD_PATH.get_file()):
			print("[Sparkform] '%s' already registered as %s, leaving it alone."
					% [AUTOLOAD_NAME, existing])
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# 4.4+ writes a uid:// reference here, which 4.2/4.3 cannot resolve.
	ProjectSettings.set_setting(setting, "*" + AUTOLOAD_PATH)
	# Save now, not on quit: the setting has to outlive this editor session.
	ProjectSettings.save()
	print("[Sparkform] autoload registered.")


func _exit_tree() -> void:
	pass
