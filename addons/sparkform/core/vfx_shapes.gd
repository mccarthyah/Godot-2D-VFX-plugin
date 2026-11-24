extends RefCounted
## Procedural outline helpers shared by the effects.
##
## Every effect draws its own geometry, and the "chaos" knob is what makes that
## geometry irregular: rings that wobble, cones with torn edges, stars with
## uneven spikes. This file holds the maths so each effect does not repeat it.
##
## Effects load it with a relative [code]preload[/code] rather than a global
## class name, so they keep parsing even when the editor's class cache has not
## been generated yet.


## Closed, wobbling ring of [param points] vertices. [param wobble] is the
## fraction of [param radius] the outline may stray by.
static func irregular_ring(radius: float, wobble: float, points: int, phase: float,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var count: int = maxi(points, 8)
	var wobble_amount: float = maxf(wobble, 0.0) * radius
	var out := PackedVector2Array()
	out.resize(count)
	# Two harmonics with random phases read as organic; the small per-vertex
	# jitter keeps it from looking like a clean sine wave.
	var harmonic_a: float = rng.randf_range(2.0, 4.0)
	var harmonic_b: float = rng.randf_range(5.0, 9.0)
	var phase_a: float = rng.randf_range(-PI, PI)
	var phase_b: float = rng.randf_range(-PI, PI)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var reach: float = radius
		reach += wobble_amount * (0.6 * sin(harmonic_a * angle + phase_a + phase) \
				+ 0.4 * sin(harmonic_b * angle + phase_b))
		reach += rng.randf_range(-0.12, 0.12) * wobble_amount
		out[i] = Vector2(cos(angle), sin(angle)) * maxf(reach, 0.5)
	return out


## Torn cone for muzzle flashes: apex at the origin, jagged edge facing
## [param direction]. [param teeth] alternates long and short tips.
static func jagged_cone(direction: Vector2, length: float, half_angle: float, teeth: int,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(Vector2.ZERO)
	var axis: Vector2 = direction.normalized()
	if axis.length_squared() < 0.0001:
		axis = Vector2.RIGHT
	var base_angle: float = axis.angle()
	var steps: int = maxi(teeth, 2) * 2
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = base_angle - half_angle + 2.0 * half_angle * t
		var reach: float = length * (1.0 if i % 2 == 0 else rng.randf_range(0.42, 0.78))
		reach *= rng.randf_range(0.9, 1.12)
		out.append(Vector2(cos(angle), sin(angle)) * reach)
	return out


## Uneven star burst, used for flashes and sparkles.
static func star_burst(inner: float, outer: float, spikes: int, rotation: float,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = maxi(spikes, 3) * 2
	for i in range(count):
		var angle: float = rotation + TAU * float(i) / float(count)
		var reach: float = outer if i % 2 == 0 else inner
		reach *= rng.randf_range(0.78, 1.18)
		out.append(Vector2(cos(angle), sin(angle)) * maxf(reach, 0.5))
	return out


## Scatters [param count] unit vectors, biased towards [param direction] by
## [param bias] (0 = fully random ring, 1 = straight ahead).
static func scattered_directions(count: int, direction: Vector2, bias: float,
		rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var axis: Vector2 = direction.normalized()
	if axis.length_squared() < 0.0001:
		axis = Vector2.UP
	for i in range(maxi(count, 0)):
		var spread: float = (1.0 - clampf(bias, 0.0, 1.0)) * PI
		var angle: float = rng.randf_range(-spread, spread)
		out.append(axis.rotated(angle))
	return out
