#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
// Solace - vanilla cloud geometry, flat toon shading.
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float sunAngle;
uniform float sbHot;
in vec4 vcolor;
in vec3 vnormal;
in vec3 viewPosC;
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outFlag; // a = 0.25 marks cloud pixels (the evening grade skips them)
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
	vec3 shade = mix(vec3(0.13, 0.14, 0.32), vec3(0.84, 0.88, 0.96), day); // soft pale undersides by day, not grey-blue blocks
	lit = mix(lit, (sunAngle > 0.75 || sunAngle < 0.25) ? vec3(1.0, 0.84, 0.78) : vec3(1.0, 0.80, 0.55), dusk * 0.75); // sunrise: peach-rose
	shade = mix(shade, (sunAngle > 0.75 || sunAngle < 0.25) ? vec3(0.86, 0.60, 0.64) : vec3(0.92, 0.56, 0.46), dusk * 0.7); // warm coral undersides
	// hot dry lands: evening clouds turn a soft peach to match the calm evening sky
	float hotC = sbHot * dusk * ((sunAngle > 0.75 || sunAngle < 0.25) ? 0.0 : 1.0);
	lit = mix(lit, vec3(1.0, 0.90, 0.82), clamp(hotC * 1.6, 0.0, 1.0));
	shade = mix(shade, vec3(0.95, 0.80, 0.76), clamp(hotC * 1.6, 0.0, 1.0));
	float k = ny > 0.5 ? 1.0 : (ny < -0.5 ? 0.0 : celBand(sl, 3) * 0.8 + 0.1);
	float dist = length(viewPosC);
#ifdef CLOUD_SMOOTH
	// far clouds: faces converge to one tone, so sub-pixel side faces no longer flicker as stair-steps
	float fz = smoothstep(96.0, 320.0, dist);
	k = mix(k, 0.62, fz);
#endif
	vec3 c = mix(shade, lit, k);
	c = mix(c, vec3(luma(c)) * 0.75, rainStrength * 0.6);
	float a = vcolor.a * 0.92 * (1.0 - smoothstep(180.0, 420.0, dist) * 0.5);
#ifdef CLOUD_SMOOTH
	// grazing faces (edge-on slivers) fade smoothly; the window widens with distance
	vec3 vd = normalize(-viewPosC);
	float ndv = abs(dot(nn, vd));
	a *= smoothstep(0.0, mix(0.05, 0.35, fz), ndv);
	// smooth mip-like fade toward the cloud edge
	a *= 1.0 - smoothstep(220.0, 520.0, dist) * 0.75;
	c = mix(c, mix(shade, lit, 0.62), fz * 0.5);
#endif
	// toward the low sun at dusk: cells melt into the glow (faces merge, edges see-through) instead of pale blocks
	float sw = smoothstep(0.2, 0.9, dot(normalize(viewPosC), sunD)) * dusk;
	c = mix(c, mix(shade, lit, 0.7), sw * 0.6);
	a *= 1.0 - 0.5 * sw;
	outColor = vec4(c, a);
	outFlag = vec4(0.0, 0.0, 0.0, 0.25);
}
