@tool
extends EditorPlugin
## Registers the [code]VFX2D[/code] autoload while the 2D VFX Kit plugin is enabled.
##
## Enabling the plugin in Project Settings → Plugins is the whole setup: it adds
## [code]res://addons/vfx_2d/vfx_2d.gd[/code] as an autoload named
## [code]VFX2D[/code] and saves the project so the setting survives the session.
##
## The autoload is only added if the project does not already define one, so a
## project that registers [code]VFX2D[/code] itself (like this repository's demo)
## keeps full control of the script path.
##
## Disabling the plugin deliberately leaves the autoload in place: it is the
## runtime API, and stripping it here would break `godot --path .` runs and
## exports made with the plugin switched off. Remove the entry from Project
## Settings → Autoload if you really want it gone.

const AUTOLOAD_NAME := "VFX2D"
const AUTOLOAD_PATH := "res://addons/vfx_2d/vfx_2d.gd"


func _enter_tree() -> void:
	var setting := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting):
		var existing: String = str(ProjectSettings.get_setting(setting))
		if not existing.ends_with(AUTOLOAD_PATH.get_file()):
			print("[2D VFX Kit] '%s' is already registered as %s — leaving it alone."
					% [AUTOLOAD_NAME, existing])
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# Godot 4.4+ stores the new autoload as a `uid://` reference. Rewrite it to a
	# plain `res://` path so the same project file still resolves on 4.2/4.3,
	# which know nothing about UIDs.
	ProjectSettings.set_setting(setting, "*" + AUTOLOAD_PATH)
	# Persist now rather than on editor quit: an autoload that only exists for the
	# length of one editor session is the classic "works in the editor, broken in
	# the export" bug.
	ProjectSettings.save()
	print("[2D VFX Kit] Registered the VFX2D autoload.")


func _exit_tree() -> void:
	pass
