#version 330 compatibility
uniform sampler2D gtexture;
uniform int renderStage;
in vec2 texcoord;
in vec4 vcolor;
flat in int sWater;
layout(location = 0) out vec4 outColor;
void main() {
	vec4 c = texture(gtexture, texcoord) * vcolor;
	if (c.a < 0.1) discard;
	// translucent terrain (stained glass, ice; water keeps its old behaviour) always marks itself with alpha < 0.95, so the
	// lighting can tell it from opaque casters even when a pack's glass texture is fully opaque
	if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && sWater == 0) c.a = clamp(c.a, 0.25, 0.75);
	else c.a = sWater == 2 ? 0.97 : 1.0; // leaves mark themselves so the ground below can get soft sun spots
	outColor = c;
}
