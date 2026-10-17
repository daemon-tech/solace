#version 330 compatibility
out vec2 tc;
void main() { gl_Position = ftransform(); tc = gl_MultiTexCoord0.xy; }
