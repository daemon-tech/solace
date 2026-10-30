#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#include "/lib/clouds.glsl"
uniform float cloudHeight;
// Solace - outlines, water depth/foam, fog and colour grading.
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA8;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex3Clear = true;
const bool colortex3MipmapEnabled = true;
const bool colortex0MipmapEnabled = true;
const vec4 colortex1ClearColor = vec4(0.5, 0.5, 1.0, 0.0);
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex0Clear = true;
const bool colortex1Clear = true;
const bool colortex2Clear = true;
const int colortex4Format = RGBA16F;
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, -1.0);
const bool colortex4Clear = true;
const int colortex5Format = RG16F;
const bool colortex5Clear = false;
*/
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform int frameCounter;
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform int isEyeInWater;
uniform mat4 gbufferProjection;
uniform vec3 moonPosition;
uniform float bTemp;
uniform int biome;
uniform int biome_category;
uniform float bRain;
uniform float bSwamp;
uniform float bDark;
uniform float bCherry;
uniform float bPale;
uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
uniform vec4 lightningBoltPosition;
uniform float lFlash;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 previousCameraPosition;
uniform vec3 eyePosition; // player eye (differs from the camera in third person)
uniform float frameTime;
uniform sampler2D colortex6; // wake map: world-anchored trail history
// biome mood: smooth weights from temperature/rainfall (custom smoothed uniforms)
vec3 biomeTint(out float extraHaze) {
	float hot = smoothstep(1.0, 1.8, bTemp) * (1.0 - smoothstep(0.2, 0.5, bRain));
	float cold = 1.0 - smoothstep(0.05, 0.35, bTemp);
	float lush = smoothstep(0.75, 0.95, bRain) * smoothstep(0.6, 0.9, bTemp);
	float plains = smoothstep(0.6, 0.85, bTemp) * (1.0 - smoothstep(0.5, 0.8, bRain)) * (1.0 - hot);
	vec3 t = vec3(1.0);
	t = mix(t, vec3(1.05, 1.02, 0.92), plains);
	t = mix(t, vec3(0.94, 1.05, 0.92), lush);
	t = mix(t, vec3(1.08, 0.99, 0.84), hot);
	t = mix(t, vec3(0.90, 0.97, 1.10), cold);
	t = mix(t, vec3(0.97, 0.98, 0.86), bSwamp); // swamps: muted olive, not mint
	t = mix(t, vec3(0.93, 0.97, 0.96), bDark);
	extraHaze = 0.35 * bSwamp + 0.30 * bDark + 0.15 * cold;
	return mix(vec3(1.0), t, BIOME_MOOD * 1.5);
}
// Voxy LOD terrain (bound by Voxy when voxy.json is present; unset = 0 otherwise)
uniform sampler2D vxDepthTexOpaque;
uniform mat4 vxProjInv;
uniform int vxRenderDistance;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform float dhNearPlane;
uniform float dhFarPlane;
#endif
in vec2 uv;
/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHist;

float linDepth(float d) { return 2.0 * near * far / max(far + near - (2.0 * d - 1.0) * (far - near), 1e-4); }

float outlineMask(vec2 c, float centerLin) {
	vec2 px = OUTLINE_THICKNESS / vec2(viewWidth, viewHeight);
	float dz[9]; vec3 nz[9];
	bool foliage = texture(colortex1, c).a < 0.75;
	float skyN = 0.0, portalN = 0.0;
	int k = 0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 o = c + vec2(x, y) * px;
		dz[k] = linDepth(texture(depthtex0, o).r);
		vec4 nt = texture(colortex1, o);
		nz[k] = nt.xyz * 2.0 - 1.0;
		portalN = max(portalN, step(0.93, nt.a) * step(nt.a, 0.97));
		skyN = max(skyN, step(1.0, texture(depthtex0, o).r));
		k++;
	}
	// Sobel on linear depth, relative to distance
	float gx = (dz[2] + 2.0 * dz[5] + dz[8]) - (dz[0] + 2.0 * dz[3] + dz[6]);
	float gy = (dz[6] + 2.0 * dz[7] + dz[8]) - (dz[0] + 2.0 * dz[1] + dz[2]);
#if EDGE_KERNEL == 0
	float de = length(vec2(gx, gy)) / max(centerLin, 0.5);
#else
	// second-difference depth edge: zero on any flat surface however grazing or far,
	// so only real breaks (silhouettes, ledges) ink - first-derivative Sobel lit up flat ground
	// where the depth gradient alone crossed the threshold (thin light polygons on grass)
	float l2x = abs(dz[3] + dz[5] - 2.0 * dz[4]), l2y = abs(dz[1] + dz[7] - 2.0 * dz[4]);
	float l2a = abs(dz[0] + dz[8] - 2.0 * dz[4]), l2b = abs(dz[2] + dz[6] - 2.0 * dz[4]);
	float de = 2.5 * max(max(l2x, l2y), max(l2a, l2b)) / max(centerLin, 0.5);
#endif
	vec3 ngx = (nz[2] + 2.0 * nz[5] + nz[8]) - (nz[0] + 2.0 * nz[3] + nz[6]);
	vec3 ngy = (nz[6] + 2.0 * nz[7] + nz[8]) - (nz[0] + 2.0 * nz[1] + nz[2]);
	float ne = sqrt(max(dot(ngx, ngx) + dot(ngy, ngy), 0.0));
	// silhouettes: crisp 1px on depth breaks
	float e = step(0.12, de);
	// leaves: only ink silhouettes against the sky or a big depth jump, not every cut-out hole
	if (foliage) e *= max(skyN, step(0.6, de));
#ifndef GRASS_LEDGE_LINES
	// graded grass ground: top and side faces share one flat tone, so a 1-block ledge has no visible
	// face and its outline reads as a stray light line across flat grass. Only ink big drops / sky there.
	float ca = texture(colortex1, c).a;
	if (ca > 0.8 && ca < 0.9) e *= max(skyN, step(1.5, de));
#endif
	e *= 1.0 - smoothstep(OUTLINE_FADE * 0.6, OUTLINE_FADE, centerLin);
	if (portalN > 0.5) return 0.0; // portal sheet sits inside its frame: no line along the obsidian
#ifdef OUTLINE_NORMALS
	// inner block edges: normal Sobel, lighter ink, near range only, never on leaves
	if (!foliage) {
		float inner = step(1.6, ne) * INNER_STRENGTH * (1.0 - smoothstep(INNER_FADE * 0.5, INNER_FADE, centerLin));
		e = max(e, inner);
	}
#endif
	return e;
}

float duskW(float h) { return clamp(1.0 - abs(h) * 4.0, 0.0, 1.0); }

vec3 grade(vec3 c) {
	float l = luma(c);
	// warm/red hues (sand, terracotta) get less saturation boost
	float warm = clamp((c.r - max(c.g * 0.85, c.b)) * 3.0, 0.0, 1.0);
	float sat = mix((SATURATION * STYLE_K + 1.0 - STYLE_K), 1.0 + ((SATURATION * STYLE_K + 1.0 - STYLE_K) - 1.0) * (1.0 - WARM_SAT_LIMIT), warm);
	c = mix(vec3(l), c, sat);
	float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
	c = mix(vec3(luma(c)), c, 1.0 + VIBRANCE * (1.0 - clamp(mx - mn, 0.0, 1.0)) * (1.0 - warm * 0.6));
	// push greens towards lime (#9dc832)
	float g = clamp((c.g - max(c.r, c.b)) * 4.0, 0.0, 1.0);
	c.r += (c.g - c.r) * (LIME_GREENS * STYLE_K) * g;
	c *= 1.0 + 0.16 * g * (LIME_GREENS * STYLE_K) / 0.25; // lush greens, no glow boost
	c.r *= 1.0 - 0.04 * g; // hue toward ~114
	c *= mix(vec3(1.0), vec3(1.06, 1.0, 0.90), WARMTH * smoothstep(0.2, 0.8, l));
	// sand-like (pale warm, low sat): brighter and more yellow
	float sand = smoothstep(0.42, 0.55, l) * step(c.b, c.g * 0.92) * step(c.g, c.r * 1.02) * (1.0 - smoothstep(0.35, 0.5, (c.r - c.b) / max(c.r, 1e-3)));
	c = mix(c, c * vec3(1.07, 1.03, 0.84), sand * SAND_BOOST); // warm, not glaring: sand stays below the white clouds
	c = max(c, 0.0);
	// soft luminance cap: compress highlights above LUMA_CAP
	float nl = luma(c);
	// highlight shoulder: the brightest tones drift toward soft white instead of clipping to saturated yellow
	c = mix(c, vec3(nl) * vec3(1.02, 0.99, 0.97), smoothstep(LUMA_CAP - 0.04, 1.05, nl) * 0.4);
	if (nl > LUMA_CAP) c *= (LUMA_CAP + (nl - LUMA_CAP) * 0.35) / nl;
	// bright pale-warm ground (sand, sandstone, birch) at noon: one calm step down, so it never glares white
	float paleW = step(c.b, c.g) * step(c.g, c.r * 1.05) * (1.0 - smoothstep(0.25, 0.45, (c.r - c.b) / max(c.r, 1e-3)));
	c *= 1.0 - 0.16 * smoothstep(0.6, 0.92, luma(c)) * paleW;
	return c;
}

// soft shadows part 2: depth/normal-aware edge smoothing + temporal history of the banded sun term
vec3 smoothShadow(vec3 col, float d0, float lin) {
	outHist = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 S = texture(colortex4, uv);
#ifdef SHADOW_DEBUG
	if (S.a < -0.5) return vec3(1.0, 0.0, 1.0);
#endif
	if (S.a < -0.5 || d0 >= 1.0 || d0 < 0.56 || texture(depthtex1, uv).r - d0 > 1e-6) return col;
	vec3 n0 = texture(colortex1, uv).xyz * 2.0 - 1.0;
	bool fol = texture(colortex1, uv).a < 0.75;
	float lb = S.a, f = lb;
	vec2 px = 1.0 / vec2(viewWidth, viewHeight);
	float mn = lb, mx = lb;
#ifdef SHADOW_FILTER
	// radius ~0.18 blocks in world size, in pixels
	float rp = clamp(0.18 * SHADOW_FILTER_SIZE * gbufferProjection[1][1] * 0.5 * viewHeight / max(lin, 0.1), 1.5, 14.0 * SHADOW_FILTER_SIZE);
	const float ang = 0.6; // fixed pattern: no per-pixel hash, no per-frame jitter
	float ws = 1.0, sum = lb;
	for (int i = 0; i < 16; i++) {
		float r = sqrt((float(i) + 0.5) / 16.0);
		float a = float(i) * 2.39996 + ang;
		vec2 o = uv + vec2(cos(a), sin(a)) * r * rp * px;
		vec4 s2 = texture(colortex4, o);
		if (s2.a < -0.5) continue;
		float l2 = linDepth(texture(depthtex0, o).r);
		float w = exp(-abs(l2 - lin) / max(lin, 0.5) * 40.0) * smoothstep(0.75, 0.95, dot(n0, texture(colortex1, o).xyz * 2.0 - 1.0));
		w *= 1.0 - r * 0.5;
		sum += s2.a * w; ws += w;
		if (r < 0.6 && w > 0.3) { mn = min(mn, s2.a); mx = max(mx, s2.a); }
	}
	f = sum / ws;
#endif
#ifdef SHADOW_TEMPORAL
	{
		vec4 vp = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
		vec3 wp = mat3(gbufferModelViewInverse) * (vp.xyz / vp.w) + gbufferModelViewInverse[3].xyz;
		wp += cameraPosition - previousCameraPosition;
		vec4 pc = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(wp, 1.0));
		vec2 puv = pc.xy / pc.w * 0.5 + 0.5;
		float plin = -(gbufferPreviousModelView * vec4(wp, 1.0)).z;
		if (all(greaterThan(puv, vec2(0.0))) && all(lessThan(puv, vec2(1.0)))) {
			vec2 h = texture(colortex5, puv).rg;
			float ok = step(abs(h.g - plin), plin * 0.04 + 0.05) * step(0.01, h.g);
			// clamp history to the current neighbourhood: no trails behind swaying plants
			float hc = clamp(h.r, min(mn, f) - 0.05, max(mx, f) + 0.05);
			float k = (fol ? 0.55 : 0.93) * ok;
			f = mix(f, hc, k);
		}
	}
	outHist = vec4(f, lin, 0.0, 1.0);
#endif
#ifdef SHADOW_DEBUG
	return vec3(lb, f, texture(colortex5, uv).r);
#endif
	return max(col + S.rgb * (f - lb), vec3(0.0));
}

void main() {
	vec3 col = texture(colortex0, uv).rgb;
	// calm far canopies: past ~20 blocks, leaf pixels take a soft average of their leafy neighbours, so the
	// bright/dark texel speckle of cutout leaves melts into one painted mass (edges to sky and trunks stay crisp)
	if (texture(colortex1, uv).a < 0.75) {
		float dl = linDepth(texture(depthtex0, uv).r);
		float kC = smoothstep(12.0, 40.0, dl);
		if (kC > 0.0) {
			vec2 pxC = clamp(1.2 * gbufferProjection[1][1] * 0.5 * viewHeight / (16.0 * max(dl, 1.0)) * 1.4, 1.5, 4.0) / vec2(viewWidth, viewHeight); // ~one leaf texel
			vec3 acc = col; float wsum = 1.0;
			for (int i = 0; i < 8; i++) {
				vec2 o = uv + vec2(cos(float(i) * 0.785), sin(float(i) * 0.785)) * pxC * (i % 2 == 0 ? 1.0 : 1.6);
				if (texture(colortex1, o).a < 0.75 && abs(linDepth(texture(depthtex0, o).r) - dl) < 2.0 + dl * 0.05) { acc += texture(colortex0, o).rgb; wsum += 1.0; }
			}
			col = mix(col, acc / wsum, kC * 0.75);
		}
	}
	if (any(isnan(col)) || any(isinf(col))) col = vec3(0.0);
	// nether portal sheet (normal alpha 0.95): self-lit, so haze, fog lift and grading must not veil it
	float portalPx = step(abs(texture(colortex1, uv).a - 0.95), 0.02);
	vec3 portalBase = col;
	float d0 = texture(depthtex0, uv).r;
	float bHaze; vec3 bTint = biomeTint(bHaze);
	float lin = linDepth(d0);
#if defined SHADOWS && (defined SHADOW_FILTER || defined SHADOW_TEMPORAL)
	col = smoothShadow(col, d0, lin);
#else
	outHist = vec4(0.0);
#endif
	bool isDH = false;
#ifdef DISTANT_HORIZONS
	if (d0 >= 1.0) {
		float dd0 = texture(dhDepthTex0, uv).r;
		if (dd0 < 1.0) { isDH = true; lin = 2.0 * dhNearPlane * dhFarPlane / max(dhFarPlane + dhNearPlane - (2.0 * dd0 - 1.0) * (dhFarPlane - dhNearPlane), 1e-4); }
	}
#endif
	// Voxy: LOD pixels sit behind the vanilla depth (excludeLodsFromVanillaDepth), read their own depth
	if (d0 >= 1.0 && vxRenderDistance > 0) {
		float vd = texture(vxDepthTexOpaque, uv).r;
		if (vd < 1.0) {
			vec4 vp = vxProjInv * vec4(vec3(uv, vd) * 2.0 - 1.0, 1.0);
			isDH = true; lin = -vp.z / vp.w;
		}
	}
	// world end for distance effects: the LOD edge when Voxy is on, else the render distance
	float wEnd = vxRenderDistance > 0 ? max(far, float(vxRenderDistance) * 16.0) : far;
	bool water = texture(colortex2, uv).r > 0.5;
#ifdef SSAO
	// screen-space ambient occlusion: soft contact shading in corners and under overhangs (banded)
	if (d0 < 1.0 && !water && isEyeInWater == 0) {
		vec4 ap = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
		vec3 P = ap.xyz / ap.w;
		vec3 Nn = safeNormalize(texture(colortex1, uv).xyz * 2.0 - 1.0, vec3(0, 0, 1));
		float occ = 0.0;
		float rr = 0.55;
		// fixed tap pattern (no per-pixel jitter), smooth falloff per tap
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 2.39996;
			float r = rr * sqrt((float(i) + 0.5) / 12.0);
			vec3 tng = safeNormalize(cross(Nn, abs(Nn.y) < 0.9 ? vec3(0, 1, 0) : vec3(1, 0, 0)), vec3(1, 0, 0));
			vec3 btg = cross(Nn, tng);
			vec3 S = P + (tng * cos(a) + btg * sin(a)) * r + Nn * r * 0.6;
			vec4 c = gbufferProjection * vec4(S, 1.0);
			vec2 so = c.xy / c.w * 0.5 + 0.5;
			vec4 q = gbufferProjectionInverse * vec4(so * 2.0 - 1.0, texture(depthtex0, so).r * 2.0 - 1.0, 1.0);
			float sz = q.z / q.w;
			occ += smoothstep(S.z + 0.02, S.z + 0.12, sz) * smoothstep(1.2, 0.0, abs(sz - P.z));
		}
		float ao = 1.0 - celBandSoft(occ / 12.0, 4, 0.4) * SSAO_STRENGTH;
		col *= mix(1.0, ao, smoothstep(far * 0.6, 8.0, lin));
	}
#endif
	float heldK = 0.0;
#ifdef HELD_LIGHT
	// held light: a torch or lantern in hand casts a soft warm pool around the player. Two calm bands
	// with a smooth falloff, strongest where the scene is dark, so daylight is never touched.
	if (d0 < 1.0 && d0 > 0.56 && isEyeInWater < 2) {
		float hl = float(max(heldBlockLightValue, heldBlockLightValue2));
		if (hl > 0.5) {
			float rad = hl * 0.9;
			// round pool: true distance from the hand (not screen depth), and surfaces facing the
			// player catch more light than ones seen edge-on, so the pool reads as a soft sphere
			vec4 hp4 = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
			vec3 hp = hp4.xyz / hp4.w - vec3(0.25, -0.35, 0.0);
			vec3 hN = safeNormalize(texture(colortex1, uv).xyz * 2.0 - 1.0, vec3(0, 0, 1));
			float face = mix(0.55, 1.0, clamp(dot(hN, -safeNormalize(hp, vec3(0, 0, -1))), 0.0, 1.0));
			float fall = (1.0 - smoothstep(0.0, rad, length(hp))) * face;
			fall = fall * fall * (3.0 - 2.0 * fall);
			// darkness of the surroundings: night or little sky light at the eye (caves), minus existing torch pools
			float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
			float dark = 1.0 - smoothstep(0.25, 0.75, dayFactor(sunPosition, upPosition) * eyeSky);
			dark *= 1.0 - clamp(texture(colortex2, uv).g * 1.2, 0.0, 0.6);
			dark *= 1.0 - smoothstep(0.55, 0.9, luma(col));
			vec3 hc = vec3(1.0, 0.64, 0.36);
			float k = fall * dark * (hl / 15.0) * HELD_LIGHT_STRENGTH;
			heldK = clamp(k * 1.5, 0.0, 1.0);
			col = mix(col, col * (1.0 + hc * 1.6) + hc * 0.05, clamp(k, 0.0, 1.0));
		}
	}
#endif
	float coolL = 0.0; // 0 warm (torch, lantern, lava) .. 1 clearly cool/coloured light (soul fire, sea lantern, amethyst)
#ifdef COLORED_LIGHT
	// coloured block light (screen space): light sources write their emitted colour to colortex3;
	// lit surfaces nearby take the average colour of the sources around them instead of plain warm.
	{
		float poolC = texture(colortex2, uv).g;
		if (poolC > 0.01 && texture(colortex3, uv).a < 0.5 && !water) {
			// blurred light-colour field from the mip chain (smooth, no speckles)
			vec4 L4 = textureLod(colortex3, uv, 4.0), L5 = textureLod(colortex3, uv, 5.0), L6 = textureLod(colortex3, uv, 6.0), L7 = textureLod(colortex3, uv, 7.0);
			vec4 Ls = L4 * 0.4 + L5 * 0.3 + L6 * 0.2 + L7 * 0.1; // reaches the whole light pool, not only the lamp itself
			vec3 acc = Ls.rgb; float wsum = Ls.a * 12.0;
			if (Ls.a > 0.00005) {
				vec3 warm = vec3(1.00, 0.72, 0.42);
				vec3 tint = acc / max(Ls.a, 1e-3);
				vec3 ratio = clamp((tint / max(luma(tint), 0.15)) / (warm / luma(warm)), vec3(0.25), vec3(2.6));
				ratio /= max(luma(ratio), 0.5); // keep brightness, change only hue (no dark halos)
				float k = clamp(poolC * 1.8, 0.0, 1.0) * smoothstep(0.0001, 0.004, Ls.a) * COLORED_LIGHT_STRENGTH;
				col = mix(col, col * ratio, k);
				// calm, not glaring: strong source hues (redstone red, amethyst) keep a soft saturation cap
				float cMx = max(col.r, max(col.g, col.b)), sat = (cMx - min(col.r, min(col.g, col.b))) / max(cMx, 1e-3);
				col = mix(col, mix(vec3(luma(col)), col, 0.55 / max(sat, 0.55)), k * smoothstep(0.15, 0.5, length(ratio - 1.0))); // warm torch pools untouched
				coolL = smoothstep(0.05, 0.30, (tint.b - tint.r) / max(luma(tint), 0.15)) * smoothstep(0.0001, 0.004, Ls.a);
				// the lit-pass torch island is always amber (it only knows the light level); inside cool pools retint it to the source colour
				vec3 tN = tint / max(max(tint.r, max(tint.g, tint.b)), 1e-3);
				col = mix(col, vec3(luma(col)) * mix(vec3(1.0), tN, 0.75) * 1.15, coolL * clamp(poolC * 1.6, 0.0, 1.0) * 0.7 * COLORED_LIGHT_STRENGTH);
			}
		}
	}
#endif

	// wet shore: land right at the water line is a touch darker and cooler, as if freshly washed (soft strip)
	if (!water && isEyeInWater == 0 && d0 < 1.0 && lin < 40.0) {
		vec2 px = 1.0 / vec2(viewWidth, viewHeight) * clamp(16.0 / max(lin, 1.0), 0.35, 2.0);
		float wet = 0.0;
		for (int k = 0; k < 12; k++) {
			float a = float(k) * 0.5236;
			float r = k < 6 ? 14.0 : 34.0;
			vec2 o = uv + vec2(cos(a), sin(a)) * px * r;
			if (texture(colortex2, o).r > 0.5 && abs(linDepth(texture(depthtex0, o).r) - lin) < 2.0) wet += k < 6 ? 1.0 : 0.6;
		}
		float wk = smoothstep(0.3, 3.0, wet) * (1.0 - smoothstep(24.0, 40.0, lin));
		col = mix(col, col * vec3(0.80, 0.84, 0.90), wk * 0.8);
	}
	if (water && isEyeInWater == 0 && d0 < 1.0) {
		float behind = max(linDepth(texture(depthtex1, uv).r) - lin, 0.0);
		{
			// thin plants (kelp, seagrass) right under the surface must not read as shallows: take the deeper of a few taps
			// two rings (near + wide, shrinking with distance) so whole seagrass blades are bridged, not just their edges
			vec2 tp = mix(10.0, 3.0, smoothstep(8.0, 64.0, lin)) / vec2(viewWidth, viewHeight);
			float bmax = behind;
			// third, wider ring: kelp tips just below the surface are bridged to the deep water around them
			for (int k = 0; k < 12; k++) {
				float a = float(k) * 0.785398 + 0.39 + (k >= 8 ? 0.2 : 0.0);
				vec2 o = uv + tp * vec2(cos(a), sin(a)) * (k < 4 ? 0.45 : (k < 8 ? 1.0 : 2.0)) * (k % 2 == 0 ? 1.0 : 0.8);
				if (texture(colortex2, o).r > 0.5) bmax = max(bmax, max(linDepth(texture(depthtex1, o).r) - linDepth(texture(depthtex0, o).r), 0.0));
			}
			behind = mix(behind, bmax, 0.95);
		}
		// deeper water -> banded deeper blue
		// clear shallows -> teal -> deep blue-green, in soft bands (bottom visible near shore)
		// 0.17 water: pale clear turquoise, near-white shallows, soft foam sheets
		float wday = dayFactor(sunPosition, upPosition);
		float t = frameTimeCounter;
		vec4 wp4 = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
		vec3 wv = wp4.xyz / max(abs(wp4.w), 1e-5);
		vec2 wxz = (mat3(gbufferModelViewInverse) * wv).xz + mod(cameraPosition.xz, 4096.0);
		float dd = celBandSoft(smoothstep(0.3, 14.0 * mix(0.8, 1.4, WATER_CLARITY * 0.5), behind), 4, 0.85); // soft painted steps from shore to deep, no hard contour lines
		vec3 shoreC = vec3(0.80, 0.98, 0.96);
#ifdef GLOW_SHALLOWS
		shoreC = vec3(0.62, 1.0, 0.98); // brighter cyan shallows
#endif
		vec3 midC = vec3(0.30, 0.82, 0.90); // bright clear turquoise
		vec3 deepC = vec3(0.10, 0.46, 0.70); // deeper end: clean sky-blue, not murky
		midC = mix(midC, vec3(0.34, 0.60, 0.46), bSwamp * BIOME_MOOD);
		deepC = mix(deepC, vec3(0.16, 0.36, 0.30), bSwamp * BIOME_MOOD);
		// swamps: murky olive-green water all the way to the shore (no pale mint shallows)
		shoreC = mix(shoreC, vec3(0.50, 0.60, 0.40), bSwamp * BIOME_MOOD);
		midC = mix(midC, vec3(0.26, 0.42, 0.30), bSwamp * BIOME_MOOD * 0.6);
		deepC = mix(deepC, vec3(0.10, 0.24, 0.18), bSwamp * BIOME_MOOD * 0.6);
		// night: same hues, darker and bluer (never navy-black)
		vec3 nightK = mix(vec3(0.30, 0.40, 0.64), vec3(1.0), wday);
		vec3 wc = (dd < 0.5 ? mix(shoreC, midC, dd * 2.0) : mix(midC, deepC, dd * 2.0 - 1.0)) * nightK;
		// golden hour: the water takes the low sun's warmth (peach-gold shallows, honeyed teal) instead of staying cold white
		float gDusk;
		{
			float wDusk = clamp(1.0 - abs(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0)))) * 4.0, 0.0, 1.0) * step(-0.08, dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))));
			wc *= mix(vec3(1.0), mix(vec3(1.10, 0.90, 0.70), vec3(1.04, 0.93, 0.84), dd), wDusk);
			gDusk = wDusk * (1.0 - rainStrength);
		}
		// open-ocean depth: past the deep band the water settles one calm step further into a soft blue-indigo
		wc = mix(wc, deepC * vec3(0.62, 0.74, 0.92) * nightK, celBandSoft(smoothstep(14.0, 34.0, behind), 2, 0.4) * 0.65);
		// falling / sloped water (normal not up): keep the surface's white flow streaks readable
		vec3 nV = texture(colortex1, uv).xyz * 2.0 - 1.0;
		float fall = smoothstep(0.3, 0.6, 1.0 - abs(dot(safeNormalize(nV, vec3(0, 1, 0)), safeNormalize(upPosition, vec3(0, 1, 0)))));
		float farF = smoothstep(24.0, far * 0.7, lin); // far water keeps the surface sky mirror
		vec3 hiPre = max(col - vec3(0.80), 0.0);
		// sky mirror: the flatter the view across the water, the more of the mirrored sky stays on the surface
		float skyM = pow(1.0 - clamp(dot(-safeNormalize(wv, vec3(0, 0, -1)), safeNormalize(upPosition, vec3(0, 1, 0))), 0.0, 1.0), 2.0);
		col = mix(col, wc, mix(0.55, 0.88, dd) * (1.0 - 0.65 * farF) * (1.0 - 0.75 * fall) * (1.0 - 0.55 * skyM * (1.0 - fall)) * WATER_DEPTH_TINT / 0.70);
		col *= 1.0 - 0.10 * texture(colortex2, uv).b * (1.0 - farF);
		float wl = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(wl), col, WATER_SAT) * WATER_BRIGHT + hiPre * 2.0;
		// golden hour: the whole water body settles into a soft warm teal-rose (no pale washed-out mint sheet)
		col = mix(col, col * vec3(1.04, 0.92, 0.96) + vec3(0.04, 0.0, 0.03), gDusk * 0.9 * (1.0 - fall));
#ifdef WATER_SSR
		// screen-space reflections of terrain/trees on the water surface (calm normal, fresnel)
		{
			vec3 upV = safeNormalize(upPosition, vec3(0, 1, 0));
			vec3 N = safeNormalize(mix(upV, safeNormalize(nV, upV), 0.16), upV); // calm: mirror-clear
			if (fall > 0.5) N = safeNormalize(nV, upV);
			vec3 V = safeNormalize(wv, vec3(0, 0, -1));
			vec3 R = reflect(V, N);
			float fres = 0.22 + 0.78 * pow(1.0 - clamp(dot(-V, N), 0.0, 1.0), 3.0);
			vec3 p = wv; vec3 st = R * max(0.35, -wv.z * 0.03);
			vec2 hitUV = vec2(-1.0);
			for (int i = 0; i < 28; i++) {
				p += st; st *= 1.14;
				vec4 c = gbufferProjection * vec4(p, 1.0);
				if (c.w <= 0.0) break;
				vec2 sc = c.xy / c.w * 0.5 + 0.5;
				if (any(lessThan(sc, vec2(0.0))) || any(greaterThan(sc, vec2(1.0)))) break;
				float sd = texture(depthtex1, sc).r;
				if (sd >= 1.0) continue;
				vec4 q = gbufferProjectionInverse * vec4(sc * 2.0 - 1.0, sd * 2.0 - 1.0, 1.0);
				float sz = q.z / q.w;
				if (sz > p.z && sz - p.z < length(st) * 2.5 + 0.4) {
					// refine
					vec3 a = p - st, b = p;
					for (int j = 0; j < 5; j++) {
						vec3 m = (a + b) * 0.5;
						vec4 cm = gbufferProjection * vec4(m, 1.0); vec2 sm = cm.xy / cm.w * 0.5 + 0.5;
						vec4 qm = gbufferProjectionInverse * vec4(sm * 2.0 - 1.0, texture(depthtex1, sm).r * 2.0 - 1.0, 1.0);
						if (qm.z / qm.w > m.z) b = m; else a = m;
					}
					vec4 cb = gbufferProjection * vec4(b, 1.0);
					hitUV = cb.xy / cb.w * 0.5 + 0.5;
					break;
				}
			}
			if (hitUV.x >= 0.0 && texture(colortex2, hitUV).r < 0.5) {
				vec2 e = smoothstep(vec2(0.0), vec2(0.08), hitUV) * smoothstep(vec2(1.0), vec2(0.92), hitUV);
				// soft painted mirror: a short vertical smear with a gentle sideways wobble from the waves (no sharp pixel copy)
				vec3 refl = vec3(0.0);
				float wob = sin(wxz.y * 1.3 + t * 0.9) * 0.0025 + sin(wxz.x * 0.9 - t * 0.7) * 0.0015;
				for (int k = -2; k <= 2; k++) refl += texture(colortex0, hitUV + vec2(wob, float(k) * 0.0035)).rgb * (k == 0 ? 0.3 : (abs(k) == 1 ? 0.2 : 0.15));
				refl = mix(refl, wc, 0.30); // reflections take a little of the water colour
				col = mix(col, refl, fres * e.x * e.y * WATER_SSR_STRENGTH * (1.0 - 0.6 * farF));
#ifdef NIGHT_LIGHT_REFLECT
				// night: light sources reflect as vivid coloured glows, stretched into a short vertical streak
				{
					float nk = (1.0 - wday) * e.x * e.y;
					if (nk > 0.01) {
						vec3 Ls = vec3(0.0);
						for (int k = -3; k <= 3; k++) {
							vec4 l4 = textureLod(colortex3, hitUV + vec2(0.0, float(k) * 0.012), 2.0);
							Ls += l4.rgb * (1.0 - abs(float(k)) / 4.0);
						}
						Ls /= 4.0;
						float ll = max(Ls.r, max(Ls.g, Ls.b));
						vec3 vivid = Ls / max(ll, 1e-3); // full-saturation hue of the light
						float brk = 0.6 + 0.4 * smoothstep(0.3, 0.6, vnoise(wxz * vec2(0.8, 0.3) + vec2(0.0, t * 0.4))); // world-space, smooth
						col += vivid * celBandSoft(clamp(ll * 1.6, 0.0, 1.0), 3, 0.4) * brk * nk * 0.9 * NIGHT_LIGHT_REFLECT_STRENGTH;
					}
				}
#endif
			}
#ifdef GLOW_SHALLOWS
			{
				// shallows glow cyan (also at night) with white wavy bands on the bottom
				float sh = 1.0 - smoothstep(0.2, 3.0, behind);
				vec3 bw = mat3(gbufferModelViewInverse) * wv + cameraPosition;
				float wb = sin(bw.x * 1.3 + bw.z * 0.7 + t * 1.2 + vnoise(bw.xz * 0.6 + t * 0.2) * 3.0);
				col += vec3(0.10, 0.45, 0.52) * sh * mix(0.6, 0.25, wday) * GLOW_SHALLOWS_AMT * (1.0 - farF);
				col = mix(col, vec3(0.92, 1.0, 1.0), smoothstep(0.86, 0.95, wb) * sh * 0.55 * GLOW_SHALLOWS_AMT * (1.0 - farF) * mix(0.55, 1.0, wday));
			}
#endif
#ifdef SUNSET_STREAK
			{
				// long bright vertical sun streak on the water when the sun is low
				vec4 ss = gbufferProjection * vec4(sunPosition, 1.0);
				float sunLow = clamp(1.0 - abs(dot(safeNormalize(sunPosition, upV), upV)) * 4.0, 0.0, 1.0);
				if (ss.w > 0.0 && sunLow > 0.01) {
					vec2 suv = ss.xy / ss.w * 0.5 + 0.5;
					float below = suv.y - uv.y;
					float w = 0.012 + 0.05 * clamp(below, 0.0, 1.0);
					float xs = 1.0 - smoothstep(w * 0.4, w, abs(uv.x - suv.x) * viewWidth / viewHeight);
					float brk = smoothstep(0.25, 0.55, vnoise(wxz * vec2(0.9, 0.35) + vec2(0.0, t * 0.5))); // world-space, smooth
					float k = xs * step(0.0, below) * brk * sunLow;
					col = mix(col, mix(vec3(1.0, 0.86, 0.55), vec3(1.0, 0.80, 0.84), ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0)), celBand(clamp(k, 0.0, 1.0), 3) * 0.9); // sunrise: peach-rose streak
				}
			}
#endif
#if DUSK_WATER_GLOW > 0
			{
				// dusk water glow: a broad, soft warm wash on the water toward the low sun, fading smoothly
				// to the sides (calm and wide, no sparkle), sunrise leans peach-rose
				vec3 LsD = safeNormalize(sunPosition, upV);
				float lowD = clamp(1.0 - abs(dot(LsD, upV)) * 3.0, 0.0, 1.0) * step(-0.08, dot(LsD, upV));
				vec3 RwD = reflect(V, upV);
				float lobe = pow(max(dot(RwD, LsD), 0.0), 3.0);
				float kD = smoothstep(0.0, 1.0, lobe) * lowD * (1.0 - rainStrength) * float(DUSK_WATER_GLOW) * 0.18;
				vec3 dC = mix(vec3(1.0, 0.70, 0.42), vec3(1.0, 0.76, 0.74), ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0));
				col = mix(col, col * 0.6 + dC * 0.55, clamp(kD, 0.0, 0.6));
			}
#endif
#ifdef WATER_SUN_GLINT
			// banded sun glint path on the surface (uses the full wave normal)
			vec3 Lsun = safeNormalize(sunPosition, upV);
			vec3 Rw = reflect(V, safeNormalize(mix(upV, safeNormalize(nV, upV), 0.8), upV));
			float g = pow(max(dot(Rw, Lsun), 0.0), 120.0);
			// broken into small glinting cells, not a solid blob
			float fpG = length(fwidth(wxz)); // texel footprint: high-frequency cells fade before they turn into pixel shimmer
			float cells = smoothstep(0.62, 0.70, vnoise(wxz * 3.5 + vec2(t * 0.8, -t * 0.5)) * 0.6 + mix(vnoise(wxz * 9.0 - t * 1.3), 0.5, smoothstep(0.03, 0.08, fpG)) * 0.4);
			cells *= 1.0 - smoothstep(0.08, 0.2, fpG); // far: fade out instead of a flat patch
			g = celBand(clamp(g * 2.5, 0.0, 1.0), 3) * cells;
			// glint colour: clean cool white by day (warm cream reads as sand flakes on deep blue), warm only with a low sun
			float gLow = 1.0 - smoothstep(0.08, 0.35, dot(Lsun, upV));
			vec3 gC = mix(vec3(0.95, 0.99, 1.0), vec3(1.0, 0.92, 0.76), gLow);
			// low sun: fewer hard sparkle cells, instead a broad soft warm sheen path under them
			col = mix(col, max(col, gC), clamp(g, 0.0, 1.0) * 0.75 * mix(1.0, 0.5, gLow) * wday * (1.0 - rainStrength));
			float gS = pow(max(dot(reflect(V, upV), Lsun), 0.0), 14.0);
			col = mix(col, vec3(1.0, 0.88, 0.72), celBandSoft(gS, 3, 0.6) * 0.30 * gLow * step(0.0, dot(Lsun, upV)) * (1.0 - rainStrength));
			// moon path: on clear nights a calm silver trail of glints leads across the water towards the moon
			{
				vec3 Lm = safeNormalize(moonPosition, upV);
				float gm = pow(max(dot(Rw, Lm), 0.0), 40.0);
				float gmW = pow(max(dot(reflect(V, upV), Lm), 0.0), 18.0); // soft wide sheen under the glints
				float nW = (1.0 - wday) * (1.0 - rainStrength);
				col = mix(col, vec3(0.80, 0.86, 1.0), clamp(celBand(clamp(gm * 2.0, 0.0, 1.0), 3) * cells * 0.5 + celBandSoft(gmW, 3, 0.8) * 0.26, 0.0, 1.0) * nW);
			}
#endif
#ifdef WATER_STARS
			{
				// stylized '+' sparkles twinkling in the sunlit part of the water (sun reflection zone)
				vec3 Rc = reflect(V, upV);
				float zone = pow(max(dot(Rc, Lsun), 0.0), 10.0) * wday * (1.0 - rainStrength) * (1.0 - farF);
				if (zone > 0.02) {
					vec2 pxy = uv * vec2(viewWidth, viewHeight);
					float cs = 26.0;
					vec2 cell = floor(pxy / cs);
					float tw = floor(t * 2.5 + hash12(cell) * 7.0);
					float pick = hash12(cell + tw * 0.37);
					if (pick > 0.88) { // sparse and gentle
						vec2 cen = (cell + 0.25 + 0.5 * vec2(hash12(cell + 1.7), hash12(cell + 4.3))) * cs;
						vec2 d = abs(pxy - cen);
						float L = mix(5.0, 11.0, hash12(cell + 9.1));
						float arm = max(step(d.y, 0.6) * smoothstep(L, 0.0, d.x), step(d.x, 0.6) * smoothstep(L, 0.0, d.y));
						float core = step(max(d.x, d.y), 1.2);
						float ph = fract(t * 2.5 + hash12(cell) * 7.0);
						float amp = sin(ph * 3.14159);
						col = mix(col, vec3(1.0, 0.98, 0.90), clamp(max(arm, core) * amp * smoothstep(0.02, 0.3, zone), 0.0, 1.0) * WATER_STARS_STRENGTH);
					}
				}
			}
#endif
		}
#endif
#ifdef WATER_FOAM
		{
			float fday = mix(0.35, 1.0, wday);
			vec3 upV0 = safeNormalize(upPosition, vec3(0, 1, 0));
			vec3 foamC = vec3(0.96, 1.0, 1.0) * nightK;
			float wob = vnoise(wxz * 1.7 + t * 0.5) * 0.35;
			float shore = 1.0 - smoothstep(0.0, 4.5, behind);
			// soft foam sheets only along shores (open lakes seen from above stay clean)
			float n = vnoise(wxz * vec2(0.16, 0.45) + vec2(t * 0.05, t * 0.02)) * 0.6 + vnoise(wxz * vec2(0.5, 1.3) - vec2(t * 0.07, 0.0)) * 0.4;
			float sheet = smoothstep(0.62, 0.66, n + shore * 0.25) * shore * (1.0 - farF);
			// flowing streak foam riding the wave crests (same phase as the surface waves)
			float ph = wxz.x * 0.55 + wxz.y * 0.25 + t * 0.9 + vnoise(wxz * 0.15) * 4.0;
			vec2 rq = mat2(0.8, -0.6, 0.6, 0.8) * wxz; // rotated so breaks are not grid-aligned
			float brk = smoothstep(0.36, 0.66, vnoise(rq * 0.45 + vec2(t * 0.2, 0.0)) * 0.7 + vnoise(rq * 1.3) * 0.3);
			// whitecap patches: only scattered drifting groups of crests carry foam, the open sea between them stays clear
			brk *= mix(smoothstep(0.36, 0.64, vnoise(rq * 0.06 + vec2(t * 0.03, -t * 0.02))), 1.0, shore);
			float streak = smoothstep(mix(0.70, 0.86, farF), 0.98, sin(ph)) * brk * (1.0 - farF * 0.35) * mix(0.60, 1.0, shore); // far sea keeps thin foam
			col = mix(col, foamC, clamp(max(sheet * 0.90, streak * 0.55), 0.0, 1.0) * (1.0 - fall) * fday * WATER_FOAM_AMT);
#ifdef SHORE_FOAM
			{
				// shoreline foam: a clean white line where the water meets the shore that slowly washes up
				// and draws back, leaving a faint wet sheet behind it; a second, fainter line follows further out.
				// The phase drifts gently along the shore so the whole coast never pulses at once.
				float sph = t * 0.55 + vnoise(wxz * 0.06) * 6.2832;
				float wash = 0.5 + 0.5 * sin(sph);
				float e1 = mix(0.30, 0.95, wash);
				float e2 = e1 + mix(0.70, 1.05, 0.5 + 0.5 * sin(sph - 1.3));
				float line1 = smoothstep(e1 - 0.24, e1 - 0.08, behind) * (1.0 - smoothstep(e1 - 0.02, e1 + 0.10, behind));
				float line2 = smoothstep(e2 - 0.18, e2 - 0.06, behind) * (1.0 - smoothstep(e2 - 0.01, e2 + 0.08, behind));
				float sheetW = 1.0 - smoothstep(e1 - 0.40, e1 - 0.08, behind);
				float sf = max(max(line1, line2 * 0.55), sheetW * 0.2) * (1.0 - farF) * (1.0 - fall);
				col = mix(col, foamC, clamp(sf, 0.0, 1.0) * fday * SHORE_FOAM);
			}
#endif
			{
				// rolling surf: soft white foam lines that form out in the shallows and roll in toward the shore,
				// broken into long calm stretches along the coast, thinning out as they reach the beach
				float rph = behind * 1.15 + t * 0.55 + vnoise(wxz * 0.05) * 2.5;
				float rl = smoothstep(0.55, 0.85, sin(rph)) * (1.0 - smoothstep(0.90, 1.0, sin(rph)) * 0.25);
				float rbrk = smoothstep(0.25, 0.45, vnoise(wxz * vec2(0.09, 0.09) + vec2(t * 0.02, 0.0)));
				float rzone = smoothstep(0.5, 1.2, behind) * (1.0 - smoothstep(5.0, 9.0, behind));
				col = mix(col, foamC, clamp(rl * rbrk * rzone, 0.0, 1.0) * 0.9 * (1.0 - farF * 0.7) * (1.0 - fall) * fday * WATER_FOAM_AMT);
			}
#ifdef WATER_ROLL
			// rolling swell: blocky white foam caps on the crests (1/8-block cells, ocean only)
			if (fall < 0.5) {
				vec2 fc = floor(wxz * 8.0) / 8.0;
				float cr = rollWave(fc, t);
				float cap = step(0.86 - 0.10 * hash12(floor(wxz * 8.0)), cr) * (1.0 - farF * 0.5);
				col = mix(col, foamC, cap * 0.92 * fday);
			}
#endif
			// foam rings around blocks standing in the water (posts, rocks, plants)
			{
				vec2 px = 5.0 / vec2(viewWidth, viewHeight) * clamp(16.0 / max(lin, 1.0), 0.35, 2.0);
				float touch = 0.0;
				for (int k = 0; k < 6; k++) {
					float a = float(k) * 1.0472;
					vec2 o = uv + vec2(cos(a), sin(a)) * px;
					float dn = texture(depthtex0, o).r;
					if (texture(colortex2, o).r < 0.5 && dn < 1.0 && abs(linDepth(dn) - lin) < 1.2) touch += 1.0;
				}
				float ring = smoothstep(0.5, 2.5, touch + wob * 2.0) * (1.0 - farF);
				col = mix(col, foamC, ring * 0.8 * fday * WATER_FOAM_AMT);
			}
#ifdef WATER_SPLASH
			// splashes: rings + white bursts around the player when wading/swimming, and foam where falling water lands
			{
#ifdef NIGHT_WAKE_BRIGHT
				// wakes and splashes stay bright white at night (no night dimming)
				vec3 foamW = vec3(0.96, 1.0, 1.0) * mix(0.90, 1.0, wday);
				float fW = mix(0.85, 1.0, wday);
#else
				vec3 foamW = foamC; float fW = fday;
#endif
				vec3 wpw = mat3(gbufferModelViewInverse) * wv;
				vec2 rel = wpw.xz + cameraPosition.xz - eyePosition.xz; // player-relative xz (works in third person and in boats)
				float feetY = eyePosition.y - 1.62;
				float surfY = wpw.y + cameraPosition.y;
				float inW = smoothstep(1.0, 0.2, abs(feetY - surfY + 0.4)); // player standing/swimming at the surface
				// speed from the wake map state (eye delta, smoothed), never from the camera
				vec2 vel = texelFetch(colortex6, ivec2(1, 256), 0).xy;
				float mv = clamp(length(vel) / 4.0, 0.0, 1.0);
				float d = length(rel);
				float rings = smoothstep(0.82, 0.96, sin(d * 7.5 - t * 6.0 + wob * 2.0)) * smoothstep(2.6, 0.5, d);
				float burst = smoothstep(0.55, 0.62, vnoise(wxz * 5.0 + t * 1.5) * smoothstep(1.4, 0.3, d) + 0.25 * smoothstep(1.0, 0.0, d));
				col = mix(col, foamW, clamp(rings * (0.22 + 0.78 * mv) + burst * mv, 0.0, 1.0) * inW * fW * WATER_SPLASH_AMT);
#ifdef WATER_WAKE
				// trail from the wake map: deposited in world space, so it stays on the water when the camera rotates
				{
					vec2 w = wxz;
					vec2 g = w * 4.0;
					vec2 base = floor(g);
					vec2 fr = fract(g);
					float core = 0.0, spread = 0.0, hgt = 0.0, hgtW = 0.0;
					for (int i = 0; i < 4; i++) {
						vec2 tc = base + vec2(i % 2, i / 2);
						vec2 tile = floor(tc / 256.0);
						float tag = 1.0 + mod(tile.x, 64.0) * 64.0 + mod(tile.y, 64.0);
						vec4 q = texelFetch(colortex6, ivec2(mod(tc, 256.0)), 0);
						float ok = 1.0 - step(0.5, abs(q.b - tag));
						float bw = (i % 2 == 0 ? 1.0 - fr.x : fr.x) * (i / 2 == 0 ? 1.0 - fr.y : fr.y);
						core += q.r * ok * bw;
						spread += q.a * ok * bw;
						hgt += q.g * ok * bw; hgtW += ok * bw;
					}
					hgt = hgtW > 0.0 ? hgt / hgtW : 0.0;
					// only where the trail was laid at this water level (no ghost wakes on water far above/below)
					float lvl = smoothstep(2.5, 0.4, abs(hgt - surfY));
					// the spread field grows outward over time; its contour reads as two diverging arms
					float edge = (1.0 - smoothstep(0.0, 0.18, abs(spread - 0.4))) * 0.55;
					float fill = smoothstep(0.12, 0.35, spread) * (1.0 - smoothstep(0.55, 0.85, spread)) * 0.15;
					// soft core: bright right behind the player, thinning out as it ages (no flat white band)
					float cr = smoothstep(0.15, 1.0, core) * 0.45 * (0.8 + 0.2 * vnoise(wxz * 0.9 + t * 0.15));
					// fade out well before the edge of the 64-block wake window (no straight cut-offs)
					vec2 eW = eyePosition.xz - cameraPosition.xz + mod(cameraPosition.xz, 4096.0);
					vec2 dW = abs(wxz - eW);
					float win = 1.0 - smoothstep(22.0, 29.0, max(dW.x, dW.y));
					float k = clamp(max(cr, max(edge * 0.65, fill)) * lvl * win, 0.0, 1.0);
					col = mix(col, foamW, celBandSoft(k, 3, 0.5) * 0.7 * fW * WATER_SPLASH_AMT);
				}
#endif
				// falling water hitting a flat surface: a churning foam pool below the stream
				if (fall < 0.5) {
					float hitF = 0.0;
					for (int k = 1; k <= 3; k++) {
						vec2 o = uv + vec2(0.0, float(k) * 6.0 / viewHeight) * clamp(16.0 / max(lin, 1.0), 0.4, 2.0);
						vec3 nO = texture(colortex1, o).xyz * 2.0 - 1.0;
						float fO = 1.0 - abs(dot(safeNormalize(nO, upV0), upV0));
						hitF = max(hitF, step(0.5, texture(colortex2, o).r) * smoothstep(0.3, 0.6, fO));
					}
					float churn = smoothstep(0.45, 0.6, vnoise(wxz * 3.0 + vec2(0.0, t * 2.5)) * 0.7 + vnoise(wxz * 7.0 - t * 4.0) * 0.3 + hitF * 0.25);
					col = mix(col, foamW, hitF * churn * fW * WATER_SPLASH_AMT);
					col = mix(col, vec3(0.95, 1.0, 1.0), hitF * 0.35 * fW * WATER_SPLASH_AMT); // white mist over the pool
				}
			}
#endif
			// crisp shoreline line + soft rim
			if (behind < 0.50 + wob * 0.5) col = mix(col, foamC, 0.95 * fday);
			else if (behind < 0.95 + wob) col = mix(col, foamC, 0.45 * fday);
		}
#endif
	}

	// view ray and world height of this pixel (for sky-matched fog and ground mist)
	vec4 vp4 = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
	vec3 vpos = vp4.xyz / max(abs(vp4.w), 1e-5);
	vec3 vdir = safeNormalize(vpos, vec3(0, 0, -1));
	vec3 fogSky = celHorizon(vdir, sunPosition, upPosition, rainStrength);
	float wY = (mat3(gbufferModelViewInverse) * vpos).y + cameraPosition.y;
	// ground reference for the low layers: sea level in normal worlds. On maps whose land sits far below
	// sea level, the ground is estimated from a few fixed taps in the lower screen (the same for every
	// pixel, so no seams) and the mist and valley fog follow it instead of burying the whole landscape.
	float gEst = 1e4;
	{
		const vec2 gTaps[5] = vec2[5](vec2(0.2, 0.12), vec2(0.5, 0.08), vec2(0.8, 0.12), vec2(0.35, 0.3), vec2(0.65, 0.3));
		for (int i = 0; i < 5; i++) {
			float dg = texture(depthtex0, gTaps[i]).r;
			if (dg >= 1.0) continue;
			vec4 g4 = gbufferProjectionInverse * vec4(gTaps[i] * 2.0 - 1.0, dg * 2.0 - 1.0, 1.0);
			gEst = min(gEst, (mat3(gbufferModelViewInverse) * (g4.xyz / max(abs(g4.w), 1e-5))).y + cameraPosition.y);
		}
		if (gEst > 1e3) gEst = min(63.0, cameraPosition.y - 14.0); // only sky below the horizon: fall back to the viewer
	}
	float gRef = mix(63.0, min(63.0, gEst), smoothstep(48.0, 30.0, gEst));
	float sunHf = dot(safeNormalize(sunPosition, safeNormalize(upPosition, vec3(0,1,0))), safeNormalize(upPosition, vec3(0,1,0)));
	float morningW = ((sunAngle < 0.25 || sunAngle > 0.75) ? 1.0 : 0.0) * clamp(1.0 - abs(sunHf - 0.05) * 4.0, 0.0, 1.0);
	float bFog = clamp(bHaze * BIOME_MOOD * BIOME_FOG, 0.0, 1.0);
	// underground / enclosed: eye sky light (smoothed) -> 0 open sky .. 1 deep cave
	float cave = smoothstep(0.55, 0.05, float(eyeBrightnessSmooth.y) / 240.0) * smoothstep(60.0, 48.0, cameraPosition.y); // dark AND below the surface (not a closed house)
#ifdef RIM_LIGHT
	// rim light: a soft, wide fringe on silhouettes that sit in front of something far away
	// (sky or distant terrain), strongest when looking towards the sun or moon. Fixed tap ring,
	// no jitter, so the fringe is a smooth gradient and never sparkles.
	if (isEyeInWater == 0 && d0 < 1.0 && d0 >= 0.56 && !water && lin < 110.0) {
		vec3 upV = safeNormalize(upPosition, vec3(0, 1, 0));
		float dayR = dayFactor(sunPosition, upPosition);
		vec3 Lv = safeNormalize(dayR > 0.15 ? sunPosition : moonPosition, upV);
		float lightH = dot(Lv, upV);
		float facing = dot(vdir, Lv); // > 0: looking towards the light (backlit)
		float back = smoothstep(-0.15, 0.85, facing);
		float strength = mix(0.18, 1.0, back) * mix(0.30, 1.0, dayR) * smoothstep(-0.05, 0.06, lightH);
		strength *= (1.0 - rainStrength * 0.7) * (1.0 - cave);
		strength *= 1.0 - smoothstep(48.0, 110.0, lin);
		if (strength > 0.002) {
			bool folR = texture(colortex1, uv).a < 0.75;
			vec3 nR = safeNormalize(texture(colortex1, uv).xyz * 2.0 - 1.0, vec3(0, 0, 1));
			float rp = clamp(2.2 * RIM_WIDTH * 10.0 / max(lin, 1.0), 1.5, 4.5 * RIM_WIDTH);
			vec2 pxR = rp / vec2(viewWidth, viewHeight);
			float sil = 0.0;
			// two rings (full and half radius, offset angles): the fringe fades out smoothly inwards
			for (int i = 0; i < 16; i++) {
				float a = float(i) * 0.785398 + (i >= 8 ? 0.392699 : 0.0);
				vec2 o = clamp(uv + vec2(cos(a), sin(a)) * pxR * (i >= 8 ? 0.5 : 1.0), vec2(0.001), vec2(0.999));
				float dt = texture(depthtex1, o).r;
				float lt = dt >= 1.0 ? far * 4.0 : linDepth(dt);
				// how far the background behind the edge is, relative to this pixel
				float gap = (lt - lin) / max(lin, 1.0);
				float w = smoothstep(0.35, 1.6, gap);
				if (folR) w *= step(1.0, dt) * 0.6; // leaves: only against open sky, no cut-out holes
				sil += w;
			}
			sil = smoothstep(0.0, 0.55, sil / 16.0);
			// faces turned away from the camera carry more rim (entity curves, block sides)
			float side = mix(0.55, 1.0, smoothstep(0.2, 0.9, 1.0 - abs(nR.z)));
			vec3 sunC = mix(vec3(1.0, 0.95, 0.84), vec3(1.0, 0.70, 0.42), duskW(lightH));
			vec3 rimC = mix(mix(fogSky, vec3(1.0), 0.35), sunC, back * dayR);
			rimC = mix(rimC, vec3(0.62, 0.72, 1.0) * 0.8, 1.0 - dayR); // cool moonlit rim
			float a = sil * side * strength * RIM_STRENGTH * 0.30;
			// lift towards the rim colour (screen-like, cannot clip or turn white)
			col = mix(col, max(col, rimC * 0.95), clamp(a, 0.0, 0.32));
#ifdef RIM_DEBUG
			col = mix(col, vec3(1.0, 0.0, 1.0), clamp(a * 6.0, 0.0, 1.0));
#endif
		}
	}
#endif
#ifdef DISTANCE_FOG
	if (isEyeInWater == 0 && (d0 < 1.0 || isDH)) {
		float day = dayFactor(sunPosition, upPosition);
		vec3 fogCol = mix(vec3(0.18, 0.20, 0.50), vec3(0.42, 0.72, 0.85), day) * bTint;
		fogCol = mix(fogCol, fogSky, FOG_SKY_MATCH);
		float fs = far * mix(0.14, 0.06, bFog), fe = far * mix(0.95, 0.75, bFog); // foggy biomes still let nearby hills read clearly
		float f = celBandSoft(smoothstep(fs, fe, lin), 4, 0.5) * min(FOG_STRENGTH * (1.0 + bFog * 0.3), 1.0);
		col = mix(col, fogCol, f * (water ? 0.35 : 1.0) * (1.0 - 0.85 * cave * CAVE_FOG_ON));
	}
#endif
#if AERIAL_PERSPECTIVE > 0
	// aerial perspective: distant land slowly fades paler and bluer into the sky colour, smooth (no bands),
	// so ridges and forests stack into soft layers; warmer toward the sun at dawn and dusk
	if (IS_OW && isEyeInWater == 0 && (d0 < 1.0 || isDH) && cave < 0.5 && !water) {
		float dayA = dayFactor(sunPosition, upPosition);
		float ap = 1.0 - exp(-max(lin - 24.0, 0.0) / (wEnd * 0.75));
		ap = smoothstep(0.0, 1.0, ap) * float(AERIAL_PERSPECTIVE) * 0.1 * mix(0.35, 1.0, dayA) * (1.0 - rainStrength * 0.5);
		vec3 apC = mix(fogSky, vec3(0.62, 0.75, 0.94), 0.55 * dayA); // daytime distance leans soft sky-blue, not milk-white
		vec3 desat = mix(vec3(luma(col)), col, 1.0 - 0.45 * ap);
		col = mix(desat, apC, ap * 0.7);
	}
#endif
#ifdef CAVE_FOG
	// cave fog: darker, denser, slightly cool-tinted; banded like the rest of the fog
	if (isEyeInWater == 0 && d0 < 1.0 && cave > 0.01) {
		float cf = celBandSoft(1.0 - exp(-lin * 0.045 * CAVE_FOG_DENSITY), 4, 0.6); // soft band steps (no hard box on far walls)
		vec3 caveC = vec3(0.040, 0.046, 0.070) + vec3(0.010, 0.020, 0.030) * dayFactor(sunPosition, upPosition);
		col = mix(col, caveC, cf * cave * 0.85);
		// glowing haze: air around lava and lights fills with a soft warm veil of their colour
		vec4 h6 = textureLod(colortex3, uv, 6.0), h7 = textureLod(colortex3, uv, 7.0);
		vec4 hs = h6 * 0.6 + h7 * 0.4;
		vec3 hTint = hs.rgb / max(hs.a, 1e-3); hTint /= max(max(hTint.r, max(hTint.g, hTint.b)), 1e-3);
		float hK = smoothstep(0.0, 0.08, hs.a) * smoothstep(1.5, 8.0, lin);
		col += hTint * vec3(1.0, 0.82, 0.62) * hK * (0.06 + 0.10 * cf) * cave * CAVE_HAZE;
	}
#endif
	// low ground mist: sunrise everywhere, swamps all day; hugs the ground, never on near water
	if (isEyeInWater == 0 && d0 < 1.0 && MORNING_MIST > 0.0) {
		float amt = MORNING_MIST * max(morningW, bSwamp * BIOME_MOOD * 0.35);
		// soft and smooth: a gentle low veil that thins with height, slowly drifting in broad swells (no bands, no noise),
		// lit warm peach toward the rising sun and cool white away from it
		float hgt = exp(-max(wY - gRef, 0.0) / 6.0);
		vec3 wp = mat3(gbufferModelViewInverse) * vpos + cameraPosition;
		float swell = 0.80 + 0.20 * sin(wp.x * 0.045 + frameTimeCounter * 0.05) * sin(wp.z * 0.038 - frameTimeCounter * 0.04);
		float m = smoothstep(0.0, 1.0, smoothstep(4.0, 64.0, lin) * hgt) * swell * amt;
		vec3 Vm = safeNormalize(vpos, vec3(0, 0, -1));
		float toSun = clamp(dot(Vm, safeNormalize(sunPosition, vec3(0, 1, 0))) * 0.5 + 0.5, 0.0, 1.0);
		vec3 mc = mix(mix(fogSky, vec3(0.94, 0.96, 1.0), 0.35), vec3(1.0, 0.88, 0.80), toSun * toSun * morningW);
		col = mix(col, mc, clamp(m, 0.0, 0.55) * (water ? 0.4 : 1.0));
	}
#ifdef VALLEY_FOG
	// valley fog: a calm, low-lying layer below VALLEY_FOG_HEIGHT that pools in valleys and over rivers all day.
	// Analytic slab: only the part of the view ray below the layer top gathers fog, thicker deeper down,
	// so hills rise out of it and looking down into a valley reads layered. Soft bands, no noise.
	if (isEyeInWater == 0 && d0 < 1.0 && cave < 0.5) {
		float Ht = VALLEY_FOG_HEIGHT - 63.0 + gRef;
		float cY = cameraPosition.y;
		float lo = min(cY, wY), hi = max(cY, wY);
		float inside = clamp((Ht - lo) / max(hi - lo, 0.01), 0.0, 1.0); // share of the ray below the top
		if (hi - lo < 0.01) inside = step(lo, Ht);
		float seg = lin * inside;
		float depthB = clamp((Ht - 0.5 * (lo + min(hi, Ht))) / 10.0, 0.0, 1.0); // denser near the valley floor
		float vf = 1.0 - exp(-seg * 0.030 * (0.35 + depthB));
		// land lying low in the valleys sits inside the mist: a soft veil that grows with distance,
		// so valley floors between hills read misty from above and from inside the valley
		float lowK = smoothstep(Ht + 3.0, Ht - 7.0, wY);
		vf = max(vf, lowK * (1.0 - exp(-lin * 0.014)) * 0.85);
		vf *= smoothstep(6.0, 30.0, lin) * (1.0 - smoothstep(far * 0.85, far, lin) * 0.5);
		vf = smoothstep(0.0, 1.0, clamp(vf, 0.0, 1.0)); // smooth, no visible steps
		vec3 vc = mix(mix(fogSky, vec3(0.92, 0.96, 1.0), 0.8), vec3(0.16, 0.20, 0.36), 1.0 - dayFactor(sunPosition, upPosition));
		col = mix(col, vc, vf * VALLEY_FOG * (1.0 - rainStrength * 0.5) * (water ? 0.6 : 1.0));
	}
#endif
#ifdef OUTLINES
#if EDGE_STYLE > 0
	// no ink underwater (avoids dark rings around bubbles/particles)
	if (isEyeInWater == 0) {
		float e = outlineMask(uv, lin);
#ifdef OUTLINE_DEBUG
		col = mix(col, vec3(1.0, 0.0, 0.0), clamp(e, 0.0, 1.0));
#endif
		#if EDGE_STYLE == 2
		col = mix(col, vec3(OUTLINE_R, OUTLINE_G, OUTLINE_B), clamp(e, 0.0, 1.0) * OUTLINE_STRENGTH);
#else
		// soft coloured edge: a darker, cooler shade of the surface itself (no black ink)
#ifdef LIGHT_OUTLINES
		// very subtle thin light line (low opacity) instead of a dark edge
#ifdef DIM_NETHER
		col = mix(col, mix(col, vec3(1.0, 0.62, 0.80), 0.5), clamp(e, 0.0, 1.0) * LIGHT_OUTLINE_OPACITY * (1.0 - smoothstep(12.0, 48.0, lin))); // soft warm edges, near only (far lines were busy)
#else
		col = mix(col, mix(col, vec3(1.0, 0.99, 0.95), 0.6), clamp(e, 0.0, 1.0) * LIGHT_OUTLINE_OPACITY);
#endif
#else
		col = mix(col, col * vec3(0.66, 0.70, 0.84), clamp(e, 0.0, 1.0) * SOFT_EDGE_STRENGTH);
#endif
#endif
	}
#endif
#endif
	bool sky = d0 >= 1.0 && !isDH;
	float sunHg = dot(safeNormalize(sunPosition, safeNormalize(upPosition, vec3(0,1,0))), safeNormalize(upPosition, vec3(0,1,0)));
	float duskG = clamp(1.0 - abs(sunHg) * 4.0, 0.0, 1.0);
	float dayG = dayFactor(sunPosition, upPosition);
	#define MORN_K ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0)
#ifdef LIGHT_HALO
	// soft radial glow around lanterns, torches, lava and other light sources (blurred light-colour field)
	{
		// small, tight glow from fine mips only: the coarse 32-px mip made a big smeared blob that
		// jumped between mip texels while the camera moved
		vec4 h2 = textureLod(colortex3, uv, 2.0), h3 = textureLod(colortex3, uv, 3.0);
		vec3 halo = (h2.rgb * 0.5 + h3.rgb * 0.5) * 0.9;
		col += halo * LIGHT_HALO * mix(1.0, 0.35, dayG * (1.0 - cave));
		// small, dim sources (candles) light almost no block-light pool of their own: give them a wider soft halo instead
		vec3 h4 = textureLod(colortex3, uv, 4.0).rgb;
		col += h4 * 1.6 * CANDLE_GLOW * smoothstep(0.25, 0.5, (h4.r - h4.b) / max(max(h4.r, h4.g), 1e-4)) * // warm sources only (no amethyst / soul / sculk halo)
		        (1.0 - smoothstep(0.15, 0.45, texture(colortex2, uv).g)) * mix(1.0, 0.3, dayG * (1.0 - cave));
	}
#endif
#ifdef SUN_HALO
	{
		// glowing sun disk halo (bloom), strongest at golden hour and through forest gaps
		vec4 shp = gbufferProjection * vec4(sunPosition, 1.0);
		if (shp.w > 0.0 && isEyeInWater == 0) {
			vec2 suv = shp.xy / shp.w * 0.5 + 0.5;
			float dS = length((uv - suv) * vec2(viewWidth / viewHeight, 1.0));
			float vis = step(1.0, texture(depthtex0, clamp(suv, 0.001, 0.999)).r);
			float hal = exp(-dS * 7.0) * 0.55 + exp(-dS * 22.0) * 0.6;
			vec3 hc = mix(mix(vec3(1.0, 0.97, 0.82), vec3(1.0, 0.95, 0.92), MORN_K), mix(vec3(1.0, 0.66, 0.30), vec3(1.0, 0.80, 0.70), MORN_K), duskG);
			col += hc * celBandSoft(clamp(hal, 0.0, 1.0), 4, 0.4) * vis * dayG * SUN_HALO * (1.0 - rainStrength);
		}
	}
#endif
#ifdef MOON_HALO
	{
		// soft moon halo: a calm silver-blue glow and a faint wide ring around the moon on clear nights
		vec4 mhp = gbufferProjection * vec4(moonPosition, 1.0);
		float nK = (1.0 - smoothstep(0.05, 0.3, dayG)) * (1.0 - rainStrength);
		nK *= smoothstep(0.02, -0.12, dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0)))); // only once the sun is down: no pale halo disc in the dawn / dusk sky
		if (mhp.w > 0.0 && isEyeInWater == 0 && nK > 0.01) {
			vec2 muv = mhp.xy / mhp.w * 0.5 + 0.5;
			float dM = length((uv - muv) * vec2(viewWidth / viewHeight, 1.0));
			float visM = step(1.0, texture(depthtex0, clamp(muv, 0.001, 0.999)).r);
			float glowM = exp(-dM * 9.0) * 0.32 + exp(-dM * 3.5) * 0.10;
			float ring = exp(-pow((dM - 0.16) / 0.035, 2.0)) * 0.06;
			col += vec3(0.72, 0.82, 1.0) * (glowM + ring) * visM * nK * MOON_HALO;
		}
	}
#endif
	// hot dry biomes (deserts, badlands, savanna plateaus): no rain there, dust instead
	float dryB = smoothstep(1.3, 1.8, bTemp) * (1.0 - smoothstep(0.05, 0.3, bRain));
#ifdef RAIN_STREAKS
	if (rainStrength * (1.0 - dryB) > 0.01 && isEyeInWater == 0) {
		// rain mood: calm, darker blue night rain (no streaks drawn over the screen)
		col = mix(col, col * vec3(0.62, 0.72, 0.98), rainStrength * (1.0 - dryB) * (1.0 - dayG) * 0.6 * RAIN_STREAKS);
	}
#endif
#if !defined DIM_NETHER && !defined DIM_END
	// overcast: the sun stays a soft pale glow behind the rain clouds (no disc, no rays)
	if (rainStrength > 0.01 && isEyeInWater == 0) {
		float toS = max(dot(vdir, safeNormalize(sunPosition, vec3(0, 0, 1))), 0.0);
		float og = celBandSoft(pow(toS, 5.0), 4, 0.5) * 0.55 + pow(toS, 40.0) * 0.45;
		col += vec3(0.86, 0.89, 0.93) * og * 0.22 * rainStrength * (1.0 - dryB) * dayG * (sky ? 1.0 : 0.35);
	}
	// gentle lightning flash: a calm cool lift of the whole scene while a bolt exists (no harsh white-out)
	// lFlash: smoothed bolt presence (fast rise, ~1 s fade out), so several bolts never flicker
	if (lFlash > 0.002) {
		float fl = (0.16 * (1.0 - smoothstep(60.0, 240.0, length(lightningBoltPosition.xyz))) + 0.06) * lFlash;
		col = mix(col, col * 1.25 + vec3(0.30, 0.34, 0.46) * (sky ? 1.0 : 0.6), fl);
	}
#endif
	// cloud pixels (flag a = 0.25 in colortex2): kept out of bloom, sun glare and the colour grades so they never blow out
	float cloudM = 1.0 - step(0.06, abs(texture(colortex2, uv).a - 0.25));
#ifdef BLOOM
	// soft wide glow: bright areas from three blurred mip levels (smooth, colour-preserving, no ring specks)
	{
		vec3 glow = vec3(0.0);
		vec2 px = 1.0 / vec2(viewWidth, viewHeight);
		for (int l = 0; l < 4; l++) {
			float lod = 3.0 + float(l);
			vec2 o = px * exp2(lod) * 0.75;
			vec3 lg = vec3(0.0);
			for (int i = 0; i < 4; i++) {
				vec2 d = vec2((i & 1) == 0 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0);
				vec3 s = textureLod(colortex0, uv + d * o, lod).rgb;
				float gr = clamp((s.g - max(s.r, s.b)) * 3.0, 0.0, 1.0); // sunlit grass barely glows
				lg += s * smoothstep(0.56, 0.95, luma(s)) * (1.0 - 0.5 * gr);
			}
			glow += lg * 0.25 * (l == 0 ? 0.30 : (l == 1 ? 0.35 : (l == 2 ? 0.35 : 0.45))); // widest level: soft sun glow
		}
		col += glow * 0.70 * (BLOOM_STRENGTH * STYLE_K) * mix(0.5, 1.6, max(duskG, 0.0)) * (1.0 - cloudM);
	}
#endif
#ifdef GODRAYS
	// screen-space light shafts: march towards the sun (or moon) and gather open sky
	{
		bool useSun = sunHg > -0.05;
		vec3 lp = useSun ? sunPosition : moonPosition;
		vec4 sc = gbufferProjection * vec4(lp, 1.0);
		if (sc.w > 0.0 && isEyeInWater == 0) {
			vec2 suv = sc.xy / sc.w * 0.5 + 0.5;
			vec2 dlt = (suv - uv) / 20.0;
			float acc = 0.0;
			vec2 p = uv;
			for (int i = 0; i < 20; i++) {
				p += dlt;
				if (any(lessThan(p, vec2(0.0))) || any(greaterThan(p, vec2(1.0)))) break;
				acc += step(1.0, texture(depthtex0, p).r);
			}
			acc /= 20.0;
			float fall = 1.0 - smoothstep(0.0, mix(0.85, 0.5, duskG), length((suv - uv) * vec2(viewWidth / viewHeight, 1.0)));
			vec3 rc = useSun ? mix(mix(vec3(1.0, 0.96, 0.70), vec3(1.0, 0.92, 0.86), MORN_K), mix(vec3(1.0, 0.62, 0.22), vec3(1.0, 0.78, 0.68), MORN_K), duskG) : vec3(0.45, 0.55, 1.0);
			float str = GODRAYS_STRENGTH * (1.0 + FOREST_RAYS * bDark + FOREST_RAYS * 0.5 * smoothstep(0.9, 0.6, float(eyeBrightnessSmooth.y) / 240.0)) * (useSun ? mix(0.55, 1.0, duskG) * (1.0 + 0.4 * morningW * MORNING_MIST) : 0.35);
			// soft bands (no hard wedges), and less on clouds/terrain at dusk so near clouds do not turn into pale fans
			col += rc * celBandSoft(acc * fall, 4, 0.5) * str * (sky ? 0.35 : mix(0.55, 0.25, duskG));
			// sun glare: a bright soft glow and a few still radial streaks around a visible sun
			if (useSun && sunHg > 0.0) {
				vec2 gd = (uv - suv) * vec2(viewWidth / viewHeight, 1.0);
				float gr = length(gd), ga = atan(gd.y, gd.x);
				float streak = pow(abs(cos(ga * 3.0 + 0.35)), 28.0) + 0.6 * pow(abs(cos(ga * 5.0 + 1.2)), 48.0);
				float vis = step(1.0, texture(depthtex0, clamp(suv, 0.0, 1.0)).r) * (1.0 - rainStrength);
				float glare = exp(-gr * 7.0) * 0.55 + streak * exp(-gr * 3.2) * 0.30;
				col += mix(rc, vec3(1.0), 0.5) * glare * vis * SUN_GLARE * (1.0 - 0.5 * duskG) * (1.0 - cloudM);
			}
#ifdef CANOPY_RAYS
			// sun beams through trees: when the sun sits behind a broken canopy, long soft beams fan out
			// from the gaps. Strongest when about half of the sky around the sun is blocked by leaves.
			if (useSun) {
				float o = 0.0;
				for (int j = 0; j < 8; j++) {
					float a = float(j) * 0.7854;
					o += step(1.0, texture(depthtex0, clamp(suv + vec2(cos(a), sin(a) * viewWidth / viewHeight) * 0.035, 0.0, 1.0)).r);
				}
				o /= 8.0;
				float broken = clamp(4.0 * o * (1.0 - o), 0.0, 1.0) * (1.0 - o * 0.5) + 0.25 * (1.0 - step(0.99, o)) * (1.0 - step(o, 0.01));
				vec2 dl2 = (suv - uv) / 32.0;
				float ac2 = 0.0; vec2 p2 = uv;
				for (int i = 0; i < 32; i++) {
					p2 += dl2;
					if (any(lessThan(p2, vec2(0.0))) || any(greaterThan(p2, vec2(1.0)))) break;
					ac2 += step(1.0, texture(depthtex0, p2).r) * (0.6 + 0.4 * float(i) / 32.0);
				}
				ac2 /= 32.0;
				float fall2 = 1.0 - smoothstep(0.05, 1.1, length((suv - uv) * vec2(viewWidth / viewHeight, 1.0)));
				float lowSun = 1.0 - smoothstep(0.35, 0.8, sunHg);
				float beam = smoothstep(0.06, 0.45, ac2) * fall2 * fall2;
				{
					// shafts: calm radial streaks fanning from the sun, slowly swaying with the breeze
					vec2 dv = (uv - suv) * vec2(viewWidth / viewHeight, 1.0);
					float ang = atan(dv.y, dv.x);
					float sway = 0.18 * sin(frameTimeCounter * 0.25 * WIND_SPEED) + 0.10 * sin(frameTimeCounter * 0.11 + 1.7);
					float st = 0.5 + 0.5 * sin(ang * 9.0 + sway) * (0.6 + 0.4 * sin(ang * 4.0 - sway * 1.3 + 0.8));
					beam *= mix(0.55, 1.25, smoothstep(0.15, 0.85, st));
				}
				vec3 bc = mix(vec3(1.0, 0.95, 0.78), vec3(1.0, 0.76, 0.48), duskG);
				col += bc * beam * broken * mix(0.45, 1.0, lowSun) * CANOPY_RAYS * 0.32 * (1.0 - rainStrength) * (sky ? 0.4 : 1.0);
			}
#endif
		}
	}
#endif
#ifdef LIGHT_SHAFTS
	// light shafts indoors / under canopies: march the view ray through the shadow map
	{
		float interior = smoothstep(0.99, 0.70, float(eyeBrightnessSmooth.y) / 240.0) * (1.0 - cave * 0.35); // cave openings keep most of their beam
#ifdef VOLUMETRIC_OUTDOOR
		// forests and misty mornings: shafts outdoors too (only show where the canopy breaks the light)
		interior = max(interior, VOLUMETRIC_OUTDOOR * clamp(0.35 + bDark + morningW * MORNING_MIST + rainStrength * 0.3, 0.0, 1.0));
#endif
		if (isEyeInWater == 0 && interior * dayG > 0.01) {
			vec3 endP = mat3(gbufferModelViewInverse) * vpos;
			float L = min(length(endP), 32.0);
			vec3 dP = endP / max(length(endP), 1e-4);
			float acc = 0.0;
			// 48 steps: the beam edge reads as one smooth shaft instead of stacked slices
			for (int i = 0; i < 48; i++) {
				vec3 pp = dP * L * (float(i) + 0.5) / 48.0;
				vec4 sc = shadowProjection * (shadowModelView * vec4(pp, 1.0));
				vec3 sp = celDistort(sc.xyz / max(sc.w, 1e-4)) * 0.5 + 0.5;
				if (all(greaterThan(sp, vec3(0.0))) && all(lessThan(sp, vec3(1.0))))
					acc += clamp((texture(shadowtex0, sp.xy).r - sp.z) / 0.0016 + 0.5, 0.0, 1.0);
			}
			acc /= 48.0;
			vec3 sunV = safeNormalize(sunPosition, vec3(0, 1, 0));
			float mie = 0.45 + 0.55 * pow(max(dot(vdir, sunV), 0.0), 3.0);
			vec3 shC = mix(mix(vec3(1.0, 0.93, 0.74), vec3(1.0, 0.92, 0.88), MORN_K), mix(vec3(1.0, 0.64, 0.30), vec3(1.0, 0.80, 0.72), MORN_K), duskG);
			float openK = smoothstep(0.99, 0.70, float(eyeBrightnessSmooth.y) / 240.0); // indoors: full; outdoors: only broken light
			float brokenK = mix(clamp(4.0 * acc * (1.0 - acc), 0.0, 1.0), 1.0, openK);
			shC *= mix(vec3(1.0), vec3(1.06, 1.0, 0.84), openK); // rooms and caves: a soft warm sunbeam instead of a grey one
			col += shC * celBandSoft(smoothstep(0.0, 0.16, acc * sqrt(L / 32.0)), 4, 0.5) * mie * interior * dayG * LIGHT_SHAFTS_STRENGTH * 0.35 * brokenK;
		}
	}
#endif
	if (IS_OW && !sky && isEyeInWater == 0) {
		vec2 px2 = 6.0 / vec2(viewWidth, viewHeight);
		float open = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			open += step(1.0, texture(depthtex0, uv + vec2(cos(a), sin(a)) * px2).r);
		}
		open /= 8.0;
		bool fol = texture(colortex1, uv).a < 0.75;
		vec3 glowC = mix(mix(vec3(0.85, 1.0, 0.45), vec3(1.0, 0.90, 0.86), MORN_K), mix(vec3(1.0, 0.70, 0.30), vec3(1.0, 0.82, 0.74), MORN_K), duskG) * dayG + vec3(0.10, 0.14, 0.30) * (1.0 - dayG);
		col += glowC * open * (fol ? CANOPY_GLOW : CANOPY_GLOW * 0.4);
	}
	// rolling field waves: broad soft light bands drift slowly across open green ground in the wind
	if (IS_OW && !sky && !water && isEyeInWater == 0 && FIELD_WAVES > 0.0) {
		vec3 wpF = mat3(gbufferModelViewInverse) * vpos + cameraPosition;
		float greenK = smoothstep(0.12, 0.32, (col.g - max(col.r, col.b)) / max(col.g, 0.02)); // relative: works on dark night grass too
		float folK = texture(colortex1, uv).a < 0.75 ? 0.45 : 1.0; // canopies sway much less than meadows
		float fwK = greenK * folK * (1.0 - smoothstep(far * 0.35, far * 0.6, lin)) * (1.0 - cave) * mix(0.55, 1.0, dayG); // moonlit waves stay readable at night
		// the bands ride the shared gust field: same fronts that bend the grass and carry the wind lines.
		// crest = blades bent over showing their pale silvery side; a soft trough shade behind keeps it readable
		float gF = windGust(wpF.xz, frameTimeCounter);
		float fw = smoothstep(0.48, 0.78, gF); // narrower crest, soft edges
		// low sun: the bent blades catch the warm light, crests turn soft gold instead of cool silver
		float goldW = smoothstep(-0.06, 0.02, sunHg) * (1.0 - smoothstep(0.10, 0.35, sunHg));
		vec3 sheen = mix(vec3(luma(col)), col, 0.70) * mix(vec3(1.10, 1.14, 1.00), vec3(1.20, 1.08, 0.84), goldW) + mix(vec3(0.035, 0.045, 0.025), vec3(0.055, 0.035, 0.0), goldW);
		sheen += (1.0 - dayG) * (sheen * 0.35 + vec3(0.010, 0.016, 0.030)); // night: moonlit crest, a soft cool silver lift that survives the night grade
		col *= 1.0 - 0.10 * FIELD_WAVES * fwK * (1.0 - fw) * (1.0 - rainStrength * 0.5);
		col = mix(col, sheen, 0.70 * FIELD_WAVES * fwK * fw * (1.0 - rainStrength * 0.5));
	}
	// warm atmospheric haze with distance (sunset orange, daytime soft yellow-green in forests)
	if (IS_OW && !sky && isEyeInWater == 0) {
		float hz = smoothstep(3.0, wEnd * 0.6, lin);
		vec3 hzc = mix(mix(mix(vec3(0.85, 0.95, 0.55), vec3(0.98, 0.90, 0.88), MORN_K), fogSky * 1.08, FOG_SKY_MATCH * 0.6), mix(vec3(1.0, 0.62, 0.22), vec3(1.0, 0.78, 0.68), MORN_K), duskG);
		col = mix(col, hzc, hz * (HAZE + bHaze * BIOME_MOOD * BIOME_FOG * 0.5) * STYLE_K * dayG * (water ? 0.25 : 1.0) * (1.0 - 0.5 * duskG));
	}
#ifdef DISTANCE_BLUE
	// aerial perspective: far terrain (mountains) turns soft blue toward the sky colour
	if (!sky && isEyeInWater == 0 && !water) {
		float hb = smoothstep(wEnd * 0.10, wEnd * 0.85, lin);
		hb = hb * hb * (3.0 - 2.0 * hb);
#if MOUNTAIN_LAYERS > 0
		// layered ridges: the fade advances in a few soft distance steps, so each ridge line sits on its own
		// calm flat haze plane and far mountains read as stacked painted silhouettes
		hb = mix(hb, celBandSoft(hb, 4, 0.45), 0.25 * float(MOUNTAIN_LAYERS) * smoothstep(0.02, 0.15, hb));
#endif
		vec3 blueC = mix(fogSky, vec3(0.64, 0.86, 0.98), 0.65) * mix(0.55, 1.0, dayG);
		// far land first loses its detail (contrast pulled toward a calm mid tone), then turns light blue
		float apK = DISTANCE_BLUE * (1.0 - 0.6 * duskG);
		vec3 flatC = mix(vec3(luma(col)), col, 0.7) * 0.45 + blueC * 0.55;
		col = mix(col, flatC, smoothstep(0.0, 0.6, hb) * min(apK * 1.4, 0.8));
		col = mix(col, blueC, hb * min(apK * 1.15, 0.85));
		// forests: blue depth haze already between nearby trunks
		float forestK = clamp(bDark + smoothstep(0.7, 0.95, bRain) * 0.6 + 0.2, 0.0, 1.0);
		col = mix(col, blueC * vec3(0.85, 0.95, 1.05), celBandSoft(smoothstep(10.0, 70.0, lin), 4, 0.45) * FOREST_HAZE * forestK * dayG * (1.0 - hb));
	}
#endif
	// render-distance border: the last stretch before the loaded world ends melts smoothly into the
	// horizon sky colour (no banding), so the edge of the world never shows as a hard line or step
	if (!sky && isEyeInWater == 0 && (d0 < 1.0 || isDH)) {
		float edgeF = smoothstep(wEnd * 0.86, wEnd * 1.0, lin); // only the very last stretch: far land stays clear
		col = mix(col, fogSky, edgeF * edgeF * (3.0 - 2.0 * edgeF) * (1.0 - cave));
	}
#ifdef WEATHER_FX
#if RAIN_SHAFTS > 0
	// rain by day: a few broad, soft pale beams fall through gaps in the overcast, drifting very slowly
	if (isEyeInWater == 0) {
		float rsK = rainStrength * (1.0 - smoothstep(1.3, 1.8, bTemp)) * dayFactor(sunPosition, upPosition) * (1.0 - cave);
		if (rsK > 0.001) {
			vec3 rv = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
			float az = atan(rv.z, rv.x);
			float bm = smoothstep(0.55, 0.85, vnoise(vec2(az * 4.0 + frameTimeCounter * 0.004, 7.3)));
			float vert = smoothstep(-0.12, 0.10, rv.y) * (1.0 - smoothstep(0.35, 0.85, rv.y));
			float reach = sky ? 1.0 : smoothstep(20.0, far * 0.6, lin);
			col += vec3(0.50, 0.62, 0.80) * bm * vert * reach * rsK * 0.17 * float(RAIN_SHAFTS);
		}
	}
#endif
	// weather: rain fog, desert sandstorm, snow haze (all banded and distance based)
	if (!sky && isEyeInWater == 0) {
		float hotDry = smoothstep(1.3, 1.8, bTemp) * (1.0 - smoothstep(0.05, 0.3, bRain));
		float coldW = 1.0 - smoothstep(0.05, 0.3, bTemp);
		float wet = rainStrength * (1.0 - hotDry);
		float rf = celBandSoft(smoothstep(2.0, far * 0.45, lin), 4, 0.4);
		vec3 rainC = mix(vec3(0.13, 0.17, 0.31), vec3(0.36, 0.48, 0.66), dayG); // calm deep blue rain air
		rainC = mix(rainC, vec3(0.86, 0.90, 0.96) * mix(0.45, 1.0, dayG), coldW); // snow: white haze
		col = mix(col, rainC, rf * wet * RAIN_FOG * 0.75 * mix(0.55, 1.0, dayG)); // night: lighter veil so the land stays readable
		// sandstorm: warm dust wall with drifting streaks, only in hot dry biomes while the weather is bad
		float sand = hotDry * rainStrength * SANDSTORM;
		if (sand > 0.001) {
			vec3 wpS = mat3(gbufferModelViewInverse) * vpos + cameraPosition;
			vec2 sq = wpS.xz * 0.08 + wpS.y * 0.05 - windDir() * frameTimeCounter * 2.0;
			float streak = vnoise(sq * vec2(1.0, 4.0)) * 0.6 + vnoise(sq * 3.0) * 0.4;
			// thinner far wall (terrain shapes stay readable), broken by rolling gust clouds
			float gust = vnoise(wpS.xz * 0.03 - windDir() * frameTimeCounter * 0.6) * 0.6 + vnoise(wpS.xz * 0.09 + 3.1) * 0.4;
			float sf = smoothstep(0.0, 1.0, smoothstep(2.0, 60.0, lin)) * (0.75 + 0.12 * streak + 0.13 * gust); // dense calm dust wall
			vec3 dustC = vec3(0.86, 0.66, 0.42) * mix(0.4, 1.0, dayG); // ochre dust
			col = mix(col, dustC * mix(0.92, 1.04, gust), clamp(sf * sand, 0.0, 0.90));
			// fast wind-blown dust streaks over the whole view (sky included): long thin bands along the wind
			vec3 vw = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
			vec2 wd = windDir();
			float along = dot(vw.xz, wd), across = dot(vw.xz, vec2(-wd.y, wd.x));
			vec2 dq = vec2(along * 6.0 - frameTimeCounter * 3.5, across * 40.0 + vw.y * 55.0);
			float ds = smoothstep(0.62, 0.80, vnoise(dq) * 0.7 + vnoise(dq * vec2(2.0, 1.3) + 5.0) * 0.3);
			float dk = smoothstep(0.55, 0.75, vnoise(dq * vec2(0.5, 0.35) + 9.0)); // darker drifting sheets
			col = mix(col, dustC * 1.10 + 0.03, ds * sand * 0.14); // faint, calm streaks
			col = mix(col, dustC * 0.70, dk * sand * 0.10 * smoothstep(1.0, 12.0, lin));
		}
	}
#endif
#ifdef WEATHER_FX
	// sandstorm sky: the whole sky turns dusty orange, denser toward the horizon
	if (sky && isEyeInWater == 0 && dryB * rainStrength * SANDSTORM > 0.001) {
		vec3 vS = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
		float hz = 1.0 - smoothstep(-0.05, 0.6, vS.y);
		vec3 dustSky = mix(vec3(0.78, 0.52, 0.30), vec3(0.95, 0.72, 0.46), hz) * mix(0.35, 1.0, dayG);
		col = mix(col, dustSky, clamp(dryB * rainStrength * SANDSTORM, 0.0, 1.0) * mix(0.70, 0.95, hz));
	}
#endif
#if defined CLOUD_LAYERS && !defined DIM_NETHER && !defined DIM_END
	// extra cubic cloud layers: high (thin, slow, behind the vanilla layer) and low (big, faster, in front)
	if (isEyeInWater == 0) {
		vec3 rd = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
		float sceneD = sky ? 1e9 : length(vpos);
		float Hc = cloudHeight > 1.0 ? cloudHeight : 192.0;
		float tC = frameTimeCounter * 0.6;
		vec3 sunW = safeNormalize(mat3(gbufferModelViewInverse) * sunPosition, vec3(0, 1, 0));
		float cDay = clamp(sunW.y * 4.0 + 0.4, 0.0, 1.0), cDusk = clamp(1.0 - abs(sunW.y) * 5.0, 0.0, 1.0);
		vec3 cLit = mix(vec3(0.20, 0.22, 0.46), vec3(1.0, 1.0, 0.98), cDay);
		vec3 cShade = mix(vec3(0.13, 0.14, 0.32), vec3(0.84, 0.88, 0.96), cDay); // soft pale undersides by day
		float cMorn = ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0);
		cLit = mix(cLit, mix(vec3(1.0, 0.80, 0.55), vec3(1.0, 0.84, 0.80), cMorn), cDusk * 0.75); // sunrise: peach-rose, not gold
		cShade = mix(cShade, mix(vec3(0.92, 0.56, 0.46), vec3(0.86, 0.60, 0.64), cMorn), cDusk * 0.7); // warm coral undersides, never pale grey-mauve
		float hotC = sbHot * cDusk * (1.0 - cMorn); // hot dry lands: soft peach evening clouds
		cLit = mix(cLit, vec3(1.0, 0.90, 0.82), clamp(hotC * 1.6, 0.0, 1.0));
		cShade = mix(cShade, vec3(0.95, 0.80, 0.76), clamp(hotC * 1.6, 0.0, 1.0));
		cLit = mix(cLit, vec3(luma(cLit)) * 0.75, rainStrength * 0.6);
		cShade = mix(cShade, vec3(luma(cShade)) * 0.75, rainStrength * 0.6);
		float toSun = max(dot(rd, sunW), 0.0);
		vec3 rimC = mix(vec3(1.0, 0.72, 0.42), vec3(1.0, 0.74, 0.66), cMorn) * cDusk * (1.0 - rainStrength);
		float pxA = 2.0 / (gbufferProjection[1][1] * viewHeight); // angle of one pixel
#ifdef CLOUD_HIGH
		if (sky) {
			float h = Hc + CL_HIGH_OFF - cameraPosition.y;
			if (rd.y * h > 0.0) {
				float th = h / rd.y;
				vec2 q = clHighQ(cameraPosition.xz + rd.xz * th, tC);
				float e = clamp(th * pxA / max(abs(rd.y), 0.03) / CL_HIGH_CELL * 0.75, 0.03, 0.5);
				float cov = clCover(q, e, 1);
				float fade = (1.0 - smoothstep(900.0, 2400.0, th)) * smoothstep(0.02, 0.15, abs(rd.y));
				vec3 hc = mix(cLit, vec3(1.0), 0.25 * cDay);
				hc = mix(hc, fogSky, 0.35 + 0.4 * smoothstep(400.0, 2000.0, th)); // pale and airy
				float soft = clCover(q, 0.18, 1);
				hc += rimC * soft * (1.0 - soft) * 2.5 * pow(toSun, 3.0) * 0.6;
				col = mix(col, hc, cov * fade * 0.42);
			}
		}
#endif
#ifdef CLOUD_LOW
		{
			float h0 = Hc + CL_LOW_OFF - cameraPosition.y, h1 = h0 + CL_LOW_THICK;
			float tA = -1.0, tB = -1.0; bool fromBelow = true;
			if (h0 > 0.0 && rd.y > 0.0) { tA = h0 / rd.y; tB = h1 / rd.y; }
			else if (h1 < 0.0 && rd.y < 0.0) { tA = h1 / rd.y; tB = h0 / rd.y; fromBelow = false; }
			else if (h0 <= 0.0 && h1 >= 0.0) { tA = 0.0; tB = (rd.y > 0.0 ? h1 : h0) / (abs(rd.y) > 1e-3 ? rd.y : 1e-3); if (tB < 0.0) tB = 600.0; }
			if (tA >= 0.0 && tA < min(sceneD, 2200.0)) {
				tB = min(min(tB, tA + 160.0), sceneD);
				float e = clamp(tA * pxA / max(abs(rd.y), 0.03) / CL_LOW_CELL * 0.75, 0.03, 0.5);
				vec2 qA = clLowQ(cameraPosition.xz + rd.xz * tA, tC);
				vec2 qM = clLowQ(cameraPosition.xz + rd.xz * mix(tA, tB, 0.5), tC);
				vec2 qB = clLowQ(cameraPosition.xz + rd.xz * tB, tC);
				float cA = clCover(qA, e, 0), cM = clCover(qM, e, 0), cB = clCover(qB, e, 0);
				float side = max(cM, cB) * (1.0 - cA);
				float cov = clamp(cA + side, 0.0, 1.0);
				if (cov > 0.002) {
					// softer-lit than the vanilla layer: lower face contrast
					vec3 faceC = fromBelow ? mix(cShade, cLit, 0.72) : mix(cShade, cLit, 0.95); // soft, bright undersides
					vec3 sideC = mix(cShade, cLit, 0.62 + 0.2 * toSun);
					vec3 lc = mix(sideC, faceC, cA / max(cov, 1e-3));
					float fz = smoothstep(150.0, 600.0, tA);
					lc = mix(lc, mix(cShade, cLit, 0.62), fz * 0.6);
					lc = mix(lc, fogSky, smoothstep(300.0, 1800.0, tA) * 0.55);
					float soft = clCover(qA, 0.2, 0);
					lc += rimC * soft * (1.0 - soft) * 2.5 * pow(toSun, 3.0) * 0.7;
					// calm horizon: far cells melt into the sky colour and thin out low over the horizon (no busy confetti)
					lc = mix(lc, fogSky, smoothstep(250.0, 1100.0, tA) * 0.35);
					// dusk: low cells take the warm sky tone behind them (no pale grey-lavender patches near the sun)
					lc = mix(lc, max(col, vec3(0.0)) * vec3(1.06, 0.97, 0.93), cDusk * (1.0 - rainStrength) * 0.8);
					lc = min(lc, vec3(max(luma(col) * 1.25, 0.6)));
					// away from the sun the dusk sky goes olive behind the cells: keep them a soft dusty rose
					lc = mix(lc, vec3(luma(lc)) * vec3(1.12, 0.88, 0.88), cDusk * (1.0 - rainStrength) * (1.0 - toSun) * 0.55);
					float fade = (1.0 - smoothstep(500.0, 1500.0, tA)) * smoothstep(0.02, 0.16, abs(rd.y));
					col = mix(col, lc, cov * fade * 0.80);
				}
			}
		}
#endif
	}
#endif
	// dusk: distant land calms into the evening air (less red/green texel contrast on far cliffs)
	if (!sky && !water && isEyeInWater == 0) {
		float dfK = mix(0.35, 1.0, smoothstep(40.0, 150.0, lin)) * smoothstep(6.0, 16.0, lin) * duskG * (1.0 - rainStrength);
		vec3 calmC = mix(vec3(luma(col)), col, 0.55) * mix(vec3(1.0), fogSky / max(luma(fogSky), 1e-3), 0.25);
		col = mix(col, calmC, dfK * 0.5);
	}
	// early morning: fresh, slightly cool blue air over the land for the first hours after sunrise (brightness kept)
	if (IS_OW && !sky && isEyeInWater == 0 && cave < 0.5) {
		float mbK = MORNING_BLUE * MORN_K * smoothstep(0.0, 0.08, sunHg) * (1.0 - smoothstep(0.30, 0.55, sunHg)) * (1.0 - rainStrength);
		vec3 coolC = col * vec3(0.84, 0.97, 1.20);
		coolC *= luma(col) / max(luma(coolC), 1e-4);
		col = mix(col, coolC, mbK * mix(0.6, 1.0, smoothstep(8.0, 64.0, lin)));
	}
	// cool air: the whole scene leans into a clear blue-cyan light (brightness kept), and the darker tones
	// sink into a deep blue-teal instead of grey, so shade reads as cool air rather than dirt
	vec3 preCA = col;
	if (IS_OW && isEyeInWater == 0) {
		float caK = COOL_AIR * mix(0.75, 1.0, dayG) * (1.0 - 0.6 * duskG);
		vec3 cc = col * vec3(0.84, 0.99, 1.17);
		cc *= luma(col) / max(luma(cc), 1e-4);
		col = mix(col, cc, caK * (sky ? 0.45 : 1.0));
		float shK = 1.0 - smoothstep(0.12, 0.45, luma(col));
		col = mix(col, col * vec3(0.74, 0.94, 1.16), caK * 0.7 * shK * (sky ? 0.0 : 1.0));
		// rain and night: the world sinks into a deep, calm navy blue (almost one hue, light kept)
		// rain weighs heavier than night: a rainy day turns clearly deep blue, not grey
		// hot dry lands (desert, badlands, savanna, sandstorms) keep their ochre dust: no navy rain there (smooth biome fade)
		float hotNv = max(smoothstep(1.3, 1.8, bTemp) * (1.0 - smoothstep(0.05, 0.3, bRain)), max(sbHot, sbMesa));
		float nvR = rainStrength * NAVY_RAIN * (1.0 - hotNv), nvN = 1.0 - dayG;
		float nvK = NAVY_MOOD * clamp(max(nvR, nvN), 0.0, 1.0) * (1.0 - cave * 0.7);
		nvK *= 1.0 - 0.85 * smoothstep(0.06, 0.28, col.r - col.b) * smoothstep(0.08, 0.3, luma(col)); // torch and fire light stay warm orange in the navy
		vec3 navyC = vec3(luma(col)) * mix(vec3(0.62, 0.80, 1.38), vec3(0.46, 0.70, 1.42), clamp(nvR - nvN * 0.5, 0.0, 1.0));
		col = mix(col, navyC, nvK * mix(0.82, 0.88, clamp(nvR, 0.0, 1.0))); // night: almost one navy hue, like rain
		// snowy nights and snowfall: gently lift the darkest tones so snowy land stays readable (navy hue kept)
		float snowL = max(1.0 - smoothstep(0.05, 0.3, bTemp), sbCold) * max(nvN, rainStrength) * (1.0 - cave) * SNOW_NIGHT_LIFT;
		vec3 liftC = pow(max(col, 0.0), vec3(0.62)) * vec3(0.92, 0.97, 1.08) + vec3(0.025, 0.035, 0.06);
		col = mix(col, liftC, snowL * 0.8 * (1.0 - smoothstep(0.2, 0.6, luma(col))));
		col = mix(col, preCA, cloudM); // clouds keep their own authored colour
	}
	// pale gardens: a quiet, muted grey-green mood on the land (less colour, slightly dimmer)
	if (IS_OW && !sky && isEyeInWater == 0) {
		vec3 paleC = mix(vec3(luma(col)), col, 0.35) * vec3(0.94, 0.99, 0.96) * 0.90;
		col = mix(col, paleC, bPale * PALE_GARDEN_MOOD * 0.5);
	}
	// near-white haze band where the sea meets the sky (water far field + sky just above horizon)
	if (isEyeInWater == 0) {
		vec3 upH = safeNormalize(upPosition, vec3(0, 1, 0));
		float hh = dot(vdir, upH);
		// sky side: a wider, softer fade (no pale stripe); far land gets the same haze so the band
		// continues across the world edge instead of sitting as a flat strip above the terrain
		float skyW = 1.0 - smoothstep(0.0, 0.13, abs(hh)); skyW *= skyW;
		float hzW = sky ? skyW * 0.42 : (water ? pow(smoothstep(24.0, wEnd * 0.8, lin), 1.5) * 0.65 : pow(smoothstep(wEnd * 0.45, wEnd * 0.95, lin), 1.5) * 0.42);
		vec3 hzC = mix(fogSky, vec3(0.97, 0.99, 1.0), 0.6);
		col = mix(col, hzC, hzW * HORIZON_HAZE * mix(0.25, 1.0, dayG) * (1.0 - rainStrength * 0.5));
	}
	// the sky is authored in its final palette: no grading / scene cast on sky pixels
	if (!sky) {
		vec3 pre = col;
		col = grade(col) * bTint;
		// clouds: the grade leaves them alone, so they keep their own colour (no blow-out to white)
		col = mix(col, pre, cloudM);
		// particles (splash mist, smoke, clouds of dust): pale ones stay neutral white, never sand-beige
		float pf = texture(colortex2, uv).a;
		if (pf > 0.4 && pf < 0.8) {
			float pale = 1.0 - smoothstep(0.08, 0.25, max(pre.r, max(pre.g, pre.b)) - min(pre.r, min(pre.g, pre.b)));
			col = mix(col, vec3(luma(col)) * vec3(0.97, 1.0, 1.03), pale);
		}
	}
#ifdef FIREFLIES
#if !defined DIM_NETHER && !defined DIM_END
	// fireflies: warm green lights drifting and blinking near the player at night (world-space cells)
	{
		float nightF = (1.0 - smoothstep(0.15, 0.45, dayG)) * (1.0 - rainStrength)
		             * smoothstep(0.45, 0.75, float(eyeBrightnessSmooth.y) / 240.0)
		             * smoothstep(0.25, 0.45, bTemp) * (1.0 - smoothstep(1.25, 1.6, bTemp));
		if (nightF > 0.01 && isEyeInWater == 0) {
			vec3 rd = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
			float maxD = min(sky ? 28.0 : lin, 28.0);
			vec3 cp = mod(cameraPosition, 1024.0);
			float glow = 0.0, halo = 0.0;
			for (int i = 0; i < 19; i++) {
				float s0 = 0.75 + float(i) * 1.5;
				if (s0 > maxD + 1.5) break;
				vec3 cell = floor((cp + rd * s0) / 3.0);
				float h = hash12(cell.xz + cell.y * 17.31);
				if (h > 0.26 * FIREFLY_AMOUNT) continue; // sparse: a few calm lights, not a field of specks
				vec3 fp = (cell + vec3(hash12(cell.xz + 3.7), hash12(cell.xz + cell.y + 8.1), hash12(cell.zx + 1.3))) * 3.0;
				fp += vec3(sin(frameTimeCounter * 0.31 + h * 40.0), sin(frameTimeCounter * 0.23 + h * 70.0) * 0.6, cos(frameTimeCounter * 0.27 + h * 55.0)) * 0.7;
				vec3 rel = fp - cp;
				if (rel.y > 3.5 || rel.y < -2.5) continue; // keep them low, over the grass, not up in the sky
				float tc = dot(rel, rd);
				if (tc < 0.3 || tc > maxD) continue;
				float d = length(rel - rd * tc);
				float r = 0.035 + 0.0035 * tc;
				float blink = smoothstep(0.35, 0.9, sin(frameTimeCounter * (0.5 + h * 0.8) + h * 30.0) * 0.5 + 0.5); // slow, gentle pulse
				glow = max(glow, step(d, r) * blink);
				halo = max(halo, exp(-d / (r * 2.2)) * blink);
			}
			vec3 ffC = vec3(0.86, 1.0, 0.38);
			col = mix(col, ffC * 1.05, clamp(glow, 0.0, 1.0) * nightF);
			col += ffC * celBandSoft(clamp(halo, 0.0, 1.0), 3, 0.4) * 0.35 * nightF;
		}
	}
#endif
#endif
#ifdef WIND_STREAKS
#if !defined DIM_NETHER && !defined DIM_END
	// wind streaks: a few thin soft white lines that drift with the breeze, draw themselves in,
	// curl into a small loop and fade. They ride the same gust fronts that bend the grass.
	{
		float wsK = WIND_STREAKS * smoothstep(0.15, 0.4, dayG) * (1.0 - smoothstep(0.1, 0.5, rainStrength))
		          * smoothstep(0.6, 0.85, float(eyeBrightnessSmooth.y) / 240.0);
		if (wsK > 0.01 && isEyeInWater == 0 && !sky && lin < far * 0.95 && wY < (cloudHeight > 1.0 ? cloudHeight : 192.0) - 6.0) { // not on vanilla clouds (they write depth)
			vec2 wd2 = windDirT(frameTimeCounter);
			vec3 wd = vec3(wd2.x, 0.0, wd2.y), side = vec3(-wd2.y, 0.0, wd2.x), upW = vec3(0, 1, 0);
			vec2 px = gl_FragCoord.xy;
			float sceneZ = sky ? 1e6 : lin;
			float line = 0.0;
			// world-anchored: each 9-block cell in a 4x4 patch around the camera owns one streak,
			// so several lines are in view at once and they stay put when the camera turns
			vec2 cc = floor(cameraPosition.xz / 9.0 + 0.5);
			for (int k = 0; k < 16; k++) {
				vec2 cell = cc + vec2(float(k % 4) - 2.0, float(k / 4) - 2.0);
				float hc = hash12(cell * 1.31 + 0.7);
				float cyc = 6.0 + 1.5 * hc;
				float tt = frameTimeCounter / cyc + hc * 7.0;
				float id = floor(tt), lt = fract(tt) * cyc;   // seconds into this streak's life
				if (lt > 6.0) continue;                          // quiet gap between streaks
				float h1 = hash12(cell + vec2(id, 7.3)), h2 = hash12(cell.yx + vec2(3.1, id + 11.0)), h3 = hash12(cell * 0.7 + vec2(id * 1.7, 5.0));
				vec3 base = vec3((cell.x + h1) * 9.0, cameraPosition.y + 1.5 + 5.0 * h3, (cell.y + h2) * 9.0) - wd * 6.0;
				base.y += 0.35 * sin(lt * 0.7 + h1 * 6.2832);         // slow, gentle rise and fall while it drifts
				base += wd * (lt * WIND_SPEED * 4.375);           // drifts downwind at the same speed as the grass gust fronts
				float life = smoothstep(0.0, 0.8, lt) * (1.0 - smoothstep(4.4, 6.0, lt));
				// ride the gusts: a line only shows while a gust front is passing under it, so the grass
				// below visibly bends and brightens with it
				life *= 0.15 + 0.85 * smoothstep(0.0, 0.2, windGust((base + wd * 5.0).xz, frameTimeCounter)); // brightest on a gust, faint between
				float head = clamp(lt / 3.4, 0.0, 1.0) * 1.35;   // line draws itself in
				float L = 8.0 + 4.0 * h2, R = 0.6 + 0.3 * h1;
				vec2 prevP = vec2(0.0); float prevZ = 0.0, prevS = 0.0; bool prevOK = false;
				for (int i = 0; i <= 22; i++) {
					float sp = float(i) / 22.0;
					// gentle S-curve along the run, then one soft loop at the end
					vec3 q = wd * (sp * L) + side * (0.45 * sin(sp * 4.7 + h1 * 6.0)) + upW * (0.25 * sin(sp * 6.3 + h3 * 6.0));
					float la = clamp((sp - 0.62) / 0.38, 0.0, 1.0) * 6.2832;
					q += wd * (R * 0.6 * sin(la) + R * 1.6 * la / 6.2832) + upW * (R * 0.8 * (1.0 - cos(la))) + side * (R * 0.8 * sin(la)); // open corkscrew curl, reads round from any side
					vec4 vq = gbufferModelView * vec4(base + q - cameraPosition, 1.0);
					vec4 cq = gbufferProjection * vq;
					bool ok = cq.w > 0.3;
					vec2 sq = (cq.xy / max(cq.w, 1e-3) * 0.5 + 0.5) * vec2(viewWidth, viewHeight);
					float zq = -vq.z;
					if (ok && prevOK) {
						vec2 ab = sq - prevP;
						float tq = clamp(dot(px - prevP, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
						float dpx = length(px - prevP - ab * tq);
						float zz = mix(prevZ, zq, tq), ss = mix(prevS, sp, tq);
						float vis = step(ss, head) * step(head - 0.75, ss);                       // visible window
						float taper = smoothstep(head - 0.75, head - 0.4, ss) * (1.0 - smoothstep(head - 0.08, head + 0.001, ss));
						taper *= smoothstep(0.0, 0.08, ss) * (1.0 - smoothstep(0.92, 1.0, ss));
						// tapered: a thin trailing tail, a soft full body and a fine tip through the curl
						float wT = mix(0.35, 1.0, smoothstep(head - 0.75, head - 0.35, ss)) * (1.0 - 0.45 * smoothstep(0.7, 1.0, ss));
						float w = max(0.075 * viewHeight / max(zz, 1.0) * wT, 1.3);                  // soft ribbon, a touch thicker up close
						float a = ((1.0 - smoothstep(w * 0.4, w * 0.4 + 1.8, dpx)) + 0.22 * (1.0 - smoothstep(w * 0.5, w * 2.2 + 2.0, dpx))) * vis * taper; // core + faint soft glow
						a *= step(zz, sceneZ + 0.3) * (1.0 - smoothstep(26.0, 40.0, zz));
						line = max(line, a * life);
					}
					prevP = sq; prevZ = zq; prevS = sp; prevOK = ok;
				}
			}
			// tint: cool white by day, a warm peach glow at golden hour
			vec3 wsC = mix(vec3(0.93, 0.96, 1.0), vec3(1.0, 0.86, 0.68), 1.0 - smoothstep(0.25, 0.7, dayG));
			// keep the middle of the view calm: lines thin out softly toward the screen centre
			line *= mix(0.45, 1.0, smoothstep(0.06, 0.3, length(gl_FragCoord.xy / vec2(viewWidth, viewHeight) - 0.5)));
			// leaf blocks (tree crowns, also seen from above): the lines only brush over them faintly; grass plants keep them
			float crownK = abs(texture(colortex1, uv).a - 0.5) < 0.05 ? 0.2 : 1.0;
			col = mix(col, wsC, clamp(line, 0.0, 1.0) * 0.82 * wsK * crownK);
		}
	}
#endif
#endif
	// glow-berry vines (flag 0.56): the berries' own warm light must not turn the leaves olive-brown; keep them leaf-green
	if (!sky && abs(texture(colortex1, uv).a - 0.56) < 0.02 && texture(colortex3, uv).a < 0.3) {
		vec3 gN = vec3(0.62, 0.80, 0.28);
		col = mix(col, gN / luma(gN) * luma(col), 0.7);
	}
	if (!sky && abs(texture(colortex1, uv).a - 0.56) < 0.02 && texture(colortex3, uv).a >= 0.3) {
		vec3 oN = vec3(1.0, 0.62, 0.22); // the berries themselves: warm orange, not salmon pink
		col = mix(col, oN * max(max(col.r, col.g), 0.55) * 1.05, 0.75);
	}
#ifdef MORNING_DEW
	// morning dew: in the first hours after sunrise, tiny drops on grass catch the sun and twinkle (near the camera only)
	{
		float fa = texture(colortex1, uv).a;
		bool grassPx = abs(fa - 0.6) < 0.03 || abs(fa - 0.85) < 0.03;
		float morn = MORN_K * smoothstep(0.02, 0.12, sunHg) * (1.0 - smoothstep(0.35, 0.6, sunHg)) * (1.0 - rainStrength);
		if (!sky && grassPx && morn > 0.01 && isEyeInWater == 0 && lin < 24.0) {
			vec4 dv = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, texture(depthtex0, uv).r * 2.0 - 1.0, 1.0);
			vec3 dw = mat3(gbufferModelViewInverse) * (dv.xyz / dv.w) + cameraPosition;
			vec3 tq = floor(dw * 16.0 + 0.001);
			float h = hash12(tq.xz * 0.913 + tq.y * 5.31);
			float tw = pow(max(sin(frameTimeCounter * (0.8 + 1.2 * h) + h * 70.0), 0.0), 8.0);
			float k = step(0.975, h) * tw * morn * (1.0 - smoothstep(12.0, 24.0, lin)) * smoothstep(0.25, 0.5, luma(col));
			col = mix(col, vec3(1.0, 0.98, 0.90) * max(luma(col) * 1.8, 1.0), clamp(k, 0.0, 1.0) * MORNING_DEW);
		}
	}
#endif
#ifdef LEAF_GLINTS
	// sun glints: in a gust a few sunlit leaf texels catch the sun for a moment (sparse, per texel, soft blink)
	if (!sky && abs(texture(colortex1, uv).a - 0.5) < 0.05 && isEyeInWater == 0) {
		vec4 gv = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, texture(depthtex0, uv).r * 2.0 - 1.0, 1.0);
		vec3 gw = mat3(gbufferModelViewInverse) * (gv.xyz / gv.w) + cameraPosition;
		vec3 tq = floor(gw * 8.0 + 0.001);
		float hg = hash12(tq.xz * 1.37 + tq.y * 7.11);
		float gG = windGust(gw.xz, frameTimeCounter);
		float on = step(0.975 - 0.045 * smoothstep(0.15, 0.7, gG), hg);
		float bl = smoothstep(0.2, 0.9, sin(frameTimeCounter * (1.3 + hg * 1.7) + hg * 40.0));
		float sunK = smoothstep(0.12, 0.35, luma(col)) * smoothstep(0.15, 0.5, dayG) * (1.0 - smoothstep(24.0, 48.0, lin)); // lit leaves, near
		col = mix(col, vec3(1.0, 0.97, 0.82), on * bl * sunK * 0.9 * LEAF_GLINTS);
	}
#endif
#ifdef DRIFT_LEAVES
#if !defined DIM_NETHER && !defined DIM_END
	// drifting leaves: when a gust front passes, a few loose leaves tumble down and sail downwind
	// (world-anchored, one per 6-block cell around the camera; small calm flat-coloured flakes)
	{
		float dlK = smoothstep(0.12, 0.4, dayG) * (1.0 - smoothstep(0.1, 0.5, rainStrength)) * smoothstep(0.5, 0.8, float(eyeBrightnessSmooth.y) / 240.0);
		if (dlK > 0.01 && isEyeInWater == 0) {
			vec2 wd2 = windDirT(frameTimeCounter);
			vec3 wd = vec3(wd2.x, 0.0, wd2.y), side = vec3(-wd2.y, 0.0, wd2.x);
			vec2 px = gl_FragCoord.xy;
			float sceneZ = sky ? 1e6 : lin;
			float best = 0.0; vec3 lc = vec3(0.0);
			vec2 cc = floor(cameraPosition.xz / 5.0 + 0.5);
			for (int k = 0; k < 50; k++) {
				vec2 cell = cc + vec2(float(k % 5) - 2.0, float((k / 5) % 5) - 2.0);
				float hc = hash12(cell * 2.17 + 4.1 + float(k / 25) * 9.3);
				float cyc = 7.0 + 3.0 * hc;
				float tt = frameTimeCounter / cyc + hc * 5.0;
				float id = floor(tt), lt = fract(tt) * cyc;
				float h1 = hash12(cell + vec2(id, 1.9 + hc)), h2 = hash12(cell.yx + vec2(2.3, id + 4.0)), h3 = hash12(cell * 0.53 + vec2(id * 1.3, 8.0));
				vec3 p0 = vec3((cell.x + h1) * 5.0, cameraPosition.y + 0.5 + 4.5 * h3, (cell.y + h2) * 5.0) - wd * 7.0;
				float g = windGust(p0.xz, frameTimeCounter - lt); // gust when this leaf let go (one lookup per leaf)
				float life = smoothstep(0.0, 0.6, lt) * (1.0 - smoothstep(cyc - 1.5, cyc, lt)) * step(hash12(cell * 3.7 + vec2(id * 0.61, 2.0)), mix(0.60, 0.85, bCherry) + 0.40 * smoothstep(0.10, 0.50, g)); // more leaves let go when a gust passes
				if (life < 0.01) continue;
				// fall with a gentle side-to-side flutter while the breeze carries it
				vec3 pw = p0 + wd * (lt * (1.6 + 2.6 * g) * WIND_SPEED) + vec3(0.0, -0.55 * lt, 0.0)
				        + side * (0.45 * sin(lt * 2.3 + h1 * 6.28)) + vec3(0.0, 0.12 * sin(lt * 4.6 + h2 * 6.28), 0.0);
				vec4 vq = gbufferModelView * vec4(pw - cameraPosition, 1.0);
				float zq = -vq.z;
				if (zq < 0.5 || zq > 30.0) continue;
				vec4 cq = gbufferProjection * vq;
				vec2 sq = (cq.xy / cq.w * 0.5 + 0.5) * vec2(viewWidth, viewHeight);
				float sz = mix(0.15, 0.13, bCherry) * viewHeight / zq;
				// tumbling: the flake turns and flips (its width pulses), drawn as a small rhombus
				float ang = lt * (1.5 + h3) + h1 * 6.28;
				vec2 dv = px - sq;
				vec2 r = vec2(cos(ang) * dv.x + sin(ang) * dv.y, -sin(ang) * dv.x + cos(ang) * dv.y);
				float flip = 0.35 + 0.65 * abs(sin(lt * 3.1 + h2 * 6.28));
				float dd = abs(r.x) / (sz * flip) + abs(r.y) / (sz * 0.55);
				// near the ground only: terrain or trees must be close behind the leaf (no leaves floating high up in the air);
				// against open sky only right next to the camera
				float grounded = sky ? 1.0 - smoothstep(4.0, 7.0, zq) : 1.0 - smoothstep(12.0, 18.0, sceneZ - zq);
				float a = (1.0 - smoothstep(0.85, 1.0, dd)) * step(zq, sceneZ + 0.2) * life * (1.0 - smoothstep(22.0, 30.0, zq)) * grounded;
				if (a > best) {
					best = a;
					vec3 leafC = mix(vec3(0.42, 0.62, 0.22), vec3(0.78, 0.74, 0.30), h2);
					leafC = mix(leafC, vec3(0.86, 0.52, 0.22), step(0.82, h3)); // now and then an orange one
					leafC = mix(leafC, mix(vec3(0.96, 0.58, 0.76), vec3(1.0, 0.76, 0.86), h1), bCherry); // cherry groves: soft pink petals
					lc = leafC * mix(0.85, 1.12, smoothstep(0.0, 0.4, r.y / (sz * 0.55) + 0.3)); // lit side up
				}
			}
			lc *= mix(vec3(1.0, 0.82, 0.62), vec3(1.0), smoothstep(0.25, 0.7, dayG)) * mix(0.55, 1.0, dayG);
			col = mix(col, lc, clamp(best, 0.0, 1.0) * dlK * DRIFT_LEAVES);
		}
	}
#endif
#endif
#if !defined DIM_NETHER && !defined DIM_END
	// snowy lands: bright snow settles into a calm soft white (a hint of cool in the shade) instead of icy cyan
	if (!sky && !water && isEyeInWater == 0) {
		float snowB = (1.0 - smoothstep(0.05, 0.3, bTemp)) * (1.0 - smoothstep(16.0, 56.0, lin)); // near snow only: far hazy terrain keeps its airy blue
		float lS = luma(col);
		float blueish = smoothstep(0.02, 0.12, col.b - col.r);
		// snow seen from a warmer biome or further off: detect it per pixel, bright, nearly grey, slightly cool
		float spread = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
		float snowP = smoothstep(0.52, 0.66, lS) * (1.0 - smoothstep(0.22, 0.34, spread)) * (1.0 - smoothstep(90.0, 170.0, lin)) * dayG;
		float k = max(snowB * smoothstep(0.45, 0.7, lS), snowP) * blueish;
		col = mix(col, vec3(lS) * vec3(0.97, 0.99, 1.03) * mix(1.02, 1.08, snowP), k * mix(0.55, 0.7, snowP));
	}
#endif
#if RAINBOW > 0 && !defined DIM_NETHER && !defined DIM_END
	{
		// after-rain rainbow: while the land is still wet and the rain has passed, a calm painted arc stands
		// opposite the sun, drawn over sky, clouds and far hills in five soft pastel bands that fade at the feet
		vec3 upR = safeNormalize(upPosition, vec3(0, 1, 0));
		vec3 sunR = safeNormalize(sunPosition, upR);
		float sUp = dot(sunR, upR);
		float rK = smoothstep(0.005, 0.08, wetness) * (1.0 - smoothstep(0.05, 0.35, rainStrength)) * smoothstep(-0.02, 0.12, sUp) * (1.0 - smoothstep(0.55, 0.8, sUp));
		if (rK > 0.01 && isEyeInWater == 0) {
			float ang = degrees(acos(clamp(dot(vdir, -sunR), -1.0, 1.0)));
			float x = (ang - 39.0) / 5.0; // 0 inner violet .. 1 outer red
			float body = smoothstep(-0.25, 0.08, x) * smoothstep(1.25, 0.92, x);
			if (body > 0.0) {
				float xb = clamp(x, 0.0, 0.999) * 5.0;
				vec3 c0 = vec3(0.66, 0.56, 0.98), c1 = vec3(0.50, 0.74, 1.0), c2 = vec3(0.62, 0.93, 0.58), c3 = vec3(1.0, 0.88, 0.50), c4 = vec3(1.0, 0.60, 0.52);
				float fb = fract(xb), sb = smoothstep(0.82, 1.0, fb); // painted bands with a soft seam
				int ib = int(xb);
				vec3 ca = ib == 0 ? c0 : ib == 1 ? c1 : ib == 2 ? c2 : ib == 3 ? c3 : c4;
				vec3 cb = ib == 0 ? c1 : ib == 1 ? c2 : ib == 2 ? c3 : c4;
				vec3 rc = mix(ca, cb, sb);
				float feet = smoothstep(-0.03, 0.22, dot(vdir, upR));
				float terr = (d0 >= 1.0) ? 1.0 : smoothstep(far * 0.35, far * 0.85, lin) * 0.7;
				float a = body * feet * terr * rK * float(RAINBOW) * 0.9;
				col = mix(col, clamp(col * rc * 1.18 + rc * 0.10, 0.0, 1.0), a); // tinted veil that keeps the sky's light
			}
		}
	}
#endif
#if defined DIM_NETHER || defined DIM_END
	// own Nether / End looks: banded dimension fog in the biome's fog colour, soft glow
	if (isEyeInWater == 0) {
		float dz = (d0 >= 1.0) ? far : lin;
#ifdef DIM_NETHER
		vec3 nf = mix(vec3(0.55, 0.16, 0.10), fogColor * 1.25 + vec3(0.06, 0.02, 0.0), 0.6);
		// per-biome accents: warped forest gets a cyan fog, soul sand valley a cool teal, basalt deltas grey ash
		if (biome == BIOME_WARPED_FOREST) nf = mix(nf, vec3(0.10, 0.42, 0.44), 0.75);
		else if (biome == BIOME_SOUL_SAND_VALLEY) nf = mix(nf, vec3(0.20, 0.40, 0.44), 0.55);
		else if (biome == BIOME_BASALT_DELTAS) nf = mix(nf, vec3(0.42, 0.38, 0.44), 0.5);
		else if (biome == BIOME_CRIMSON_FOREST) nf = mix(nf, vec3(0.62, 0.10, 0.08), 0.4);
		float nfK = celBandSoft(smoothstep(far * 0.04, far * 0.75, dz), 5, 0.35) * NETHER_FOG;
		// depth: far fog sinks into a calm deep maroon so layers of cavern separate instead of one orange wall
		nf = mix(nf, nf * vec3(0.62, 0.52, 0.70), smoothstep(far * 0.15, far * 0.7, dz) * 0.75);
		// glowing lava keeps its deep orange through the near fog instead of washing out pale
		col = mix(col, nf, nfK * (1.0 - 0.45 * smoothstep(0.55, 0.9, col.r) * smoothstep(0.25, 0.05, col.b) * (1.0 - smoothstep(far * 0.2, far * 0.6, dz))));
		// soft overall calm: slightly less saturation on the hottest surfaces
		col = mix(vec3(luma(col)), col, mix(1.0, 0.76, smoothstep(0.3, 0.8, max(col.r - col.b, 0.0))));
		// crimson forest: wart and nylium settle into a calmer rose-maroon instead of a harsh pure red
		if (biome == BIOME_CRIMSON_FOREST) col = mix(vec3(luma(col)) * vec3(1.08, 0.94, 0.92), col, mix(1.0, 0.82, smoothstep(0.15, 0.5, col.r - max(col.g, col.b))));
		// heat: fog turns red-orange around lava (blurred light field)
		vec4 heat = textureLod(colortex3, uv, 6.0);
		col = mix(col, vec3(1.0, 0.35, 0.10), clamp(heat.a * 6.0, 0.0, 0.5) * max(NETHER_FOG, NETHER_EMBERS * 0.6) * smoothstep(4.0, 30.0, lin));
		// rising embers: tiny warm specks drifting up
		// few soft round embers that fade in and out slowly (no square specks, no on/off blinking)
		vec2 eq = uv * vec2(viewWidth / viewHeight, 1.0) * 18.0 + vec2(0.0, -frameTimeCounter * 0.5);
		vec2 ec = floor(eq), ef = fract(eq) - 0.5;
		float eh = hash12(ec);
		float ePh = fract(frameTimeCounter * 0.12 + hash12(ec + 3.1));
		float em = step(0.985, eh) * smoothstep(0.18, 0.06, length(ef + (vec2(hash12(ec + 5.3), hash12(ec + 9.1)) - 0.5) * 0.5)) * sin(ePh * 3.14159);
		col += vec3(1.0, 0.60, 0.28) * em * 0.35 * max(NETHER_FOG, NETHER_EMBERS);
		// calm warm ambient tint (independent of the fog setting): shadows lean soft amber instead of flat grey
		col = mix(col, col * vec3(1.07, 0.97, 0.88) + vec3(0.012, 0.005, 0.0), NETHER_AMBIENT);
#else
		vec3 ef = vec3(0.16, 0.10, 0.26);
		if (d0 >= 1.0) {
			// End sky: deep violet gradient, slow nebula bands, sparse stars (painted, banded)
			vec3 wdE = mat3(gbufferModelViewInverse) * vdir;
			float hE = wdE.y * 0.5 + 0.5;
			// calm violet dusk: one smooth gradient from a soft rose-violet horizon up to deep indigo (no stepped bands)
			float hS = smoothstep(0.35, 1.0, hE);
			vec3 sk = mix(vec3(0.30, 0.17, 0.36), vec3(0.07, 0.05, 0.17), hS * hS * (3.0 - 2.0 * hS));
			float neb = vnoise(wdE.xz / (abs(wdE.y) + 0.4) * 2.0 + frameTimeCounter * 0.01) * vnoise(wdE.xy * 3.0 + 1.7);
			sk += vec3(0.26, 0.13, 0.36) * smoothstep(0.22, 0.7, neb) * 0.35; // faint soft nebula glow
			// stars: soft round dots that hold still (no single-pixel cells that shimmer)
			vec2 sp = vec2(atan(wdE.z, wdE.x) * 40.0, wdE.y * 64.0);
			vec2 sc = floor(sp), sf = fract(sp) - 0.5;
			float sDot = step(0.972, hash12(sc + 17.3)) * smoothstep(0.22, 0.08, length(sf));
			sk = mix(sk, vec3(0.90, 0.85, 1.0), sDot * (1.0 - smoothstep(0.75, 0.95, abs(wdE.y))));
			col = sk;
		}
		float efK = celBandSoft(smoothstep(far * 0.08, far * 0.9, dz), 4, 0.35) * END_FOG;
		col = mix(col, ef, efK * (d0 >= 1.0 ? 0.0 : 1.0));
		// soft violet glow low on the horizon of the void, so the islands sit in light, not a flat black
		if (d0 >= 1.0) {
			vec3 wdH = mat3(gbufferModelViewInverse) * vdir;
			col += vec3(0.20, 0.10, 0.30) * celBandSoft(smoothstep(0.35, -0.05, abs(wdH.y + 0.05)), 3, 0.5) * 0.9;
		}
		// calm void mist: island undersides and low edges sink into a soft violet haze
		if (d0 < 1.0) col = mix(col, ef * 1.35 + vec3(0.03, 0.01, 0.05), celBandSoft(smoothstep(58.0, 10.0, wY), 3, 0.4) * 0.55 * END_FOG);
		col = mix(col, col * vec3(0.92, 0.88, 1.12), 0.6);
#endif
	}
	if (false)
#endif
	// whole-scene cast: orange at sunset, indigo/purple at night (never black)
	{
		vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
		float sunH = dot(safeNormalize(sunPosition, up), up);
		float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
		float night = clamp(-sunH * 4.0, 0.0, 1.0);
		if (!sky) {
			// dusk cast: gold-orange at sunset, soft peach-rose at sunrise. It is sky light, so it fades
			// where the eye has little sky (pits, dug holes, caves) instead of washing the whole view yellow.
			float mornT = (sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0;
			float skyEye = smoothstep(0.25, 0.85, float(eyeBrightnessSmooth.y) / 240.0);
			vec3 dMul = mix(vec3(1.30, 0.92, 0.55), vec3(1.10, 0.96, 0.93), mornT);
			vec3 dAdd = mix(vec3(0.07, 0.03, 0.0), vec3(0.035, 0.022, 0.006), mornT); // dawn: soft peach-gold lift, no magenta veil
			col = mix(col, col * dMul + dAdd, dusk * DUSK_TINT * mix(0.30, 1.0, skyEye) * (1.0 - cave));
			// golden hour on sunlit dirt and terracotta: low sun + dusk cast pushed them to a garish neon orange; keep them warm but calm
			{ float mxD = max(col.r, max(col.g, col.b)); float satD = (mxD - min(col.r, min(col.g, col.b))) / max(mxD, 0.02);
			  float kD = dusk * (1.0 - mornT) * smoothstep(0.42, 0.65, satD) * smoothstep(0.08, 0.22, col.r - col.g) * smoothstep(0.40, 0.65, mxD) * (1.0 - cave);
			  col = mix(col, mix(vec3(luma(col)), col, 0.62) * 0.92, kD); }
#ifdef TIME_GRADING
			// per time of day: sunrise (soft pink-gold), noon (clean, slightly crisper), blue hour (cool), night handled below
			float morn = (sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0;
			float rise = morn * clamp(1.0 - abs(sunH - 0.08) * 6.0, 0.0, 1.0);
			float noon = smoothstep(0.55, 0.9, sunH);
			float blueH = clamp(1.0 - abs(sunH + 0.10) * 9.0, 0.0, 1.0);
			// sunrise pink and blue-hour cool are sky light too: in pits, dug holes and caves they stacked
			// on the cool shade ambient into a lavender cast, so they fade with the eye's sky view
			float tgSky = mix(0.15, 1.0, skyEye) * (1.0 - cave);
			col = mix(col, col * vec3(1.06, 0.99, 0.95) + vec3(0.025, 0.014, 0.0), rise * TIME_GRADING_STRENGTH * tgSky);
			// dawn on warm surfaces (wood, terracotta, paths): the pink morning light left too much blue and they read salmon; keep them warm wood
			float wW = smoothstep(0.06, 0.18, col.r - col.g) * morn * clamp(1.6 - abs(sunH) * 4.0, 0.0, 1.0) * (1.0 - cave) * step(0.75, texture(colortex1, uv).a);
			col.b = mix(col.b, min(col.b, col.g * 0.66), wW);
			col = mix(col, mix(vec3(luma(col)), col, 1.05) * vec3(0.99, 1.0, 1.02), noon * TIME_GRADING_STRENGTH);
			// blue hour: pale walls, quartz and stone take a calm, slightly darker cool grey instead of glowing lavender-white
			vec3 bhGain = mix(vec3(0.84, 0.91, 1.10), vec3(0.80, 0.84, 0.96), sky ? 0.0 : smoothstep(0.18, 0.55, luma(col))); // from mid tones up (stone, cobble, pale walls)
			col = mix(col, col * bhGain + vec3(0.0, 0.01, 0.025), blueH * TIME_GRADING_STRENGTH * tgSky);
			// blue hour on grey stone and cobble: cool, but never periwinkle (blue capped a step above red/green; foliage and sky keep theirs)
			if (!sky && texture(colortex1, uv).a >= 0.75) col.b = mix(col.b, min(col.b, max(col.r, col.g) * 1.22), clamp(max(blueH, night * 0.6), 0.0, 1.0) * 0.85);
#endif
			// night: hue-shift towards indigo but keep warm torch pools warm
			// warm pools fall off with the light level: only the core near the flame keeps day colour, the rim fades into the night
			float warmPix = smoothstep(0.30, 0.92, texture(colortex2, uv).g) * (1.0 - coolL); // soul fire & co keep their own cool colour
#ifdef FLAME_FLICKER
			// living flames: torch and lantern pools breathe softly (slow, per-area, a little livelier on gusts), never a strobe
			if (warmPix > 0.01 && !sky) {
				vec4 fv = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, texture(depthtex0, uv).r * 2.0 - 1.0, 1.0);
				vec3 fw = mat3(gbufferModelViewInverse) * (fv.xyz / fv.w) + cameraPosition;
				float ft = frameTimeCounter * (1.1 + 0.6 * windGust(fw.xz, frameTimeCounter));
				float fl = vnoise(fw.xz * 0.12 + vec2(ft * 0.9, ft * 0.37)) * 0.65 + vnoise(fw.xz * 0.12 - vec2(ft * 2.1, -ft * 1.3) + 7.0) * 0.35;
				col *= 1.0 + (fl - 0.5) * 0.16 * FLAME_FLICKER * warmPix * (1.0 - heldK);
			}
#endif
			// moonlit night: a soft silver-blue instead of deep saturated indigo; the mids are lifted gently
			// so shapes, grass and paths stay readable, while the darkest shadows stay calm and deep
			vec3 ind = mix(vec3(luma(col)) * vec3(0.78, 0.88, 1.22), col * vec3(0.84, 0.97, 1.16), 0.55) + vec3(0.018, 0.022, 0.044);
			// deeper night: moonlit land sits a step lower so torch, lantern and campfire pools read as warm islands
			ind = pow(max(ind, vec3(0.0)), vec3(1.0)) * (0.80 + 0.12 * smoothstep(0.35, 0.8, luma(ind)));
			// pale ground (sand, snow, quartz) under the moon: a calm shoulder so it never glows white-lavender
			ind *= 1.0 - 0.26 * smoothstep(0.42, 0.85, luma(ind));
			// foliage keeps more of its own green at night (the blue lift turned close leaves teal)
			if (texture(colortex1, uv).a < 0.75) ind = mix(ind, ind * vec3(1.02, 1.04, 0.88), 0.8);
			col = mix(col, ind, night * SCENE_TINT * (1.0 - max(warmPix, heldK)));
			// moonlit wood and stone: indigo moon ambient on warm albedo dipped green below red and blue and read purple; lift green to a cool grey-brown
			col.g = mix(col.g, max(col.g, min(col.r, col.b) * 0.98), night * 0.85 * (1.0 - max(warmPix, heldK)));
			// calm deep night: unlit land steps down, warm light pools keep their full strength
			col *= mix(1.0, 0.70, night * (1.0 - smoothstep(0.05, 0.45, max(warmPix, heldK))));
			// the pool itself glows a soft amber instead of neutral daylight green
			col = mix(col, col * vec3(1.10, 0.95, 0.78), night * warmPix * (1.0 - heldK) * 0.55);
			// pale walls inside a torch pool: indigo ambient + orange flame mixed into pink-lavender; settle them into warm cream
			col = mix(col, vec3(luma(col)) * vec3(1.12, 0.96, 0.74), clamp(night * warmPix * 1.6, 0.0, 1.0) * (1.0 - heldK) * smoothstep(0.30, 0.65, luma(col)) * 0.85 * (1.0 - step(0.5, texture(colortex3, uv).a))); // flames and lamps themselves keep their colour
			// overcast rain: the land loses its sunny punch, a calm grey-green under soft cool light (warm pools excluded)
			if (IS_OW && !sky) col = mix(col, mix(vec3(luma(col)), col, 0.74) * vec3(0.95, 0.98, 1.03) * 0.90, rainStrength * skyEye * (1.0 - warmPix));
			// neon lime guard: very saturated bright yellow-greens settle into a softer meadow green (same shift on blocks and grass)
			if (IS_OW && !sky) { float gEx = col.g - max(col.r, col.b); float lk = smoothstep(0.10, 0.28, gEx) * smoothstep(0.25, 0.55, col.g);
				col = mix(col, mix(vec3(luma(col)), col, 0.72) * vec3(1.02, 0.97, 0.98), lk * 0.75); }
			// sunlit canopy tops: the brightest leaf faces washed out to a chalky pale lime; keep a little green depth there
			if (IS_OW && !sky && texture(colortex1, uv).a < 0.75) { float lT = luma(col);
				col = mix(col, mix(vec3(lT), col, 1.25) * 0.95, smoothstep(0.60, 0.82, lT) * 0.6); }
			// highlight shoulder: pale walls, sand and quartz in full sun roll off softly instead of clipping to flat white
			if (!sky) { float hM = max(col.r, max(col.g, col.b)); if (hM > 0.80) col *= (0.80 + (1.0 - exp(-(hM - 0.80) * 2.6)) * 0.17) / hM; }
			// twilight white balance where the eye sees little sky (pits, dug holes, caves): the still-indigo
			// dawn/dusk ambient read lavender on grey stone there. Neutralise its hue, keep its brightness.
			{
				float tw = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0) * mix(1.0, 0.3, skyEye * skyEye);
				vec3 neutral = vec3(luma(col)) * vec3(1.0, 0.99, 1.0);
				float warmP = clamp(texture(colortex2, uv).g * 1.5, 0.0, 1.0); // torch pools keep their warmth
				col = mix(col, mix(neutral, col, 0.25), tw * 0.85 * (1.0 - warmP));
				// open land: dawn/dusk indigo ambient + pink sky light still turn grey stone lavender; pull only that hue towards a soft warm grey
				float twO = clamp(1.6 - abs(sunH) * 4.0, 0.0, 1.0) * (1.0 - tw);
				float lav = smoothstep(0.0, 0.05, min(col.r, col.b) - col.g) * smoothstep(-0.07, 0.0, col.b - col.r) * step(0.75, texture(colortex1, uv).a);
				col = mix(col, vec3(luma(col)) * vec3(1.06, 1.0, 0.93), clamp(twO * lav * 1.3 * (1.0 - 0.6 * warmP), 0.0, 0.9));
				// late dusk: pink sky light on wooden roofs and paths reads salmon-rose (blue above green); settle it into warm wood brown
				float rose = smoothstep(-0.03, 0.01, col.b - col.g) * smoothstep(0.04, 0.10, col.r - col.g) * smoothstep(0.03, 0.08, col.r - col.b) * step(0.75, texture(colortex1, uv).a);
				col = mix(col, vec3(luma(col)) * vec3(1.14, 0.98, 0.84), clamp(twO * rose * (1.0 - 0.6 * warmP), 0.0, 0.7));
			}
		}
	}
#ifdef CAUSTICS
	// underwater caustics: banded light net on surfaces seen underwater (and on the bottom seen from above)
	if (d0 < 1.0 && (isEyeInWater == 1 || water)) {
		float dB = isEyeInWater == 1 ? d0 : texture(depthtex1, uv).r;
		vec4 cp4 = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, dB * 2.0 - 1.0, 1.0);
		vec3 cw = mat3(gbufferModelViewInverse) * (cp4.xyz / cp4.w) + cameraPosition;
		vec2 cq = cw.xz * 0.9 + cw.y * 0.3;
		float tC = frameTimeCounter * 0.6;
		float c1 = abs(vnoise(cq + vec2(tC, tC * 0.7)) - vnoise(cq * 1.3 - vec2(tC * 0.8, -tC * 0.5)));
		float ca = celBand(smoothstep(0.12, 0.0, c1), 3);
		float dayC = clamp(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))) * 3.0 + 0.2, 0.0, 1.0);
		float k = isEyeInWater == 1 ? 0.22 : 0.10 * (1.0 - smoothstep(1.0, 8.0, max(linDepth(dB) - lin, 0.0)));
		col += vec3(0.75, 1.0, 0.95) * ca * k * dayC * CAUSTICS_STRENGTH * smoothstep(48.0, 8.0, lin);
		if (isEyeInWater == 0) {
			// sunlit shallows seen from above: a soft, slowly drifting light net on the bottom (smooth lines, no hard cells)
			float sh = max(linDepth(dB) - lin, 0.0);
			float sk = smoothstep(0.15, 0.6, sh) * (1.0 - smoothstep(1.5, 5.0, sh)) * (1.0 - smoothstep(14.0, 40.0, lin));
			vec2 sq = cw.xz * 0.7;
			float tS = frameTimeCounter * 0.35;
			float s1 = abs(vnoise(sq + vec2(tS, -tS * 0.6)) - vnoise(sq * 1.25 - vec2(tS * 0.7, tS * 0.4)));
			float net = smoothstep(0.09, 0.015, s1);
			col = mix(col, col * 0.75 + vec3(0.86, 1.0, 0.96) * 0.35, net * sk * dayC * 0.55 * CAUSTICS_STRENGTH);
		}
	}
#endif
	// in lava / powder snow: only a short visibility limit
	if (isEyeInWater == 2) col = mix(col, vec3(0.92, 0.32, 0.06), clamp(lin / 3.0, 0.0, 1.0));
	if (isEyeInWater == 3) col = mix(col, vec3(0.82, 0.87, 0.94), clamp(lin / 2.0, 0.0, 1.0));
	if (isEyeInWater == 1) {
		// light cyan underwater fog, applied after grading so it is not over-saturated.
		// Sky pixels (seen through the surface) only get a light tint, not full fog.
		float dist = (d0 >= 1.0 && !isDH) ? 12.0 : lin;
		// open water beyond render distance: sideways and downward views melt into full fog, no bright band at the far edge
		if (d0 >= 1.0 && !isDH) dist = mix(48.0, 12.0, smoothstep(0.05, 0.35, (mat3(gbufferModelViewInverse) * vdir).y));
		// smooth depth falloff (no hard fog rings); at night the water sinks into a calm deep navy
		float f = celBandSoft(clamp(dist / 36.0, 0.0, 1.0), 4, 0.6) * UNDERWATER_FOG;
		vec3 uw = mix(vec3(0.20, 0.60, 0.82), vec3(0.06, 0.26, 0.44), f); // calm soft teal, no saturated navy
		float uwDay = clamp(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))) * 3.0 + 0.2, 0.0, 1.0);
		uw = mix(uw * vec3(0.30, 0.36, 0.55), uw, uwDay);
		col = mix(col * vec3(0.55, 0.85, 1.15) + vec3(0.0, 0.05, 0.14), uw, clamp(f * 0.95 + 0.18, 0.0, 0.9));
		{
			// clear cyan near the surface, settling into a calm dark blue toward the depths below
			float vyD = (mat3(gbufferModelViewInverse) * vdir).y;
			float deepK = smoothstep(0.20, -0.55, vyD) * smoothstep(4.0, 28.0, dist);
			col = mix(col, vec3(0.03, 0.14, 0.34) * mix(0.45, 1.0, uwDay), deepK * 0.60);
			col = mix(col, vec3(0.26, 0.84, 0.96) * mix(0.35, 1.0, uwDay), smoothstep(-0.10, 0.45, vyD) * 0.22);
		}
		{
			// looking up: the water brightens gently toward the sunlit surface (soft vertical light gradient)
			float upG = smoothstep(-0.1, 0.8, (mat3(gbufferModelViewInverse) * vdir).y);
			col = mix(col, vec3(0.62, 0.90, 0.96) * mix(0.35, 1.0, uwDay), upG * 0.22);
		}
		{
			// light window: looking up, a soft bright circle of sky light opens in the surface; around it the surface stays a calmer deep teal
			float wy = (mat3(gbufferModelViewInverse) * vdir).y;
			float win = smoothstep(0.58, 0.74, wy);
			float rimW = smoothstep(0.52, 0.64, wy) * (1.0 - smoothstep(0.66, 0.80, wy));
			float upOnly = smoothstep(0.15, 0.40, wy) * (1.0 - smoothstep(4.0, 1.0, lin) * 0.0);
			col = mix(col, col * vec3(0.78, 0.88, 0.92), upOnly * (1.0 - win) * 0.55);
			col = mix(col, mix(vec3(0.16, 0.27, 0.50), vec3(0.80, 0.96, 1.0), uwDay), (win * 0.22 + rimW * 0.12) * mix(0.6, 1.0, uwDay));
		}
#ifdef UNDERWATER_RAYS
		{
			// soft shafts of light slanting down from the surface, drifting slowly
			vec3 wd = mat3(gbufferModelViewInverse) * vdir;
			vec2 rq = wd.xz / (abs(wd.y) + 0.35) * 3.0 + vec2(frameTimeCounter * 0.05, 0.0);
			float rays = smoothstep(0.55, 0.85, vnoise(rq * vec2(1.0, 0.25) * 2.0 + vnoise(rq * 0.5) * 0.6));
			float upw = smoothstep(-0.3, 0.6, wd.y);
			float dayU = clamp(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))) * 3.0 + 0.2, 0.0, 1.0);
			col += vec3(0.60, 0.92, 1.0) * celBandSoft(rays * upw, 3, 0.7) * 0.28 * dayU * UNDERWATER_RAYS * smoothstep(1.0, 10.0, min(lin, 40.0));
		}
		{
			// slanted light beams: soft volumetric shafts falling from the surface along the sun direction, swaying slowly
			vec3 wd2 = mat3(gbufferModelViewInverse) * vdir;
			vec3 Lw = mat3(gbufferModelViewInverse) * safeNormalize(sunPosition, upPosition);
			if (Lw.y < 0.0) Lw = -Lw; // night: follow the moon
			Lw = normalize(vec3(Lw.x * 0.55, Lw.y + 0.6, Lw.z * 0.55)); // refracted: steeper under water
			float dayB = clamp(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))) * 3.0 + 0.2, 0.0, 1.0);
			float maxD = min((d0 >= 1.0 && !isDH) ? 32.0 : lin, 32.0);
			float acc = 0.0;
			float tB = frameTimeCounter * 0.04;
			for (int i = 0; i < 16; i++) {
				float sd = (float(i) + 0.5) / 16.0 * maxD;
				vec3 P = cameraPosition + wd2 * sd;
				vec2 q = P.xz - Lw.xz / Lw.y * P.y; // project along the beam onto a flat plane
				float b = vnoise(q * 0.16 + vec2(tB, -tB * 0.6)) * 0.65 + vnoise(q * 0.37 - vec2(tB * 0.7, tB * 0.3)) * 0.35;
				acc += smoothstep(0.58, 0.78, b);
			}
			acc /= 16.0;
			float beamK = acc * smoothstep(0.0, 6.0, maxD) * mix(0.35, 1.0, smoothstep(-0.6, 0.5, wd2.y));
			col += vec3(0.62, 0.94, 1.0) * beamK * 0.30 * mix(0.15, 1.0, dayB) * UNDERWATER_RAYS;
		}
#endif
	}
	col = mix(col, portalBase, portalPx * (isEyeInWater == 0 ? 0.8 : 0.0));
	outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
