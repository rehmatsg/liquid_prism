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
uniform vec4 u_material; // Recipe (0 custom, 1 regular, 2 clear, 3 lens), dark, role, tint alpha.
uniform vec4 u_tintRed;
uniform vec4 u_tintGreen;
uniform vec4 u_tintBlue;
uniform vec4 u_state;    // Press, smooth contour, absence, tab pill glint.
uniform vec4 u_shapeA;
uniform vec4 u_shapeB;
uniform vec4 u_shapeC;
uniform vec4 u_shapeD;     // cos(top arc span), cos(right arc span), chromatic band (pt), unused.
// Superellipse arc vertices at k*pi/256, k = 0..64: top octant in xy, right in zw.
uniform vec4 u_curve[65];
// Uniform-only terms, computed once per surface in Dart rather than once per
// fragment: [0] lens band reciprocal, displacement, split scale, split
// threshold (px^2); [1] frost sigma (px), single-read and pair footprint
// thresholds (px^2), chromatic split (px); [2] broad and rim reflection ends, rim tap
// spacing, radius; [3] reflection end, 1/dpr, extent aspect, smooth bypass depth.
uniform vec4 u_derived[4];
uniform sampler2D u_backdrop;
out vec4 frag_color;

#include "glass_core.glsl"
void main() { shadeGlass(); }
