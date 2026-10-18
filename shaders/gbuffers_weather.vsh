#version 330 compatibility
// rain and snow: plain textured quads
out vec2 tc;
out vec4 vc;
void main() {
	gl_Position = ftransform();
	tc = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vc = gl_Color;
}
