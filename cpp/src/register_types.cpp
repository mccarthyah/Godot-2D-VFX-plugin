#include "vfx_streak_field.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

namespace {
void initialize_vfx_streaks_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(VFXStreakField2D);
}

void uninitialize_vfx_streaks_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}
} // namespace

extern "C" {
GDExtensionBool GDE_EXPORT vfx_streaks_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_vfx_streaks_module);
	init_obj.register_terminator(uninitialize_vfx_streaks_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
