#version 330 compatibility
#include "/lib/settings.glsl"
// rain and snow: colour only, soft and slightly cool; never touches the normal/flag buffers
// (otherwise the water behind would lose its water flag and grow foam under every drop)
uniform sampler2D gtexture;
uniform float rainStrength;
uniform float near;
uniform float far;
in vec2 tc;
in vec4 vc;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
	vec4 c = texture(gtexture, tc) * vc;
	if (c.a < 0.05) discard;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l), c.rgb, 0.4) * vec3(0.86, 0.92, 1.0);
	c.a *= 0.55;
	// close drops: the big pixel streaks right in front of the camera fade out softly, so rain
	// reads as a calm veil instead of hard lines across the view
	float zl = 2.0 * near * far / max(far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near), 1e-4);
	c.a *= mix(0.18, 1.0, smoothstep(1.5, 7.0, zl));
	if (c.a < 0.02) discard;
	outColor = c;
}
