#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
// Solace - outlines, water depth/foam, fog and colour grading.
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
const vec4 colortex1ClearColor = vec4(0.5, 0.5, 1.0, 0.0);
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex0Clear = true;
const bool colortex1Clear = true;
const bool colortex2Clear = true;
*/
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
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
uniform float bRain;
uniform float bSwamp;
uniform float bDark;
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
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

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
	float de = length(vec2(gx, gy)) / max(centerLin, 0.5);
	vec3 ngx = (nz[2] + 2.0 * nz[5] + nz[8]) - (nz[0] + 2.0 * nz[3] + nz[6]);
	vec3 ngy = (nz[6] + 2.0 * nz[7] + nz[8]) - (nz[0] + 2.0 * nz[1] + nz[2]);
	float ne = sqrt(max(dot(ngx, ngx) + dot(ngy, ngy), 0.0));
	// silhouettes: crisp 1px on depth breaks
	float e = step(0.12, de);
	// leaves: only ink silhouettes against the sky or a big depth jump, not every cut-out hole
	if (foliage) e *= max(skyN, step(0.6, de));
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

void main() {
	vec3 col = texture(colortex0, uv).rgb;
	if (any(isnan(col)) || any(isinf(col))) col = vec3(0.0);
	float d0 = texture(depthtex0, uv).r;
	float bHaze; vec3 bTint = biomeTint(bHaze);
	float lin = linDepth(d0);
	bool isDH = false;
#ifdef DISTANT_HORIZONS
	if (d0 >= 1.0) {
		float dd0 = texture(dhDepthTex0, uv).r;
		if (dd0 < 1.0) { isDH = true; lin = 2.0 * dhNearPlane * dhFarPlane / max(dhFarPlane + dhNearPlane - (2.0 * dd0 - 1.0) * (dhFarPlane - dhNearPlane), 1e-4); }
	}
#endif
	bool water = texture(colortex2, uv).r > 0.5;

	if (water && isEyeInWater == 0 && d0 < 1.0) {
		float behind = max(linDepth(texture(depthtex1, uv).r) - lin, 0.0);
		// deeper water -> banded deeper blue
		// clear shallows -> teal -> deep blue-green, in soft bands (bottom visible near shore)
		float dd = celBand(smoothstep(0.3, 12.0, behind), 4);
		float wday = dayFactor(sunPosition, upPosition);
		// strong turquoise: clear tinted shallows -> turquoise -> dark blue depths (banded)
		vec3 midC = mix(vec3(0.05, 0.24, 0.32), vec3(0.14, 0.68, 0.72), wday);
		midC = mix(midC, vec3(0.20, 0.44, 0.34) * wday + 0.04, bSwamp * BIOME_MOOD);
		vec3 deepC = mix(vec3(0.03, 0.12, 0.20), vec3(0.05, 0.36, 0.46), wday); // dark teal, never navy
		vec3 hiPre = max(col - vec3(0.80), 0.0); // keep localized glints/foam lines from the surface pass
		col = mix(col * vec3(0.62, 1.02, 0.98), midC, clamp(dd * 2.0, 0.0, 1.0) * 0.75);
		col = mix(col, deepC, clamp(dd * 2.0 - 1.0, 0.0, 1.0) * WATER_DEPTH_TINT);
		col *= 1.0 - 0.38 * texture(colortex2, uv).b; // drifting deep patches (clearly visible)
		float wl = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(wl), col, WATER_SAT) * WATER_BRIGHT + hiPre * 2.5;
#ifdef WATER_FOAM
		// shore foam: solid edge band plus a broken second band
		float wob = vnoise(uv * vec2(viewWidth, viewHeight) * 0.03 + frameTimeCounter * 0.6) * 0.35;
		float fday = mix(0.45, 1.0, dayFactor(sunPosition, upPosition));
		// shoreline foam lines: solid edge line + a thinner wavy line pulsing outward
		float pulse = fract(frameTimeCounter * 0.15);
		if (behind < 0.55 + wob * 0.5) col = mix(col, vec3(0.98, 1.0, 1.0), 0.97 * fday);
		else if (behind < 0.70 + wob * 0.5) col = mix(col, vec3(0.90, 0.97, 1.0), 0.55 * fday); // soft foam rim
		else if (abs(behind - (0.75 + pulse * 0.6 + wob)) < 0.16) col = mix(col, vec3(0.97, 1.0, 1.0), 0.90 * fday * (1.0 - 0.6 * pulse));
#endif
	}

#ifdef DISTANCE_FOG
	if (isEyeInWater == 0 && (d0 < 1.0 || isDH)) {
		float day = dayFactor(sunPosition, upPosition);
		vec3 fogCol = mix(vec3(0.18, 0.20, 0.50), vec3(0.42, 0.72, 0.85), day); // blue-teal
		float f = celBand(smoothstep(far * 0.12, far * 0.9, lin), 4) * FOG_STRENGTH;
		fogCol *= bTint;
		col = mix(col, fogCol, f * (water ? 0.35 : 1.0));
	}
#endif
#if defined OUTLINES && EDGE_STYLE > 0
	// no ink underwater (avoids dark rings around bubbles/particles)
	if (isEyeInWater == 0) {
		float e = outlineMask(uv, lin);
		#if EDGE_STYLE == 2
		col = mix(col, vec3(OUTLINE_R, OUTLINE_G, OUTLINE_B), clamp(e, 0.0, 1.0) * OUTLINE_STRENGTH);
#else
		// soft coloured edge: a darker, cooler shade of the surface itself (no black ink)
#ifdef LIGHT_OUTLINES
		// very subtle thin light line (low opacity) instead of a dark edge
		col = mix(col, mix(col, vec3(1.0, 0.99, 0.95), 0.6), clamp(e, 0.0, 1.0) * LIGHT_OUTLINE_OPACITY);
#else
		col = mix(col, col * vec3(0.66, 0.70, 0.84), clamp(e, 0.0, 1.0) * SOFT_EDGE_STRENGTH);
#endif
#endif
	}
#endif
	bool sky = d0 >= 1.0 && !isDH;
	float sunHg = dot(safeNormalize(sunPosition, safeNormalize(upPosition, vec3(0,1,0))), safeNormalize(upPosition, vec3(0,1,0)));
	float duskG = clamp(1.0 - abs(sunHg) * 4.0, 0.0, 1.0);
	float dayG = dayFactor(sunPosition, upPosition);
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
			float str = GODRAYS_STRENGTH * (useSun ? mix(0.55, 1.0, duskG) : 0.35);
			col += rc * celBand(acc * fall, 4) * str * (sky ? 0.35 : 0.55);
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
		vec3 hzc = mix(vec3(0.85, 0.95, 0.55), vec3(1.0, 0.62, 0.22), duskG);
		col = mix(col, hzc, hz * (HAZE + bHaze * BIOME_MOOD * 0.5) * STYLE_K * dayG * (water ? 0.25 : 1.0) * (1.0 - 0.5 * duskG));
	}
	// the sky is authored in its final palette: no grading / scene cast on sky pixels
	if (!sky) col = grade(col) * bTint;
	// whole-scene cast: orange at sunset, indigo/purple at night (never black)
	{
		vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
		float sunH = dot(safeNormalize(sunPosition, up), up);
		float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
		float night = clamp(-sunH * 4.0, 0.0, 1.0);
		if (!sky) {
			col = mix(col, col * vec3(1.30, 0.92, 0.55) + vec3(0.07, 0.03, 0.0), dusk * DUSK_TINT);
			// night: hue-shift towards indigo but keep warm torch pools warm
			float warmPix = clamp(texture(colortex2, uv).g * 1.5, 0.0, 1.0);
			vec3 ind = mix(vec3(luma(col)) * vec3(0.62, 0.70, 1.45), col * vec3(0.70, 0.95, 1.30), 0.5) + vec3(0.03, 0.03, 0.08);
			col = mix(col, ind, night * SCENE_TINT * (1.0 - warmPix));
		}
	}
	if (isEyeInWater == 1) {
		// light cyan underwater fog, applied after grading so it is not over-saturated.
		// Sky pixels (seen through the surface) only get a light tint, not full fog.
		float dist = (d0 >= 1.0 && !isDH) ? 12.0 : lin;
		float f = celBand(clamp(dist / 36.0, 0.0, 1.0), 4) * UNDERWATER_FOG;
		vec3 uw = mix(vec3(0.16, 0.52, 0.90), vec3(0.04, 0.17, 0.42), f);
		col = mix(col * vec3(0.55, 0.85, 1.15) + vec3(0.0, 0.05, 0.14), uw, clamp(f * 0.95 + 0.18, 0.0, 0.9));
	}
	outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
