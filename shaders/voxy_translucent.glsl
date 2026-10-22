// Solace - Voxy LOD water/glass: turquoise like dh_water, flagged as water for composite
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
void voxy_emitFragment(VoxyFragmentParameters p) {
	uint axis = p.face >> 1u;
	float s = (p.face & 1u) == 1u ? 1.0 : -1.0;
	vec3 wn = axis == 0u ? vec3(0, s, 0) : (axis == 1u ? vec3(0, 0, s) : vec3(s, 0, 0));
	vec3 n = normalize(mat3(gbufferModelView) * wn);
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	float day = dayFactor(sunPosition, upPosition);
	float lb = celBand(clamp(dot(n, safeNormalize(shadowLightPosition, up)) * 1.5, 0.0, 1.0), CEL_BANDS);
	vec3 amb = mix(vec3(0.30, 0.36, 0.72), vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), day) * AMBIENT_BOOST;
	vec3 sunC = mix(vec3(0.16, 0.22, 0.42), max(vec3(1.04, 1.02, 1.0) - vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), 0.0), day);
	vec3 alb = p.sampledColour.rgb * p.tinting.rgb;
	// Iris id 10001 (block.properties); fallback: blue biome water tint on a translucent face
	bool water = p.customId == 10001u || (p.tinting.b > p.tinting.r * 1.2 && p.sampledColour.a < 0.95);
	if (water) alb = mix(vec3(0.12, 0.40, 0.82), alb, 0.2); // same deep blue as near water
	vec3 col = alb * (amb + sunC * lb * smoothstep(0.3, 0.7, max(p.lightMap.y, 0.5)));
	// LOD water side walls (section borders) are hidden so the sea reads as one calm surface (no seam wall)
	outColor = vec4(col, water ? (axis == 0u ? 0.85 : 0.0) : p.sampledColour.a);
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
	outFlag = vec4(0.0, 0.0, 0.0, 1.0); // like dh_water: no near-water effects (no matching depth)
}
