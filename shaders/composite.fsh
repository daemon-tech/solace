#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
// Solace - outlines, water depth/foam, fog and colour grading.
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA8;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex3Clear = true;
const bool colortex3MipmapEnabled = true;
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
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 previousCameraPosition;
uniform vec3 eyePosition; // player eye (differs from the camera in third person)
uniform float frameTime;
uniform float wakeVX;
uniform float wakeVZ;
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
	t = mix(t, vec3(0.90, 1.00, 0.95), bSwamp);
	t = mix(t, vec3(0.93, 0.97, 0.96), bDark);
	extraHaze = 0.35 * bSwamp + 0.30 * bDark + 0.15 * cold;
	return mix(vec3(1.0), t, BIOME_MOOD * 1.5);
}
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
	float skyN = 0.0;
	int k = 0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 o = c + vec2(x, y) * px;
		dz[k] = linDepth(texture(depthtex0, o).r);
		nz[k] = texture(colortex1, o).xyz * 2.0 - 1.0;
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
#ifdef OUTLINE_NORMALS
	// inner block edges: normal Sobel, lighter ink, near range only, never on leaves
	if (!foliage) {
		float inner = step(1.6, ne) * INNER_STRENGTH * (1.0 - smoothstep(INNER_FADE * 0.5, INNER_FADE, centerLin));
		e = max(e, inner);
	}
#endif
	return e;
}

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
	c = mix(c, c * vec3(1.18, 1.12, 0.78), sand * SAND_BOOST);
	c = max(c, 0.0);
	// soft luminance cap: compress highlights above LUMA_CAP
	float nl = luma(c);
	if (nl > LUMA_CAP) c *= (LUMA_CAP + (nl - LUMA_CAP) * 0.35) / nl;
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
	float ang = hash12(gl_FragCoord.xy) * 6.2831853;
#ifdef SHADOW_TEMPORAL
	ang += fract(float(frameCounter) * 0.7548777) * 6.2831853;
#endif
	float ws = 1.0, sum = lb;
	for (int i = 0; i < 12; i++) {
		float r = sqrt((float(i) + 0.5) / 12.0);
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
	if (any(isnan(col)) || any(isinf(col))) col = vec3(0.0);
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
	bool water = texture(colortex2, uv).r > 0.5;
#ifdef SSAO
	// screen-space ambient occlusion: soft contact shading in corners and under overhangs (banded)
	if (d0 < 1.0 && !water && isEyeInWater == 0) {
		vec4 ap = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
		vec3 P = ap.xyz / ap.w;
		vec3 Nn = safeNormalize(texture(colortex1, uv).xyz * 2.0 - 1.0, vec3(0, 0, 1));
		float occ = 0.0;
		float rr = 0.55;
		float jit = fract(sin(dot(floor(uv * vec2(viewWidth, viewHeight)), vec2(12.9898, 78.233))) * 43758.5);
		for (int i = 0; i < 8; i++) {
			float a = (float(i) + jit) * 2.39996;
			float r = rr * sqrt((float(i) + 0.5) / 8.0);
			vec3 tng = safeNormalize(cross(Nn, abs(Nn.y) < 0.9 ? vec3(0, 1, 0) : vec3(1, 0, 0)), vec3(1, 0, 0));
			vec3 btg = cross(Nn, tng);
			vec3 S = P + (tng * cos(a) + btg * sin(a)) * r + Nn * r * 0.6;
			vec4 c = gbufferProjection * vec4(S, 1.0);
			vec2 so = c.xy / c.w * 0.5 + 0.5;
			vec4 q = gbufferProjectionInverse * vec4(so * 2.0 - 1.0, texture(depthtex0, so).r * 2.0 - 1.0, 1.0);
			float sz = q.z / q.w;
			occ += step(S.z + 0.04, sz) * smoothstep(1.2, 0.0, abs(sz - P.z));
		}
		float ao = 1.0 - celBandSoft(occ / 8.0, 4, 0.4) * SSAO_STRENGTH;
		col *= mix(1.0, ao, smoothstep(far * 0.6, 8.0, lin));
	}
#endif
#ifdef COLORED_LIGHT
	// coloured block light (screen space): light sources write their emitted colour to colortex3;
	// lit surfaces nearby take the average colour of the sources around them instead of plain warm.
	{
		float poolC = texture(colortex2, uv).g;
		if (poolC > 0.01 && texture(colortex3, uv).a < 0.5 && !water) {
			// blurred light-colour field from the mip chain (smooth, no speckles)
			vec4 L4 = textureLod(colortex3, uv, 4.0), L5 = textureLod(colortex3, uv, 5.0), L6 = textureLod(colortex3, uv, 6.0);
			vec4 Ls = L4 * 0.6 + L5 * 0.3 + L6 * 0.1;
			vec3 acc = Ls.rgb; float wsum = Ls.a * 12.0;
			if (Ls.a > 0.0003) {
				vec3 warm = vec3(1.00, 0.72, 0.42);
				vec3 tint = acc / max(Ls.a, 1e-3);
				vec3 ratio = clamp((tint / max(luma(tint), 0.15)) / (warm / luma(warm)), vec3(0.25), vec3(2.6));
				ratio /= max(luma(ratio), 0.5); // keep brightness, change only hue (no dark halos)
				float k = clamp(poolC * 1.8, 0.0, 1.0) * smoothstep(0.001, 0.04, Ls.a) * COLORED_LIGHT_STRENGTH;
				col = mix(col, col * ratio, k);
			}
		}
	}
#endif

	if (water && isEyeInWater == 0 && d0 < 1.0) {
		float behind = max(linDepth(texture(depthtex1, uv).r) - lin, 0.0);
		{
			// thin plants (kelp, seagrass) right under the surface must not read as shallows: take the deeper of a few taps
			vec2 tp = 3.0 / vec2(viewWidth, viewHeight);
			float bmax = behind;
			for (int k = 0; k < 4; k++) {
				vec2 o = uv + tp * vec2(k == 0 ? 1.0 : (k == 1 ? -1.0 : 0.0), k == 2 ? 1.0 : (k == 3 ? -1.0 : 0.0));
				if (texture(colortex2, o).r > 0.5) bmax = max(bmax, max(linDepth(texture(depthtex1, o).r) - linDepth(texture(depthtex0, o).r), 0.0));
			}
			behind = mix(behind, bmax, 0.85);
		}
		// deeper water -> banded deeper blue
		// clear shallows -> teal -> deep blue-green, in soft bands (bottom visible near shore)
		// 0.17 water: pale clear turquoise, near-white shallows, soft foam sheets
		float wday = dayFactor(sunPosition, upPosition);
		float t = frameTimeCounter;
		vec4 wp4 = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
		vec3 wv = wp4.xyz / max(abs(wp4.w), 1e-5);
		vec2 wxz = (mat3(gbufferModelViewInverse) * wv).xz + mod(cameraPosition.xz, 4096.0);
		float dd = celBand(smoothstep(0.3, 14.0 * mix(0.8, 1.4, WATER_CLARITY * 0.5), behind), 4);
		vec3 shoreC = vec3(0.80, 0.98, 0.96);
#ifdef GLOW_SHALLOWS
		shoreC = vec3(0.62, 1.0, 0.98); // brighter cyan shallows
#endif
		vec3 midC = vec3(0.27, 0.74, 0.82);
		vec3 deepC = vec3(0.07, 0.36, 0.54); // deeper end of the shallow-to-deep gradient
		midC = mix(midC, vec3(0.34, 0.60, 0.46), bSwamp * BIOME_MOOD);
		deepC = mix(deepC, vec3(0.16, 0.36, 0.30), bSwamp * BIOME_MOOD);
		// night: same hues, darker and bluer (never navy-black)
		vec3 nightK = mix(vec3(0.30, 0.40, 0.64), vec3(1.0), wday);
		vec3 wc = (dd < 0.5 ? mix(shoreC, midC, dd * 2.0) : mix(midC, deepC, dd * 2.0 - 1.0)) * nightK;
		// falling / sloped water (normal not up): keep the surface's white flow streaks readable
		vec3 nV = texture(colortex1, uv).xyz * 2.0 - 1.0;
		float fall = smoothstep(0.3, 0.6, 1.0 - abs(dot(safeNormalize(nV, vec3(0, 1, 0)), safeNormalize(upPosition, vec3(0, 1, 0)))));
		float farF = smoothstep(24.0, far * 0.7, lin); // far water keeps the surface sky mirror
		vec3 hiPre = max(col - vec3(0.80), 0.0);
		col = mix(col, wc, mix(0.55, 0.88, dd) * (1.0 - 0.65 * farF) * (1.0 - 0.75 * fall) * WATER_DEPTH_TINT / 0.70);
		col *= 1.0 - 0.10 * texture(colortex2, uv).b * (1.0 - farF);
		float wl = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(wl), col, WATER_SAT) * WATER_BRIGHT + hiPre * 2.0;
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
				vec3 refl = texture(colortex0, hitUV).rgb;
				refl = mix(refl, wc, 0.25); // reflections take a little of the water colour
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
						float brk = 0.6 + 0.4 * step(0.4, vnoise(vec2(uv.x * 60.0, uv.y * 220.0 + t * 1.5)));
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
					float brk = step(0.35, vnoise(vec2(uv.x * 90.0, uv.y * 260.0 + t * 2.0)));
					float k = xs * step(0.0, below) * brk * sunLow;
					col = mix(col, vec3(1.0, 0.86, 0.55), celBand(clamp(k, 0.0, 1.0), 3) * 0.9);
				}
			}
#endif
#ifdef WATER_SUN_GLINT
			// banded sun glint path on the surface (uses the full wave normal)
			vec3 Lsun = safeNormalize(sunPosition, upV);
			vec3 Rw = reflect(V, safeNormalize(mix(upV, safeNormalize(nV, upV), 0.8), upV));
			float g = pow(max(dot(Rw, Lsun), 0.0), 120.0);
			// broken into small glinting cells, not a solid blob
			float cells = smoothstep(0.62, 0.70, vnoise(wxz * 3.5 + vec2(t * 0.8, -t * 0.5)) * 0.6 + vnoise(wxz * 9.0 - t * 1.3) * 0.4);
			g = celBand(clamp(g * 2.5, 0.0, 1.0), 3) * cells;
			col = mix(col, vec3(1.0, 0.97, 0.88), clamp(g, 0.0, 1.0) * 0.9 * wday * (1.0 - rainStrength));
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
					if (pick > 0.80) {
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
			float brk = smoothstep(0.30, 0.62, vnoise(rq * 0.45 + vec2(t * 0.2, 0.0)) * 0.7 + vnoise(rq * 1.3) * 0.3);
			float streak = smoothstep(mix(0.82, 0.90, farF), 0.94, sin(ph)) * brk * (1.0 - farF * 0.35) * mix(0.60, 1.0, shore); // far sea keeps thin foam
			col = mix(col, foamC, clamp(max(sheet * 0.90, streak * 1.0), 0.0, 1.0) * (1.0 - fall) * fday * WATER_FOAM_AMT);
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
				// smoothed velocity (custom uniform): the raw per-frame camera delta is zero on some frames and
				// doubled on others (20 Hz ticks vs render frames), which made wakes and splashes flicker
				vec2 vel = vec2(wakeVX, wakeVZ);
				float mv = clamp(length(vel) / 4.0, 0.0, 1.0);
				float d = length(rel);
				float rings = smoothstep(0.82, 0.96, sin(d * 7.5 - t * 6.0 + wob * 2.0)) * smoothstep(2.6, 0.5, d);
				float burst = smoothstep(0.55, 0.62, vnoise(wxz * 5.0 + t * 1.5) * smoothstep(1.4, 0.3, d) + 0.25 * smoothstep(1.0, 0.0, d));
				col = mix(col, foamW, clamp(rings * (0.22 + 0.78 * mv) + burst * mv, 0.0, 1.0) * inW * fW * WATER_SPLASH_AMT);
#ifdef WATER_WAKE
				// V-shaped wake behind the player or the player's boat (direction from camera motion)
				{
					float sp = length(vel);
					if (sp > 0.8) {
						vec2 fwd = vel / sp;
						float along = -dot(rel, fwd);
						float perp = abs(dot(rel, vec2(-fwd.y, fwd.x)));
						float arm = abs(perp - along * 0.36 - 0.3);
						float wk = (1.0 - smoothstep(0.10, 0.35, arm + vnoise(wxz * 2.0 + t * 0.4) * 0.15)) * step(0.0, along) * (1.0 - smoothstep(4.0, 14.0, along));
						// trail foam texture anchored to the water (world xz), not to the player: no jumping pattern
						float trail = (1.0 - smoothstep(0.2, 0.9, perp)) * step(0.0, along) * (1.0 - smoothstep(2.0, 7.0, along)) * step(0.5, vnoise(wxz * 3.0 + vec2(t * 0.25, -t * 0.18)));
						float wakeW = smoothstep(2.5, 0.0, abs(feetY - surfY + 0.4)) * clamp(sp / 5.0, 0.0, 1.0);
						col = mix(col, foamW, celBand(clamp(max(wk, trail * 0.8), 0.0, 1.0), 3) * wakeW * fW * WATER_SPLASH_AMT);
					}
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
	float sunHf = dot(safeNormalize(sunPosition, safeNormalize(upPosition, vec3(0,1,0))), safeNormalize(upPosition, vec3(0,1,0)));
	float morningW = ((sunAngle < 0.25 || sunAngle > 0.75) ? 1.0 : 0.0) * clamp(1.0 - abs(sunHf - 0.05) * 4.0, 0.0, 1.0);
	float bFog = clamp(bHaze * BIOME_MOOD * BIOME_FOG, 0.0, 1.0);
	// underground / enclosed: eye sky light (smoothed) -> 0 open sky .. 1 deep cave
	float cave = smoothstep(0.55, 0.05, float(eyeBrightnessSmooth.y) / 240.0) * smoothstep(60.0, 48.0, cameraPosition.y); // dark AND below the surface (not a closed house)
#ifdef DISTANCE_FOG
	if (isEyeInWater == 0 && (d0 < 1.0 || isDH)) {
		float day = dayFactor(sunPosition, upPosition);
		vec3 fogCol = mix(vec3(0.18, 0.20, 0.50), vec3(0.42, 0.72, 0.85), day) * bTint;
		fogCol = mix(fogCol, fogSky, FOG_SKY_MATCH);
		float fs = far * mix(0.12, 0.02, bFog), fe = far * mix(0.9, 0.6, bFog);
		float f = celBand(smoothstep(fs, fe, lin), 4) * min(FOG_STRENGTH * (1.0 + bFog * 0.3), 1.0);
		col = mix(col, fogCol, f * (water ? 0.35 : 1.0) * (1.0 - 0.85 * cave * CAVE_FOG_ON));
	}
#endif
#ifdef CAVE_FOG
	// cave fog: darker, denser, slightly cool-tinted; banded like the rest of the fog
	if (isEyeInWater == 0 && d0 < 1.0 && cave > 0.01) {
		float cf = celBandSoft(1.0 - exp(-lin * 0.045 * CAVE_FOG_DENSITY), 4, 0.6); // soft band steps (no hard box on far walls)
		vec3 caveC = vec3(0.040, 0.046, 0.070) + vec3(0.010, 0.020, 0.030) * dayFactor(sunPosition, upPosition);
		col = mix(col, caveC, cf * cave * 0.85);
	}
#endif
	// low ground mist: sunrise everywhere, swamps all day; hugs the ground, never on near water
	if (isEyeInWater == 0 && d0 < 1.0 && MORNING_MIST > 0.0) {
		float amt = MORNING_MIST * max(morningW, bSwamp * BIOME_MOOD * 0.35);
		float hgt = exp(-max(wY - 63.0, 0.0) / 7.0);
		float m = celBand(smoothstep(6.0, 56.0, lin) * hgt, 4) * amt;
		vec3 mc = mix(fogSky, vec3(1.0), 0.15);
		col = mix(col, mc, clamp(m, 0.0, 0.5) * (water ? 0.4 : 1.0));
	}
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
		col = mix(col, mix(col, vec3(1.0, 0.55, 0.85), 0.7), clamp(e, 0.0, 1.0) * LIGHT_OUTLINE_OPACITY * 1.6); // pink/purple glow edges
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
#ifdef LIGHT_HALO
	// soft radial glow around lanterns, torches, lava and other light sources (blurred light-colour field)
	{
		vec4 h3 = textureLod(colortex3, uv, 3.0), h5 = textureLod(colortex3, uv, 5.0);
		vec3 halo = h3.rgb * 0.6 + h5.rgb * 1.4;
		col += halo * LIGHT_HALO * mix(1.0, 0.35, dayG * (1.0 - cave));
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
			vec3 hc = mix(vec3(1.0, 0.97, 0.82), vec3(1.0, 0.66, 0.30), duskG);
			col += hc * celBandSoft(clamp(hal, 0.0, 1.0), 4, 0.4) * vis * dayG * SUN_HALO * (1.0 - rainStrength);
		}
	}
#endif
	// hot dry biomes (deserts, badlands, savanna plateaus): no rain there, dust instead
	float dryB = smoothstep(1.3, 1.8, bTemp) * (1.0 - smoothstep(0.05, 0.3, bRain));
#ifdef RAIN_STREAKS
	if (rainStrength * (1.0 - dryB) > 0.01 && isEyeInWater == 0) {
		// slanted rain streaks over the scene + darker blue mood at night
		vec2 rq = vec2(uv.x * viewWidth / viewHeight * 60.0 + uv.y * 8.0, uv.y * 6.0 + frameTimeCounter * 9.0);
		float cell = hash12(floor(rq));
		float rs = step(0.93, cell) * smoothstep(0.0, 0.3, fract(rq.y)) * (1.0 - smoothstep(0.3, 0.9, fract(rq.y)));
		col = mix(col, vec3(0.80, 0.86, 0.95) * mix(0.45, 1.0, dayG), rs * 0.35 * rainStrength * (1.0 - dryB) * RAIN_STREAKS);
		col = mix(col, col * vec3(0.62, 0.72, 0.98), rainStrength * (1.0 - dryB) * (1.0 - dayG) * 0.6 * RAIN_STREAKS);
	}
#endif
#ifdef BLOOM
	// cheap glow haze: sparse ring taps of bright pixels
	{
		vec3 glow = vec3(0.0);
		vec2 px = 1.0 / vec2(viewWidth, viewHeight);
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 2.39996;
			float r = (4.0 + float(i) * 2.2);
			vec3 s = texture(colortex0, uv + vec2(cos(a), sin(a)) * r * px).rgb;
			float gr = clamp((s.g - max(s.r, s.b)) * 3.0, 0.0, 1.0); // green surfaces (sunlit grass) barely bloom
			glow += s * max(luma(s) - 0.62, 0.0) * 1.6 * (1.0 - 0.5 * gr);
		}
		glow /= 12.0;
		col += glow * (BLOOM_STRENGTH * STYLE_K) * mix(0.5, 1.6, max(duskG, 0.0));
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
			float fall = 1.0 - smoothstep(0.0, 0.85, length((suv - uv) * vec2(viewWidth / viewHeight, 1.0)));
			vec3 rc = useSun ? mix(vec3(1.0, 0.96, 0.70), vec3(1.0, 0.62, 0.22), duskG) : vec3(0.45, 0.55, 1.0);
			float str = GODRAYS_STRENGTH * (1.0 + FOREST_RAYS * bDark + FOREST_RAYS * 0.5 * smoothstep(0.9, 0.6, float(eyeBrightnessSmooth.y) / 240.0)) * (useSun ? mix(0.55, 1.0, duskG) * (1.0 + 0.4 * morningW * MORNING_MIST) : 0.35);
			col += rc * celBand(acc * fall, 4) * str * (sky ? 0.35 : 0.55);
		}
	}
#endif
#ifdef LIGHT_SHAFTS
	// light shafts indoors / under canopies: march the view ray through the shadow map
	{
		float interior = smoothstep(0.99, 0.70, float(eyeBrightnessSmooth.y) / 240.0) * (1.0 - cave * 0.7);
#ifdef VOLUMETRIC_OUTDOOR
		// forests and misty mornings: shafts outdoors too (only show where the canopy breaks the light)
		interior = max(interior, VOLUMETRIC_OUTDOOR * clamp(0.35 + bDark + morningW * MORNING_MIST + rainStrength * 0.3, 0.0, 1.0));
#endif
		if (isEyeInWater == 0 && interior * dayG > 0.01) {
			vec3 endP = mat3(gbufferModelViewInverse) * vpos;
			float L = min(length(endP), 32.0);
			vec3 dP = endP / max(length(endP), 1e-4);
			float acc = 0.0;
			for (int i = 0; i < 20; i++) {
				vec3 pp = dP * L * (float(i) + 0.5) / 20.0;
				vec4 sc = shadowProjection * (shadowModelView * vec4(pp, 1.0));
				vec3 sp = celDistort(sc.xyz / max(sc.w, 1e-4)) * 0.5 + 0.5;
				if (all(greaterThan(sp, vec3(0.0))) && all(lessThan(sp, vec3(1.0))))
					acc += step(sp.z - 0.0008, texture(shadowtex0, sp.xy).r);
			}
			acc /= 20.0;
			vec3 sunV = safeNormalize(sunPosition, vec3(0, 1, 0));
			float mie = 0.45 + 0.55 * pow(max(dot(vdir, sunV), 0.0), 3.0);
			vec3 shC = mix(vec3(1.0, 0.93, 0.74), vec3(1.0, 0.64, 0.30), duskG);
			float openK = smoothstep(0.99, 0.70, float(eyeBrightnessSmooth.y) / 240.0); // indoors: full; outdoors: only broken light
			float brokenK = mix(clamp(4.0 * acc * (1.0 - acc), 0.0, 1.0), 1.0, openK);
			col += shC * celBand(smoothstep(0.0, 0.16, acc * sqrt(L / 32.0)), 4) * mie * interior * dayG * LIGHT_SHAFTS_STRENGTH * 0.35 * brokenK;
		}
	}
#endif
	if (!sky && isEyeInWater == 0) {
		vec2 px2 = 6.0 / vec2(viewWidth, viewHeight);
		float open = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			open += step(1.0, texture(depthtex0, uv + vec2(cos(a), sin(a)) * px2).r);
		}
		open /= 8.0;
		bool fol = texture(colortex1, uv).a < 0.75;
		vec3 glowC = mix(vec3(0.85, 1.0, 0.45), vec3(1.0, 0.70, 0.30), duskG) * dayG + vec3(0.10, 0.14, 0.30) * (1.0 - dayG);
		col += glowC * open * (fol ? CANOPY_GLOW : CANOPY_GLOW * 0.4);
	}
	// warm atmospheric haze with distance (sunset orange, daytime soft yellow-green in forests)
	if (!sky && isEyeInWater == 0) {
		float hz = smoothstep(3.0, far * 0.6, lin);
		vec3 hzc = mix(mix(vec3(0.85, 0.95, 0.55), fogSky * 1.08, FOG_SKY_MATCH * 0.6), vec3(1.0, 0.62, 0.22), duskG);
		col = mix(col, hzc, hz * (HAZE + bHaze * BIOME_MOOD * 0.5) * STYLE_K * dayG * (water ? 0.25 : 1.0) * (1.0 - 0.5 * duskG));
	}
#ifdef DISTANCE_BLUE
	// aerial perspective: far terrain (mountains) turns soft blue toward the sky colour
	if (!sky && isEyeInWater == 0 && !water) {
		float hb = smoothstep(far * 0.22, far * 0.95, lin);
		vec3 blueC = mix(fogSky, vec3(0.55, 0.70, 0.92), 0.45) * mix(0.55, 1.0, dayG);
		col = mix(col, blueC, celBandSoft(hb, 4, 0.45) * DISTANCE_BLUE * (1.0 - 0.6 * duskG));
		// forests: blue depth haze already between nearby trunks
		float forestK = clamp(bDark + smoothstep(0.7, 0.95, bRain) * 0.6 + 0.2, 0.0, 1.0);
		col = mix(col, blueC * vec3(0.85, 0.95, 1.05), celBandSoft(smoothstep(10.0, 70.0, lin), 4, 0.45) * FOREST_HAZE * forestK * dayG * (1.0 - hb));
	}
#endif
#ifdef WEATHER_FX
	// weather: rain fog, desert sandstorm, snow haze (all banded and distance based)
	if (!sky && isEyeInWater == 0) {
		float hotDry = smoothstep(1.3, 1.8, bTemp) * (1.0 - smoothstep(0.05, 0.3, bRain));
		float coldW = 1.0 - smoothstep(0.05, 0.3, bTemp);
		float wet = rainStrength * (1.0 - hotDry);
		float rf = celBandSoft(smoothstep(2.0, far * 0.45, lin), 4, 0.4);
		vec3 rainC = mix(vec3(0.20, 0.22, 0.30), vec3(0.58, 0.64, 0.72), dayG);
		rainC = mix(rainC, vec3(0.86, 0.90, 0.96) * mix(0.45, 1.0, dayG), coldW); // snow: white haze
		col = mix(col, rainC, rf * wet * RAIN_FOG * 0.75);
		// sandstorm: warm dust wall with drifting streaks, only in hot dry biomes while the weather is bad
		float sand = hotDry * rainStrength * SANDSTORM;
		if (sand > 0.001) {
			vec3 wpS = mat3(gbufferModelViewInverse) * vpos + cameraPosition;
			vec2 sq = wpS.xz * 0.08 + wpS.y * 0.05 - windDir() * frameTimeCounter * 2.0;
			float streak = vnoise(sq * vec2(1.0, 4.0)) * 0.6 + vnoise(sq * 3.0) * 0.4;
			// thinner far wall (terrain shapes stay readable), broken by rolling gust clouds
			float gust = vnoise(wpS.xz * 0.03 - windDir() * frameTimeCounter * 0.6) * 0.6 + vnoise(wpS.xz * 0.09 + 3.1) * 0.4;
			float sf = celBandSoft(smoothstep(2.0, 70.0, lin), 4, 0.4) * (0.55 + 0.30 * streak + 0.25 * gust);
			vec3 dustC = vec3(0.86, 0.70, 0.46) * mix(0.4, 1.0, dayG);
			col = mix(col, dustC * mix(0.82, 1.08, gust), clamp(sf * sand, 0.0, 0.80));
			// fast wind-blown dust streaks over the whole view (sky included): long thin bands along the wind
			vec3 vw = safeNormalize(mat3(gbufferModelViewInverse) * vpos, vec3(0, 0, 1));
			vec2 wd = windDir();
			float along = dot(vw.xz, wd), across = dot(vw.xz, vec2(-wd.y, wd.x));
			vec2 dq = vec2(along * 6.0 - frameTimeCounter * 3.5, across * 40.0 + vw.y * 55.0);
			float ds = smoothstep(0.62, 0.80, vnoise(dq) * 0.7 + vnoise(dq * vec2(2.0, 1.3) + 5.0) * 0.3);
			float dk = smoothstep(0.55, 0.75, vnoise(dq * vec2(0.5, 0.35) + 9.0)); // darker drifting sheets
			col = mix(col, dustC * 1.18 + 0.04, ds * sand * 0.45);
			col = mix(col, dustC * 0.62, dk * sand * 0.22 * smoothstep(1.0, 12.0, lin));
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
	// near-white haze band where the sea meets the sky (water far field + sky just above horizon)
	if (isEyeInWater == 0) {
		vec3 upH = safeNormalize(upPosition, vec3(0, 1, 0));
		float hh = dot(vdir, upH);
		float hzW = sky ? (1.0 - smoothstep(0.0, 0.07, abs(hh))) * 0.55 : (water ? pow(smoothstep(24.0, far * 0.8, lin), 1.5) * 0.65 : 0.0);
		vec3 hzC = mix(fogSky, vec3(0.97, 0.99, 1.0), 0.6);
		col = mix(col, hzC, hzW * HORIZON_HAZE * mix(0.25, 1.0, dayG) * (1.0 - rainStrength * 0.5));
	}
	// the sky is authored in its final palette: no grading / scene cast on sky pixels
	if (!sky) {
		vec3 pre = col;
		col = grade(col) * bTint;
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
				if (h > 0.45 * FIREFLY_AMOUNT) continue;
				vec3 fp = (cell + vec3(hash12(cell.xz + 3.7), hash12(cell.xz + cell.y + 8.1), hash12(cell.zx + 1.3))) * 3.0;
				fp += vec3(sin(frameTimeCounter * 0.31 + h * 40.0), sin(frameTimeCounter * 0.23 + h * 70.0) * 0.6, cos(frameTimeCounter * 0.27 + h * 55.0)) * 0.7;
				vec3 rel = fp - cp;
				if (rel.y > 3.5 || rel.y < -2.5) continue; // keep them low, over the grass, not up in the sky
				float tc = dot(rel, rd);
				if (tc < 0.3 || tc > maxD) continue;
				float d = length(rel - rd * tc);
				float r = 0.035 + 0.0035 * tc;
				float blink = smoothstep(0.35, 0.9, sin(frameTimeCounter * (0.8 + h * 1.5) + h * 30.0) * 0.5 + 0.5);
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
		col = mix(col, nf, nfK);
		// heat: fog turns red-orange around lava (blurred light field)
		vec4 heat = textureLod(colortex3, uv, 6.0);
		col = mix(col, vec3(1.0, 0.35, 0.10), clamp(heat.a * 6.0, 0.0, 0.5) * NETHER_FOG * smoothstep(4.0, 30.0, lin));
		// rising embers: tiny warm specks drifting up
		vec2 eq = uv * vec2(viewWidth / viewHeight, 1.0) * 40.0 + vec2(0.0, -frameTimeCounter * 1.2);
		float em = step(0.995, hash12(floor(eq))) * step(0.5, fract(frameTimeCounter * 0.3 + hash12(floor(eq) + 3.1)));
		col += vec3(1.0, 0.55, 0.20) * em * 0.6 * NETHER_FOG;
#else
		vec3 ef = vec3(0.16, 0.10, 0.26);
		if (d0 >= 1.0) {
			// End sky: deep violet gradient, slow nebula bands, sparse stars (painted, banded)
			vec3 wdE = mat3(gbufferModelViewInverse) * vdir;
			float hE = wdE.y * 0.5 + 0.5;
			vec3 sk = mix(vec3(0.20, 0.12, 0.30), vec3(0.06, 0.04, 0.14), celBand(hE, 4));
			float neb = vnoise(wdE.xz / (abs(wdE.y) + 0.4) * 2.0 + frameTimeCounter * 0.01) * vnoise(wdE.xy * 3.0 + 1.7);
			sk += vec3(0.30, 0.14, 0.42) * celBand(smoothstep(0.25, 0.6, neb), 3) * 0.45;
			vec3 cE = floor(wdE * 160.0);
			if (hash12(cE.xy + cE.z * 31.7) > 0.997) sk = vec3(0.90, 0.85, 1.0);
			col = sk;
		}
		float efK = celBandSoft(smoothstep(far * 0.08, far * 0.9, dz), 4, 0.35) * END_FOG;
		col = mix(col, ef, efK * (d0 >= 1.0 ? 0.0 : 1.0));
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
			col = mix(col, col * vec3(1.30, 0.92, 0.55) + vec3(0.07, 0.03, 0.0), dusk * DUSK_TINT);
#ifdef TIME_GRADING
			// per time of day: sunrise (soft pink-gold), noon (clean, slightly crisper), blue hour (cool), night handled below
			float morn = (sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0;
			float rise = morn * clamp(1.0 - abs(sunH - 0.08) * 6.0, 0.0, 1.0);
			float noon = smoothstep(0.55, 0.9, sunH);
			float blueH = clamp(1.0 - abs(sunH + 0.10) * 9.0, 0.0, 1.0);
			col = mix(col, col * vec3(1.08, 0.97, 0.98) + vec3(0.03, 0.01, 0.02), rise * TIME_GRADING_STRENGTH);
			col = mix(col, mix(vec3(luma(col)), col, 1.05) * vec3(0.99, 1.0, 1.02), noon * TIME_GRADING_STRENGTH);
			col = mix(col, col * vec3(0.80, 0.90, 1.22) + vec3(0.0, 0.01, 0.04), blueH * TIME_GRADING_STRENGTH);
#endif
			// night: hue-shift towards indigo but keep warm torch pools warm
			float warmPix = clamp(texture(colortex2, uv).g * 1.5, 0.0, 1.0);
			vec3 ind = mix(vec3(luma(col)) * vec3(0.62, 0.70, 1.45), col * vec3(0.70, 0.95, 1.30), 0.5) + vec3(0.03, 0.03, 0.08);
			col = mix(col, ind, night * SCENE_TINT * (1.0 - warmPix));
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
	}
#endif
	if (isEyeInWater == 1) {
		// light cyan underwater fog, applied after grading so it is not over-saturated.
		// Sky pixels (seen through the surface) only get a light tint, not full fog.
		float dist = (d0 >= 1.0 && !isDH) ? 12.0 : lin;
		float f = celBand(clamp(dist / 36.0, 0.0, 1.0), 4) * UNDERWATER_FOG;
		vec3 uw = mix(vec3(0.16, 0.52, 0.90), vec3(0.04, 0.17, 0.42), f);
		col = mix(col * vec3(0.55, 0.85, 1.15) + vec3(0.0, 0.05, 0.14), uw, clamp(f * 0.95 + 0.18, 0.0, 0.9));
#ifdef UNDERWATER_RAYS
		{
			// soft shafts of light slanting down from the surface, drifting slowly
			vec3 wd = mat3(gbufferModelViewInverse) * vdir;
			vec2 rq = wd.xz / (abs(wd.y) + 0.35) * 3.0 + vec2(frameTimeCounter * 0.05, 0.0);
			float rays = smoothstep(0.55, 0.85, vnoise(rq * vec2(1.0, 0.25) * 2.0 + vnoise(rq * 0.5) * 0.6));
			float upw = smoothstep(-0.3, 0.6, wd.y);
			float dayU = clamp(dot(safeNormalize(sunPosition, upPosition), safeNormalize(upPosition, vec3(0, 1, 0))) * 3.0 + 0.2, 0.0, 1.0);
			col += vec3(0.55, 0.85, 1.0) * celBand(rays * upw, 3) * 0.18 * dayU * UNDERWATER_RAYS * smoothstep(1.0, 10.0, min(lin, 40.0));
		}
#endif
	}
	outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
