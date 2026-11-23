#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_textureSize;
uniform vec2 u_origin;
uniform vec2 u_extent;
uniform vec4 u_geometry;
uniform vec4 u_shapeA;
uniform vec4 u_shapeB;
uniform vec4 u_shapeC;
uniform vec4 u_shapeD;
uniform vec4 u_curve[65];
uniform vec4 u_effect;
uniform float u_tone;
uniform float u_wrapper;
uniform sampler2D u_content;
out vec4 frag_color;

#include "superellipse.glsl"
#include "chromatic_fringe.glsl"

float fieldProfile(float depth, float h) {
    float t = clamp(1.-depth/h,0.,1.);
    return 1.-sqrt(max(1.-t*t,0.));
}
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
    vec4 result;
    if (any(lessThan(p, vec2(0.))) || any(greaterThan(p, u_extent))) {
        result = readContent(pixel);
    } else {
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
        if (field.x >= 0.) {
            result = readContent(pixel);
        } else {
            float depth = -field.x;
            float lift = u_geometry.y;
            float outer = u_wrapper*lift*fieldProfile(depth,u_effect.y);
            float inner = u_effect.x*lift*fieldProfile(depth+outer,u_effect.y);
            vec2 displaced = pixel-field.yz*((outer+inner)*u_geometry.x);
            vec4 green = readContent(displaced);
            float size = min(u_extent.x,u_extent.y)/73.6;
            float band = u_effect.w*size;
            if (u_effect.z > 0. && band > 0. && depth < 3.1*band) {
                vec2 shift = chromaticDirection(field.yz) *
                    (.77*glyphFringeWeight(depth,band)*size*u_effect.z);
                vec4 red = readContent(displaced-shift);
                vec4 blue = readContent(displaced+shift);
                vec4 split = vec4(red.r,green.g,blue.b,max(max(red.a,green.a),blue.a));
                split.rgb += (split.a-vec3(red.a,green.a,blue.a))*u_tone;
                result = mix(green,split,.5);
            } else {
                result = green;
            }
        }
    }
    frag_color = result;
}
