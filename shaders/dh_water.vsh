#version 330 compatibility
// Solace - Distant Horizons LOD terrain (simple cel lighting to match near terrain)
out vec4 vcolor;
out vec3 vnormal;
out vec2 lm;
out vec3 vpos;
void main() {
	gl_Position = ftransform();
	vpos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	vcolor = gl_Color;
	vnormal = normalize(gl_NormalMatrix * gl_Normal);
	lm = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
}
