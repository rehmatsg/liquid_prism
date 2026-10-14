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
uniform vec4 u_effect; // Displacement/depth (pt), effective split (px), band (pt).
uniform sampler2D u_content;
out vec4 frag_color;

#include "superellipse.glsl"
#include "chromatic_fringe.glsl"

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
    // Outside the contour's box the field is positive: pass the pixel through
    // without the contour search. The filter covers the whole foreground row,
    // most of it beyond the pill.
    if (any(lessThan(p, vec2(0.))) || any(greaterThan(p, u_extent))) {
        frag_color = readContent(pixel);
        return;
    }
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
    vec4 green = readContent(displaced);
    float depth = -field.x;
    if (u_effect.z > 0. && u_effect.w > 0. && depth < u_effect.w) {
        // Glyphs fringe at half the backdrop's split, half blended with the
        // unshifted sample: a full split on thin strokes left opaque pure
        // primaries wherever one channel alone hit the glyph, where native
        // shows a soft tint. Fitted by eye to the iOS 27 segmented capture.
        vec2 shift = chromaticDirection(field.yz) *
            (.25*max(chromaticWeight(depth,u_effect.w),0.)*u_effect.z);
        vec4 red = readContent(displaced-shift);
        vec4 blue = readContent(displaced+shift);
        // Each source channel is already premultiplied and <= its own alpha,
        // so the union alpha bounds all three; mixing two valid premultiplied
        // colours stays valid.
        vec4 split = vec4(red.r,green.g,blue.b,max(max(red.a,green.a),blue.a));
        frag_color = mix(green,split,.5);
    } else { frag_color = green; }
}
