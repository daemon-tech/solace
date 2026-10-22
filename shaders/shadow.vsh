#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_midBlock;
out vec2 texcoord;
out vec4 vcolor;
flat out int sWater;
void main() {
	vec4 vp = shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
#ifdef WAVING_FOLIAGE
	int eid = int(mc_Entity.x + 0.5);
	bool plant = eid == 10006 || eid == 10007 || eid == 10008;
	if (plant || eid == 10002 || eid == 10009 || eid == 10021) {
		float top = (gl_MultiTexCoord0.y < mc_midTexCoord.y) ? 1.0 : 0.0;
		vec2 wo = windOffset(plant ? 1 : 2, vp.xyz + cameraPosition, top, frameTimeCounter);
		if (eid == 10009 || eid == 10021) wo -= gl_Normal.xz * dot(wo, gl_Normal.xz); // vines slide along their wall
		vp.xz += wo;
		if (plant) vp.xz += playerPush(vp.xyz, top);
	}
	if (eid == 10020) { vec3 w = vp.xyz + cameraPosition; vp.xz += reedOffset(w, floor(w + at_midBlock.xyz / 64.0), frameTimeCounter); } // reed shadows sway with the stalk
#endif
	gl_Position = gl_ProjectionMatrix * (shadowModelView * vp);
	gl_Position.xyz = celDistort(gl_Position.xyz);
	texcoord = gl_MultiTexCoord0.xy;
	vcolor = gl_Color;
	sWater = int(mc_Entity.x + 0.5) == 10001 ? 1 : (int(mc_Entity.x + 0.5) == 10002 ? 2 : 0); // 2 = leaves (sun spots)
}
