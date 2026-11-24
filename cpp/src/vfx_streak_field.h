#ifndef VFX_STREAK_FIELD_2D_H
#define VFX_STREAK_FIELD_2D_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <random>
#include <vector>

namespace godot {

/// Data-oriented spark field: thousands of velocity-aligned streaks integrated
/// and drawn in one multimesh-style canvas call.
///
/// This is the C++ half of the 2D VFX Kit. GDScript is fine at a few dozen
/// particles, but per-particle line geometry in `_draw()` does not scale to the
/// densities that make sparks read as heat (hundreds to thousands). Here every
/// particle is a plain struct, integration is a tight loop, and all streaks are
/// submitted to the RenderingServer as a single multiline draw.
///
/// The addon uses it as an optional enhancement layer: when the library is
/// loaded, hit sparks and explosions add a streak pass; when it is absent,
/// `VFXStreaks.is_available()` returns false and the GDScript effects run alone.
class VFXStreakField2D : public Node2D {
	GDCLASS(VFXStreakField2D, Node2D)

	struct Particle {
		Vector2 position;
		Vector2 velocity;
		float life = 0.0f;
		float max_life = 1.0f;
		float phase = 0.0f;
		float shade = 0.0f;
	};

	std::vector<Particle> particles;
	std::mt19937 rng;
	int write_cursor = 0;

	int max_particles = 4096;
	float gravity = 900.0f;
	float drag = 1.8f;
	float turbulence = 0.0f;
	float streak_scale = 0.035f;
	float base_width = 2.0f;
	Color head_color = Color(1.0f, 0.98f, 0.92f);
	Color tail_color = Color(1.0f, 0.55f, 0.15f, 0.0f);
	bool additive = true;
	int seed = 0;

	// Diagnostics, also used by the headless test suite.
	int last_segment_count = 0;
	int total_spawned = 0;

	float rand01();
	void spawn_particle(const Vector2 &p_origin, const Vector2 &p_direction, float p_spread,
			float p_speed_min, float p_speed_max, float p_life_min, float p_life_max);

protected:
	static void _bind_methods();

public:
	VFXStreakField2D();

	void burst(const Dictionary &config);
	void clear();
	int get_alive_count() const;
	int get_drawn_segment_count() const;
	int get_total_spawned() const;

	void set_max_particles(int p_value);
	int get_max_particles() const;
	void set_gravity(float p_value);
	float get_gravity() const;
	void set_drag(float p_value);
	float get_drag() const;
	void set_turbulence(float p_value);
	float get_turbulence() const;
	void set_streak_scale(float p_value);
	float get_streak_scale() const;
	void set_base_width(float p_value);
	float get_base_width() const;
	void set_head_color(const Color &p_value);
	Color get_head_color() const;
	void set_tail_color(const Color &p_value);
	Color get_tail_color() const;
	void set_additive(bool p_value);
	bool get_additive() const;
	void set_seed(int p_value);
	int get_seed() const;

	void _ready() override;
	void _process(double p_delta) override;
	void _draw() override;
};

} // namespace godot

#endif // VFX_STREAK_FIELD_2D_H
