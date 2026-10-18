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
flat out int lightId;
out float windG; // gust strength at this vertex (sheen) // 0 none, 1 warm, 2 soul, 3 red, 4 purple, 5 cool, 6 green
out vec3 cwpos;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
void main() {
	gl_Position = ftransform();
	int eid = int(mc_Entity.x + 0.5);
	lightId = (eid >= 10010 && eid <= 10015) ? eid - 10009 : 0;
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
#ifdef WAVING_FOLIAGE
	bool plant = eid == 10006 || eid == 10007;
	if (isFoliage == 1 || plant) {
		vec4 vp = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		float top = (gl_MultiTexCoord0.y < mc_midTexCoord.y) ? 1.0 : 0.0;
		vp.xz += windOffset(plant ? 1 : 2, cwpos, top, frameTimeCounter);
		gl_Position = gl_ProjectionMatrix * (gbufferModelView * vp);
	}
#endif
	windG = 0.0;
#ifdef WIND_GUSTS
	windG = windGust(cwpos.xz, frameTimeCounter);
#endif
	shadowClip = shadowProjection * (shadowModelView * playerPos);
}
