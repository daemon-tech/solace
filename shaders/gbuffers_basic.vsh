#version 330 compatibility
out vec4 vcolor;
void main() { gl_Position = ftransform(); vcolor = gl_Color; }
