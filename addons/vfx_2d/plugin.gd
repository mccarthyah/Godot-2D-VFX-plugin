@tool
extends EditorPlugin
## Registers the [code]VFX2D[/code] autoload while the 2D VFX Kit plugin is enabled.
##
## The autoload is only added if the project does not already define one, so a
## project that registers [code]VFX2D[/code] itself (like this repository's demo)
## keeps full control of the script path.

const AUTOLOAD_NAME := "VFX2D"
const AUTOLOAD_PATH := "res://addons/vfx_2d/vfx_2d.gd"

var _owns_autoload: bool = false


func _enter_tree() -> void:
	var setting := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting):
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_owns_autoload = true
	print("[2D VFX Kit] Registered the VFX2D autoload.")


func _exit_tree() -> void:
	if not _owns_autoload:
		return
	remove_autoload_singleton(AUTOLOAD_NAME)
	_owns_autoload = false
	print("[2D VFX Kit] Removed the VFX2D autoload.")
