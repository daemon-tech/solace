#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
// Solace - vanilla cloud geometry, flat toon shading.
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
in vec4 vcolor;
in vec3 vnormal;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	float ny = dot(safeNormalize(vnormal, up), up);
	float sunH = dot(safeNormalize(sunPosition, up), up);
	float day = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
	float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
	// night clouds: dim indigo slabs, only slightly lighter than the night sky
	vec3 top = mix(vec3(0.17, 0.19, 0.42), vec3(1.0), day);
	top = mix(top, vec3(1.0, 0.93, 0.62), dusk * 0.8);
	vec3 side = top * vec3(0.90, 0.93, 1.0);
	vec3 under = top * vec3(0.74, 0.82, 1.0); // slightly bluish underside
	vec3 c = ny > 0.5 ? top : (ny < -0.5 ? under : side);
	c = mix(c, vec3(luma(c)) * 0.75, rainStrength * 0.6);
	outColor = vec4(c, vcolor.a * 0.95);
}
