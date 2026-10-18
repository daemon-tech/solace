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
out vec3 cwpos;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;
in vec4 mc_Entity;
void main() {
	gl_Position = ftransform();
	int eid = int(mc_Entity.x + 0.5);
	isFoliage = eid == 10002 ? 1 : (eid == 10003 ? 2 : (eid == 10004 ? 3 : (eid == 10010 ? 4 : 0)));
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
	if (isFoliage == 1) {
		// gentle wind sway: slow main wave + small flutter, phase from world position
		vec3 wp = cwpos;
		float t = frameTimeCounter;
		vec2 sway = vec2(sin(t * 1.4 + wp.x * 0.45 + wp.z * 0.20), cos(t * 1.1 + wp.z * 0.40 + wp.x * 0.15)) * 0.045
		          + vec2(sin(t * 3.7 + wp.y * 1.3 + wp.x), sin(t * 3.1 + wp.z * 1.1)) * 0.012;
		vec4 vp = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		vp.xz += sway * WAVING_STRENGTH;
		gl_Position = gl_ProjectionMatrix * (gbufferModelView * vp);
	}
#endif
	shadowClip = shadowProjection * (shadowModelView * playerPos);
}
