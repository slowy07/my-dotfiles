#version 440
// dot mask: the element becomes a matrix of LED dots. The dot color is taken from the center of its cell,
// so all dots are the same size and even tone, like Glyph on the back of the phone. Color is brightness only: monochrome
// build: qsb --qt6 -o dots.frag.qsb dots.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;  // element size, px
    float pitch; // grid pitch, px. Not step: it is a GLSL built-in, SPIRV-Cross renames it to _step and Qt will not find the uniform
    float circ;  // 1 means dots only inside the circle (covers)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;
    float r = pitch * 0.3; // like radial-gradient(#000 40%, transparent 44%) in the concept
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    if (circ > 0.5 && distance(c, size * 0.5) > min(size.x, size.y) * 0.5) m = 0.0;
    vec4 t = texture(source, c / size);
    float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)); // monochrome: colored covers are grey too
    fragColor = vec4(vec3(l), t.a) * m * qt_Opacity;
}
