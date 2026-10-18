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
flat in int lightId;
in float windG;
in vec3 cwpos;
uniform float frameTimeCounter;
/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
layout(location = 3) out vec4 outLight; // emitted light colour of light sources (for coloured block light)

const vec2 poisson12[12] = vec2[12](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));
float shadowAt(vec4 clip, float ndl) {
#ifdef SHADOWS
	if (abs(clip.w) < 1e-5) return 1.0;
	vec3 nd = clip.xyz / clip.w;
	float dist = length(nd.xy) * 0.85 + 0.15; // distortion factor: texel density at this point
	vec3 p = celDistort(nd) * 0.5 + 0.5;
	if (any(lessThan(p.xy, vec2(0.0))) || any(greaterThan(p.xy, vec2(1.0))) || p.z > 1.0) return 1.0;
	float texel = 1.0 / float(shadowMapResolution);
	// slope-scaled bias in distorted space (no acne on grazing faces, no peter-panning on flat ones)
	float bias = (0.00025 + 0.0009 * (1.0 - clamp(ndl, 0.0, 1.0))) * dist;
	// rotation anchored to the world (stable while the camera moves, no crawling noise)
	float ang = hash12(floor(cwpos.xz * 8.0) + floor(cwpos.y * 8.0) * 17.0) * 6.2831853;
	mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
	float rad = (0.6 + float(SHADOW_SOFTNESS) * 1.1) * texel * mix(1.0, 1.6, dist);
	float lit = 0.0;
	for (int i = 0; i < 12; i++) {
		vec2 o = rot * poisson12[i] * rad;
		lit += step(p.z - bias, texture(shadowtex0, p.xy + o).r);
	}
	return lit / 12.0;
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
#ifdef HIDE_LEAF_LITTER
	if (isFoliage == 3) discard;
#endif
	// low-pass texture detail: smooth even grass tops and leaf masses (mip bias, alpha-corrected)
	{
		bool tinted = vcolor.g > vcolor.b * 1.15 && vcolor.g > vcolor.r * 1.05;
		float sm = (isFoliage == 2 && tinted) ? GRASS_SMOOTH : (isFoliage == 1 ? FOLIAGE_SMOOTH : 0.0);
		if (sm > 0.0) {
			vec4 lo = texture(gtexture, texcoord, 4.0);
			lo.rgb /= max(lo.a, 0.25);
			albedo.rgb = mix(albedo.rgb, lo.rgb * vcolor.rgb, sm);
		}
	}
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
	if (ndl > 0.0) light *= smoothstep(0.0, 1.0, shadowAt(shadowClip, ndl));
#endif
	light *= smoothstep(0.3, 0.7, lm.y) * (1.0 - rainStrength * 0.7);
	float lb = celBandSoft(light, CEL_BANDS, SHADOW_EDGE); // cel bands with soft shadow edges
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
	float golden = GOLDEN_HOUR_TINT * day * clamp(1.0 - dot(safeNormalize(sunPosition, up), up) * 3.5, 0.0, 1.0);
	// torch light: warm orange pool with a sharp-ish falloff
	// two hard-ish rings: wide pool + bright core
	float torch = celBand(pow(lm.x, 1.8), 4) * TORCH_STRENGTH; // softer falloff, 4 gentle bands
	vec3 block = vec3(1.0, 0.76, 0.50) * torch * mix(0.95, 0.35, day * lm.y); // neutral warm
	vec3 lighting = ambient + sunCol * lb + block + vec3(0.03);
	// underwater: kelp/seagrass/floor stay readable (light, not black)
	if (isEyeInWater == 1) lighting = max(lighting, vec3(0.62, 0.78, 0.95) * mix(0.6, 1.0, day));

#ifdef FLAT_NORMAL
	// particles: neutral brightness only, so they never pick up the cool/indigo tint
	lighting = vec3(max(mix(0.35, 1.0, lm.y * mix(0.4, 1.0, day)), lm.x));
#endif
#ifdef GROUND_GRADE
	// grass ground: tinted texels (grass top / side overlay) get flat, soft lighting
	bool grassTex = isFoliage == 2 && vcolor.g > vcolor.b * 1.15 && vcolor.g > vcolor.r * 1.05;
	if (grassTex) {
		lb = mix(lb, 1.0, 0.55 * smoothstep(0.1, 0.4, light)); // fewer, softer steps in sun
		lighting = ambient + sunCol * lb + block + vec3(0.03);
	}
#endif
	vec3 col = albedo.rgb * lighting;
#ifdef GROUND_GRADE
	if (grassTex && isEyeInWater == 0) {
		// pull toward the target-look grass: hue ~113, S ~0.66, V ~0.73, keep texture detail as luma
		float gl = luma(col), lf = gl / max(luma(vec3(0.31, 0.73, 0.25)), 1e-3);
#if GRASS_TONE == 1
		vec3 tone = vec3(0.33, 0.73, 0.27); // warmer, yellow-leaning meadow green
		vec2 tex = vec2(0.88, 1.06);        // smoother texel contrast
#else
		vec3 tone = vec3(0.27, 0.72, 0.38);
		vec2 tex = vec2(0.82, 1.10);
#endif
		// golden hour: low sun warms the lit grass and deepens its shade side
		float shadeK = mix(lb * 0.35 + 0.65, lb * 0.55 + 0.45, golden);
		vec3 target = tone * 1.02 * mix(tex.x, tex.y, clamp(lf, 0.0, 1.0)) * mix(0.45, 1.0, day) * shadeK;
		target *= mix(vec3(1.0), vec3(1.20, 0.96, 0.68), golden * lb);
		// subtle colour-wave sway: slow lighter bands rolling over the field
		float wave = sin(dot(cwpos.xz, vec2(0.21, 0.13)) + frameTimeCounter * GRASS_SWAY_SPEED);
		target *= 1.0 + GRASS_SWAY * smoothstep(0.6, 1.0, wave) * 0.5;
		// wind sheen: bent grass catches a little more light where a gust passes (subtle, no glow)
		target *= 1.0 + WIND_SHEEN * windGust(cwpos.xz, frameTimeCounter) * mix(0.4, 1.0, day);
		col = mix(col, target, GROUND_GRADE_STRENGTH * mix(1.0, 0.4, torch));
	}
#endif
	if (isFoliage == 1) col *= mix(vec3(1.0), vec3(1.14, 0.98, 0.78), golden * lb); // warm low sun on blades/leaves
	if (isFoliage == 1) col *= 1.0 + WIND_SHEEN * 0.6 * windG * day * lb; // grass blades / leaves in gusts
	if (isFoliage == 1) {
		// lime-leaning, brighter foliage (#9dc832 direction)
		float l = luma(col);
		col = mix(col, vec3(l) * (isEyeInWater == 1 ? vec3(0.55, 1.05, 1.0) : mix(vec3(0.50, 0.78, 1.15), vec3(0.82, 1.30, 0.72) * 0.96, day)), FOLIAGE_LIME * STYLE_K * mix(1.0, 1.0 - torch * 0.6, 1.0 - day));
	}
	// warm torch pool painted over the surface (reads orange even on dark green leaves)
	float pool = torch * (1.0 - day * lm.y);
	col = mix(col, vec3(luma(albedo.rgb) * 0.7 + 0.35) * vec3(1.0, 0.70, 0.42), clamp(pool * 0.30, 0.0, 0.35));
#ifdef EMISSIVE_BLOCKS
	if (isFoliage == 4) col = max(col, albedo.rgb * EMISSIVE_STRENGTH); // self-lit in its own colour (blooms)
#endif
	outColor = vec4(clamp(col, 0.0, 4.0), albedo.a);
	outFlag = vec4(0.0, clamp(pool, 0.0, 1.0), 0.0, 1.0);
	outLight = lightId > 0 ? vec4(lightColor(lightId), 1.0) : vec4(0.0); // premultiplied: only sources write colour
	outNormal = vec4(n * 0.5 + 0.5, isFoliage == 1 ? 0.5 : 1.0); // alpha 0.5 = foliage flag for outlines
}
