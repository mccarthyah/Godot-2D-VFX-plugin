#include "vfx_streak_field.h"

#include <godot_cpp/classes/canvas_item_material.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <algorithm>

using namespace godot;

namespace {
constexpr float TAU_F = 6.28318530718f;
}

VFXStreakField2D::VFXStreakField2D() {
	rng.seed(0x5eed5eedu);
}

float VFXStreakField2D::rand01() {
	// 24 bits of the Mersenne stream: plenty for particle jitter and cheaper
	// than constructing a uniform_real_distribution per call.
	return static_cast<float>(rng() >> 8) / 16777216.0f;
}

void VFXStreakField2D::spawn_particle(const Vector2 &p_origin, const Vector2 &p_direction,
		float p_spread, float p_speed_min, float p_speed_max, float p_life_min, float p_life_max) {
	Particle particle;
	const float angle = (rand01() - 0.5f) * p_spread;
	const float speed = p_speed_min + (p_speed_max - p_speed_min) * rand01();
	particle.position = p_origin;
	particle.velocity = p_direction.rotated(angle) * speed;
	particle.max_life = std::max(p_life_min + (p_life_max - p_life_min) * rand01(), 0.01f);
	particle.life = particle.max_life;
	particle.phase = rand01() * TAU_F;
	particle.shade = rand01();

	if (static_cast<int>(particles.size()) < max_particles) {
		particles.push_back(particle);
	} else if (!particles.empty()) {
		// Full: recycle in a ring so a sustained emitter keeps reusing memory.
		write_cursor = (write_cursor + 1) % static_cast<int>(particles.size());
		particles[static_cast<size_t>(write_cursor)] = particle;
	}
	total_spawned++;
}

void VFXStreakField2D::burst(const Dictionary &p_config) {
	if (max_particles <= 0) {
		return;
	}
	if (seed != 0) {
		rng.seed(static_cast<uint32_t>(seed));
	}
	const Vector2 origin = p_config.get("origin", Vector2());
	Vector2 direction = p_config.get("direction", Vector2(0.0f, -1.0f));
	if (direction.length_squared() < 0.000001f) {
		direction = Vector2(0.0f, -1.0f);
	}
	direction = direction.normalized();
	const int count = static_cast<int>(p_config.get("count", 24));
	const float spread = static_cast<float>(static_cast<double>(p_config.get("spread", TAU_F)));
	const float speed_min = static_cast<float>(static_cast<double>(p_config.get("speed_min", 120.0)));
	const float speed_max = static_cast<float>(static_cast<double>(p_config.get("speed_max", 420.0)));
	const float life_min = static_cast<float>(static_cast<double>(p_config.get("lifetime_min", 0.25)));
	const float life_max = static_cast<float>(static_cast<double>(p_config.get("lifetime_max", 0.6)));

	for (int i = 0; i < count; i++) {
		spawn_particle(origin, direction, spread, speed_min, speed_max,
				std::min(life_min, life_max), std::max(life_min, life_max));
	}
	if (!particles.empty() && !is_processing()) {
		set_process(true);
	}
}

void VFXStreakField2D::clear() {
	particles.clear();
	write_cursor = 0;
	last_segment_count = 0;
	set_process(false);
	queue_redraw();
}

int VFXStreakField2D::get_alive_count() const {
	return static_cast<int>(particles.size());
}

int VFXStreakField2D::get_drawn_segment_count() const {
	return last_segment_count;
}

int VFXStreakField2D::get_total_spawned() const {
	return total_spawned;
}

void VFXStreakField2D::_ready() {
	set_process(false);
	if (additive) {
		Ref<CanvasItemMaterial> material;
		material.instantiate();
		material->set_blend_mode(CanvasItemMaterial::BLEND_MODE_ADD);
		set_material(material);
	}
}

void VFXStreakField2D::_process(double p_delta) {
	if (particles.empty()) {
		set_process(false);
		return;
	}
	const float dt = static_cast<float>(p_delta);
	const float drag_factor = std::min(drag * dt, 1.0f);

	for (size_t i = 0; i < particles.size();) {
		Particle &particle = particles[i];
		particle.life -= dt;
		if (particle.life <= 0.0f) {
			// Swap-remove keeps the array dense without shifting.
			particle = particles.back();
			particles.pop_back();
			continue;
		}
		particle.velocity.y += gravity * dt;
		particle.velocity -= particle.velocity * drag_factor;
		if (turbulence > 0.0f) {
			particle.phase += dt * 7.0f;
			const float ax = std::sin(particle.phase + particle.position.y * 0.01f);
			const float ay = std::cos(particle.phase * 1.3f + particle.position.x * 0.012f);
			particle.velocity.x += ax * turbulence * 620.0f * dt;
			particle.velocity.y += ay * turbulence * 620.0f * dt;
		}
		particle.position += particle.velocity * dt;
		i++;
	}
	queue_redraw();
}

void VFXStreakField2D::_draw() {
	const int count = static_cast<int>(particles.size());
	// Two line segments per streak (head->mid, mid->tail): the renderer takes one
	// colour per segment, so this is what buys a head-to-tail gradient in a single
	// draw call. Anything else trips the "p_colors * 2 != p_points" assertion.
	const int segments_per_particle = 2;
	last_segment_count = count * segments_per_particle;
	if (count == 0) {
		return;
	}

	PackedVector2Array points;
	PackedColorArray colors;
	points.resize(count * segments_per_particle * 2);
	colors.resize(count * segments_per_particle);

	for (int i = 0; i < count; i++) {
		const Particle &particle = particles[static_cast<size_t>(i)];
		const float life_ratio = std::clamp(particle.life / particle.max_life, 0.0f, 1.0f);
		const Vector2 head = particle.position;
		const Vector2 tail = head - particle.velocity * streak_scale;
		const Vector2 middle = (head + tail) * 0.5f;

		// Head is hot and opaque; the tail cools toward tail_color and fades out.
		// Per-particle shade keeps dense bursts from looking stamped.
		Color head_color_local = head_color.lerp(tail_color, (1.0f - life_ratio) * 0.55f);
		head_color_local.a = head_color.a * life_ratio * (0.75f + 0.25f * particle.shade);
		Color tail_color_local = tail_color;
		tail_color_local.a = tail_color.a * life_ratio * 0.15f;

		const int point_index = i * segments_per_particle * 2;
		points.set(point_index, head);
		points.set(point_index + 1, middle);
		points.set(point_index + 2, middle);
		points.set(point_index + 3, tail);
		colors.set(i * segments_per_particle, head_color_local);
		colors.set(i * segments_per_particle + 1, tail_color_local);
	}

	RenderingServer *rs = RenderingServer::get_singleton();
	if (rs != nullptr) {
		rs->canvas_item_add_multiline(get_canvas_item(), points, colors, base_width);
	}
}

//region Properties

void VFXStreakField2D::set_max_particles(int p_value) {
	max_particles = std::max(p_value, 0);
}
int VFXStreakField2D::get_max_particles() const {
	return max_particles;
}
void VFXStreakField2D::set_gravity(float p_value) {
	gravity = p_value;
}
float VFXStreakField2D::get_gravity() const {
	return gravity;
}
void VFXStreakField2D::set_drag(float p_value) {
	drag = std::max(p_value, 0.0f);
}
float VFXStreakField2D::get_drag() const {
	return drag;
}
void VFXStreakField2D::set_turbulence(float p_value) {
	turbulence = std::clamp(p_value, 0.0f, 4.0f);
}
float VFXStreakField2D::get_turbulence() const {
	return turbulence;
}
void VFXStreakField2D::set_streak_scale(float p_value) {
	streak_scale = std::max(p_value, 0.0f);
}
float VFXStreakField2D::get_streak_scale() const {
	return streak_scale;
}
void VFXStreakField2D::set_base_width(float p_value) {
	base_width = std::max(p_value, 0.1f);
}
float VFXStreakField2D::get_base_width() const {
	return base_width;
}
void VFXStreakField2D::set_head_color(const Color &p_value) {
	head_color = p_value;
}
Color VFXStreakField2D::get_head_color() const {
	return head_color;
}
void VFXStreakField2D::set_tail_color(const Color &p_value) {
	tail_color = p_value;
}
Color VFXStreakField2D::get_tail_color() const {
	return tail_color;
}
void VFXStreakField2D::set_additive(bool p_value) {
	additive = p_value;
}
bool VFXStreakField2D::get_additive() const {
	return additive;
}
void VFXStreakField2D::set_seed(int p_value) {
	seed = p_value;
	if (seed != 0) {
		rng.seed(static_cast<uint32_t>(seed));
	}
}
int VFXStreakField2D::get_seed() const {
	return seed;
}

//endregion

void VFXStreakField2D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("burst", "config"), &VFXStreakField2D::burst);
	ClassDB::bind_method(D_METHOD("clear"), &VFXStreakField2D::clear);
	ClassDB::bind_method(D_METHOD("get_alive_count"), &VFXStreakField2D::get_alive_count);
	ClassDB::bind_method(D_METHOD("get_drawn_segment_count"), &VFXStreakField2D::get_drawn_segment_count);
	ClassDB::bind_method(D_METHOD("get_total_spawned"), &VFXStreakField2D::get_total_spawned);

	ClassDB::bind_method(D_METHOD("set_max_particles", "value"), &VFXStreakField2D::set_max_particles);
	ClassDB::bind_method(D_METHOD("get_max_particles"), &VFXStreakField2D::get_max_particles);
	ClassDB::bind_method(D_METHOD("set_gravity", "value"), &VFXStreakField2D::set_gravity);
	ClassDB::bind_method(D_METHOD("get_gravity"), &VFXStreakField2D::get_gravity);
	ClassDB::bind_method(D_METHOD("set_drag", "value"), &VFXStreakField2D::set_drag);
	ClassDB::bind_method(D_METHOD("get_drag"), &VFXStreakField2D::get_drag);
	ClassDB::bind_method(D_METHOD("set_turbulence", "value"), &VFXStreakField2D::set_turbulence);
	ClassDB::bind_method(D_METHOD("get_turbulence"), &VFXStreakField2D::get_turbulence);
	ClassDB::bind_method(D_METHOD("set_streak_scale", "value"), &VFXStreakField2D::set_streak_scale);
	ClassDB::bind_method(D_METHOD("get_streak_scale"), &VFXStreakField2D::get_streak_scale);
	ClassDB::bind_method(D_METHOD("set_base_width", "value"), &VFXStreakField2D::set_base_width);
	ClassDB::bind_method(D_METHOD("get_base_width"), &VFXStreakField2D::get_base_width);
	ClassDB::bind_method(D_METHOD("set_head_color", "value"), &VFXStreakField2D::set_head_color);
	ClassDB::bind_method(D_METHOD("get_head_color"), &VFXStreakField2D::get_head_color);
	ClassDB::bind_method(D_METHOD("set_tail_color", "value"), &VFXStreakField2D::set_tail_color);
	ClassDB::bind_method(D_METHOD("get_tail_color"), &VFXStreakField2D::get_tail_color);
	ClassDB::bind_method(D_METHOD("set_additive", "value"), &VFXStreakField2D::set_additive);
	ClassDB::bind_method(D_METHOD("get_additive"), &VFXStreakField2D::get_additive);
	ClassDB::bind_method(D_METHOD("set_seed", "value"), &VFXStreakField2D::set_seed);
	ClassDB::bind_method(D_METHOD("get_seed"), &VFXStreakField2D::get_seed);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "max_particles", PROPERTY_HINT_RANGE, "0,65536,1"),
			"set_max_particles", "get_max_particles");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gravity", PROPERTY_HINT_RANGE, "-4000,4000,1,suffix:px/s"),
			"set_gravity", "get_gravity");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drag", PROPERTY_HINT_RANGE, "0,12,0.01"),
			"set_drag", "get_drag");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "turbulence", PROPERTY_HINT_RANGE, "0,2,0.01"),
			"set_turbulence", "get_turbulence");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "streak_scale", PROPERTY_HINT_RANGE, "0,0.3,0.001,suffix:s"),
			"set_streak_scale", "get_streak_scale");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "base_width", PROPERTY_HINT_RANGE, "0.1,24,0.1,suffix:px"),
			"set_base_width", "get_base_width");
	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "head_color"), "set_head_color", "get_head_color");
	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "tail_color"), "set_tail_color", "get_tail_color");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "additive"), "set_additive", "get_additive");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");
}
