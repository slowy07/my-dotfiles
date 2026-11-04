#version 440
// точечная маска: элемент превращается в матрицу точек-светодиодов. Цвет точки берётся из центра её клетки —
// поэтому все точки одного размера и ровного тона, как Glyph на спинке телефона. Цвет — только яркость: монохром
// собрать: qsb --qt6 -o dots.frag.qsb dots.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;  // размер элемента, px
    float pitch; // шаг сетки, px. Не step: это встроенная функция GLSL, SPIRV-Cross переименует её в _step и Qt не найдёт uniform
    float circ;  // 1 — только точки внутри круга (обложки)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;
    float r = pitch * 0.3; // как radial-gradient(#000 40%, transparent 44%) в концепте
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    if (circ > 0.5 && distance(c, size * 0.5) > min(size.x, size.y) * 0.5) m = 0.0;
    vec4 t = texture(source, c / size);
    float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)); // монохром: цветные обложки тоже серые
    fragColor = vec4(vec3(l), t.a) * m * qt_Opacity;
}
