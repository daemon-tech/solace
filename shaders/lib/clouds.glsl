// Solace - extra cubic cloud layers (low + high) around the vanilla mid layer.
// Analytic: ray-plane hits + block cells with filtered (anti-aliased) edges. No raymarch, no noise.
#ifndef SOLACE_CLOUDS
#define SOLACE_CLOUDS
const float CL_LOW_OFF = -45.0, CL_LOW_THICK = 6.0, CL_LOW_CELL = 16.0;
const float CL_HIGH_OFF = 110.0, CL_HIGH_CELL = 8.0;
vec2 clDir(float deg) { float a = radians(deg); vec2 d = vec2(1.0, 0.0); return vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a)); }
// cell occupancy (0/1 per block cell), from a smooth low-frequency field
float clLowCell(vec2 c) {
	float f = vnoise(c * 0.23) * 0.65 + vnoise(c * 0.61 + 13.7) * 0.35;
	return step(mix(0.72, 0.62, CLOUD_COVER), f); // sparse big puffs
}
float clHighCell(vec2 c) {
	// stretched along the wind: thin, wispy-blocky streaks
	float f = vnoise(c * vec2(0.09, 0.30) + 41.0) * 0.7 + vnoise(c * vec2(0.27, 0.8) + 7.0) * 0.3;
	return step(mix(0.70, 0.60, CLOUD_COVER), f);
}
// nearest-cell lookup with a filtered transition of width e (cells): crisp blocks up close,
// smooth (mip-like) blend once a cell edge is smaller than a pixel or two
float clCover(vec2 q, float e, int layer) {
#ifdef CLOUD_PUFFY
	if (layer == 0) {
		// big rounded puffs: the same smooth field, read continuously with a wide soft edge (no cells)
		vec2 c = q - 0.5;
		float f = vnoise(c * 0.23) * 0.65 + vnoise(c * 0.61 + 13.7) * 0.35;
		float th = mix(0.72, 0.62, CLOUD_COVER);
		return smoothstep(th - 0.05 - e * 0.1, th + 0.07 + e * 0.1, f);
	}
#endif
	vec2 b = floor(q - 0.5), f = q - 0.5 - b;
	vec2 w = smoothstep(0.5 - e, 0.5 + e, f);
	float o00, o10, o01, o11;
	if (layer == 0) { o00 = clLowCell(b); o10 = clLowCell(b + vec2(1, 0)); o01 = clLowCell(b + vec2(0, 1)); o11 = clLowCell(b + vec2(1, 1)); }
	else { o00 = clHighCell(b); o10 = clHighCell(b + vec2(1, 0)); o01 = clHighCell(b + vec2(0, 1)); o11 = clHighCell(b + vec2(1, 1)); }
	return mix(mix(o00, o10, w.x), mix(o01, o11, w.x), w.y);
}
// low-layer cloud coordinates (cells) at world xz
vec2 clLowQ(vec2 xz, float t) { return (xz - clDir(8.0) * t * 1.6 * CLOUD_LAYER_SPEED) / CL_LOW_CELL; }
vec2 clHighQ(vec2 xz, float t) { return (xz - clDir(-12.0) * t * 0.4 * CLOUD_LAYER_SPEED) / CL_HIGH_CELL; }
#endif
