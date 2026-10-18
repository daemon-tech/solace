#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform int biome_category;
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
	vec3 rollVP = vec3(0.0); bool rolled = false;
#ifdef WATER_ROLL
	// optional rolling swell on ocean surfaces: still water tops sink by up to 0.6 blocks in long waves,
	// stepped to 1/8 block for a blocky look (applies to all still water when enabled)
	if (int(mc_Entity.x + 0.5) == 10001 && gl_Normal.y > 0.9) {
		vec4 vp = gl_ModelViewMatrix * gl_Vertex;
		vec3 wp = (gbufferModelViewInverse * vp).xyz + cameraPosition;
		vec2 rq = wp.xz - cameraPosition.xz + mod(cameraPosition.xz, 4096.0); // same frame as composite
		float h = floor(rollWave(rq, frameTimeCounter) * 8.0 + 0.5) / 8.0;
		vec3 wpD = wp - vec3(0.0, (1.0 - h) * 0.6 * WATER_ROLL_HEIGHT, 0.0);
		vp = gbufferModelView * vec4(wpD - cameraPosition, 1.0);
		gl_Position = gl_ProjectionMatrix * vp;
		rollVP = vp.xyz; rolled = true;
	}
#endif
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vcolor = gl_Color;
	vnormal = safeNormalize(gl_NormalMatrix * gl_Normal, vec3(0.0, 0.0, 1.0));
	viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	if (rolled) viewPos = rollVP;
	worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
	int eid = int(mc_Entity.x + 0.5);
	isWater = eid == 10001 ? 1 : (eid == 10013 ? 2 : 0); // 2 = purple light source (nether portal)
}
