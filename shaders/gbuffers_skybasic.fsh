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
// filtered fbm: an octave whose period drops below ~2 px fades to its mean (no aliasing near the horizon)
float fbmAA(vec2 p) {
	float fw = max(length(fwidth(p)), 1e-5), s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * mix(vnoise(p), 0.5, smoothstep(0.25, 0.5, fw)); p = p * 2.03 + 17.1; fw *= 2.03; a *= 0.5; }
	return s;
}
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
uniform int renderStage;
void main() {
	// vanilla star quads would draw over our clouds (white dots at sunrise): Solace draws its own stars
#ifdef MC_RENDER_STAGE_STARS
	if (renderStage == MC_RENDER_STAGE_STARS) discard;
#endif
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
#if SOFT_STARS > 0
		{
			// soft round stars: a jittered point per cell, smooth disc with a faint halo, a few slightly warm or cool,
			// with a very slow gentle breathing (no flicker)
			vec3 sc3 = floor(sd * 60.0); float h3 = hash12(sc3.xy + sc3.z * 37.1); cell = sc3;
			vec3 fp = fract(sd * 60.0) - 0.5;
			vec3 jit = (vec3(hash12(cell.xy + 3.1), hash12(cell.yz + 7.7), hash12(cell.zx + 1.3)) - 0.5) * 0.4;
			vec3 dv = fp - jit; vec3 nS = normalize(sd); dv -= dot(dv, nS) * nS; float d = length(dv);
			float sz = mix(0.13, 0.26, hash12(cell.yx + 11.0));
			float disc = 1.0 - smoothstep(sz * 0.35, sz, d);
			float halo = (1.0 - smoothstep(sz, sz * 2.6, d)) * 0.3;
			float breathe = 0.85 + 0.15 * sin(frameTimeCounter * 0.6 + h3 * 60.0);
			float on = step(1.0 - 0.05 * float(SOFT_STARS), h3);
			h = 0.0; // no square band dots with soft stars
			vec3 sc = mix(vec3(0.86, 0.90, 1.0), vec3(1.0, 0.93, 0.82), step(0.7, hash12(cell.zy + 5.0)));
			col = mix(col, sc, clamp((disc + halo) * breathe * on, 0.0, 1.0) * night * (1.0 - rainStrength));
		}
#else
		if (h > 0.9965) col = mix(col, vec3(0.95, 0.95, 1.0), night * (1.0 - rainStrength));
#endif
#ifdef MILKY_WAY
		// faint painted Milky Way band across the night sky (soft, two-tone, banded)
		float band = 1.0 - abs(dot(normalize(sd), normalize(vec3(0.35, 0.25, 0.90))));
		// soft falloff + cloudy breakup so the band never shows straight edges
		float core = smoothstep(0.62, 1.0, band);
		float cl = fbm(sd.xy * 2.6 + sd.z * 1.7) * 0.65 + fbm(sd.yz * 6.0 + 3.0) * 0.35; // dust lanes and clumps
		float mw = core * smoothstep(0.30, 0.78, cl + core * 0.22);
		mw = clamp(mw, 0.0, 1.0) * 0.6;
		col = mix(col, col + vec3(0.16, 0.14, 0.26), mw * MILKY_WAY * night * (1.0 - rainStrength));
		if (h > 0.985 && mw > 0.3) col = mix(col, vec3(0.92, 0.92, 1.0), 0.6 * night * (1.0 - rainStrength)); // denser stars in the band
#endif
	}
#ifdef SOFT_CLOUDS
	// soft, puffy cel cumulus on a sky plane (replaces blocky vanilla clouds)
	{
		vec3 w = mat3(gbufferModelViewInverse) * dir;
		if (w.y > 0.015) {
			vec2 cp = w.xz / w.y * 1.6 + vec2(frameTimeCounter * 0.006, 0.0);
			float d = fbmAA(cp * 1.3);
			float cov = mix(0.56, 0.44, CLOUD_COVER);
			float mask = smoothstep(cov, cov + 0.06 + 0.25 * smoothstep(0.1, 1.0, length(fwidth(cp))), d) * smoothstep(0.015, 0.12, w.y);
			if (mask > 0.0) {
				vec3 sunW = normalize(mat3(gbufferModelViewInverse) * sunPosition);
				// self-shadow: density a little toward the sun -> lit tops, soft undersides
				float d2 = fbmAA(cp * 1.3 + sunW.xz * 0.10 + vec2(0.0, 0.06));
				float lit = celBand(clamp((d - d2) * 5.0 + 0.55 + (d - cov) * 1.5, 0.0, 1.0), 3);
				float sunH = dot(safeNormalize(sunPosition, up), up);
				float dayC = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
				float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
				vec3 top = mix(vec3(0.20, 0.22, 0.45), vec3(1.0, 1.0, 0.98), dayC);
				top = mix(top, mix(vec3(1.0, 0.82, 0.58), vec3(1.0, 0.85, 0.80), ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0)), dusk * 0.85); // sunrise: peach-rose
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
