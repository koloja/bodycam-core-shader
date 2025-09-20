#version 150

out vec2 texCoord;

const vec2 corners[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2(-1.0,  1.0),
    vec2( 1.0,  1.0)
);

void main() {
    vec2 pos = corners[gl_VertexID];
    gl_Position = vec4(pos, 0.0, 1.0);
    texCoord = pos * 0.5 + 0.5; // clip-space -> [0,1] UV
}
