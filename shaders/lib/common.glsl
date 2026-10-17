// Solace - shared helpers
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
