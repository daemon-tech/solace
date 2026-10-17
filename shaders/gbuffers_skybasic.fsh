#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
	vec4 p = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
	vec3 dir = safeNormalize(p.xyz / max(abs(p.w), 1e-5), vec3(0, 0, -1));
	vec3 col = celSky(dir, sunPosition, upPosition, rainStrength);
	// stylized stars: sparse square-ish dots at night, above the horizon
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	float night = clamp(-dot(safeNormalize(sunPosition, up), up) * 4.0, 0.0, 1.0);
	if (night > 0.0 && dot(dir, up) > 0.05) {
		vec3 cell = floor(dir * 180.0);
		float h = hash12(cell.xy + cell.z * 37.1);
		if (h > 0.9965) col = mix(col, vec3(0.95, 0.95, 1.0), night * (1.0 - rainStrength));
	}
	outColor = vec4(col, 1.0);
}
