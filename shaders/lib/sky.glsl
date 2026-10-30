// Solace - stylized banded sky with time-of-day palettes. dir/sun/up in view space.
uniform float sunAngle;
uniform float thunderStrength; // 0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight
uniform float sbHot, sbMesa, sbCold, sbSwamp, sbJungle, sbCherry; // smoothed biome weights (shaders.properties)
// biome sky: pull the day zenith / horizon colours toward a per-biome pair (k = day weight)
void biomeSky(inout vec3 zen, inout vec3 hor, float k) {
#ifdef BIOME_SKY
	k *= BIOME_SKY;
	if (k < 0.001) return;
	zen = mix(zen, vec3(0.44, 0.44, 0.86), sbHot * 0.60 * k);   hor = mix(hor, vec3(0.97, 0.82, 0.62), sbHot * 0.70 * k); // hot dry lands: soft violet zenith over a warm peach horizon
	zen = mix(zen, vec3(0.32, 0.50, 0.78), sbMesa * 0.50 * k);  hor = mix(hor, vec3(0.96, 0.68, 0.46), sbMesa * 0.70 * k);
	zen = mix(zen, vec3(0.34, 0.54, 0.84), sbCold * 0.55 * k);  hor = mix(hor, vec3(0.70, 0.82, 0.96), sbCold * 0.65 * k); // cold: crisp soft-blue horizon, no white wall
	zen = mix(zen, vec3(0.26, 0.40, 0.46), sbSwamp * 0.60 * k); hor = mix(hor, vec3(0.60, 0.68, 0.56), sbSwamp * 0.65 * k);
	zen = mix(zen, vec3(0.14, 0.48, 0.70), sbJungle * 0.77 * k); hor = mix(hor, vec3(0.56, 0.86, 0.74), sbJungle * 0.90 * k); // jungle: calm warmer green-teal
	zen = mix(zen, vec3(0.42, 0.54, 0.90), sbCherry * 0.55 * k); hor = mix(hor, vec3(0.97, 0.80, 0.89), sbCherry * 0.65 * k);
#endif
}
// discs=false: no sun/moon discs (used for fog / aerial colour so the fog never shows a sun spot)
// below the horizon (view past the loaded world from high spots): lean toward a calm, darker land-like tone
// instead of pale sky, so it never reads as a fog wall; stays sky-coloured right at the horizon line (seamless edge)
vec3 celBelowHorizon(vec3 col, float hv, float day, float rain) {
	if (hv >= 0.0) return col;
	vec3 land = mix(vec3(0.07, 0.09, 0.14), vec3(0.42, 0.62, 0.74), day); // day: a soft blue-teal far-land tone that sits with the cyan horizon
	land = mix(land, vec3(luma(land)) * vec3(0.92, 0.97, 1.04), rain * 0.5) * mix(1.0, 0.85, rain);
	land = mix(land, col * 0.8, 0.35 * (1.0 - rain)); // rain: do not pull the pale overcast sky back in
	land *= mix(1.0, 0.8, rain); // the rain veil drawn on top brightens it again, so start a bit darker
	// snowfall: below the horizon keeps the soft white-grey of the snow overcast (no dark band under a pale sky)
	land = mix(land, col * 0.92, clamp(rain * sbCold, 0.0, 1.0) * 0.8);
	float k = smoothstep(0.0, mix(0.22, 0.165, rain), -hv); // rain: start a little closer to the horizon, same smooth ramp
	return mix(col, land, k * k * (3.0 - 2.0 * k) * mix(mix(0.75, 0.55, day), 0.9, rain));
}
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
	// bright open day sky: a clear lighter zenith and a luminous pale horizon
	zen = mix(zen, vec3(0.13, 0.43, 0.93), day * (1.0 - dusk) * SKY_BRIGHT);
	hor = mix(hor, vec3(0.46, 0.83, 0.99), day * (1.0 - dusk) * SKY_BRIGHT);
	// daytime: pale warm glow on the horizon under the sun (atmospheric scattering)
	hor = mix(hor, vec3(0.80, 0.88, 0.96), SKY_SUN_GLOW * day * (1.0 - dusk) * facing * facing * facing * facing * 0.45);
	biomeSky(zen, hor, day * (1.0 - smoothstep(0.0, 0.6, dusk) * 0.7));
	vec3 mid = mix(zen, hor, 0.5);
	// sunset gold/orange vs sunrise peach/rose; replaces (not averages) the blue palette
	// layered: a warm glowing horizon, a coral middle and a soft rose-lilac above it
	vec3 dZen = mix(vec3(0.640, 0.540, 0.860), vec3(0.62, 0.70, 0.90), morning); // sunrise: soft blue above
	vec3 dMid = mix(vec3(0.960, 0.640, 0.500), vec3(0.95, 0.78, 0.64), morning); // sunrise: soft peach middle
	vec3 dHor = mix(vec3(0.980, 0.700, 0.280), vec3(1.00, 0.86, 0.64), morning); // sunrise: pale gold near the sun
	// anti-sun side at dusk: soft violet/rose band ("belt of Venus")
	// hot dry lands (savanna, desert): the evening sky settles into a calm soft peach instead of deep orange
	float hotD = sbHot * (1.0 - morning);
	dHor = mix(dHor, vec3(0.97, 0.76, 0.58), hotD * 0.75);
	dMid = mix(dMid, vec3(0.94, 0.70, 0.62), hotD * 0.65);
	dZen = mix(dZen, vec3(0.80, 0.66, 0.74), hotD * 0.5);
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
	float t0 = t;
	// soft-edged cel bands (no hard rings); at night the steps blend almost fully
	float bx = pow(t, 0.6) * float(SKY_BANDS);
	float bw = mix(0.18, 0.48, night);
	t = (floor(bx) + smoothstep(0.5 - bw, 0.5 + bw, fract(bx))) / float(SKY_BANDS);
	// clear day: one long smooth gradient instead of steps
	t = mix(t, pow(t0, 0.6), day * (1.0 - dusk) * SKY_BRIGHT);
	// dusk: the colour layers flow into each other as one calm gradient
	t = mix(t, pow(t0, 0.6), smoothstep(0.0, 0.6, dusk) * mix(0.6, 1.0, morning)); // dawn: fully smooth gradient
	vec3 col = t < 0.5 ? mix(hor, mid, t * 2.0) : mix(mid, zen, t * 2.0 - 1.0);
	// luminous horizon: a wide soft bright glow just above the horizon line
	float jW = sbJungle * min(BIOME_SKY, 1.0); // jungle: the bright horizon glow keeps the green-teal tint
	col = mix(col, mix(hor, vec3(0.78, 0.94, 1.0), 0.45 * (1.0 - 0.6 * jW)), (1.0 - smoothstep(0.0, 0.22, t0)) * day * (1.0 - dusk) * SKY_BRIGHT * 0.55 * step(0.0, h));
	if (h < 0.0) col = hor * mix(1.0, 0.92, clamp(-h * 3.0, 0.0, 1.0));
	// clear day: a soft painted gradient at the horizon, pale blue-white at the line, melting into the sky colour above and below
	{
		float hzK = day * (1.0 - smoothstep(0.0, 0.6, dusk)) * (1.0 - rain);
		vec3 pale = mix(vec3(0.60, 0.86, 0.99), hor * 1.08, 0.55 * jW);
		float g = h >= 0.0 ? 1.0 - smoothstep(0.0, 0.30, pow(h, 0.8)) : 1.0 - smoothstep(0.0, 0.45, -h);
		col = mix(col, pale, g * hzK * 0.32 * (1.0 - 0.6 * jW));
	}

	if (discs) {
		float s = dot(dir, sun);
		vec3 sunCol = mix(mix(vec3(1.0, 0.75, 0.4), vec3(1.0, 0.80, 0.68), ((sunAngle > 0.75 || sunAngle < 0.25) ? 1.0 : 0.0)), vec3(1.0, 0.97, 0.8), day); // sunrise disc: peach
		if (s > 0.9990) col = sunCol * 1.4;
		else {
			// calm glow around the disc: soft-edged layers instead of hard concentric rings
			float gl = smoothstep(0.9935, 0.9975, s) * 0.55 + smoothstep(0.982, 0.9935, s) * 0.18 + smoothstep(0.945, 0.99, s) * 0.10 * (0.4 + duskW);
			gl *= 1.0 - 0.45 * sbHot * duskW; // calmer glow around the evening sun in hot lands
			col = mix(col, sunCol, clamp(gl, 0.0, 0.6));
		}
		float m = dot(dir, -sun);
		// the moon's glow rings belong to the night; by day only a faint pale moon remains (no blue dome over the horizon)
		float mk = smoothstep(0.12, -0.08, dot(sun, up));
		// calm soft moon: a feathered pale disc inside one smooth silver glow (no stepped rings)
		float mGlow = smoothstep(0.950, 0.9965, m);
		col = mix(col, mix(vec3(0.42, 0.52, 0.92), vec3(0.72, 0.80, 1.0), mGlow * mGlow), mGlow * mGlow * 0.45 * mk);
		col = mix(col, vec3(0.92, 0.94, 1.0), smoothstep(0.99895, 0.99945, m) * mix(0.35, 1.0, mk));
	}
	col = mix(col, vec3(luma(col)) * 0.7, rain * 0.6);
	// rain: the whole sky settles into one calm slate overcast (no bright blue gaps), navy at night
	col = mix(col, mix(vec3(0.07, 0.09, 0.18), vec3(0.32, 0.39, 0.53), day) * mix(0.92, 1.05, clamp(h, 0.0, 1.0)), rain * 0.75 * (1.0 - sbCold * 0.5));
	// rain by day: a calm, lighter band of light low on the horizon under the overcast
	col = mix(col, vec3(0.56, 0.64, 0.78), (1.0 - smoothstep(0.0, 0.20, abs(h))) * rain * day * (1.0 - sbCold) * (1.0 - 0.5 * thunderStrength) * 0.45);
	// cold lands: snowfall overcast settles into a gentle cool white instead of a dull grey
	col = mix(col, vec3(0.80, 0.84, 0.90) * mix(0.3, 1.0, day), rain * sbCold * 0.55);
	// thunderstorm: the overcast sinks a calm step darker and cooler, so storms read heavier than rain
	col = mix(col, col * vec3(0.70, 0.74, 0.86), thunderStrength * rain);
	return celBelowHorizon(col, h, day, rain);
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
	hor = mix(hor, vec3(0.46, 0.83, 0.99), day * (1.0 - dusk) * SKY_BRIGHT);
	hor = mix(hor, vec3(0.80, 0.88, 0.96), SKY_SUN_GLOW * day * (1.0 - dusk) * facing * facing * facing * facing * 0.45);
	{ vec3 zDummy = hor; biomeSky(zDummy, hor, day * (1.0 - smoothstep(0.0, 0.6, dusk) * 0.7)); }
	vec3 dHor = mix(vec3(0.980, 0.700, 0.280), vec3(1.00, 0.78, 0.56), morning);
	dHor = mix(dHor, vec3(0.97, 0.76, 0.58), sbHot * (1.0 - morning) * 0.75);
	vec3 belt = mix(vec3(0.62, 0.42, 0.66), vec3(0.70, 0.58, 0.80), morning);
	hor = mix(hor, mix(belt * 1.05, dHor, facing), smoothstep(0.0, 0.6, dusk) * DUSK_SKY);
	float night = clamp(-sunH * 4.0, 0.0, 1.0);
	hor = mix(hor, hor * 1.12 + vec3(0.03, 0.03, 0.06), night * 0.6);
	// same pale horizon line as the sky, so the world edge melts into it without a seam
	float hv = dot(dir, up);
	float g = hv >= 0.0 ? 1.0 - smoothstep(0.0, 0.30, pow(max(hv, 0.0), 0.8)) : 1.0 - smoothstep(0.0, 0.45, -hv);
	hor = mix(hor, vec3(0.78, 0.88, 0.98), g * day * (1.0 - smoothstep(0.0, 0.6, dusk)) * (1.0 - rain) * 0.45);
	hor = mix(hor, vec3(luma(hor)) * 0.7, rain * 0.6);
	hor = mix(hor, vec3(0.56, 0.64, 0.78), (1.0 - smoothstep(0.0, 0.20, abs(hv))) * rain * day * (1.0 - sbCold) * (1.0 - 0.5 * thunderStrength) * 0.45);
	hor = mix(hor, hor * vec3(0.70, 0.74, 0.86), thunderStrength * rain);
	return celBelowHorizon(hor, hv, day, rain);
}
