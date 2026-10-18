#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
in vec4 vcolor;
in vec3 vnormal;
in vec2 lm;
in vec3 vpos;
uniform float far;
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
void main() {
	// LODs only beyond the real chunks: never draw over near terrain (prevents overlap artifacts)
	if (length(vpos) < far * 0.85) discard;
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	vec3 n = safeNormalize(vnormal, up);
	float day = dayFactor(sunPosition, upPosition);
	float lb = celBand(clamp(dot(n, safeNormalize(shadowLightPosition, up)) * 1.5, 0.0, 1.0), CEL_BANDS);
	vec3 amb = mix(vec3(0.30, 0.36, 0.72), vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), day) * AMBIENT_BOOST;
	vec3 sunC = mix(vec3(0.16, 0.22, 0.42), max(vec3(1.04, 1.02, 1.0) - vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B), 0.0), day);
	vec3 col = mix(vec3(0.10, 0.52, 0.62), vcolor.rgb, 0.25) * (amb + sunC * lb * smoothstep(0.3, 0.7, max(lm.y, 0.5)));
	outColor = vec4(col, 0.85);
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
	outFlag = vec4(0.0, 0.0, 0.0, 1.0);
}
