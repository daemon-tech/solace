#version 330 compatibility
uniform sampler2D colortex0;
in vec2 uv;
layout(location = 0) out vec4 outColor;
void main() {
	vec3 c = texture(colortex0, uv).rgb;
	if (any(isnan(c))) c = vec3(0.0);
	outColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
