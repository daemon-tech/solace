// Solace - stylized 3-colour banded sky. dir/sun/up in view space.
vec3 celSky(vec3 dir, vec3 sunView, vec3 upView, float rain) {
	vec3 up = safeNormalize(upView, vec3(0, 1, 0));
	vec3 sun = safeNormalize(sunView, up);
	float h = dot(dir, up);
	float sunH = dot(sun, up);
	float day = clamp(sunH * 4.0 + 0.4, 0.0, 1.0);
	float dusk = clamp(1.0 - abs(sunH) * 5.0, 0.0, 1.0);

	// palette: day #2465ab->#6fbff3, sunset #f5e714->#cf861c, night #111673/#230b5e->#3d53b8
	vec3 zen = mix(vec3(0.090, 0.060, 0.420), vec3(0.141, 0.396, 0.671), day);
	vec3 hor = mix(vec3(0.239, 0.325, 0.722), vec3(0.435, 0.749, 0.953), day);
	vec3 mid = mix(zen, hor, 0.5);
	// Sunset palette replaces (not averages with) the blue palette, so yellow + blue
	// never turns olive. Top #f5e714 -> orange mid -> horizon #cf861c.
	float duskW = smoothstep(0.0, 0.6, dusk);
	vec3 zenBase = zen;
	zen = mix(zen, vec3(0.961, 0.906, 0.078), duskW);
	mid = mix(mid, vec3(0.950, 0.640, 0.140), duskW);
	hor = mix(hor, vec3(0.812, 0.525, 0.110), duskW);
	// high above the sunset band, return to the normal zenith colour
	zen = mix(zen, zenBase, duskW * smoothstep(0.45, 0.95, h));

	// quantize height into flat bands
	float t = clamp(h, 0.0, 1.0);
	t = floor(pow(t, 0.6) * float(SKY_BANDS) + 0.5) / float(SKY_BANDS);
	vec3 col = t < 0.5 ? mix(hor, mid, t * 2.0) : mix(mid, zen, t * 2.0 - 1.0);
	if (h < 0.0) col = hor * mix(1.0, 0.6, clamp(-h * 3.0, 0.0, 1.0));

	// banded sun & moon discs with flat halo rings
	float s = dot(dir, sun);
	vec3 sunCol = mix(vec3(1.0, 0.75, 0.4), vec3(1.0, 0.97, 0.8), day);
	if (s > 0.9990) col = sunCol * 1.4;
	else if (s > 0.9960) col = mix(col, sunCol, 0.55);
	else if (s > 0.9880) col = mix(col, sunCol, 0.25);
	float m = dot(dir, -sun);
	if (m > 0.9993) col = vec3(0.85, 0.88, 1.0);
	else if (m > 0.9965) col = mix(col, vec3(0.6, 0.7, 1.0), 0.25);

	return mix(col, vec3(luma(col)) * 0.7, rain * 0.6);
}
