// Optical profile, spectral dispersion and lighting adapted from GPUI glass
// contributors (BSD-3-Clause). See THIRD_PARTY_NOTICES.md.
vec2 scenePoint(vec2 local) {
    return u_origin + mat2(u_transform.x, u_transform.z,
                          u_transform.y, u_transform.w) * local * u_geometry.y;
}
// The engine replaces the bound image with the live backdrop while preserving
// the linear sampler descriptor configured by the material's shader factory.
vec3 readScene(vec2 px) {
    vec2 uv = clamp(px, vec2(0.5), u_textureSize - 0.5) * (1. / u_textureSize);
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return texture(u_backdrop, uv).rgb;
}
vec3 sampleLocal(vec2 p) { return readScene(scenePoint(p)); }

// The backdrop has already been Gaussian filtered, before refraction. Integrate
// the mapped pixel footprint only where the lens compresses that source.
vec3 filteredScene(vec2 p, vec2 dx, vec2 dy) {
    float dxx = dot(dx, dx);
    float dyy = dot(dy, dy);
    float stretch2 = max(dxx, dyy);
    // The frost kernel bounds the backdrop's curvature: box-integrating a width
    // under 0.3 sigma moves a channel below half an 8-bit step, and under
    // 0.7 sigma a +-1/4 pair matches the four-point rule to the same precision.
    float sigma = u_optics.z * u_geometry.y;
    if (stretch2 <= max(2.25, 0.09 * sigma * sigma)) return readScene(p);
    vec2 major = dxx > dyy ? dx : dy;
    vec2 minor = dxx > dyy ? dy : dx;
    // Bound a grazing footprint while retaining subpixel integration at the rim.
    major *= min(1., 16. / max(sqrt(stretch2), 0.0001));
    vec3 result = vec3(0.);
    // With a frost kernel of at least 2px and a short minor axis, the ±¼ pair
    // equals its midpoint well below 8-bit precision; one read covers each step.
    if (sigma >= 2. && dot(minor, minor) <= 4.) {
        if (stretch2 <= 0.49 * sigma * sigma) {
            return (readScene(p - major * 0.25) + readScene(p + major * 0.25)) * 0.5;
        }
        for (int i = 0; i < 4; i++) {
            result += readScene(p + major * ((float(i) + 0.5) * 0.25 - 0.5));
        }
        return result * 0.25;
    }
    for (int i = 0; i < 4; i++) {
        vec2 step = major * ((float(i) + 0.5) * 0.25 - 0.5);
        result += readScene(p + step + minor * 0.25);
        result += readScene(p + step - minor * 0.25);
    }
    return result * 0.125;
}

#include "superellipse.glsl"

// Distance, outward direction and its length for a rounded rectangle/capsule.
// Beyond 26 points plus the corner's diagonal slack nothing reads the smooth
// field (the profile, reflections and highlights all end within 24 points),
// so the box depth stands in for it there.
vec4 shape(vec2 p) {
    vec2 rel = p - u_extent * 0.5;
    if (u_tintBias.w > .5) {
        vec2 qb = abs(rel) - u_extent*0.5;
        float boxDepth = -max(qb.x,qb.y);
        if (boxDepth > 26. + 0.4142136*min(u_geometry.x,min(u_extent.x,u_extent.y)*0.5)) return vec4(-boxDepth, 0., 0., 0.);
        return vec4(roundedSuperellipse(p), 1.);
    }
    float radius = min(u_geometry.x, min(u_extent.x,u_extent.y) * 0.5);
    vec2 q = abs(rel) - u_extent * 0.5 + radius;
    float d = min(max(q.x,q.y),0.) + length(max(q,0.)) - radius;
    vec2 n;
    float len = 1.;
    if (q.x > 0. && q.y > 0.) {
        n = sign(rel) * normalize(max(q,vec2(0.0001)));
    } else {
        n = q.x > q.y ? vec2(sign(rel.x),0.) : vec2(0.,sign(rel.y));
        len = smoothstep(0.,1.,abs(q.x-q.y));
        n *= len;
    }
    return vec4(d,n,len);
}
float highlight(float direction, float depth, float width,
                float spread, float focus, float softness, float aa) {
    float ramp = 1. - clamp(depth / width, 0., 1.);
    float core = mix(step(0.0001,ramp),ramp,softness);
    float band = core * clamp((width-depth)/aa+0.5,0.,1.)
                      * clamp(depth/aa+0.5,0.,1.);
    vec2 lobes = clamp((vec2(direction,-direction)-spread)/(1.-spread),0.,1.) * band;
    vec2 shaped = lobes / (1. + focus * (1.-lobes));
    return shaped.x + shaped.y;
}
// Clear-glass highlight color adjustment.
// It transforms backdrop color under the specular mask, not white stroke RGB.
vec3 vibrantHighlight(vec3 color, float strength) {
    vec3 transformed = vec3(
        dot(color,vec3(2.6492,-1.1803,-0.1189)),
        dot(color,vec3(-0.3507,1.8199,-0.1192)),
        dot(color,vec3(-0.3509,-1.1799,2.8809))) + 0.15;
    if (u_material.x > 1.5) {
        transformed = vec3(dot(color,vec3(1.3192,-0.0478,-0.0047)),
          dot(color,vec3(-0.0142,1.2856,-0.0048)),
          dot(color,vec3(-0.0142,-0.0476,1.3285))) + 0.2;
    } else if (u_material.x > 0.5 && u_material.y < 0.5) {
        transformed = vec3(dot(color,vec3(1.2024,-1.0014,-0.1010)),
          dot(color,vec3(-0.2976,0.4987,-0.1011)),
          dot(color,vec3(-0.2977,-1.0012,1.3989))) + 0.9;
    }
    return mix(color,clamp(transformed,0.,1.),clamp(strength,0.,1.));
}
vec3 radiance(vec3 base, vec3 reflected, float weight) {
    float y = dot(base,vec3(0.2126,0.7152,0.0722));
    float peak = max(max(reflected.r,reflected.g),reflected.b);
    float y2 = y*y;
    vec3 absorption = base * (vec3(peak)-reflected) * (y2*y2) * 0.3;
    absorption *= min(1.,0.08/max(dot(absorption,vec3(0.2126,0.7152,0.0722)),0.0001));
    float response = weight / (1. + weight);
    return clamp(base + ((1.-base)*reflected*mix(1.,(1.-y)*(1.-y)*(1.-y)*(1.-y),0.65)-absorption)*response,0.,1.);
}
void shadeGlass() {
    vec2 screen = FlutterFragCoord().xy;
    float det = u_transform.x*u_transform.w - u_transform.y*u_transform.z;
    if (abs(det) < 0.00001) { frag_color = vec4(0.); return; }
    mat2 inv = mat2(u_transform.w,-u_transform.z,-u_transform.y,u_transform.x)/det;
    vec2 local = inv * (screen-u_origin) / u_geometry.y;
    vec4 field = shape(local);
    float d = field.x;
    vec2 normal = field.yz;
    float aa = 1. / u_geometry.y;
    float depth = max(-d,0.);
    // Restrict the lens band to the available thickness to preserve a flat center.
    float edge = min(u_optics.x,min(u_extent.x,u_extent.y)*0.49);
    float t = clamp(1.+d/max(edge,0.001),0.,1.);
    float profile = 1.-sqrt(max(1.-t*t,0.));
    float displacement = min(u_optics.y, min(u_extent.x,u_extent.y)*0.55);
    // The lens offset vanishes with the profile, so the flat center skips the
    // direction arithmetic. The branch follows the band contour, so SIMD groups
    // stay coherent away from its boundary.
    vec2 direction = vec2(0.);
    vec2 offset = vec2(0.);
    if (profile > 0.) {
        vec2 centered = (local-u_extent*0.5)*vec2(1.,u_extent.x/u_extent.y);
        vec2 radial = centered/max(length(centered),0.0001);
        direction = mix(normal,radial,u_finish.w);
        direction = direction/max(length(direction),0.0001)*min(field.w,1.);
        offset = direction*displacement*profile;
    }
    vec2 samplePoint = scenePoint(local-offset);
    vec2 dx = vec2(1., 0.);
    vec2 dy = vec2(0., 1.);
    #if defined(IMPELLER_GRAPHICS_BACKEND)
    // Evaluate before per-fragment coverage branches so derivatives stay defined.
    dx = dFdx(samplePoint);
    dy = dFdy(samplePoint);
    aa = max(fwidth(d), 0.0001);
    #endif
    float coverage = clamp(0.5-d/aa,0.,1.);
    // The narrow exterior lobe darkens the sides between vertical highlights.
    float rimAlpha = 0.;
    if (u_material.x > 1.5 && u_finish.y > 0. && d > -0.5*aa) {
        float facing = clamp((abs(normal.x)-0.258819)/0.741181,0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float outerCoverage = clamp(0.5-(d-0.533333)/aa,0.,1.);
        rimAlpha = clamp(side*u_finish.y*0.46,0.,1.)*max(outerCoverage-coverage,0.);
    }
    if (coverage < 0.001) { frag_color = vec4(0.,0.,0.,rimAlpha); return; }
    vec3 color;
    if (u_optics.w > 0.001 && profile > 0.001) {
        vec2 split = mat2(u_transform.x, u_transform.z, u_transform.y, u_transform.w)
                   * (direction*(u_optics.w*(2.+displacement*0.12)*profile*u_geometry.y));
        // The outer bands are shared by both tap sets, so only the half-split
        // taps sit behind the divergent branch.
        vec3 outerA = filteredScene(samplePoint-split,dx,dy);
        vec3 center = filteredScene(samplePoint,dx,dy);
        vec3 outerB = filteredScene(samplePoint+split,dx,dy);
        if (dot(split,split) <= 0.2025 * u_optics.z*u_optics.z*u_geometry.y*u_geometry.y) {
            // Over the frost kernel the five bands equal three taps whose per-channel
            // weights match the zeroth to second moments of each band kernel.
            color = outerA*vec3(0.3575,0.095,-0.0025)
                  + center*vec3(0.645,0.81,0.645)
                  + outerB*vec3(-0.0025,0.095,0.3575);
        } else {
            color = outerA*vec3(0.22,0.04,0.01)
                  + filteredScene(samplePoint-split*0.5,dx,dy)*vec3(0.40,0.22,0.10)
                  + center*vec3(0.27,0.48,0.27)
                  + filteredScene(samplePoint+split*0.5,dx,dy)*vec3(0.10,0.22,0.40)
                  + outerB*vec3(0.01,0.04,0.22);
        }
    } else { color = filteredScene(samplePoint,dx,dy); }
    float luma = dot(color,vec3(0.2126,0.7152,0.0722));
    color = clamp(mix(vec3(luma),color,u_finish.x),0.,1.);
    color = clamp(mix(color,u_tint.rgb,u_tint.a) + u_geometry.w,0.,1.);
    // radiance() moves a channel by at most w/(1+w). Past the depth where both
    // weights fall below half an 8-bit step (w < 0.001965) the terms are
    // invisible, so the reflection reads stop there instead of at 24/4 points.
    // Both limits sit inside 24 points, so the depth test runs before their math.
    if (depth < 24. && u_finish.z > 0.001 && u_geometry.z > 0.001) {
        float invisible = 0.001965 / max(u_finish.z, 0.0001);
        float broadEnd = 24. * (1. - sqrt(min(invisible / 0.32, 1.)));
        float rimEnd = 4. * (1. - pow(min(invisible, 1.), 0.6666667));
        vec2 boundary = local-normal*d;
        vec2 tangent = vec2(-normal.y,normal.x);
        float reach = u_geometry.z;
        if (depth < rimEnd) {
            float edge = max(1.-depth/4.,0.);
            float rim = edge*sqrt(edge);
            // Reflection taps land outside the contour, where the backdrop is not
            // frosted; a cross of four taps one sigma apart stands in for it.
            vec2 tap = boundary+normal*(1.+depth*reach/12.);
            float s = u_optics.z * 0.85;
            vec3 reflected = s > 0.05
                ? (sampleLocal(tap+normal*s) + sampleLocal(tap-normal*s)
                 + sampleLocal(tap+tangent*s) + sampleLocal(tap-tangent*s)) * 0.25
                : sampleLocal(tap);
            color = radiance(color,reflected,u_finish.z*rim);
        }
        if (depth < broadEnd) {
            vec3 diffuse = (sampleLocal(boundary+normal*reach)
                          + sampleLocal(boundary+normal*reach*0.5+tangent*reach*0.4)
                          + sampleLocal(boundary+normal*reach*0.5-tangent*reach*0.4))/3.;
            float fade = 1.-depth/24.;
            color = radiance(color,diffuse,u_finish.z*fade*fade*0.32);
        }
    }
    if (u_material.x > 0.5 && u_material.x < 1.5) {
        bool dark = u_material.y > 0.5;
        bool bar = u_material.z > 1.5 && u_material.z < 2.5;
        float value = dot(color,vec3(0.2126,0.7152,0.0722));
        float mapped;
        if (bar) {
            float black = dark ? 0.1870968 : 0.5741935;
            float white = dark ? 0.8370968 : 1.03;
            mapped = mix(black + value*(white-black),1.,dark ? 0. : 0.25);
        } else {
            // Resting regular surfaces and buttons, measured against SwiftUI
            // over four neutral backdrops. Preserve chroma independently.
            vec4 levels = dark ? vec4(56.,106.,151.,174.) / 255.
                               : vec4(146.,177.,213.,241.) / 255.;
            vec3 intervals = vec3(63.,77.,63.) / 255.;
            vec3 slope = (levels.yzw-levels.xyz)/intervals;
            float x = value-26./255.;
            mapped = levels.x + slope.x*x
                   + (slope.y-slope.x)*max(value-89./255.,0.)
                   + (slope.z-slope.y)*max(value-166./255.,0.);
        }
        float saturation = bar ? (dark ? 1.3 : 1.1) : (dark ? 1.2 : 0.9);
        float chroma = bar && !dark ? 0.75 : 1.;
        color = clamp((color-vec3(value))*saturation*chroma + mapped,0.,1.);
    }
    if (u_material.w > 0.) {
        float value = dot(color,vec3(0.2126,0.7152,0.0722));
        vec3 tinted = clamp(u_tintBias.rgb + u_tintSlope.rgb * value,0.,1.);
        color = mix(color,tinted,u_material.w);
    }
    // Vertical key/fill lighting has a sharp rim and a softer eight-point lobe.
    // Every lobe's band is zero past its width plus half the AA step.
    bool clear = u_material.x > 1.5;
    if (depth < (clear ? 8. : 1.) + aa) {
        float light;
        if (clear) {
            float sharp = highlight(-normal.y,depth,1.,0.130526,0.,0.75,aa);
            float diffuse = highlight(-normal.y,depth,8.,0.593419,11.333333,1.,aa);
            light = sharp + diffuse;
        } else {
            light = highlight(dot(normal,vec2(-0.70710678,-0.70710678)),depth,1.,0.,0.,0.7,aa);
        }
        // Both matrices are mixed in by weight; at zero weight skip their arithmetic.
        if (light*u_finish.y > 0.) color = vibrantHighlight(color,light*u_finish.y);
    }
    if (u_tintSlope.w > 0.) {
        vec3 pressed = vec3(dot(color,vec3(1.1575,-0.1431,-0.0144)),
            dot(color,vec3(-0.0425,1.0570,-0.0145)),
            dot(color,vec3(-0.0426,-0.1430,1.1856))) + 0.05;
        color = mix(color,clamp(pressed,0.,1.),u_tintSlope.w * 0.9);
    }
    frag_color = vec4(color*coverage,coverage+rimAlpha);
}
