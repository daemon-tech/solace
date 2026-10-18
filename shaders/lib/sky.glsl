// Solace - stylized banded sky with time-of-day palettes. dir/sun/up in view space.
uniform float sunAngle; // 0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight
// discs=false: no sun/moon discs (used for fog / aerial colour so the fog never shows a sun spot)
vec3 celSkyImpl(vec3 dir, vec3 sunView, vec3 upView, float rain, bool discs) {
	vec3 up = safeNormalize(upView, vec3(0, 1, 0));
	vec3 sun = safeNormalize(sunView, up);
	float h = dot(dir, up);
	float sunH = dot(sun, up);
	float day = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
	float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
	float morning = (sunAngle < 0.25 || sunAngle > 0.75) ? 1.0 : 0.0;
	// how much this view direction faces the sun's azimuth (0 away .. 1 towards), banded
	vec3 dh = dir - up * h, sh = sun - up * sunH;
	float facing = dot(safeNormalize(dh, up), safeNormalize(sh, up)) * 0.5 + 0.5;
	facing = smoothstep(0.0, 1.0, facing); // smooth: banding here drew vertical seams in the sky

	// palette: day #2465ab->#6fbff3, night #111673/#230b5e->#3d53b8
	vec3 zen = mix(vec3(0.075, 0.050, 0.360), vec3(0.141, 0.396, 0.671), day);
	vec3 hor = mix(vec3(0.250, 0.330, 0.720), vec3(0.435, 0.749, 0.953), day);
	// daytime: pale warm glow on the horizon under the sun (atmospheric scattering)
	hor = mix(hor, vec3(0.80, 0.88, 0.96), SKY_SUN_GLOW * day * (1.0 - dusk) * facing * facing * 0.6);
	vec3 mid = mix(zen, hor, 0.5);
	// sunset gold/orange vs sunrise peach/rose; replaces (not averages) the blue palette
	vec3 dZen = mix(vec3(0.965, 0.700, 0.090), vec3(0.78, 0.62, 0.78), morning);
	vec3 dMid = mix(vec3(0.930, 0.500, 0.090), vec3(0.98, 0.62, 0.50), morning);
	vec3 dHor = mix(vec3(0.840, 0.430, 0.070), vec3(1.00, 0.74, 0.42), morning);
	// anti-sun side at dusk: soft violet/rose band ("belt of Venus")
	vec3 belt = mix(vec3(0.62, 0.42, 0.66), vec3(0.70, 0.58, 0.80), morning);
	float duskW = smoothstep(0.0, 0.6, dusk) * DUSK_SKY;
	float side = mix(0.55, 1.0, facing);
	vec3 zenBase = zen;
	zen = mix(zen, dZen, duskW * side);
	mid = mix(mid, mix(belt, dMid, facing), duskW);
	hor = mix(hor, mix(belt * 1.05, dHor, facing), duskW);
	zen = mix(zen, zenBase, duskW * smoothstep(0.45, 0.95, h));
	// night: faint lighter horizon glow so the sky is never a flat slab
	float night = clamp(-sunH * 4.0, 0.0, 1.0);
	hor = mix(hor, hor * 1.12 + vec3(0.03, 0.03, 0.06), night * 0.6);

	float t = clamp(h, 0.0, 1.0);
	t = floor(pow(t, 0.6) * float(SKY_BANDS) + 0.5) / float(SKY_BANDS);
	vec3 col = t < 0.5 ? mix(hor, mid, t * 2.0) : mix(mid, zen, t * 2.0 - 1.0);
	if (h < 0.0) col = hor * mix(1.0, 0.92, clamp(-h * 3.0, 0.0, 1.0));

	if (discs) {
		float s = dot(dir, sun);
		vec3 sunCol = mix(vec3(1.0, 0.75, 0.4), vec3(1.0, 0.97, 0.8), day);
		if (s > 0.9990) col = sunCol * 1.4;
		else if (s > 0.9960) col = mix(col, sunCol, 0.55);
		else if (s > 0.9880) col = mix(col, sunCol, 0.25);
		else if (s > 0.960) col = mix(col, sunCol, 0.10 * (0.4 + duskW));
		float m = dot(dir, -sun);
		if (m > 0.9993) col = vec3(0.90, 0.92, 1.0);
		else if (m > 0.9965) col = mix(col, vec3(0.70, 0.78, 1.0), 0.45);
		else if (m > 0.990) col = mix(col, vec3(0.55, 0.65, 1.0), 0.28);
		else if (m > 0.975) col = mix(col, vec3(0.45, 0.55, 0.95), 0.16);
		else if (m > 0.950) col = mix(col, vec3(0.40, 0.50, 0.90), 0.08);
	}
	return mix(col, vec3(luma(col)) * 0.7, rain * 0.6);
}
vec3 celSky(vec3 dir, vec3 sunView, vec3 upView, float rain) { return celSkyImpl(dir, sunView, upView, rain, true); }
// horizon sky colour in the view direction (for fog / haze). Light-weight copy of the
// horizon palette of celSkyImpl (no bands, no discs) so the composite pass stays small.
vec3 celHorizon(vec3 dir, vec3 sunView, vec3 upView, float rain) {
	vec3 up = safeNormalize(upView, vec3(0, 1, 0));
	vec3 sun = safeNormalize(sunView, up);
	float sunH = dot(sun, up);
	float day = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
	float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);
	float morning = (sunAngle < 0.25 || sunAngle > 0.75) ? 1.0 : 0.0;
	vec3 dh = dir - up * dot(dir, up), sh = sun - up * sunH;
	float facing = smoothstep(0.0, 1.0, dot(safeNormalize(dh, up), safeNormalize(sh, up)) * 0.5 + 0.5);
	vec3 hor = mix(vec3(0.250, 0.330, 0.720), vec3(0.435, 0.749, 0.953), day);
	hor = mix(hor, vec3(0.80, 0.88, 0.96), SKY_SUN_GLOW * day * (1.0 - dusk) * facing * facing * 0.6);
	vec3 dHor = mix(vec3(0.840, 0.430, 0.070), vec3(1.00, 0.74, 0.42), morning);
	vec3 belt = mix(vec3(0.62, 0.42, 0.66), vec3(0.70, 0.58, 0.80), morning);
	hor = mix(hor, mix(belt * 1.05, dHor, facing), smoothstep(0.0, 0.6, dusk) * DUSK_SKY);
	float night = clamp(-sunH * 4.0, 0.0, 1.0);
	hor = mix(hor, hor * 1.12 + vec3(0.03, 0.03, 0.06), night * 0.6);
	return mix(hor, vec3(luma(hor)) * 0.7, rain * 0.6);
}
