// Optical profile, five-band dispersion and key/fill color equations adapted
// from GPUI glass contributors (BSD-3-Clause). See THIRD_PARTY_NOTICES.md.
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_textureSize;
uniform vec2 u_origin;
uniform vec2 u_extent;
uniform vec4 u_transform;
uniform vec4 u_optics;
uniform vec4 u_tint;
uniform vec4 u_finish;
uniform vec4 u_geometry;
uniform vec4 u_material;
uniform vec4 u_tintRed;
uniform vec4 u_tintGreen;
uniform vec4 u_tintBlue;
uniform vec4 u_state;
uniform vec4 u_shapeA;
uniform vec4 u_shapeB;
uniform vec4 u_shapeC;
uniform vec4 u_shapeD;
uniform vec4 u_curve[65];
uniform vec4 u_derived[4];
uniform vec4 u_face;
uniform vec4 u_frost;
uniform float u_headroom;
uniform sampler2D u_backdrop;
out vec4 frag_color;

#include "glass_core.glsl"
void main() { shadeGlass(); }
