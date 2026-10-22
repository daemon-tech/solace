// Solace - Voxy LOD terrain: same calm cel lighting as dh_terrain, so far land matches near land
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
vec3 vxFaceNormal(uint face) {
	// Minecraft face order: 0 down, 1 up, 2 north(-z), 3 south(+z), 4 west(-x), 5 east(+x)
	uint axis = face >> 1u;
	float s = (face & 1u) == 1u ? 1.0 : -1.0;
	vec3 n = axis == 0u ? vec3(0, s, 0) : (axis == 1u ? vec3(0, 0, s) : vec3(s, 0, 0));
	return normalize(mat3(gbufferModelView) * n);
}
vec3 vxLight(vec3 n, vec2 lm) {
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	float day = dayFactor(sunPosition, upPosition);
	float lb = celBand(clamp(dot(n, safeNormalize(shadowLightPosition, up)) * 1.5, 0.0, 1.0), CEL_BANDS);
	vec3 amb = mix(vec3(0.30, 0.36, 0.72), vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), day) * AMBIENT_BOOST;
	vec3 sunC = mix(vec3(0.16, 0.22, 0.42), max(vec3(1.04, 1.02, 1.0) - vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), 0.0), day);
	// LODs carry no shadow map: sky light stands in, so caves and overhangs stay dark without artifacts
	return amb * mix(0.55, 1.0, lm.y) + sunC * lb * smoothstep(0.3, 0.7, lm.y);
}
void voxy_emitFragment(VoxyFragmentParameters p) {
	vec3 n = vxFaceNormal(p.face);
	vec3 alb = p.sampledColour.rgb * p.tinting.rgb;
	// tinted grass tops: pull toward the same meadow green as GROUND_GRADE near terrain (no seam at chunk end)
	bool grass = p.face == 1u && p.tinting.g > p.tinting.b * 1.15 && p.tinting.g > p.tinting.r * 1.05;
	if (grass) alb = vec3(0.33, 0.73, 0.27) * mix(0.91, 1.04, clamp(luma(alb) / 0.55, 0.0, 1.0)) * 0.95;
	outColor = vec4(alb * vxLight(n, p.lightMap), 1.0);
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
	outFlag = vec4(0.0, 0.0, 0.0, 1.0);
}
