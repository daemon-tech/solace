#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
// Solace - vanilla cloud geometry, flat toon shading.
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
in vec4 vcolor;
in vec3 vnormal;
in vec3 viewPosC;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
#ifdef SOFT_CLOUDS
	discard;
#endif
	// cubic block clouds: soft lit faces (sun side brighter), warm sunset tint, see-through edges far away
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	vec3 nn = safeNormalize(vnormal, up);
	float ny = dot(nn, up);
	vec3 sunD = safeNormalize(sunPosition, up);
	float sunH = dot(sunD, up);
	float day = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
	float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
	float sl = clamp(dot(nn, sunD) * 0.5 + 0.5, 0.0, 1.0);
	vec3 lit = mix(vec3(0.20, 0.22, 0.46), vec3(1.0, 1.0, 0.98), day);
	vec3 shade = mix(vec3(0.13, 0.14, 0.32), vec3(0.72, 0.80, 0.94), day);
	lit = mix(lit, vec3(1.0, 0.80, 0.55), dusk * 0.75);
	shade = mix(shade, vec3(0.80, 0.56, 0.62), dusk * 0.6);
	float k = ny > 0.5 ? 1.0 : (ny < -0.5 ? 0.0 : celBand(sl, 3) * 0.8 + 0.1);
	vec3 c = mix(shade, lit, k);
	c = mix(c, vec3(luma(c)) * 0.75, rainStrength * 0.6);
	float dist = length(viewPosC);
	float a = vcolor.a * 0.92 * (1.0 - smoothstep(180.0, 420.0, dist) * 0.5);
	outColor = vec4(c, a);
}
