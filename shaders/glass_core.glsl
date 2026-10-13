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
    float sigma = u_derived[1].x;
    if (stretch2 <= u_derived[1].y) return readScene(p);
    vec2 major = dxx > dyy ? dx : dy;
    // Bound a grazing footprint while retaining subpixel integration at the rim.
    major *= min(1., 16. / max(sqrt(stretch2), 0.0001));
    // Integrate along the major axis only. The minor axis of a compressed
    // footprint stays within the frost kernel, where its +-1/4 pair equals the
    // midpoint; a frost of at least 2px lets a short footprint use one pair.
    if (sigma >= 2. && stretch2 <= u_derived[1].z) {
        return (readScene(p - major * 0.25) + readScene(p + major * 0.25)) * 0.5;
    }
    vec3 result = vec3(0.);
    for (int i = 0; i < 4; i++) {
        result += readScene(p + major * ((float(i) + 0.5) * 0.25 - 0.5));
    }
    return result * 0.25;
}

#include "superellipse.glsl"

// Distance, outward direction and its length for a rounded rectangle/capsule.
// Nothing reads the smooth field deeper than the reflections (24 points), the
// lens band, or the coverage ramp and its derivative quad. The round-corner
// depth of the same radius exceeds the smooth-corner depth by at most 0.0181 r
// over the geometry table, so it proves that bound and its value stands in
// beyond it; u_derived carries the resulting limit.
vec4 shape(vec2 p) {
    vec2 rel = p - u_extent * 0.5;
    float radius = u_derived[2].w;
    if (u_state.y > .5) {
        vec2 qb = abs(rel) - u_extent*0.5 + radius;
        float roundDepth = -(min(max(qb.x,qb.y),0.) + length(max(qb,0.)) - radius);
        if (roundDepth > u_derived[3].w) return vec4(-roundDepth, 0., 0., 0.);
        return vec4(roundedSuperellipse(p), 1.);
    }
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
    if (u_material.x > 2.5) {
        // The lifted tab lens has its own, much quieter key/fill matrix.
        transformed = vec3(dot(color,vec3(1.1202,-0.1894,-0.0190)),
          dot(color,vec3(-0.0563,0.9871,-0.0191)),
          dot(color,vec3(-0.0563,-0.1893,1.1574))) + 0.1471;
    } else if (u_material.x > 1.5) {
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
// Saturation and tint grading of the sampled backdrop.
vec3 gradeInput(vec3 color) {
    float luma = dot(color,vec3(0.2126,0.7152,0.0722));
    color = clamp(mix(vec3(luma),color,u_finish.x),0.,1.);
    return clamp(mix(color,u_tint.rgb,u_tint.a) + u_geometry.w,0.,1.);
}
// Material face remap and the optional tint matrix.
vec3 gradeFace(vec3 color) {
    if (u_material.x > .5 && u_material.x < 2.5) {
        // Extracted iOS 27 gray-backdrop glassBackground face inputs. The
        // optical/compositing implementation remains this package's renderer.
        bool dark = u_material.y > .5;
        bool clear = u_material.x > 1.5;
        float value = dot(color,vec3(.2126,.7152,.0722));
        float black = clear || dark ? .125 : .4000000059604645;
        float white = clear ? 1.0800000429153442 :
            (dark ? 1.100000023841858 : 1.0299999713897705);
        float saturation = clear ? 1.059999942779541 :
            (dark ? 1.399999976158142 : 1.2000000476837158);
        color = (color-vec3(value))*saturation + mix(black,white,value);
        float fill = clear || dark ? 0. : .20000000298023224;
        color = clamp(mix(color,vec3(1.),fill),0.,1.);
    }
    if (u_material.w > 0.) {
        vec4 inputColor = vec4(color,1.);
        vec3 tinted = clamp(vec3(dot(u_tintRed,inputColor),
            dot(u_tintGreen,inputColor),dot(u_tintBlue,inputColor)),0.,1.);
        color = mix(color,tinted,u_material.w);
    }
    return color;
}
vec3 gradePressed(vec3 color) {
    if (u_state.x > 0.) {
        vec3 pressed = vec3(dot(color,vec3(1.1575,-0.1431,-0.0144)),
            dot(color,vec3(-0.0425,1.0570,-0.0145)),
            dot(color,vec3(-0.0426,-0.1430,1.1856))) + 0.05;
        color = mix(color,clamp(pressed,0.,1.),u_state.x * 0.9);
    }
    return color;
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
    float aa = u_derived[3].y;
    float depth = max(-d,0.);
    // The lens band is limited to the available thickness to preserve a flat
    // center; its reciprocal and the displacement arrive precomputed.
    float t = clamp(1.+d*u_derived[0].x,0.,1.);
    float profile = 1.-sqrt(max(1.-t*t,0.));
    float displacement = u_derived[0].y;
    // The lens offset vanishes with the profile, so the flat center skips the
    // direction arithmetic. The branch follows the band contour, so SIMD groups
    // stay coherent away from its boundary.
    vec2 direction = vec2(0.);
    vec2 offset = vec2(0.);
    if (profile > 0.) {
        vec2 centered = (local-u_extent*0.5)*vec2(1.,u_derived[3].z);
        vec2 radial = centered/max(length(centered),0.0001);
        direction = mix(normal,radial,u_finish.w);
        direction = direction/max(length(direction),0.0001)*min(field.w,1.);
        offset = direction*displacement*profile;
    }
    // The lifted tab lens also displaces the underlying housing across its
    // face. Native uses a separate 36-point SDF with displacement amount 9;
    // the narrow rim above cannot produce this minification on its own.
    // Sample farther out along the SDF normal, so the housing seen through
    // the lens is smaller. The tab foreground is painted after this pass.
    vec2 underlayOffset = vec2(0.);
    if (u_material.x > 2.5 && u_material.x < 3.5 && u_material.z < 8.5) {
        float underlayT = clamp(1.-depth/36.,0.,1.);
        float underlayProfile = 1.-sqrt(max(1.-underlayT*underlayT,0.));
        // All selection lenses share this field. The slider (role 9) opts out:
        // its knob grows, but the track inside keeps its normal thickness.
        // Labels/icons are painted after the lens at their normal size.
        float underlayAmount = displacement;
        underlayOffset = normal*underlayAmount*underlayProfile;
    }
    vec2 samplePoint = scenePoint(local+underlayOffset-offset);
    vec2 dx = vec2(1., 0.);
    vec2 dy = vec2(0., 1.);
    #if defined(IMPELLER_GRAPHICS_BACKEND)
    // Evaluate before per-fragment coverage branches so derivatives stay defined.
    dx = dFdx(samplePoint);
    dy = dFdy(samplePoint);
    aa = max(fwidth(d), 0.0001);
    #endif
    // Past every band that reaches inward (lens, reflections, highlights, the
    // tab lens's underlay and shade) a fragment is one undisplaced read and
    // its grading. The derivatives above are evaluated first, and an extra AA
    // step keeps this exit clear of the coverage ramp and the band edges.
    float interiorEnd = max(1./u_derived[0].x, u_derived[3].x);
    interiorEnd = max(interiorEnd, (u_material.x > 1.5 ? 8. : 1.) + aa);
    if (u_material.x > 2.5 && u_material.x < 3.5) {
        if (u_material.z < 8.5) interiorEnd = max(interiorEnd, 36.);
        interiorEnd = max(interiorEnd, 16.*u_extent.y/70.);
    }
    if (depth > interiorEnd + aa) {
        vec3 face = gradePressed(gradeFace(gradeInput(readScene(scenePoint(local)))));
        frag_color = vec4(face, 1.) * clamp(1.-u_state.z,0.,1.);
        return;
    }
    float coverage = clamp(0.5-d/aa,0.,1.);
    // The narrow exterior lobe darkens the sides between vertical highlights.
    float rimAlpha = 0.;
    if (u_material.x > 1.5 && u_material.x < 3.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        float facing = clamp((abs(normal.x)-0.258819)/0.741181,0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float outerCoverage = clamp(0.5-(d-0.533333)/aa,0.,1.);
        rimAlpha = clamp(side*u_finish.y*0.46,0.,1.)*max(outerCoverage-coverage,0.);
    }
    // Native regular glassBackground negative key/fill highlight. The effect
    // occupies the exterior 0.533333-point band; its -0.3 color bias darkens
    // a white backdrop where the ordinary positive specular pass saturates.
    if (u_material.x > .5 && u_material.x < 1.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        float spread = u_material.y > .5 ? 0.2588190451 : -0.2756373558;
        float facing = clamp((abs(normal.x)-spread)/(1.-spread),0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float outerCoverage = clamp(0.5-(d-0.5333333333)/aa,0.,1.);
        rimAlpha = clamp(side*u_finish.y*0.3,0.,1.)*
                   max(outerCoverage-coverage,0.);
    }
    // u_state.z is absence, so the reserved zero default stays fully present.
    // A premultiplied fade composites the glass over the live backdrop.
    float presence = clamp(1.-u_state.z,0.,1.);
    if (coverage < 0.001) { frag_color = vec4(0.,0.,0.,rimAlpha*presence); return; }
    vec3 color;
    if (u_optics.w > 0.001 && profile > 0.001) {
        vec2 split = mat2(u_transform.x, u_transform.z, u_transform.y, u_transform.w)
                   * (direction*(u_derived[0].z*profile));
        // The outer bands are shared by both tap sets, so only the half-split
        // taps sit behind the divergent branch.
        vec3 outerA = filteredScene(samplePoint-split,dx,dy);
        vec3 center = filteredScene(samplePoint,dx,dy);
        vec3 outerB = filteredScene(samplePoint+split,dx,dy);
        if (dot(split,split) <= u_derived[0].w) {
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
    color = gradeInput(color);
    // radiance() moves a channel by at most w/(1+w). Past the depth where both
    // weights fall below two 8-bit steps (w < 0.00784) the terms are
    // imperceptible, so the reflection reads stop there instead of at 24/4
    // points. Dart derives both ends (zero without reflection or reach).
    if (depth < u_derived[3].x) {
        float broadEnd = u_derived[2].x;
        float rimEnd = u_derived[2].y;
        vec2 boundary = local-normal*d;
        vec2 tangent = vec2(-normal.y,normal.x);
        float reach = u_geometry.z;
        if (depth < rimEnd) {
            float edge = max(1.-depth/4.,0.);
            float rim = edge*sqrt(edge);
            // Reflection taps land outside the contour, where the backdrop is not
            // frosted; a pair of taps one sigma apart along the normal stands in
            // for it. The tangent pair of the former cross added two reads for a
            // change below two 8-bit steps on frosted content.
            vec2 tap = boundary+normal*(1.+depth*reach/12.);
            float s = u_derived[2].z;
            vec3 reflected = s > 0.05
                ? (sampleLocal(tap+normal*s) + sampleLocal(tap-normal*s)) * 0.5
                : sampleLocal(tap);
            color = radiance(color,reflected,u_finish.z*rim);
        }
        if (depth < broadEnd) {
            // The broad lobe keeps its two tangent taps at half reach; the far
            // normal tap contributed a third read for a near-identical average.
            vec3 diffuse = (sampleLocal(boundary+normal*reach*0.5+tangent*reach*0.4)
                          + sampleLocal(boundary+normal*reach*0.5-tangent*reach*0.4))*0.5;
            float fade = 1.-depth/24.;
            color = radiance(color,diffuse,u_finish.z*fade*fade*0.32);
        }
    }
    color = gradeFace(color);
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
    if (u_material.x > 2.5 && u_material.x < 3.5) {
        float faceScale = u_extent.y/70.;
        float shadeDepth = 16.*faceScale;
        float top = max(-normal.y,0.);
        float inner = smoothstep(1.*faceScale,5.*faceScale,depth)
            * (1.-smoothstep(5.*faceScale,shadeDepth,depth));
        color *= 1.-.12*u_finish.y*top*inner;
    }
    color = gradePressed(color);
    frag_color = vec4(color*coverage,coverage+rimAlpha)*presence;
}
