// Solace - shared vertex stage for lit gbuffers
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
out vec2 texcoord;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 vnormal;
out vec4 shadowClip;
flat out int isFoliage;
flat out int isLeaf;
flat out int lightId;
out float windG; // gust strength at this vertex (sheen) // 0 none, 1 warm, 2 soul, 3 red, 4 purple, 5 cool, 6 green
out vec3 cwpos;
out float vTop; // 1 at the top vertices of a plant sprite, 0 at the base
flat out int isGrassPlant;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_midBlock;
void main() {
	gl_Position = ftransform();
	int eid = int(mc_Entity.x + 0.5);
	lightId = (eid >= 10010 && eid <= 10017) ? eid - 10009 : (eid == 10018 ? 1 : (eid == 10019 ? 2 : 0));
	isLeaf = eid == 10002 ? 1 : 0;
	isFoliage = (eid == 10002 || eid == 10006) ? 1 : (eid == 10003 ? 2 : (eid == 10004 ? 3 : (lightId > 0 ? 4 : (eid == 10007 ? 5 : 0))));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vcolor = gl_Color;
	// particles may have no normal -> keep it NaN-free
	vnormal = safeNormalize(gl_NormalMatrix * gl_Normal, vec3(0.0, 0.0, 1.0));
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 playerPos = gbufferModelViewInverse * viewPos;
	// small normal offset against shadow acne
	playerPos.xyz += mat3(gbufferModelViewInverse) * vnormal * 0.05;
	cwpos = playerPos.xyz + cameraPosition;
	vTop = (gl_MultiTexCoord0.y < mc_midTexCoord.y) ? 1.0 : 0.0;
	isGrassPlant = eid == 10006 ? 1 : 0;
#ifdef WAVING_FOLIAGE
	bool plant = eid == 10006 || eid == 10007 || eid == 10008;
	if (isFoliage == 1 || plant || eid == 10009) {
		vec4 vp = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		float top = (gl_MultiTexCoord0.y < mc_midTexCoord.y) ? 1.0 : 0.0;
		vec2 wo = windOffset(plant ? 1 : 2, cwpos, top, frameTimeCounter);
		if (eid == 10009) { vec3 nW = mat3(gbufferModelViewInverse) * vnormal; wo -= nW.xz * dot(wo, nW.xz); } // vines slide along their wall, never into it
		vp.xz += wo;
		if (plant) vp.xz += playerPush(vp.xyz, top);
		gl_Position = gl_ProjectionMatrix * (gbufferModelView * vp);
	}
	if (eid == 10020) {
		// sugar cane and bamboo: the stalk bends as one piece; the offset depends only on world position, so stacked
		// segments stay joined, and a slow ripple runs up the stalk; gusts lean it downwind
		vec4 vp = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		vec3 w = vp.xyz + cameraPosition;
		vp.xz += reedOffset(w, floor(w + at_midBlock.xyz / 64.0), frameTimeCounter);
		gl_Position = gl_ProjectionMatrix * (gbufferModelView * vp);
	}
#endif
#ifdef LANTERN_SWAY
	if (eid == 10018 || eid == 10019) {
		// hanging lanterns swing gently on their chain like a pendulum (pivot at the top of the block), more in a gust
		vec4 vp = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		vec3 bc = floor(vp.xyz + cameraPosition + at_midBlock.xyz / 64.0) + 0.5; // block centre
		float d = clamp(bc.y + 0.5 - (vp.y + cameraPosition.y), 0.0, 1.0);
		float g = windGust(bc.xz, frameTimeCounter);
		float ph = fract(sin(dot(bc.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.28;
		vec2 wd = windDirT(frameTimeCounter);
		float sw = sin(frameTimeCounter * 1.6 + ph) * (0.05 + 0.10 * g) * LANTERN_SWAY;
		float sw2 = sin(frameTimeCounter * 1.1 + ph * 1.7) * 0.025 * LANTERN_SWAY;
		vp.xz += (wd * sw + vec2(-wd.y, wd.x) * sw2) * d;
		gl_Position = gl_ProjectionMatrix * (gbufferModelView * vp);
	}
#endif
	windG = 0.0;
#ifdef WIND_GUSTS
	windG = windGust(cwpos.xz, frameTimeCounter);
#endif
	shadowClip = shadowProjection * (shadowModelView * playerPos);
}
