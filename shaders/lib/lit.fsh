// Solace - shared cel-shaded fragment stage
uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform vec4 entityColor;
uniform int isEyeInWater;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 vnormal;
in vec4 shadowClip;
flat in int isFoliage;
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;

float shadowAt(vec4 clip) {
#ifdef SHADOWS
	if (abs(clip.w) < 1e-5) return 1.0;
	vec3 p = celDistort(clip.xyz / clip.w) * 0.5 + 0.5;
	if (any(lessThan(p.xy, vec2(0.0))) || any(greaterThan(p.xy, vec2(1.0))) || p.z > 1.0) return 1.0;
	float bias = 0.0006;
	float lit = 0.0, count = 0.0;
	float texel = 1.0 / float(shadowMapResolution);
	int r = SHADOW_SOFTNESS;
	for (int x = -r; x <= r; x++)
	for (int y = -r; y <= r; y++) {
		float d = texture(shadowtex0, p.xy + vec2(x, y) * texel).r;
		lit += step(p.z - bias, d);
		count += 1.0;
	}
	return lit / count;
#else
	return 1.0;
#endif
}

void main() {
	vec4 albedo = texture(gtexture, texcoord) * vcolor;
#ifdef FLAT_NORMAL
	if (albedo.a < 0.3) discard; // particles: drop soft/empty texels (no square halos)
#else
	if (albedo.a < 0.1) discard;
#endif
	albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);

	vec2 lm = clamp((lmcoord - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
#ifdef FLAT_NORMAL
	vec3 n = up;
	float ndl = 0.7;
#else
	vec3 n = safeNormalize(vnormal, up);
	float ndl = dot(n, safeNormalize(shadowLightPosition, up));
#endif
	float day = dayFactor(sunPosition, upPosition);
	float light = clamp(ndl * 1.5, 0.0, 1.0);
#ifndef FLAT_NORMAL
	if (ndl > 0.0) light *= shadowAt(shadowClip);
#endif
	light *= smoothstep(0.3, 0.7, lm.y) * (1.0 - rainStrength * 0.7);
	float lb = celBand(light, CEL_BANDS);
	// foliage: flat fields with a single shadow tone (2 bands)
	if (isFoliage == 1) lb = step(0.35, light) * 0.9 + 0.1 * lb;

	// Light is white-balanced: ambient + sun ~= neutral white on a fully lit surface.
	// Shadowed areas keep only the cool ambient term (blue, never pink/purple on warm albedo).
	vec3 ambDay = vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B);
	vec3 sunDay = max(vec3(1.04, 1.02, 1.0) - ambDay, 0.0); // complement -> neutral sum
	vec3 ambNight = vec3(0.30, 0.36, 0.72);                 // indigo, never black
	vec3 sunNight = vec3(0.16, 0.22, 0.42);                 // moonlight
	// at dusk the sun is low: lift ambient so foliage doesn't go black
	float duskLift = 1.0 + 1.2 * clamp(1.0 - abs(dot(safeNormalize(sunPosition, up), up)) * 5.0, 0.0, 1.0);
	vec3 ambient = duskLift * mix(ambNight, ambDay, day) * mix(0.55, 1.0, celBand(lm.y, 3)) * AMBIENT_BOOST;
	vec3 sunCol = mix(sunNight, sunDay, day);
	// torch light: warm orange pool with a sharp-ish falloff
	// two hard-ish rings: wide pool + bright core
	float torch = smoothstep(0.22, 0.34, lm.x) * 0.75 + smoothstep(0.55, 0.66, lm.x) * 0.9;
	vec3 block = vec3(1.0, 0.56, 0.20) * torch * mix(2.2, 0.45, day * lm.y);
	vec3 lighting = ambient + sunCol * lb + block + vec3(0.03);
	// underwater: kelp/seagrass/floor stay readable (light, not black)
	if (isEyeInWater == 1) lighting = max(lighting, vec3(0.80, 0.92, 1.0) * mix(0.6, 1.0, day));

#ifdef FLAT_NORMAL
	// particles: neutral brightness only, so they never pick up the cool/indigo tint
	lighting = vec3(max(mix(0.35, 1.0, lm.y * mix(0.4, 1.0, day)), lm.x));
#endif
	vec3 col = albedo.rgb * lighting;
	if (isFoliage == 1) {
		// lime-leaning, brighter foliage (#9dc832 direction)
		float l = luma(col);
		col = mix(col, vec3(l) * (isEyeInWater == 1 ? vec3(0.55, 1.05, 1.0) : mix(vec3(0.50, 0.78, 1.15), vec3(1.0, 1.28, 0.28) * 1.15, day)), FOLIAGE_LIME * mix(1.0, 1.0 - torch * 0.6, 1.0 - day));
	}
	outColor = vec4(clamp(col, 0.0, 4.0), albedo.a);
	outNormal = vec4(n * 0.5 + 0.5, isFoliage == 1 ? 0.5 : 1.0); // alpha 0.5 = foliage flag for outlines
}
