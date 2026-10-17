#version 330 compatibility
in vec4 vcolor;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() { outColor = vcolor; }
