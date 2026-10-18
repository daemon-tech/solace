#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
// Solace - stylized turquoise water; other translucents get simple cel lighting.
uniform sampler2D gtexture;
uniform mat4 gbufferModelView;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 vnormal;
in vec3 viewPos;
in vec3 worldPos;
flat in int isWater;
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;

void main() {
	vec2 lm = clamp((lmcoord - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
	float day = dayFactor(sunPosition, upPosition);
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	vec3 n = safeNormalize(vnormal, up);
	float light = celBand(max(lm.y * mix(0.35, 1.0, day), lm.x), 4) * 0.85 + 0.15;

	if (isWater == 1) {
		float t = frameTimeCounter;
		vec2 p = worldPos.xz;
#ifdef WATER_WAVES
		vec3 wn = vec3(sin(p.x * 1.3 + t * 1.4) * 0.09 + sin(p.y * 0.9 - t * 1.1) * 0.07, 1.0,
		               cos(p.y * 1.2 + t * 1.2) * 0.09 + cos(p.x * 0.7 + t * 0.8) * 0.07);
		if (abs(dot(n, up)) > 0.9) n = safeNormalize(mat3(gbufferModelView) * wn, n);
#endif
		vec3 v = safeNormalize(-viewPos, up);
		// banded fresnel: 4 clearly visible steps
		float fres = celBand(pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.0), 4);
		// softer teal surface; the depth colour is added in composite (shore -> deep gradient)
		vec3 base = vec3(0.30, 0.68, 0.85);
		vec3 bright = vec3(0.62, 0.86, 0.96);
		vec3 far = vec3(0.18, 0.46, 0.72);
		vec3 col = mix(base, bright, fres);
		col = mix(col, far, celBand(smoothstep(24.0, 96.0, length(viewPos)), 3) * 0.45);
		// banded sky reflection (stronger at grazing angles)
		vec3 refl = celSky(reflect(-v, n), sunPosition, upPosition, rainStrength);
		col = mix(col, refl, fres * 0.38);
		// darker deep patches drifting slowly (banded, world-space)
		float patch = vnoise(p * 0.06 + vec2(t * 0.02, 0.0));
		float deepPatch = step(0.58, patch) * 0.6 + step(0.45, patch) * 0.4;
		// soft wave crest lines drifting across the surface
		float wv = sin(p.x * 0.55 + p.y * 0.25 + t * 0.9 + vnoise(p * 0.15) * 4.0);
		float crest = step(0.86, wv) + step(0.93, wv); // two-step stylized crest line
		col = mix(col, vec3(0.86, 0.98, 1.0), clamp(crest, 0.0, 1.0) * mix(0.50, 0.85, step(1.5, crest)) * mix(0.4, 1.0, day));
		float spec = dot(reflect(-safeNormalize(shadowLightPosition, up), n), v);
		// banded sun glint: warm halo band + white core
		if (day > 0.3) {
			col = mix(col, vec3(1.0, 0.93, 0.72), step(0.955, spec) * 0.45);
			if (spec > 0.988) col = vec3(1.0);
		}
#ifdef WATER_SPARKLE
		// white sparkle streaks drifting with the waves
		vec2 sp = p * vec2(0.8, 3.0) + vec2(t * 0.4, 0.0);
		float sparkle = step(0.86, vnoise(sp)) * step(0.50, vnoise(p * 0.2 + t * 0.07)) * step(0.50, spec)
		              + step(0.965, vnoise(p * 1.6 + vec2(t * 0.35, -t * 0.2))) * day; // scattered small glints
		col = mix(col, vec3(1.0), clamp(sparkle, 0.0, 1.0) * 0.9 * mix(0.4, 1.0, day));
#endif
		outColor = vec4(col * mix(light, 1.0, 0.5 * day), max(mix(0.30, 0.85, fres) * WATER_OPACITY, clamp(crest, 0.0, 1.0) * 0.80));
		outFlag = vec4(1.0, 0.0, deepPatch, 1.0);
	} else {
		vec4 albedo = texture(gtexture, texcoord) * vcolor;
		if (albedo.a < 0.05) discard;
		outColor = vec4(albedo.rgb * light, albedo.a);
		outFlag = vec4(0.0, 0.0, 0.0, 1.0);
	}
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
}
