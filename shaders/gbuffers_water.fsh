#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
// Solace - stylized turquoise water; other translucents get simple cel lighting.
uniform sampler2D gtexture;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 vnormal;
in vec3 viewPos;
in vec3 worldPos;
flat in int isWater;
/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outFlag;
layout(location = 3) out vec4 outLight;

void main() {
	vec2 lm = clamp((lmcoord - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
	float day = dayFactor(sunPosition, upPosition);
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
	vec3 n = safeNormalize(vnormal, up);
	float light = celBand(max(lm.y * mix(0.35, 1.0, day), lm.x), 4) * 0.85 + 0.15;

	if (isWater == 1) {
		float t = frameTimeCounter;
		vec2 p = worldPos.xz;
#ifdef WATER_WAVES
		vec3 wn = vec3(sin(p.x * 1.3 + t * 1.4) * 0.09 + sin(p.y * 0.9 - t * 1.1) * 0.07, 1.0,
		               cos(p.y * 1.2 + t * 1.2) * 0.09 + cos(p.x * 0.7 + t * 0.8) * 0.07);
		if (abs(dot(n, up)) > 0.9) n = safeNormalize(mat3(gbufferModelView) * wn, n);
#endif
		vec3 v = safeNormalize(-viewPos, up);
		// banded fresnel: 4 clearly visible steps
		float fres = celBand(pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.0), 4);
		// softer teal surface; the depth colour is added in composite (shore -> deep gradient)
		vec3 base = vec3(0.30, 0.68, 0.85);
		vec3 bright = vec3(0.62, 0.86, 0.96);
		vec3 far = vec3(0.18, 0.46, 0.72);
		vec3 col = mix(base, bright, fres);
		col = mix(col, far, celBand(smoothstep(24.0, 96.0, length(viewPos)), 3) * 0.45);
		// banded sky reflection (stronger at grazing angles)
		vec3 rd = reflect(-v, n);
		vec3 refl = celSky(rd, sunPosition, upPosition, rainStrength);
#if 1 // reflected soft cloud pattern (any cloud style)
		{
			// cheap reflected clouds (same sky-plane mapping as the sky pass, 3 octaves)
			vec3 rw = mat3(gbufferModelViewInverse) * rd;
			if (rw.y > 0.02) {
				vec2 cp = rw.xz / rw.y * 1.6 + vec2(t * 0.006, 0.0);
				float fwc = length(fwidth(cp * 1.3)); // octave filtering: no aliasing in far reflections
				float cd = mix(vnoise(cp * 1.3), 0.5, smoothstep(0.25, 0.5, fwc)) * 0.5 + mix(vnoise(cp * 2.64 + 17.1), 0.5, smoothstep(0.12, 0.25, fwc)) * 0.25 + mix(vnoise(cp * 5.36 + 51.0), 0.5, smoothstep(0.06, 0.12, fwc)) * 0.125;
				float cov = mix(0.56, 0.44, CLOUD_COVER) * 0.875;
				float cm = smoothstep(cov, cov + 0.06, cd) * smoothstep(0.02, 0.12, rw.y);
				vec3 cc = mix(vec3(0.20, 0.22, 0.45), vec3(1.0, 1.0, 0.98), day);
				refl = mix(refl, cc, cm * 0.85);
			}
		}
#endif
		// sky mirror grows with distance (far water reads as the sky, the target look)
		float farR = smoothstep(12.0, 72.0, length(viewPos));
		// bright mirror toward the horizon (lifted a touch so it reads as sheen, not a copy of the sky)
		col = mix(col, refl * 1.06 + vec3(0.05), clamp(fres * 0.40 + farR * 0.60 * WATER_REFLECT, 0.0, 0.88));
		// darker deep patches drifting slowly (banded, world-space)
		float patch = vnoise(p * 0.10 + vec2(t * 0.02, 0.0)) * 0.7 + vnoise(p * 0.23 - vec2(0.0, t * 0.03)) * 0.3;
		float deepPatch = smoothstep(0.56, 0.64, patch) * 0.55 + smoothstep(0.44, 0.52, patch) * 0.45;
		// soft wave crest lines drifting across the surface
		float wv = sin(p.x * 0.55 + p.y * 0.25 + t * 0.9 + vnoise(p * 0.15) * 4.0);
		float crest = step(0.86, wv) + step(0.93, wv); // two-step stylized crest line
		col = mix(col, vec3(0.86, 0.98, 1.0), clamp(crest, 0.0, 1.0) * mix(0.50, 0.85, step(1.5, crest)) * mix(0.75, 1.0, day));
		float spec = dot(reflect(-safeNormalize(shadowLightPosition, up), n), v);
		// banded sun glint: warm halo band + white core
		if (day > 0.3) {
			col = mix(col, vec3(1.0, 0.93, 0.72), step(0.955, spec) * 0.45);
			if (spec > 0.988) col = vec3(1.0);
		} else {
			// night: banded moon glint path and moonlit ripple highlights
			col = mix(col, vec3(0.70, 0.80, 1.0), step(0.94, spec) * 0.45);
			if (spec > 0.985) col = vec3(0.90, 0.94, 1.0);
			float rph = sin(p.x * 1.1 - p.y * 0.6 + t * 1.3 + vnoise(p * 0.3) * 3.0);
			float rip = step(0.84, rph) + step(0.95, rph);
			col = mix(col, vec3(0.60, 0.74, 1.0), clamp(rip, 0.0, 1.0) * mix(0.45, 0.75, step(1.5, rip)) * (1.0 - day));
		}
		// flowing water (falls, slopes): white streaks running downhill
		float side = 1.0 - abs(dot(safeNormalize(vnormal, up), up));
		if (side > 0.3) {
			float fl = vnoise(vec2((p.x + p.y) * 2.0, worldPos.y * 0.7 + t * 2.6));
			col = mix(col, vec3(0.92, 0.99, 1.0), (step(0.62, fl) * 0.55 + step(0.80, fl) * 0.4) * mix(0.4, 1.0, day));
			crest = max(crest, step(0.62, fl));
#ifdef WATERFALL_BLOBS
			// big stylized cel blobs tumbling down: white cores with pale blue rims, two tones
			float bl = vnoise(vec2((p.x + p.y) * 0.9, worldPos.y * 0.35 + t * 1.8)) * 0.7 + vnoise(vec2((p.x + p.y) * 2.2, worldPos.y * 0.9 + t * 3.0)) * 0.3;
			col = mix(col, vec3(0.62, 0.86, 1.0), step(0.48, bl) * 0.7 * mix(0.45, 1.0, day));
			col = mix(col, vec3(0.97, 1.0, 1.0), step(0.60, bl) * 0.9 * mix(0.45, 1.0, day));
			crest = max(crest, step(0.48, bl));
#endif
		}
		// rain: expanding ripple rings on the surface
		if (rainStrength > 0.01) {
			vec2 rc = floor(p * 0.8); vec2 rf = fract(p * 0.8) - 0.5;
			float ph0 = hash12(rc);
			float age = fract(t * 0.9 + ph0);
			float ring = abs(length(rf + (vec2(hash12(rc + 3.1), hash12(rc + 7.7)) - 0.5) * 0.4) - age * 0.45);
			float rr = step(ring, 0.06) * (1.0 - age) * step(0.35, ph0) * (1.0 - smoothstep(16.0, 40.0, length(viewPos)));
			col = mix(col, vec3(0.90, 0.97, 1.0), rr * 0.85 * rainStrength);
		}
#ifdef WATER_SPARKLE
		// white sparkle streaks drifting with the waves
		vec2 sp = p * vec2(0.8, 3.0) + vec2(t * 0.4, 0.0);
		// footprint fade: glints never get smaller than a few pixels (no far shimmer)
		float fpS = length(fwidth(p));
		float sparkle = smoothstep(0.84, 0.88, vnoise(sp)) * smoothstep(0.45, 0.55, vnoise(p * 0.2 + t * 0.07)) * step(0.50, spec) * (1.0 - smoothstep(0.15, 0.35, fpS))
		              + smoothstep(0.955, 0.975, vnoise(p * 1.6 + vec2(t * 0.35, -t * 0.2))) * day * 0.5 * (1.0 - smoothstep(0.04, 0.10, fpS)); // scattered small glints: near water only, gentle
		col = mix(col, vec3(1.0), clamp(sparkle, 0.0, 1.0) * 0.9 * mix(0.4, 1.0, day));
#endif
		outColor = vec4(col * mix(light, 1.0, 0.5 * day), max(max(mix(mix(0.30, 0.20, WATER_CLARITY), 0.85, fres), farR * 0.9 * min(WATER_REFLECT, 1.0)) * WATER_OPACITY, clamp(crest, 0.0, 1.0) * 0.80));
		outFlag = vec4(1.0, 0.0, deepPatch * step(side, 0.3), 1.0); // no deep patches on falling water
	} else {
		vec4 albedo = texture(gtexture, texcoord) * vcolor;
		if (albedo.a < 0.05) discard;
		vec3 gc = albedo.rgb * light;
#ifdef GLASS_REFLECT
		// glass: fresnel sky sheen + a stylized diagonal highlight streak (only on see-through blocks)
		if (albedo.a < 0.95 && isWater != 2) {
			vec3 V = safeNormalize(viewPos, vec3(0, 0, -1));
			float fr = pow(1.0 - clamp(abs(dot(V, n)), 0.0, 1.0), 3.0);
			vec3 skyC = mix(vec3(0.20, 0.24, 0.45), vec3(0.62, 0.80, 0.98), day);
			gc = mix(gc, skyC, fr * 0.45 * GLASS_REFLECT_STRENGTH);
			float diag = fract((worldPos.x + worldPos.z) * 0.5 + worldPos.y * 0.5);
			float streak = step(0.18, diag) * step(diag, 0.26) + step(0.32, diag) * step(diag, 0.35);
			gc = mix(gc, vec3(1.0), streak * 0.25 * GLASS_REFLECT_STRENGTH * mix(0.3, 1.0, day));
			albedo.a = max(albedo.a, fr * 0.5 * GLASS_REFLECT_STRENGTH);
		}
#endif
		// nether portal: self-lit swirl in its own colour (no glass sheen, no white streaks, not dimmed by night)
		if (isWater == 2) gc = mix(albedo.rgb * light, albedo.rgb * EMISSIVE_STRENGTH, 0.85);
		outColor = vec4(gc, albedo.a);
		outFlag = vec4(0.0, 0.0, 0.0, 1.0);
	}
	outLight = isWater == 2 ? vec4(lightColor(4) * 0.5, 0.5) : vec4(0.0); // portal: gentle purple light, a big panel needs less per pixel
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
}
