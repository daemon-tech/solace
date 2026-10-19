#version 330 compatibility
#include "/lib/settings.glsl"
// Solace - wake map update: a world-anchored history of where the player moved through water.
// colortex6: 256x256 texels = 64x64 blocks (4 per block), toroidal addressing by world XZ,
// row 256 holds state (previous eye position, smoothed velocity). Nothing here depends on the camera.
/*
const int colortex6Format = RGBA32F;
const bool colortex6Clear = false;
*/
uniform sampler2D colortex6;
uniform vec3 eyePosition;
uniform vec3 cameraPosition;
uniform float frameTime;
/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 outWake;

vec2 eyeW() { return eyePosition.xz - cameraPosition.xz + mod(cameraPosition.xz, 4096.0); }

void main() {
	ivec2 c = ivec2(gl_FragCoord.xy);
	float dt = clamp(frameTime, 0.0, 0.25);
	vec4 st0 = texelFetch(colortex6, ivec2(0, 256), 0); // xyz previous eye (world, xz in 4096 basis), w valid
	vec4 st1 = texelFetch(colortex6, ivec2(1, 256), 0); // xy smoothed velocity, z feet height
	vec3 eye = vec3(eyeW().x, eyePosition.y, eyeW().y);
	vec3 prev = st0.w > 0.5 ? st0.xyz : eye;
	vec2 step2 = eye.xz - prev.xz;
	bool jump = length(step2) > 6.0 || length(step2) > 30.0 * max(dt, 0.02); // teleports / basis wrap: no smear
	if (jump) { prev = eye; step2 = vec2(0.0); }
	if (c.y >= 256) {
		if (c == ivec2(0, 256)) outWake = vec4(eye, 1.0);
		else if (c == ivec2(1, 256)) {
			vec2 v = dt > 0.0 ? step2 / dt : vec2(0.0);
			outWake = vec4(mix(st1.xy, v, 1.0 - exp(-dt / 0.25)), eyePosition.y - 1.62, 1.0);
		} else outWake = vec4(0.0);
		return;
	}
#ifdef WATER_WAKE
	// world cell this texel stands for: the one inside the 64-block window around the player
	vec2 g = vec2(c) + 256.0 * floor((eye.xz * 4.0 - vec2(c)) / 256.0 + 0.5);
	vec2 tile = floor(g / 256.0);
	float tag = 1.0 + mod(tile.x, 64.0) * 64.0 + mod(tile.y, 64.0);
	vec2 w = (g + 0.5) / 4.0;
	vec4 p = texelFetch(colortex6, c, 0);
	if (abs(p.b - tag) > 0.5) p = vec4(0.0, 0.0, tag, 0.0);
	// spread field: grows outward (~1.4 blocks/s) while it fades -> the trail widens into a fan behind the player
	float nmax = 0.0;
	for (int i = 0; i < 4; i++) {
		ivec2 o = ivec2(i == 0 ? 1 : (i == 1 ? -1 : 0), i == 2 ? 1 : (i == 3 ? -1 : 0));
		vec4 q = texelFetch(colortex6, (c + o + 256) % 256, 0);
		vec2 gq = vec2((c + o + 256) % 256) + 256.0 * floor((eye.xz * 4.0 - vec2((c + o + 256) % 256)) / 256.0 + 0.5);
		vec2 tq = floor(gq / 256.0);
		float tagq = 1.0 + mod(tq.x, 64.0) * 64.0 + mod(tq.y, 64.0);
		if (abs(q.b - tagq) < 0.5) nmax = max(nmax, q.a * 0.985);
	}
	float spread = mix(p.a, max(p.a, nmax), clamp(1.4 * 4.0 * dt, 0.0, 1.0));
	float core = p.r * exp(-dt / 2.4);
	spread *= exp(-dt / 3.2);
	// deposit along the swept segment previous eye -> eye (continuous at any frame rate)
	vec2 a = prev.xz, b = eye.xz, ab = b - a;
	float h = clamp(dot(w - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float d = length(w - a - ab * h);
	float spd = length(st1.xy);
	float amt = smoothstep(0.6, 2.5, spd);
	float dep = (1.0 - smoothstep(0.15, 0.6, d)) * amt;
	float feet = eyePosition.y - 1.62;
	float hgt = p.g;
	if (dep > 0.01) hgt = mix(p.g > 0.0 ? p.g : feet, feet, clamp(dep, 0.0, 1.0));
	core = max(core, dep);
	spread = max(spread, dep);
	outWake = vec4(core, hgt, tag, spread);
#else
	outWake = vec4(0.0);
#endif
}
