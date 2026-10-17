#version 330 compatibility
out vec4 vcolor;
out vec3 vnormal;
void main() { gl_Position = ftransform(); vcolor = gl_Color; vnormal = gl_NormalMatrix * gl_Normal; }
