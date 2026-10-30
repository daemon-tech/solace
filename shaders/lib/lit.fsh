// Solace - shared cel-shaded fragment stage
#include "/lib/clouds.glsl"
uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform float cloudHeight;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float wetness;
uniform vec4 entityColor;
uniform int isEyeInWater;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform vec3 cameraPosition;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 vnormal;
in vec4 shadowClip;
flat in int isFoliage;
flat in int isLeaf;
flat in int lightId;
in float windG;
in vec3 cwpos;
in float vTop;
flat in int isGrassPlant;
uniform float frameTimeCounter;
uniform float sbHot;
uniform float sbCold;
/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
layout(location = 3) out vec4 outLight; // emitted light colour of light sources (for coloured block light)
layout(location = 4) out vec4 outShadow; // rgb = sun share of lighting, a = banded sun term (composite smoothing)
uniform int frameCounter;

const vec2 poisson12[12] = vec2[12](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));
vec3 glassTint = vec3(1.0);
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
	// fixed tap pattern: no per-pixel or per-frame rotation (no grain, nothing crawls)
	const mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
	// PCSS-style: blocker search -> penumbra grows with caster distance; wide rotated vogel-disk filter
	float baseR = (2.0 + float(SHADOW_SOFTNESS) * 1.4) * texel * mix(1.0, 1.6, dist);
	float searchR = baseR * 6.0;
	float bsum = 0.0, bn = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 o = rot * poisson12[i] * searchR;
		float sd = texture(shadowtex0, p.xy + o).r;
		if (sd < p.z - bias * 1.5) { bsum += sd; bn += 1.0; }
	}
	if (bn < 0.5) return 1.0; // fully lit, no blocker nearby
	float blocker = bsum / bn;
	float pen = clamp((p.z - blocker) * 220.0 * SHADOW_PENUMBRA, 0.0, 10.0); // caster-receiver distance in shadow depth units
	float rad = baseR * (1.0 + pen);
	rad *= 1.0 + SHADOW_DIST_SOFT * clamp(length(cwpos - cameraPosition) / 48.0, 0.0, 2.0); // softer with view distance
	float lit = 0.0;
	for (int i = 0; i < 32; i++) {
		float r = sqrt((float(i) + 0.5) / 32.0);
		float a = float(i) * 2.39996;
		vec2 o = rot * vec2(cos(a), sin(a)) * r * rad;
		// slightly larger bias for wide taps (no acne at the penumbra edge)
		// receiver-plane bias: wide taps on sloped receivers need more bias (no grain inside shadows)
		// smooth depth ramp per tap instead of a hard step: no stair-stepped penumbra
		float ref = p.z - bias - r * rad * (0.12 + 0.8 * (1.0 - clamp(ndl, 0.0, 1.0)));
		lit += clamp((texture(shadowtex0, p.xy + o).r - ref) / (bias * 1.5) + 0.5, 0.0, 1.0);
	}
	lit /= 32.0;
	lit = smoothstep(0.08, 0.92, lit); // creamy falloff, clean full shadow / full light
#ifdef SUN_SPOTS
	{
		// dappled light: under a leaf canopy, soft round sun spots fall through the gaps. Smooth blobs
		// anchored in the world and projected along the sun ray, so they lean with the light and stay calm.
		vec4 scL = texture(shadowcolor0, p.xy);
		float leafC = step(0.955, scL.a) * (1.0 - step(0.985, scL.a)) * (1.0 - step(p.z - bias, texture(shadowtex0, p.xy).r));
		if (leafC > 0.5 && lit < 0.98) {
			vec3 sW = safeNormalize(mat3(gbufferModelViewInverse) * shadowLightPosition, vec3(0, 1, 0));
			vec2 q = cwpos.xz - sW.xz / max(sW.y, 0.25) * cwpos.y;
			float sp = vnoise(q * 0.45) * 0.7 + vnoise(q * 1.1 + 7.1) * 0.3; // larger, calmer blobs
			sp = smoothstep(0.50, 0.70, sp); // more of them, soft edges
			lit = max(lit, sp * SUN_SPOTS);
		}
	}
#endif
#ifdef GLASS_TINT_LIGHT
	// light through stained glass: the nearest shadow caster is translucent -> take the glass colour.
	// (shadowtex1, the opaque-only depth, reads empty on this Iris build, so the caster's alpha in
	// shadowcolor0 decides: opaque casters write alpha 1, glass < 0.95, clear stays 1)
	float all0 = step(p.z - bias, texture(shadowtex0, p.xy).r);
	vec4 sc = texture(shadowcolor0, p.xy);
#ifdef GLASS_DEBUG
	glassTint = all0 < 0.5 ? (sc.a < 0.95 ? vec3(3.0, 0.0, 3.0) : vec3(3.0, 0.0, 0.0)) : vec3(0.0, 3.0, 0.0);
	return 1.0;
#endif
	if (all0 < 0.5 && sc.a > 0.05 && sc.a < 0.95) {
		glassTint = mix(vec3(1.0), clamp(sc.rgb * 1.5, 0.0, 1.2), clamp(sc.a, 0.0, 1.0) * 0.85);
#ifdef GLASS_DEBUG
		glassTint = vec3(3.0, 0.0, 3.0);
#endif
		return 1.0;
	}
#endif
	return lit;
#else
	return 1.0;
#endif
}

void main() {
	vec4 albedo = texture(gtexture, texcoord) * vcolor;
#ifdef FLAT_NORMAL
	if (albedo.a < 0.3) discard; // particles: drop soft/empty texels (no square halos)
	if (isEyeInWater == 1 && length(cwpos - cameraPosition) < 3.0) discard; // no big bubble rings in front of the camera underwater
#else
#ifdef TERRAIN_PASS
	// far leaves: the gaps close smoothly into one calm canopy mass (no jagged, crawling cut-out edges far away)
	if (isLeaf == 1 && albedo.a < 0.1) {
		float fillK = smoothstep(18.0, 56.0, length(cwpos - cameraPosition));
		vec4 avg = textureLod(gtexture, texcoord, 2.0);
		if (fillK > 0.0 && avg.a > 1.0 - fillK * 0.95 && luma(avg.rgb / max(avg.a, 1e-3)) < 0.7) albedo = vec4(avg.rgb / max(avg.a, 1e-3), 1.0) * vcolor;
	}
#endif
	if (albedo.a < 0.1) discard;
#endif
#ifdef HIDE_LEAF_LITTER
	if (isFoliage == 3) discard;
#endif
	// low-pass texture detail: smooth even grass tops and leaf masses (mip bias, alpha-corrected)
	{
		bool tinted = vcolor.g > vcolor.b * 1.15 && vcolor.g > vcolor.r * 1.05;
		float sm = ((isFoliage == 2 || isGrassPlant == 1) && tinted) ? GRASS_SMOOTH : (isFoliage == 1 ? FOLIAGE_SMOOTH : 0.0);
#ifdef SOFT_GRASS
		if ((isFoliage == 2 || isGrassPlant == 1) && tinted) sm = min(sm + 0.25 * SOFT_GRASS_STRENGTH, 0.9); // calmer grass surface, texels fade out
#endif
#ifdef TERRAIN_PASS
		// texture calm: stone, dirt, sand, wood keep their blocky pattern but lose harsh texel contrast
		// (pulled toward the block's own average tone). Light sources keep full detail.
		if (isFoliage == 0 && lightId == 0) sm = max(sm, TEXTURE_CALM);
#if FAR_SOFTEN > 0
		// painterly distance: far blocks flatten toward their own average tone (calm, no shimmering texels)
		if (lightId == 0) sm = max(sm, smoothstep(24.0, 110.0, length(cwpos - cameraPosition)) * float(FAR_SOFTEN) * 0.1);
#endif
#endif
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
#ifdef CLOUD_SHADOWS
	{
		// soft cloud shadows drifting with the wind field (same direction and pace as the gust fronts)
#if defined CLOUD_LAYERS && defined CLOUD_LOW && !defined DIM_NETHER && !defined DIM_END
		// shadows of the low cloud layer: project along the sun onto the layer, wide soft edges
		vec3 sW = safeNormalize(mat3(gbufferModelViewInverse) * sunPosition, vec3(0, 1, 0));
		if (sW.y > 0.05) {
			float Hl = (cloudHeight > 1.0 ? cloudHeight : 192.0) + CL_LOW_OFF + CL_LOW_THICK * 0.5;
			vec2 pc = cwpos.xz + sW.xz * (Hl - cwpos.y) / sW.y;
			float cs = clCover(clLowQ(pc, frameTimeCounter * 0.6), 0.45, 0);
			light *= 1.0 - smoothstep(0.05, 0.95, cs) * CLOUD_SHADOW_STRENGTH * 1.35;
		}
#else
		vec2 cq = cwpos.xz * 0.011 - windDir() * frameTimeCounter * WIND_SPEED * 0.07;
		float cn = vnoise(cq) * 0.65 + vnoise(cq * 2.3 + 7.1) * 0.35;
		light *= 1.0 - smoothstep(0.56, 0.68, cn) * CLOUD_SHADOW_STRENGTH;
#endif
	}
#endif
	float lb = celBandSoft(light, CEL_BANDS, SHADOW_EDGE); // cel bands with soft shadow edges
	lb = mix(lb, smoothstep(0.0, 1.0, light), SMOOTH_SHADING); // smooth: one soft gradient, contrast from colour
#if defined ENTITY_PASS && ENTITY_SOFT > 0
	// mobs and players: soft two-tone cartoon shading (wrapped light, one wide soft step, brighter shade side)
	{
		float wrapL = clamp((ndl + 0.35) / 1.1, 0.0, 1.0) * clamp(light * 4.0, 0.0, 1.0);
		float soft2 = smoothstep(0.25, 0.65, max(light, wrapL * 0.85));
		lb = mix(lb, soft2, float(ENTITY_SOFT) * 0.1);
	}
#endif
	// foliage: flat fields with a single shadow tone (2 bands)
	if (isFoliage == 1) lb = mix(step(0.35, light), smoothstep(0.15, 0.65, light), SMOOTH_SHADING) * 0.9 + 0.1 * lb;

	// Light is white-balanced: ambient + sun ~= neutral white on a fully lit surface.
	// Shadowed areas keep only the cool ambient term (blue, never pink/purple on warm albedo).
	vec3 ambDay = vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B);
	vec3 sunDay = max(vec3(1.04, 1.02, 1.0) - ambDay, 0.0); // complement -> neutral sum
	vec3 ambNight = vec3(0.30, 0.36, 0.72);                 // indigo, never black
	vec3 sunNight = vec3(0.16, 0.22, 0.42);                 // moonlight
	// at dusk the sun is low: lift ambient so foliage doesn't go black
	float duskLift = 1.0 + 1.2 * clamp(1.0 - abs(dot(safeNormalize(sunPosition, up), up)) * 5.0, 0.0, 1.0);
	vec3 ambient = duskLift * mix(ambNight, ambDay, day) * mix(0.55, 1.0, celBand(lm.y, 3)) * AMBIENT_BOOST;
	// twilight in pits, dug holes and caves: the lifted dawn/dusk ambient is still mostly the indigo night tone,
	// which turns grey stone lavender where little sky reaches. Less sky light -> more neutral ambient hue.
	{
		float twA = clamp(1.0 - abs(dot(safeNormalize(sunPosition, up), up)) * 5.0, 0.0, 1.0) * (1.0 - smoothstep(0.55, 0.95, lm.y));
		vec3 ambN = vec3(dot(ambient, vec3(0.3333))) * vec3(0.96, 0.98, 1.06);
		ambient = mix(ambient, ambN, twA * 0.8);
	}
	vec3 sunCol = mix(sunNight, sunDay, day);
	{
		// smooth shading at range: far away the shade side keeps a deeper blue-teal so hills still read as lit and shaded
		float farS = smoothstep(32.0, 140.0, length(cwpos - cameraPosition)) * SMOOTH_SHADING * FAR_SHADE;
		ambient *= mix(vec3(1.0), vec3(0.70, 0.84, 1.02), farS * (1.0 - lb) * day);
		sunCol *= 1.0 + 0.12 * farS * day;
	}
#if WARM_COOL > 0
	{
		// warm-cool contrast: sunlit faces lean a touch warm, shade leans soft sky-blue; stronger with a lower sun
		float sHw = dot(safeNormalize(sunPosition, up), up);
		float wcK = float(WARM_COOL) * 0.25 * day * (1.0 - rainStrength) * mix(1.4, 0.8, smoothstep(0.15, 0.8, sHw));
		sunCol *= mix(vec3(1.0), vec3(1.07, 1.0, 0.88), wcK);
		ambient *= mix(vec3(1.0), vec3(0.93, 1.0, 1.12), wcK);
	}
#endif
#if defined ENTITY_PASS && ENTITY_SOFT > 0
	ambient *= 1.0 + 0.012 * float(ENTITY_SOFT); // lifted shade side: soft, never muddy
#endif
#ifdef DIM_NETHER
	// Nether: warm ember ambient, no sun; block light does the rest
	ambient = vec3(0.70, 0.46, 0.38) * mix(0.8, 1.0, celBand(lm.x, 3)) * AMBIENT_BOOST; sunCol = vec3(0.0); day = 0.0;
#endif
#ifdef DIM_END
	// End: cool violet ambient with a faint top light
	ambient = vec3(0.50, 0.44, 0.68) * AMBIENT_BOOST; sunCol = vec3(0.30, 0.26, 0.40); day = 0.0;
#endif
	float golden = GOLDEN_HOUR_TINT * day * clamp(1.0 - dot(safeNormalize(sunPosition, up), up) * 3.5, 0.0, 1.0);
	// torch light: warm orange pool with a sharp-ish falloff
	// two hard-ish rings: wide pool + bright core
	float torch = celBandSoft(smoothstep(0.0, 1.0, pow(lm.x, 1.8)), 4, 0.45) * TORCH_STRENGTH; // smooth falloff: no ring at a fixed distance around held/dynamic lights
	vec3 block = vec3(1.0, 0.76, 0.50) * torch * mix(0.95, 0.15, day * lm.y); // neutral warm
#if !defined DIM_NETHER && !defined DIM_END
	{
		// caves: where no sky reaches the ambient sinks lower, so torches, lanterns and lava
		// become warm, soft islands of light in the dark (smooth falloff, never pitch black)
		float caveK = 1.0 - smoothstep(0.02, 0.4, lm.y);
		ambient *= mix(1.0, 0.42, caveK);
		block *= mix(1.0, 1.18, caveK) * mix(vec3(1.0), vec3(1.04, 0.97, 0.88), caveK);
	}
	{
		// open night: torch and lantern pools in villages read as warm amber islands against the cool moonlight
		float nightOut = (1.0 - day) * smoothstep(0.5, 0.9, lm.y);
		block *= mix(vec3(1.0), vec3(1.16, 0.96, 0.74), nightOut);
	}
#endif
	// shade twice: fully shadowed (lb=0) and fully lit (lb=1); the real band value blends them, so composite can
	// re-blend with a smoothed shadow term (soft shadows part 2) without re-running the lighting
#if BOUNCE_LIGHT > 0
	{
		// bounce light: sunlit ground throws a soft warm-green glow back up onto undersides and
		// shaded sides (tree canopies from below, overhangs, mobs). Smooth, no sampling, calm.
		float downF = clamp(-dot(n, up), 0.0, 1.0), sideF = 1.0 - abs(dot(n, up));
		vec3 bounceC = mix(vec3(0.62, 0.78, 0.36), vec3(1.0, 0.72, 0.42), golden) * sunCol;
		ambient += bounceC * (downF * 0.55 + sideF * 0.14) * day * smoothstep(0.55, 0.95, lm.y) * (1.0 - rainStrength * 0.8) * float(BOUNCE_LIGHT) * 0.1;
	}
#endif
	float lbReal = lb; float pool = 0.0;
	vec3 cOut[2];
	for (int it = 0; it < 2; it++) {
		lb = float(it);
		vec3 lighting = ambient + sunCol * glassTint * lb + block + vec3(0.03);
	#if defined TERRAIN_PASS && !defined FLAT_NORMAL
		// high sun: block sides get a soft sky key (east/west a touch brighter than north/south),
		// so walls read as two calm tones instead of one flat shade
		if (isFoliage == 0) {
			float sH = dot(safeNormalize(sunPosition, up), up);
			float noonK = smoothstep(0.45, 0.85, sH) * (1.0 - rainStrength) * smoothstep(0.5, 0.9, lm.y);
			float sideK = smoothstep(0.6, 0.95, 1.0 - abs(dot(n, up)));
			vec3 nw = mat3(gbufferModelViewInverse) * n;
			lighting += sunDay * (0.07 + 0.12 * abs(nw.x)) * noonK * sideK * (1.0 - lb); // only lifts the unlit side: tops stay the brightest face
			lighting *= 1.0 - 0.08 * noonK * sideK * lb; // lit walls sit one soft step below the sunlit tops
		}
	#endif
		// underwater: kelp/seagrass/floor stay readable (light, not black)
		if (isEyeInWater == 1) lighting = max(lighting, vec3(0.62, 0.78, 0.95) * mix(0.6, 1.0, day));

	#ifdef FLAT_NORMAL
		// particles: neutral brightness only, so they never pick up the cool/indigo tint
		// at night smoke and dust over a fire glow a soft ember tone from below instead of bright white
		lighting = max(vec3(mix(0.26, 1.0, lm.y * mix(0.32, 1.0, day))), vec3(lm.x) * mix(vec3(1.0, 0.70, 0.46) * 0.62, vec3(1.0), day));
	#endif
	#ifdef GROUND_GRADE
		// grass ground: tinted texels (grass top / side overlay) get flat, soft lighting
		bool grassTex = (isFoliage == 2 || isGrassPlant == 1) && vcolor.g > vcolor.b * 1.15 && vcolor.g > vcolor.r * 1.05;
		if (grassTex) {
			lb = mix(lb, 1.0, 0.55 * smoothstep(0.1, 0.4, light)); // fewer, softer steps in sun
			lighting = ambient + sunCol * glassTint * lb + block + vec3(0.03);
		}
	#endif
		vec3 col = albedo.rgb * lighting;
		#ifdef GROUND_GRADE
		if (grassTex && isEyeInWater == 0) {
			// pull toward the target-look grass: hue ~113, S ~0.66, V ~0.73, keep texture detail as luma
			float gl = luma(col), lf = gl / max(luma(vec3(0.31, 0.73, 0.25)), 1e-3);
	#if GRASS_TONE == 1
			vec3 tone = vec3(0.33, 0.73, 0.27); // warmer, yellow-leaning meadow green
			vec2 tex = vec2(0.91, 1.04);        // smoother texel contrast (calm, still readable)
	#else
			vec3 tone = vec3(0.27, 0.72, 0.38);
			vec2 tex = vec2(0.82, 1.10);
	#endif
			// savanna and other hot dry lands: the grass keeps a warm golden-olive tone (sun-dried, still soft)
			tone = mix(tone, vec3(0.64, 0.66, 0.27), sbHot * SAVANNA_GOLD);
			// golden hour: low sun warms the lit grass and deepens its shade side
			float shadeK = mix(lb * 0.35 + 0.65, lb * 0.55 + 0.45, golden);
			vec3 target = tone * 1.02 * mix(tex.x, tex.y, clamp(lf, 0.0, 1.0)) * mix(0.45, 1.0, day) * shadeK;
			target *= mix(vec3(1.0), vec3(1.20, 0.96, 0.68), golden * lb);
			target *= mix(vec3(0.90, 0.98, 1.08), vec3(1.06, 1.04, 0.86), lb * FOLIAGE_CONTRAST); // yellow-green sunlit, cool shade
			// subtle colour-wave sway: slow lighter bands rolling over the field
			float wave = sin(dot(cwpos.xz, vec2(0.21, 0.13)) + frameTimeCounter * GRASS_SWAY_SPEED);
#ifdef SOFT_GRASS
			target *= 1.0 + GRASS_SWAY * smoothstep(0.2, 1.0, wave) * 0.35; // wider window: no moving stripes
			{
				// very gentle large-scale tone drift (period ~40 blocks), so lawns are not one flat colour
				float drift = vnoise(cwpos.xz * 0.025) * 0.7 + vnoise(cwpos.xz * 0.06 + 3.7) * 0.3;
				target *= 1.0 + (drift - 0.5) * 0.05 * SOFT_GRASS_STRENGTH;
				// sides: soft contact shade toward the bottom of the face
				float side = 1.0 - abs(dot(n, up));
				target *= 1.0 - 0.07 * SOFT_GRASS_STRENGTH * smoothstep(0.5, 0.9, side) * (1.0 - smoothstep(0.0, 1.0, fract(cwpos.y)));
			}
#else
			target *= 1.0 + GRASS_SWAY * smoothstep(0.6, 1.0, wave) * 0.5;
#endif
			// wind sheen: bent grass catches a little more light where a gust passes (subtle, no glow)
			target *= 1.0 + WIND_SHEEN * windGust(cwpos.xz, frameTimeCounter) * mix(0.4, 1.0, day);
			col = mix(col, target, GROUND_GRADE_STRENGTH * mix(1.0, 0.4, torch * (1.0 - day * lm.y)));
		}
	#if defined TERRAIN_PASS && !defined FLAT_NORMAL
		// snowy grass sides keep their white snow cap (no green fringe painted over the snow)
		else if (isFoliage == 2 && isEyeInWater == 0 && abs(dot(n, up)) < 0.3 && !(luma(albedo.rgb) > 0.62 && max(albedo.r, max(albedo.g, albedo.b)) - min(albedo.r, min(albedo.g, albedo.b)) < 0.14)) {
			// soft grass fringe: the top of a grass block's side fades from grass green into the dirt,
			// in calm blocky steps (quarter-texel bands) instead of a ragged pixel edge
			float fy = floor(fract(cwpos.y + 0.001) * 16.0) / 16.0;
			float fr = smoothstep(0.42, 0.78, fy);
	#if GRASS_TONE == 1
			vec3 toneF = vec3(0.33, 0.73, 0.27);
	#else
			vec3 toneF = vec3(0.27, 0.72, 0.38);
	#endif
			toneF = mix(toneF, vec3(0.64, 0.66, 0.27), sbHot * SAVANNA_GOLD); // same golden side fringe as the savanna tops
			vec3 fc = toneF * 0.96 * mix(0.45, 1.0, day) * (lb * 0.35 + 0.65) * (0.9 + 0.1 * lb);
			col = mix(col, fc * mix(0.82, 1.0, fr), min(fr * 1.15 * GROUND_GRADE_STRENGTH, 0.92));
		}
	#endif
		// meadow patches: lawns get calm large tonal drifts (sunny yellow-green / deeper cool green); applied before the
		// ground colour is taken, so blades, block tops and side fringes all share the same patch (seamless)
		if (grassTex && isEyeInWater == 0) {
			float mp = vnoise(floor(cwpos.xz) * 0.045) * 0.65 + vnoise(floor(cwpos.xz) * 0.11 + 7.3) * 0.35;
			mp = celBandSoft(smoothstep(0.32, 0.68, mp), 3, 0.5);
			col *= mix(vec3(0.78, 0.86, 0.92), vec3(1.08, 1.07, 0.88), mp);
		}
		vec3 colGround = col;
	#endif
#ifdef WET_GROUND
		{
			// rain: darker, glossier ground with soft puddle sheen on open flat surfaces
			float upF = smoothstep(0.85, 0.98, dot(safeNormalize(n, up), up));
			float open = smoothstep(0.85, 0.97, lm.y);
			float wetK = max(wetness, rainStrength * 0.85) * open * WET_GROUND_STRENGTH; // react as soon as it rains
			if (wetK > 0.001 && isFoliage != 1) {
				// soaked ground: a little darker and richer in colour (after the grass grade, so lawns get wet too)
				col *= 1.0 - (isFoliage == 2 ? 0.30 : 0.40) * wetK; // bare paths, sand and stone soak darker than lawns
				col = max(mix(vec3(luma(col)), col, 1.0 + 0.30 * wetK), vec3(0.0));
				// soft sheen toward grazing angles on open flat ground (calm sky-coloured lift, no specks)
				vec4 wv4 = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
				vec3 wvd = safeNormalize(wv4.xyz / wv4.w, vec3(0, 0, -1));
				float wfr = pow(1.0 - clamp(dot(safeNormalize(n, up), -wvd), 0.0, 1.0), 2.2);
				vec3 wsky = mix(vec3(0.20, 0.24, 0.34), vec3(0.62, 0.68, 0.76), day);
				col = mix(col, wsky, clamp(0.24 + wfr, 0.0, 1.0) * upF * wetK * (isFoliage == 2 ? 0.48 : 0.62));
				// small calm puddles in flat dips: smooth large patches that mirror the grey sky
				float pd = smoothstep(0.60, 0.70, vnoise(cwpos.xz * 0.30) * 0.75 + vnoise(cwpos.xz * 0.9 + 5.1) * 0.25) * upF;
				col = mix(col, mix(vec3(luma(col)) * 0.55, wsky, 0.55 + 0.4 * wfr), pd * wetK * (isFoliage == 2 ? 0.12 : 0.45)); // lawns only glisten, paths and stone hold puddles
			}
		}
	#endif
		if (isFoliage == 1) col *= mix(vec3(1.0), vec3(1.14, 0.98, 0.78), golden * lb); // warm low sun on blades/leaves
		float fcK = FOLIAGE_CONTRAST, shK = 1.0;
#ifdef SOFT_GRASS
		if (isGrassPlant == 1) { fcK *= 1.0 - 0.4 * min(SOFT_GRASS_STRENGTH, 1.5); shK = 0.5; } // blades never pop out
#endif
		if (isFoliage == 1) col *= mix(mix(vec3(1.0), vec3(0.78, 0.86, 0.98), fcK), mix(vec3(1.0), vec3(1.10, 1.08, 0.90), fcK), lb); // bright sunlit leaves, dark cool inner shade
		if (isFoliage == 1) col *= 1.0 + WIND_SHEEN * 0.6 * windG * day * lb * shK; // grass blades / leaves in gusts
		// leaf flip: a passing gust turns leaves to show their paler, silvery undersides (calm, travels with the front)
		// canopy tops: a calm, broad painted sheen where the sun falls on upward faces (no sparkle, no motion)
		if (isLeaf == 1) col = mix(col, col * vec3(1.14, 1.16, 0.90) + vec3(0.035, 0.045, 0.0), LEAF_SHEEN * 0.65 * smoothstep(0.55, 0.95, dot(n, up)) * lb * day * (1.0 - 0.5 * golden));
		if (isLeaf == 1) col = mix(col, vec3(luma(col)) * vec3(0.96, 1.04, 1.00) * 1.14, WIND_SHEEN * 1.6 * smoothstep(0.15, 0.85, windG) * mix(0.45, 1.0, day));
#ifdef SOFT_GRASS
		// grass plants: soft contact shade at the base fading out by mid-height (tips unchanged, no glow)
		if (isGrassPlant == 1) col *= 1.0 - 0.12 * SOFT_GRASS_STRENGTH * (1.0 - smoothstep(0.0, 0.6, vTop));
#if GRASS_GRADIENT > 0
		// blade gradient: deep cool green at the root rising to a bright, warm sunlit tip
		if (isGrassPlant == 1) {
			float gg = float(GRASS_GRADIENT) * 0.1;
			col *= mix(mix(vec3(1.0), vec3(0.74, 0.82, 0.86), gg), vec3(1.0), smoothstep(0.0, 0.7, vTop));
			col = mix(col, vec3(0.88, 0.97, 0.58) * (luma(col) + 0.25), smoothstep(0.55, 1.0, vTop) * gg * 0.45 * mix(0.3, 1.0, day));
		}
#endif
#endif
		if (isFoliage == 1) {
			// lime-leaning, brighter foliage (#9dc832 direction)
			float l = luma(col);
			float pinkLeaf = smoothstep(0.02, 0.12, albedo.r - albedo.g); // cherry leaves keep their pink
			col = mix(col, vec3(l) * (isEyeInWater == 1 ? vec3(0.55, 1.05, 1.0) : mix(vec3(0.60, 0.80, 0.70) * 0.92, vec3(0.82, 1.30, 0.72) * 0.96, day)), FOLIAGE_LIME * STYLE_K * mix(1.0, 1.0 - torch * 0.6, 1.0 - day) * (1.0 - pinkLeaf) * (1.0 - 0.55 * rainStrength));
			// cherry leaves: the cool shade ambient pushed them to lavender; keep a warm cherry-blossom pink
			col = mix(col, col * vec3(1.10, 0.96, 0.84), pinkLeaf * 0.85 * (isEyeInWater == 1 ? 0.0 : 1.0));
			// overcast rain: leaf masses sit a step deeper instead of glowing pale lime
			if (isFoliage == 1 && isGrassPlant == 0) col *= 1.0 - 0.18 * rainStrength;
		}
	#ifdef GROUND_GRADE
		// grass plants: the root is exactly the grass top colour, only a soft gradient toward the tip
		if (isGrassPlant == 1 && grassTex && isEyeInWater == 0) col = mix(colGround, col, 0.35 * smoothstep(0.25, 1.0, vTop));
	#endif
	#ifdef LEAF_TRANSLUCENCY
		if (isFoliage == 1 || isFoliage == 5) {
			// backlit leaves and blades glow warm-green when looking toward the sun
			vec3 vW = safeNormalize(cwpos - cameraPosition, vec3(0, 0, 1));
			vec3 sW = safeNormalize(mat3(gbufferModelViewInverse) * sunPosition, vec3(0, 1, 0));
			float bl = pow(max(dot(vW, sW), 0.0), 3.0) * day * smoothstep(0.5, 0.9, lm.y);
			float gk = (isGrassPlant == 1 || isFoliage == 5) ? 0.45 : 1.0; // grass tufts: a gentle glow, not neon specks on the darker ground
			col += albedo.rgb * vec3(1.18, 0.92, 0.40) * celBand(bl, 3) * LEAF_TRANSLUCENCY * 1.5 * gk;
			// low sun: a soft warm rim of light through grass and leaves seen against the sun
			float lowSun = smoothstep(-0.03, 0.05, sW.y) * (1.0 - smoothstep(0.18, 0.42, sW.y)) * (1.0 - rainStrength);
			float blLow = smoothstep(0.55, 1.0, dot(vW, sW)) * lowSun * smoothstep(0.6, 0.95, lm.y);
			col += albedo.rgb * vec3(1.25, 0.88, 0.42) * blLow * blLow * (isFoliage == 5 ? 0.6 : 0.30) * LEAF_TRANSLUCENCY / 0.35 * gk
			     * (1.0 - 0.7 * smoothstep(0.45, 0.85, luma(col))); // already bright (pale) leaves never wash out
		}
	#endif
	#ifdef NIGHT_GLOW
		// flowers: a faint glow at night so meadows still read in the dark
		if (isFoliage == 5) col += albedo.rgb * smoothstep(0.25, 0.6, max(albedo.r, albedo.b) - albedo.g * 0.5) * 0.14 * (1.0 - day) * NIGHT_GLOW;
		// canopy depth: leaves that see less open sky (inside and under the crown) settle into a cooler deep green
		// cherry blossoms: pink petals glow a soft pastel in the sun and stay light in the crown's shade
		if (isLeaf == 1) {
			float pinkK = smoothstep(0.04, 0.16, albedo.r - albedo.g) * smoothstep(-0.02, 0.08, albedo.b - albedo.g * 0.85);
			// calm the busy petal texels into one soft pastel pink; keep the light and shade of the crown
			vec3 blossomC = vec3(1.0, 0.76, 0.87) * (0.50 + 0.62 * luma(col)) + vec3(0.07, 0.03, 0.05) * lb * day;
			col = mix(col, blossomC, pinkK * CHERRY_GLOW * 1.2 * mix(0.4, 1.0, day));
		}
		// snowy lands: tree crowns wear a soft pale frost on their upward faces (calm, no sparkle)
		if (isLeaf == 1) col = mix(col, vec3(0.86, 0.92, 0.98) * (0.62 + 0.38 * lb) * mix(0.45, 1.0, day), FROST_TIPS * 0.5 * sbCold * smoothstep(0.55, 0.92, dot(n, up)));
		if (isLeaf == 1) col *= mix(vec3(1.0), vec3(0.74, 0.88, 1.0), CANOPY_DEPTH * (1.0 - smoothstep(0.62, 0.95, lm.y)) * mix(0.5, 1.0, day));
	#endif
		// warm torch pool painted over the surface (reads orange even on dark green leaves)
		pool = torch * (1.0 - day * lm.y);
		col = mix(col, vec3(luma(albedo.rgb) * 0.7 + 0.35) * vec3(1.0, 0.70, 0.42), clamp(pool * 0.30, 0.0, 0.35));
		// caves and roofed rooms (little sky light): torch light reads as a calm amber island, saturated even on grey stone,
		// strongest near the flame and fading softly with the light level
		{
			float islK = smoothstep(0.12, 0.95, lm.x) * (1.0 - smoothstep(0.25, 0.65, lm.y)) * TORCH_STRENGTH;
			islK *= (1.0 - 0.55 * smoothstep(0.30, 0.65, luma(col))) * (1.0 - 0.6 * smoothstep(0.08, 0.30, col.r - col.b)); // already bright or warm (wood): little extra, never garish
			col = mix(col, col * vec3(1.30, 0.94, 0.60) + vec3(0.03, 0.012, 0.0), clamp(islK * 0.65, 0.0, 0.65));
			col *= 1.0 + 0.30 * islK * islK; // a soft glow close to the flame
		}
	#ifdef EMISSIVE_BLOCKS
		// self-lit only where the texture itself glows (flame tip, lantern glass, lava); the torch stick,
		// lantern frame and dark parts keep normal lighting instead of glowing as a whole block
		if (isFoliage == 4) col = mix(col, max(col, albedo.rgb * EMISSIVE_STRENGTH), emitMask(albedo.rgb) * (isLeaf == 4 ? step(0.53, fract(cwpos.y - 0.001)) : 1.0)); // candle cakes: the cake itself is not self-lit
		if (isFoliage == 4 && lightId == 1 && albedo.r > 0.7 && albedo.b < 0.3) {
			// lava / fire: hotter orange, slow shimmer
			float sh = vnoise(cwpos.xz * 0.8 + vec2(frameTimeCounter * 0.4, -frameTimeCounter * 0.3));
			col *= vec3(1.25, 1.0, 0.7) * (0.9 + 0.25 * celBand(sh, 3));
		}
		if (lightId == 8) {
			// sculk: the bright specks glow a soft blue, the dark body keeps a faint cool sheen
			float sp = smoothstep(0.30, 0.65, max(albedo.g, albedo.b));
			col = mix(col, max(col, vec3(0.32, 0.70, 1.0) * (0.45 + 0.35 * luma(albedo.rgb)) * EMISSIVE_STRENGTH), sp * 0.5);
			col += vec3(0.03, 0.07, 0.12) * (1.0 - sp * 0.5);
		}
	#ifdef STYLISED_LAVA
		if (lightId == 7) {
			// stylised lava: a deep saturated orange body with calm, slowly drifting bright veins.
			// Large world-space blobs replace the busy texture; soft two-band edges, never pale or white.
			vec2 lq = cwpos.xz * 0.35;
			float t = frameTimeCounter * 0.06;
			float fl = vnoise(lq + vec2(t, t * 0.7)) * 0.65 + vnoise(lq * 2.1 - vec2(t * 0.8, -t)) * 0.35;
			fl = mix(fl, luma(albedo.rgb), 0.15);
			float v = celBandSoft(smoothstep(0.42, 0.78, fl), 2, 0.5);
			vec3 lavaC = mix(vec3(0.86, 0.24, 0.04), vec3(1.0, 0.62, 0.16), v);
			// cooling crust: a few large dark-ember rafts drift slowly on the surface, edged with a hot rim
			float cr = vnoise(cwpos.xz * 0.11 + vec2(-t * 0.5, t * 0.35));
			float crust = celBandSoft(smoothstep(0.30, 0.20, cr), 2, 0.5);
			float rim = smoothstep(0.36, 0.30, cr) * (1.0 - crust);
			lavaC = mix(lavaC, vec3(0.40, 0.08, 0.03), crust * 0.75);
			lavaC = mix(lavaC, vec3(1.0, 0.72, 0.26), rim * 0.6);
			// slightly dimmer at night so the glow around it stays orange instead of washing out pale
			col = lavaC * LAVA_BRIGHT * mix(0.72, 1.0, day);
		}
	#endif
	#endif
		cOut[it] = col;
	}
	lb = lbReal;
	vec3 col = mix(cOut[0], cOut[1], lb);
#ifdef GOLDEN_RIM
#ifdef ENTITY_PASS
	// golden-hour rim: at sunrise and sunset, characters seen against the low sun get a soft warm
	// fringe along their silhouette (wide smooth falloff, two soft bands, never a hard white line)
	{
		vec4 vP4 = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
		vec3 vP = vP4.xyz / vP4.w;
		vec3 vV = safeNormalize(vP, vec3(0, 0, -1));
		// entity vertex normals are not reliable here: use the flat face normal from screen derivatives
		vec3 nF = safeNormalize(cross(dFdx(vP), dFdy(vP)), n);
		if (dot(nF, vV) > 0.0) nF = -nF;
		vec3 sV = safeNormalize(sunPosition, up);
		float sh = dot(sV, up);
		float gold = smoothstep(-0.04, 0.04, sh) * (1.0 - smoothstep(0.12, 0.38, sh)) * (1.0 - rainStrength);
		float backG = smoothstep(-0.3, 0.7, dot(vV, sV));
		float fres = 1.0 - clamp(dot(nF, -vV), 0.0, 1.0);
		float rimG = celBandSoft(smoothstep(0.45, 0.95, fres), 2, 0.6) * mix(0.35, 1.0, backG) * gold * lm.y;
		col += vec3(1.0, 0.66, 0.30) * clamp(rimG * GOLDEN_RIM_STRENGTH, 0.0, 1.5) * 0.34;
	#ifdef MOON_RIM
		// night: characters get a faint silver fringe from the moon (same soft two-band falloff, cool and dim)
		vec3 mV = -sV;
		float mUp = smoothstep(0.05, 0.3, dot(mV, up)) * (1.0 - rainStrength);
		float rimM = celBandSoft(smoothstep(0.5, 0.95, fres), 2, 0.6) * mix(0.4, 1.0, smoothstep(-0.3, 0.7, dot(vV, mV))) * mUp * lm.y;
		col += vec3(0.62, 0.74, 1.0) * clamp(rimM * MOON_RIM, 0.0, 1.0) * 0.16;
	#endif
	}
#endif
#endif
#if defined ENTITY_PASS && CHAR_RIM > 0
	// character rim: all day, a soft light fringe along the silhouette so mobs and players stand
	// out from the scene like painted figures (wide smooth falloff, never a hard white line)
	{
		vec4 vQ4 = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
		vec3 vQ = vQ4.xyz / vQ4.w;
		vec3 vW = safeNormalize(vQ, vec3(0, 0, -1));
		vec3 nR = safeNormalize(cross(dFdx(vQ), dFdy(vQ)), n);
		if (dot(nR, vW) > 0.0) nR = -nR;
		float fr = 1.0 - clamp(dot(nR, -vW), 0.0, 1.0);
		float rimK = smoothstep(0.15, 0.85, fr) * mix(0.35, 1.0, lm.y);
		vec3 rimC = mix(vec3(0.42, 0.50, 0.85), vec3(0.92, 0.96, 1.0), day);
		col = mix(col, max(col, rimC * (luma(col) * 0.7 + 0.55)), rimK * float(CHAR_RIM) * 0.085);
	}
#endif
	if (lightId == 4) {
		// amethyst: a few crystal texels twinkle now and then (sharp short flash, calm in between)
		vec3 tq = floor(cwpos * 8.0 + 0.001);
		float h = hash12(tq.xz * 0.731 + tq.y * 3.17);
		float tw = pow(max(sin(frameTimeCounter * (1.5 + 2.5 * h) + h * 60.0), 0.0), 6.0);
		col += vec3(1.0, 0.92, 1.0) * step(0.78, h) * tw * smoothstep(0.25, 0.5, luma(albedo.rgb)) * 3.0 * AMETHYST_TWINKLE;
	}
	outColor = vec4(clamp(col, 0.0, 4.0), albedo.a);
	outFlag = vec4(0.0, clamp(pool, 0.0, 1.0), 0.0, 1.0);
#ifdef FLAT_NORMAL
	outFlag.a = 0.6; // particle flag: composite keeps white mist/smoke neutral (no sand/warm grading)
#endif
	// premultiplied: only the glowing texels of a source write colour (no light from the torch stick)
	float em = lightId > 0 ? emitMask(albedo.rgb) : 0.0;
	// sea lantern, end rod, froglight: pale, low-chroma glow faces; the chroma test missed them and the animated texture made the pool flicker warm/cool
	if (isLeaf == 2) em = smoothstep(0.45, 0.70, albedo.r) * (1.0 - smoothstep(0.55, 0.75, albedo.g)) * (1.0 - smoothstep(0.30, 0.45, albedo.b)) * 0.55; // glow-berry vines (soft spill below): only the orange berries glow, leaves stay green
	if (lightId == 5) em = max(em, smoothstep(0.50, 0.72, max(albedo.r, max(albedo.g, albedo.b))));
	outLight = em > 0.01 ? vec4(lightColor(lightId) * em, em) : vec4(0.0);
	// candles: the flames are particles (not drawn here), so the upper wax glows faintly and feeds a soft warm halo
	if (isLeaf == 3 || isLeaf == 4) { float cE = smoothstep(0.25, 0.5, luma(albedo.rgb)) * CANDLE_GLOW * (isLeaf == 4 ? step(0.53, fract(cwpos.y - 0.001)) : 1.0); /* on a cake only the candle, not the cake top */ outLight = vec4(vec3(1.0, 0.62, 0.30) * cE, cE * 0.45); }
	outShadow = vec4(-1.0);
#ifndef FLAT_NORMAL
	if (isEyeInWater == 0 && ndl > 0.0) outShadow = vec4(cOut[1] - cOut[0], lb);
#endif
	// alpha 0.5 = foliage, 0.85 = graded grass ground (outlines skip small grass ledges), 1.0 = other
	bool grassG = isFoliage == 2 && vcolor.g > vcolor.b * 1.15 && vcolor.g > vcolor.r * 1.05;
	outNormal = vec4(n * 0.5 + 0.5, isFoliage == 1 ? (isGrassPlant == 1 ? 0.6 : (isLeaf == 2 ? 0.56 : 0.5)) : (grassG ? 0.85 : 1.0)); // 0.5 leaves, 0.6 grass plants (both < 0.75 = foliage)
}
