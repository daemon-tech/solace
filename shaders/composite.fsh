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
#ifdef OUTLINE_NORMALS
	float e = max(smoothstep(0.25, 0.45, de), smoothstep(1.2, 1.8, ne));
#else
	// silhouettes / depth breaks only; normals just reinforce real depth steps
	// crisp: hard threshold, 1px
	float e = step(0.12, de);
	// leaves: only ink silhouettes against the sky or a big depth jump, not every cut-out hole
	if (foliage) e *= max(skyN, step(0.6, de));
#endif
	return e * (1.0 - smoothstep(OUTLINE_FADE * 0.6, OUTLINE_FADE, centerLin));
}

vec3 grade(vec3 c) {
	float l = luma(c);
	// warm/red hues (sand, terracotta) get less saturation boost
	float warm = clamp((c.r - max(c.g * 0.85, c.b)) * 3.0, 0.0, 1.0);
	float sat = mix(SATURATION, 1.0 + (SATURATION - 1.0) * (1.0 - WARM_SAT_LIMIT), warm);
	c = mix(vec3(l), c, sat);
	float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
	c = mix(vec3(luma(c)), c, 1.0 + VIBRANCE * (1.0 - clamp(mx - mn, 0.0, 1.0)) * (1.0 - warm * 0.6));
	// push greens towards lime (#9dc832)
	float g = clamp((c.g - max(c.r, c.b)) * 4.0, 0.0, 1.0);
	c.r += (c.g - c.r) * LIME_GREENS * g;
	c *= 1.0 + 0.30 * g * LIME_GREENS / 0.25; // brighter, glowing greens
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
	float lin = linDepth(d0);
	bool water = texture(colortex2, uv).r > 0.5;

	if (water && isEyeInWater == 0) {
		float behind = max(linDepth(texture(depthtex1, uv).r) - lin, 0.0);
		// deeper water -> banded deeper blue
		col = mix(col, vec3(0.08, 0.42, 0.72), celBand(smoothstep(2.0, 10.0, behind), 3) * 0.35);
#ifdef WATER_FOAM
		// shore foam: solid edge band plus a broken second band
		float wob = vnoise(uv * vec2(viewWidth, viewHeight) * 0.03 + frameTimeCounter * 0.6) * 0.35;
		if (behind < 1.25 + wob) col = vec3(0.97, 1.0, 1.0);
		else if (behind > 1.75 + wob && behind < 2.25 + wob) col = mix(col, vec3(0.94, 0.99, 1.0), 0.80);
#endif
	}

#ifdef DISTANCE_FOG
	if (isEyeInWater == 0 && d0 < 1.0) {
		float day = dayFactor(sunPosition, upPosition);
		vec3 fogCol = mix(vec3(0.18, 0.20, 0.50), vec3(0.42, 0.72, 0.85), day); // blue-teal
		float f = celBand(smoothstep(far * 0.12, far * 0.9, lin), 4) * FOG_STRENGTH;
		col = mix(col, fogCol, f);
	}
#endif
#ifdef OUTLINES
	// no ink underwater (avoids dark rings around bubbles/particles)
	if (isEyeInWater == 0) {
		float e = outlineMask(uv, lin);
		col = mix(col, vec3(OUTLINE_R, OUTLINE_G, OUTLINE_B), clamp(e, 0.0, 1.0) * OUTLINE_STRENGTH);
	}
#endif
	bool sky = d0 >= 1.0;
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
			glow += max(s - 0.55, 0.0);
		}
		glow /= 12.0;
		col += glow * BLOOM_STRENGTH * mix(0.5, 1.6, max(duskG, 0.0));
	}
#endif
	// warm atmospheric haze with distance (sunset orange, daytime soft yellow-green in forests)
	if (!sky && isEyeInWater == 0) {
		float hz = smoothstep(3.0, far * 0.6, lin);
		vec3 hzc = mix(vec3(0.85, 0.95, 0.55), vec3(1.0, 0.62, 0.22), duskG);
		col = mix(col, hzc, hz * HAZE * dayG);
	}
	// the sky is authored in its final palette: no grading / scene cast on sky pixels
	if (!sky) col = grade(col);
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
		float dist = d0 >= 1.0 ? 12.0 : lin;
		float f = celBand(clamp(dist / 36.0, 0.0, 1.0), 4) * UNDERWATER_FOG;
		vec3 uw = mix(vec3(0.16, 0.52, 0.90), vec3(0.04, 0.17, 0.42), f);
		col = mix(col * vec3(0.55, 0.85, 1.15) + vec3(0.0, 0.05, 0.14), uw, clamp(f * 0.95 + 0.18, 0.0, 0.9));
	}
	outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
