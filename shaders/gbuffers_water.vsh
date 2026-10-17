#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
in vec4 mc_Entity;
out vec2 texcoord;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 vnormal;
out vec3 viewPos;
out vec3 worldPos;
flat out int isWater;
void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vcolor = gl_Color;
	vnormal = safeNormalize(gl_NormalMatrix * gl_Normal, vec3(0.0, 0.0, 1.0));
	viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
	isWater = int(mc_Entity.x + 0.5) == 10001 ? 1 : 0;
}
