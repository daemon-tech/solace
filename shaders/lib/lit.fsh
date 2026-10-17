// Solace - shared cel-shaded fragment stage
uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform vec4 entityColor;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 vnormal;
in vec4 shadowClip;
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;

float shadowAt(vec4 clip) {
#ifdef SHADOWS
	if (abs(clip.w) < 1e-5) return 1.0;
	vec3 p = celDistort(clip.xyz / clip.w) * 0.5 + 0.5;
	if (any(lessThan(p.xy, vec2(0.0))) || any(greaterThan(p.xy, vec2(1.0))) || p.z > 1.0) return 1.0;
	float bias = 0.0006;
	float lit = 0.0, count = 0.0;
	float texel = 1.0 / float(shadowMapResolution);
	int r = SHADOW_SOFTNESS;
	for (int x = -r; x <= r; x++)
	for (int y = -r; y <= r; y++) {
		float d = texture(shadowtex0, p.xy + vec2(x, y) * texel).r;
		lit += step(p.z - bias, d);
		count += 1.0;
	}
	return lit / count;
#else
	return 1.0;
#endif
}

void main() {
	vec4 albedo = texture(gtexture, texcoord) * vcolor;
	if (albedo.a < 0.1) discard;
	albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);

	vec2 lm = clamp((lmcoord - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
	vec3 up = safeNormalize(upPosition, vec3(0, 1, 0));
#ifdef FLAT_NORMAL
	vec3 n = up;
	float ndl = 0.7;
#else
	vec3 n = safeNormalize(vnormal, up);
	float ndl = dot(n, safeNormalize(shadowLightPosition, up));
#endif
	float day = dayFactor(sunPosition, upPosition);
	float light = clamp(ndl * 1.5, 0.0, 1.0);
#ifndef FLAT_NORMAL
	if (ndl > 0.0) light *= shadowAt(shadowClip);
#endif
	light *= smoothstep(0.3, 0.7, lm.y) * (1.0 - rainStrength * 0.7);
	float lb = celBand(light, CEL_BANDS);

	// warm sun by day, indigo moonlight at night (never pitch black)
	vec3 sunCol = mix(vec3(0.30, 0.30, 0.75), vec3(1.05, 0.93, 0.80), day);
	vec3 tint = vec3(SHADOW_TINT_R, SHADOW_TINT_G, SHADOW_TINT_B);
	vec3 nightAmb = vec3(0.24, 0.20, 0.55);
	vec3 ambient = mix(nightAmb, tint * 0.62, day) * mix(0.35, 1.0, celBand(lm.y, 3));
	// torch light: warm orange pool with a sharp-ish falloff
	float torch = smoothstep(0.45, 0.62, lm.x) * 0.75 + smoothstep(0.75, 0.85, lm.x) * 0.35;
	vec3 block = vec3(1.0, 0.58, 0.24) * torch;
	vec3 lighting = ambient + sunCol * lb * 0.72 + block + vec3(0.04, 0.035, 0.08);

	outColor = vec4(clamp(albedo.rgb * lighting, 0.0, 4.0), albedo.a);
	outNormal = vec4(n * 0.5 + 0.5, 1.0);
}
