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
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
	vec4 p = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
	vec3 dir = safeNormalize(p.xyz / max(abs(p.w), 1e-5), vec3(0, 0, -1));
	vec3 col = celSky(dir, sunPosition, upPosition, rainStrength);
	// stylized stars: sparse square-ish dots at night, above the horizon
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	float night = clamp((-dot(safeNormalize(sunPosition, up), up) - 0.30) * 4.0, 0.0, 1.0);
	if (night > 0.0 && dot(dir, up) > 0.05) {
		// fixed in sky-space: view -> world, then rotate with the celestial sphere (sun path axis = z)
		vec3 w = mat3(gbufferModelViewInverse) * dir;
		float a = sunAngle * 6.2831853;
		vec3 sd = vec3(w.x * cos(a) + w.y * sin(a), -w.x * sin(a) + w.y * cos(a), w.z);
		vec3 cell = floor(sd * 180.0);
		float h = hash12(cell.xy + cell.z * 37.1);
		if (h > 0.9965) col = mix(col, vec3(0.95, 0.95, 1.0), night * (1.0 - rainStrength));
	}
#ifdef SOFT_CLOUDS
	// soft, puffy cel cumulus on a sky plane (replaces blocky vanilla clouds)
	{
		vec3 w = mat3(gbufferModelViewInverse) * dir;
		if (w.y > 0.015) {
			vec2 cp = w.xz / w.y * 1.6 + vec2(frameTimeCounter * 0.006, 0.0);
			float d = fbm(cp * 1.3);
			float cov = mix(0.56, 0.44, CLOUD_COVER);
			float mask = smoothstep(cov, cov + 0.06, d) * smoothstep(0.015, 0.12, w.y);
			if (mask > 0.0) {
				vec3 sunW = normalize(mat3(gbufferModelViewInverse) * sunPosition);
				// self-shadow: density a little toward the sun -> lit tops, soft undersides
				float d2 = fbm(cp * 1.3 + sunW.xz * 0.10 + vec2(0.0, 0.06));
				float lit = celBand(clamp((d - d2) * 5.0 + 0.55 + (d - cov) * 1.5, 0.0, 1.0), 3);
				float sunH = dot(safeNormalize(sunPosition, up), up);
				float dayC = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
				float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
				vec3 top = mix(vec3(0.20, 0.22, 0.45), vec3(1.0, 1.0, 0.98), dayC);
				top = mix(top, vec3(1.0, 0.82, 0.58), dusk * 0.85);
				vec3 under = mix(vec3(0.12, 0.13, 0.30), vec3(0.66, 0.74, 0.88), dayC);
				under = mix(under, vec3(0.78, 0.52, 0.55), dusk * 0.7);
				vec3 cc = mix(under, top, lit);
				cc = mix(cc, vec3(luma(cc)) * 0.8, rainStrength * 0.6);
				col = mix(col, cc, mask * 0.97);
			}
		}
	}
#endif
	outColor = vec4(col, 1.0);
}
