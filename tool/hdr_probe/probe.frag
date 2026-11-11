#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 u_size;
out vec4 frag_color;
void main() {
    // Nonlinear extended-sRGB values: the last patch is ~1.20 in linear light.
    float x = FlutterFragCoord().x / u_size.x;
    float value = x < .25 ? .5 : x < .5 ? 1. : x < .75 ? 1.04 : 1.0832683;
    frag_color = vec4(vec3(value), 1.);
}
