#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
out vec2 texcoord;
out vec4 vcolor;
void main() {
	gl_Position = ftransform();
	gl_Position.xyz = celDistort(gl_Position.xyz);
	texcoord = gl_MultiTexCoord0.xy;
	vcolor = gl_Color;
}
