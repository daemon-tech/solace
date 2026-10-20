#version 330 compatibility
#include "/lib/settings.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
in vec2 uv;
layout(location = 0) out vec4 outColor;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 fetch(vec2 p) { vec3 c = texture(colortex0, p).rgb; return any(isnan(c)) ? vec3(0.0) : c; }
void main() {
	vec2 px = 1.0 / vec2(viewWidth, viewHeight);
	vec3 c = fetch(uv);
#ifdef FXAA
	{
		// light FXAA: smooths stair-steps on geometry edges, leaves high-contrast outlines crisp
		float lM = lum(c), lN = lum(fetch(uv + vec2(0, px.y))), lS = lum(fetch(uv - vec2(0, px.y)));
		float lE = lum(fetch(uv + vec2(px.x, 0))), lW = lum(fetch(uv - vec2(px.x, 0)));
		float mn = min(lM, min(min(lN, lS), min(lE, lW))), mx = max(lM, max(max(lN, lS), max(lE, lW)));
		float rng = mx - mn;
		if (rng > max(0.04, mx * 0.12) && rng < 0.45) {
			vec2 dir = vec2(-((lN + lS) - (lE + lW)), (lN + lS) - (lE + lW)) ;
			dir = vec2(-(lN - lS), lE - lW);
			dir /= min(abs(dir.x), abs(dir.y)) + max(0.03, (lN + lS + lE + lW) * 0.03);
			dir = clamp(dir, -2.0, 2.0) * px;
			vec3 a = 0.5 * (fetch(uv + dir * (-1.0 / 6.0)) + fetch(uv + dir * (1.0 / 6.0)));
			c = mix(c, a, 0.6);
		}
	}
#endif
#if PAINTERLY_FAR > 0
	{
		// painterly distance: far land is flattened into soft brush-like patches (4-sector smoothing
		// filter keeps silhouettes, removes small texture detail; no noise, no grain)
		float d = texture(depthtex0, uv).r;
		float lin = 2.0 * near * far / max(far + near - (2.0 * d - 1.0) * (far - near), 1e-4);
		float k = smoothstep(far * 0.18, far * 0.55, lin) * step(d, 0.99999);
		if (k > 0.01) {
			vec2 st = px * mix(1.0, 2.0, k);
			vec3 m[4]; vec3 v[4];
			for (int q = 0; q < 4; q++) { m[q] = vec3(0.0); v[q] = vec3(0.0); }
			for (int y = 0; y <= 2; y++) for (int x = 0; x <= 2; x++) {
				vec3 s0 = fetch(uv + vec2(-x, -y) * st), s1 = fetch(uv + vec2(x, -y) * st);
				vec3 s2 = fetch(uv + vec2(-x, y) * st), s3 = fetch(uv + vec2(x, y) * st);
				m[0] += s0; v[0] += s0 * s0; m[1] += s1; v[1] += s1 * s1;
				m[2] += s2; v[2] += s2 * s2; m[3] += s3; v[3] += s3 * s3;
			}
			vec3 best = c; float bv = 1e9;
			for (int q = 0; q < 4; q++) {
				vec3 mu = m[q] / 9.0; vec3 va = abs(v[q] / 9.0 - mu * mu);
				float sv = va.r + va.g + va.b;
				if (sv < bv) { bv = sv; best = mu; }
			}
			c = mix(c, best, k * float(PAINTERLY_FAR) * 0.1);
		}
	}
#endif
#ifdef DISTANCE_BLUR
	{
		float d = texture(depthtex0, uv).r;
		float lin = 2.0 * near * far / max(far + near - (2.0 * d - 1.0) * (far - near), 1e-4);
		float k = smoothstep(far * 0.35, far * 0.9, lin) * (d < 1.0 ? 1.0 : 0.6);
		if (k > 0.01) {
			vec3 b = vec3(0.0);
			for (int i = 0; i < 8; i++) { float a = float(i) * 0.785398; b += fetch(uv + vec2(cos(a), sin(a)) * px * 2.5 * DISTANCE_BLUR_STRENGTH); }
			c = mix(c, b / 8.0, k);
		}
	}
#endif
	outColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
