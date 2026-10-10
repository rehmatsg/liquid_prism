// Optical profile, five-band dispersion and key/fill color equations adapted
// from GPUI glass contributors (BSD-3-Clause). See THIRD_PARTY_NOTICES.md.
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_textureSize;
uniform vec2 u_origin;
uniform vec2 u_extent;
uniform vec4 u_transform;
uniform vec4 u_optics;   // Edge width, displacement, frost, dispersion.
uniform vec4 u_tint;
uniform vec4 u_finish;   // Saturation, light, reflection, splay.
uniform vec4 u_geometry; // Radius, device pixel ratio, reflection reach, face brightness.
uniform vec4 u_material; // Recipe (0 custom, 1 regular, 2 clear), dark, role, tint alpha.
uniform vec4 u_tintSlope;
uniform vec4 u_tintBias;
uniform vec4 u_shapeA;
uniform vec4 u_shapeB;
uniform vec4 u_shapeC;
uniform vec4 u_shapeD;     // cos(top arc span), cos(right arc span), unused, unused.
// Superellipse arc vertices at k*pi/256, k = 0..64: top octant in xy, right in zw.
uniform vec4 u_curve[65];
uniform sampler2D u_backdrop;
out vec4 frag_color;

#include "glass_core.glsl"
void main() { shadeGlass(); }
