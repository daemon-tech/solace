#version 330 compatibility
uniform sampler2D gtexture;
in vec2 texcoord;
in vec4 vcolor;
layout(location = 0) out vec4 outColor;
void main() {
	vec4 c = texture(gtexture, texcoord) * vcolor;
	if (c.a < 0.1) discard;
	outColor = c;
}
