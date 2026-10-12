#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_textureSize;
uniform vec2 u_origin;
uniform vec2 u_extent;
uniform vec4 u_geometry; // pixel ratio, lift, radius, continuous contour.
uniform vec4 u_shapeA;
uniform vec4 u_shapeB;
uniform vec4 u_shapeC;
uniform vec4 u_shapeD;
uniform vec4 u_curve[65];
uniform vec2 u_effect; // Foreground displacement magnitude and SDF depth.
uniform sampler2D u_content;
out vec4 frag_color;

#include "superellipse.glsl"

vec4 readContent(vec2 p) {
    vec2 uv = p / u_textureSize;
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1. - uv.y;
    #endif
    #endif
    if (any(lessThan(uv, vec2(0.))) || any(greaterThan(uv, vec2(1.)))) return vec4(0.);
    return texture(u_content, uv);
}
void main() {
    vec2 pixel = FlutterFragCoord().xy;
    vec2 p = pixel / u_geometry.x - u_origin;
    vec3 field;
    if (u_geometry.w > .5 && u_geometry.z > .001) {
        field = roundedSuperellipse(p);
    } else {
        float r = min(u_geometry.z, min(u_extent.x, u_extent.y)*.5);
        vec2 rel = p-u_extent*.5;
        vec2 q = abs(rel)-u_extent*.5+r;
        float d = min(max(q.x,q.y),0.)+length(max(q,0.))-r;
        vec2 n = q.x > 0. && q.y > 0. ? sign(rel)*normalize(max(q,vec2(.0001))) :
                 q.x > q.y ? vec2(sign(rel.x),0.) : vec2(0.,sign(rel.y));
        field = vec3(d,n);
    }
    if (field.x >= 0.) { frag_color = readContent(pixel); return; }
    // Native ContentLensingView uses -14 displacement with an 11.2-point SDF.
    // Pull source samples inward near the rim: glyphs bulge across the contour
    // while the flat center keeps its ordinary size. This pass never samples
    // or grades the page/housing below the foreground.
    float t = clamp(1.+field.x/u_effect.y,0.,1.);
    float profile = 1.-sqrt(max(1.-t*t,0.));
    vec2 displaced = pixel-field.yz*(u_effect.x*u_geometry.y*profile*u_geometry.x);
    frag_color = readContent(displaced);
}
