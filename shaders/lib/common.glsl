// Solace - shared helpers
// Nether / End builds (generated folders define DIM_NETHER / DIM_END): no sun, sky or weather effects there
#if defined DIM_NETHER || defined DIM_END
#undef SHADOWS
#undef GODRAYS
#undef LIGHT_SHAFTS
#undef VOLUMETRIC_OUTDOOR
#undef CLOUD_SHADOWS
#undef WEATHER_FX
#undef DISTANCE_BLUE
#undef TIME_GRADING
#undef CAVE_FOG
#undef SOFT_CLOUDS
#undef MILKY_WAY
#undef WET_GROUND
#undef DISTANCE_FOG
#undef GROUND_GRADE
#undef GLASS_TINT_LIGHT
#endif
vec3 celDistort(vec3 p) {
	// Radial shadow-map distortion: more resolution near the player.
	float d = length(p.xy);
	p.xy /= d * 0.85 + 0.15;
	p.z *= 0.25;
	return p;
}

// normalize() that never returns NaN for zero-length input
vec3 safeNormalize(vec3 v, vec3 fallback) {
	float l = length(v);
	return l > 1e-5 ? v / l : fallback;
}

float celBand(float x, int bands) {
	float n = float(bands - 1);
	float s = clamp(x, 0.0, 1.0) * n;
	float f = floor(s);
	return (f + smoothstep(0.5 - CEL_EDGE, 0.5 + CEL_EDGE, fract(s))) / n;
}

// cel bands with an adjustable soft transition between bands
float celBandSoft(float x, int bands, float edge) {
	float n = float(bands - 1);
	float s = clamp(x, 0.0, 1.0) * n;
	float f = floor(s);
	return (f + smoothstep(0.5 - edge, 0.5 + edge, fract(s))) / n;
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x),
	           mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

// 0 = night, 1 = full day
float dayFactor(vec3 sunView, vec3 upView) {
	vec3 s = safeNormalize(sunView, vec3(0, 1, 0));
	vec3 u = safeNormalize(upView, vec3(0, 1, 0));
	return clamp(dot(s, u) * 4.0 + 0.4, 0.0, 1.0);
}

// light colour per light-source id (see block.properties 10010-10015)
vec3 lightColor(int id) {
	if (id == 2) return vec3(0.30, 0.85, 1.00); // soul fire: cyan
	if (id == 3) return vec3(1.00, 0.22, 0.15); // redstone: red
	if (id == 4) return vec3(0.72, 0.38, 1.00); // amethyst, portal, crying obsidian: purple
	if (id == 5) return vec3(0.80, 0.92, 1.00); // sea lantern, end rod: cool white
	if (id == 6) return vec3(0.55, 1.00, 0.45); // verdant froglight: green
	return vec3(1.00, 0.72, 0.42);              // torches, lanterns, lava: warm
}

// shared wind field (world xz, time): 0..1 gust strength. Large breeze waves travel across the
// land along the wind direction, broken up by slow noise so fronts are irregular.
vec2 windDir() { return normalize(vec2(0.8, 0.45)); }
float windGust(vec2 xz, float t) {
	vec2 wd = windDir();
	float front = dot(xz, wd) * 0.08 - t * WIND_SPEED * 0.5;
	float g = sin(front + vnoise(xz * 0.015) * 3.0) * 0.5 + 0.5;
	g = smoothstep(0.45, 0.95, g);
	g *= 0.6 + 0.4 * vnoise(xz * 0.03 - wd * t * WIND_SPEED * 0.6);
	return g;
}

// shared plant/leaf wind offset (player-space xz), used by terrain and shadow passes
// kind: 1 = grass/flowers (top vertices only), 2 = leaves
vec2 windOffset(int kind, vec3 wp, float top, float t) {
	vec2 wd = windDir();
	float gust = 0.0;
#ifdef WIND_GUSTS
	gust = windGust(wp.xz, t) * WIND_GUST_STRENGTH;
#endif
	if (kind == 1) {
		float base = sin(t * 2.1 + wp.x * 0.7 + wp.z * 0.5) * 0.05 + sin(t * 4.3 + wp.z * 1.3) * 0.015;
		vec2 lean = wd * (0.03 + 0.34 * gust) + vec2(base, base * 0.6) * (1.0 + gust);
		return lean * top * WAVING_STRENGTH;
	}
	vec2 sway = vec2(sin(t * 1.4 + wp.x * 0.45 + wp.z * 0.20), cos(t * 1.1 + wp.z * 0.40 + wp.x * 0.15)) * 0.045
	          + vec2(sin(t * 3.7 + wp.y * 1.3 + wp.x), sin(t * 3.1 + wp.z * 1.1)) * 0.012;
	return (sway * (1.0 + 0.8 * gust) + wd * 0.03 * gust) * WAVING_STRENGTH;
}

// rolling ocean swell (WATER_ROLL): 0..1, 1 = crest; long waves travelling along one direction
float rollWave(vec2 xz, float t) {
	float a = dot(xz, vec2(0.83, 0.56)) * 0.571 - t * 1.1;  // ~11-block wavelength
	float b = dot(xz, vec2(-0.35, 0.94)) * 0.42 - t * 0.7; // cross swell breaks the pattern up
	return clamp(0.5 + 0.38 * sin(a) + 0.12 * sin(b), 0.0, 1.0);
}

// how much a texel of a light-source block glows: bright / saturated texels (flame, glass, lava) yes,
// dull brown sticks and grey metal frames no. Smooth so the edge of the flame never flickers.
float emitMask(vec3 a) {
	float mx = max(a.r, max(a.g, a.b)), mn = min(a.r, min(a.g, a.b));
	return smoothstep(0.50, 0.72, mx) * smoothstep(0.08, 0.30, mx - mn + max(mx - 0.85, 0.0) * 2.0);
}

// broad rolling wind wave over fields: two slow, wide sine fronts, smooth 0..1 (no noise)
float fieldWave(vec2 p, float t) {
	vec2 d = normalize(vec2(0.8, 0.6));
	float x = dot(p, d) * 0.30 + sin(dot(p, vec2(-0.6, 0.8)) * 0.07) * 1.6 - t * 0.9;
	float w = 0.5 + 0.5 * sin(x);
	float w2 = 0.5 + 0.5 * sin(x * 0.53 + 1.3);
	return smoothstep(0.35, 1.0, w) * mix(0.55, 1.0, w2);
}
