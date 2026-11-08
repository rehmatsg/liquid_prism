// Optical profile, spectral dispersion and lighting adapted from GPUI glass
// contributors (BSD-3-Clause). See THIRD_PARTY_NOTICES.md.
vec2 scenePoint(vec2 local) {
    return u_origin + mat2(u_transform.x, u_transform.z,
                          u_transform.y, u_transform.w) * local * u_geometry.y;
}
// The engine supplies a live backdrop with the factory's linear sampler.
vec3 readScene(vec2 px) {
    vec2 uv = clamp(px, vec2(0.5), u_textureSize - 0.5) * (1. / u_textureSize);
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return texture(u_backdrop, uv).rgb;
}

// Integrate compressed pixel footprints with one, two or four taps.
vec3 filteredScene(vec2 p, vec2 dx, vec2 dy) {
    float dxx = dot(dx, dx);
    float dyy = dot(dy, dy);
    float stretch2 = max(dxx, dyy);
    float sigma = u_derived[1].x;
    if (stretch2 <= u_derived[1].y) return readScene(p);
    vec2 major = dxx > dyy ? dx : dy;
    major *= min(1., 16. / max(sqrt(stretch2), 0.0001));
    // A moment-matched pair suffices up to 2.2 frost sigma.
    if (sigma >= 2. && stretch2 <= u_derived[1].z) {
        return (readScene(p - major * 0.28867513) + readScene(p + major * 0.28867513)) * 0.5;
    }
    vec3 result = vec3(0.);
    for (int i = 0; i < 4; i++) {
        result += readScene(p + major * ((float(i) + 0.5) * 0.25 - 0.5));
    }
    return result * 0.25;
}

#include "superellipse.glsl"
#include "chromatic_fringe.glsl"

// Past the inward bands, round-corner depth bounds the smooth contour.
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
// Abramowitz and Stegun 7.1.26, within 1.5e-7.
float erfApprox(float x) {
    float a = abs(x);
    float t = 1./(1.+0.3275911*a);
    float y = 1.-((((1.061405429*t-1.453152027)*t+1.421413741)*t
                   -0.284496736)*t+0.254829592)*t*exp(-a*a);
    return x < 0. ? -y : y;
}
// Blurred, shifted inner stroke with a fitted rim mask; see doc/native_shadows.md.
float ringShadow(float d, vec2 normal, float depth) {
    float x = d-8.*normal.y;
    if (abs(x) > 17.) return 0.;
    float g = 0.5*(erfApprox((x+2.)*0.14142136)-erfApprox((x-2.)*0.14142136));
    float facing = clamp((abs(normal.y)-0.5)/0.43969262,0.,1.);
    float gain = normal.y < 0. ? 1.5 : 1.70212766;
    return g*(1.-facing*clamp(gain*(1.-depth/8.),0.,1.));
}
float highlight(float direction, float depth, float width,
                float spread, float focus, float softness, float aa) {
    float ramp = 1. - clamp(depth / width, 0., 1.);
    float core = mix(step(0.0001,ramp),ramp,softness);
    float band = core * clamp((width-depth)/aa+0.5,0.,1.)
                      * clamp(depth/aa+0.5,0.,1.);
    float lobe = clamp((abs(direction)-spread)/(1.-spread),0.,1.) * band;
    return lobe / (1. + focus * (1.-lobe));
}
vec3 vibrantHighlight(vec3 color, float strength) {
    vec3 r = vec3(2.6492,-1.1803,-0.1189);
    vec3 g = vec3(-0.3507,1.8199,-0.1192);
    vec3 b = vec3(-0.3509,-1.1799,2.8809);
    float bias = 0.15;
    if (u_material.x > 2.5 || (u_material.x > 0.5 && u_material.x < 1.5 &&
                               u_material.y < 0.5)) {
        r = vec3(1.1202,-0.1894,-0.0190);
        g = vec3(-0.0563,0.9871,-0.0191);
        b = vec3(-0.0563,-0.1893,1.1574);
        bias = 0.1471;
    } else if (u_material.x > 1.5) {
        r = vec3(1.3192,-0.0478,-0.0047);
        g = vec3(-0.0142,1.2856,-0.0048);
        b = vec3(-0.0142,-0.0476,1.3285);
        bias = 0.2;
    }
    vec3 transformed = vec3(dot(color,r),dot(color,g),dot(color,b)) + bias;
    return mix(color,clamp(transformed,0.,1.),clamp(strength,0.,1.));
}
vec3 radiance(vec3 base, vec3 reflected, float weight) {
    float y = dot(base,vec3(0.2126,0.7152,0.0722));
    float peak = max(max(reflected.r,reflected.g),reflected.b);
    float y2 = y*y;
    vec3 absorption = base * (vec3(peak)-reflected);
    absorption *= min((y2*y2)*0.3,
        0.08/max(dot(absorption,vec3(0.2126,0.7152,0.0722)),1e-8));
    float response = weight / (1. + weight);
    return clamp(base + ((1.-base)*reflected
        *mix(1.,(1.-y)*(1.-y)*(1.-y)*(1.-y),0.65)-absorption)*response,0.,1.);
}
vec3 gradeInput(vec3 color) {
    float luma = dot(color,vec3(0.2126,0.7152,0.0722));
    color = clamp(mix(vec3(luma),color,u_finish.x),0.,1.);
    return clamp(mix(color,u_tint.rgb,u_tint.a) + u_geometry.w,0.,1.);
}
vec3 gradeFace(vec3 color) {
    if (u_material.x > .5 && u_material.x < 2.5) {
        bool dark = u_material.y > .5;
        bool clear = u_material.x > 1.5;
        float value = dot(color,vec3(.2126,.7152,.0722));
        float black = clear || dark ? .125 : .4000000059604645;
        float white = clear ? 1.0800000429153442 :
            (dark ? 1.100000023841858 : 1.0299999713897705);
        float saturation = clear ? 1.059999942779541 :
            (dark ? 1.399999976158142 : 1.2000000476837158);
        float tone = mix(black,white,value);
        // Fitted light-regular face curve; see doc/native_adaptive_layout.md.
        if (!clear && !dark) tone = .4 + value*(.7239-.129*value);
        color = (color-vec3(value))*saturation + tone;
        float fill = clear || dark ? 0. : u_face.x;
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
float exteriorRim(float d, vec2 normal, float aa, float coverage) {
    float rimAlpha = 0.;
    if (u_material.x > 1.5 && u_material.x < 3.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        float facing = clamp((abs(normal.x)-0.258819)/0.741181,0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float outerCoverage = clamp(0.5-(d-0.533333)/aa,0.,1.);
        float strength = u_material.x > 2.5 ? 0.46 : 0.3;
        rimAlpha = clamp(side*u_finish.y*strength,0.,1.)*max(outerCoverage-coverage,0.);
    }
    if (u_material.x > .5 && u_material.x < 1.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        float spread = u_material.y > .5 ? 0.2588190451 : -0.2756373558;
        float facing = clamp((abs(normal.x)-spread)/(1.-spread),0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        if (u_material.y < .5) side = max(side, 0.3);
        float outerCoverage = clamp(0.5-(d-0.5333333333)/aa,0.,1.);
        rimAlpha = clamp(side*u_finish.y*0.3,0.,1.)*
                   max(outerCoverage-coverage,0.);
    }
    return rimAlpha;
}

vec3 sampleGlass(vec2 samplePoint, vec2 dx, vec2 dy, vec2 direction,
                 vec2 normal, float profile, float d, float depth, bool lens) {
    float chromaticSplit = lens ? u_derived[1].w : 0.;
    float chromaticBand = u_shapeD.z;
    vec3 color;
    if (chromaticSplit > 0. && chromaticBand > 0. && d <= 0. && depth < chromaticBand) {
        float weight = max(chromaticWeight(depth,chromaticBand),0.);
        vec2 shift = mat2(u_transform.x,u_transform.z,u_transform.y,u_transform.w)
            * (chromaticDirection(normal)*(.5*weight*chromaticSplit));
        vec3 red = filteredScene(samplePoint-shift,dx,dy);
        vec3 green = filteredScene(samplePoint,dx,dy);
        vec3 blue = filteredScene(samplePoint+shift,dx,dy);
        color = vec3(red.r,green.g,blue.b);
    } else if (u_optics.w > 0.001 && profile > 0.001) {
        vec2 split = mat2(u_transform.x, u_transform.z, u_transform.y, u_transform.w)
                   * (direction*(u_derived[0].z*profile));
        vec3 outerA = filteredScene(samplePoint-split,dx,dy);
        vec3 center = filteredScene(samplePoint,dx,dy);
        vec3 outerB = filteredScene(samplePoint+split,dx,dy);
        if (dot(split,split) <= u_derived[0].w) {
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
    } else {
        color = filteredScene(samplePoint,dx,dy);
    }
    return color;
}

vec3 reflectGlass(vec3 color, vec2 local, vec2 normal, float d, float depth) {
    if (depth < u_derived[3].x) {
        float broadEnd = u_derived[2].x;
        float rimEnd = u_derived[2].y;
        mat2 toScene = mat2(u_transform.x,u_transform.z,u_transform.y,u_transform.w)*u_geometry.y;
        vec2 sceneBoundary = scenePoint(local-normal*d);
        vec2 sceneNormal = toScene*normal;
        vec2 sceneTangent = toScene*vec2(-normal.y,normal.x);
        float reach = u_geometry.z;
        if (depth < rimEnd) {
            float edge = max(1.-depth/4.,0.);
            float rim = edge*sqrt(edge);
            vec2 tap = sceneBoundary+sceneNormal*(1.+depth*reach/12.);
            vec2 s = sceneNormal*u_derived[2].z;
            vec3 reflected = u_derived[2].z > 0.05
                ? (readScene(tap+s) + readScene(tap-s)) * 0.5
                : readScene(tap);
            color = radiance(color,reflected,u_finish.z*rim);
        }
        if (depth < broadEnd) {
            vec2 lobe = sceneBoundary+sceneNormal*(reach*0.5);
            vec2 spread = sceneTangent*(reach*0.4);
            vec3 diffuse = (readScene(lobe+spread) + readScene(lobe-spread))*0.5;
            float fade = 1.-depth/24.;
            color = radiance(color,diffuse,u_finish.z*fade*fade*0.32);
        }
    }
    return color;
}

vec3 lightGlass(vec3 color, vec2 normal, float depth, float aa, float lensRim) {
    if (depth < (u_material.x > .5 ? 8. : 1.) + aa) {
        float light;
        if (u_material.x > .5) {
            float sharp = highlight(-normal.y,depth,1.,0.130526,0.,0.75,aa);
            float diffuse = highlight(-normal.y,depth,8.,0.593419,11.333333,1.,aa);
            light = sharp + diffuse;
        } else {
            light = highlight(dot(normal,vec2(-0.70710678,-0.70710678)),depth,1.,0.,0.,0.7,aa);
        }
        if (light*u_finish.y > 0.) color = vibrantHighlight(color,light*u_finish.y);
    }
    if (u_material.x > 2.5 && u_material.x < 3.5) {
        float faceScale = u_extent.y/70.;
        float shadeDepth = 16.*faceScale;
        float top = max(-normal.y,0.);
        float inner = smoothstep(1.*faceScale,5.*faceScale,depth)
            * (1.-smoothstep(5.*faceScale,shadeDepth,depth));
        color *= 1.-.12*u_finish.y*top*inner;
        if (lensRim > 0. && depth < 2.*faceScale + aa) {
            float width = 1.5*faceScale;
            float spread = .3*faceScale;
            vec3 glint = clamp(1.-vec3(depth+spread,depth,max(depth-spread,0.))
                               /width,0.,1.);
            color += (1.-color)*glint*glint*(.16*lensRim);
        }
    }
    return color;
}

void shadeGlass() {
    vec2 screen = FlutterFragCoord().xy;
    float det = u_transform.x*u_transform.w - u_transform.y*u_transform.z;
    if (abs(det) < 0.00001) {
        frag_color = vec4(0.);
        return;
    }
    mat2 inv = mat2(u_transform.w,-u_transform.z,-u_transform.y,u_transform.x)/det;
    vec2 local = inv * (screen-u_origin) / u_geometry.y;
    vec4 field = shape(local);
    float d = field.x;
    vec2 normal = field.yz;
    float aa = u_derived[3].y;
    float depth = max(-d,0.);
    float t = clamp(1.+d*u_derived[0].x,0.,1.);
    float profile = 1.-sqrt(max(1.-t*t,0.));
    float displacement = u_derived[0].y;
    vec2 direction = vec2(0.);
    vec2 offset = vec2(0.);
    if (profile > 0.) {
        vec2 centered = (local-u_extent*0.5)*vec2(1.,u_derived[3].z);
        vec2 radial = centered/max(length(centered),0.0001);
        direction = mix(normal,radial,u_finish.w);
        direction = direction/max(length(direction),0.0001)*min(field.w,1.);
        offset = direction*displacement*profile;
    }
    vec2 underlayOffset = vec2(0.);
    bool underlay = u_material.x > 2.5 && u_material.x < 3.5 &&
                    u_material.z < 8.5 && u_shapeD.w > 0.;
    if (underlay) {
        float underlayT = clamp(1.-(depth+length(offset))/36.,0.,1.);
        float underlayProfile = 1.-sqrt(max(1.-underlayT*underlayT,0.));
        underlayOffset = normal*u_shapeD.w*underlayProfile;
    }
    vec2 samplePoint = scenePoint(local+underlayOffset-offset);
    vec2 dx = vec2(1., 0.);
    vec2 dy = vec2(0., 1.);
    #if defined(IMPELLER_GRAPHICS_BACKEND)
    // Derivatives must precede per-fragment coverage branches.
    dx = dFdx(samplePoint);
    dy = dFdy(samplePoint);
    aa = max(fwidth(d), 0.0001);
    #endif
    float interiorEnd = max(1./u_derived[0].x, u_derived[3].x);
    interiorEnd = max(interiorEnd, (u_material.x > .5 ? 8. : 1.) + aa);
    if (u_material.x > 2.5 && u_material.x < 3.5) {
        if (underlay) interiorEnd = max(interiorEnd, 36.);
        interiorEnd = max(interiorEnd, 16.*u_extent.y/70.);
        interiorEnd = max(interiorEnd, u_shapeD.z);
    }
    if (depth > interiorEnd + aa) {
        vec3 face = gradeFace(gradeInput(readScene(scenePoint(local))));
        if (u_face.y > 0.) face *= 1.-u_face.y*ringShadow(d,normal,depth);
        face = gradePressed(face);
        frag_color = vec4(face, 1.) * clamp(1.-u_state.z,0.,1.);
        return;
    }
    float coverage = clamp(0.5-d/aa,0.,1.);
    float rimAlpha = exteriorRim(d,normal,aa,coverage);
    float presence = clamp(1.-u_state.z,0.,1.);
    if (coverage < 0.001) {
        frag_color = vec4(0.,0.,0.,rimAlpha*presence);
        return;
    }
    bool lens = u_material.x > 2.5 && u_material.x < 3.5;
    float lensRim = lens ? u_state.w : 0.; // Tab glint, independent of split.
    vec3 color = sampleGlass(
        samplePoint,dx,dy,direction,normal,profile,d,depth,lens);
    color = gradeInput(color);
    color = reflectGlass(color,local,normal,d,depth);
    color = gradeFace(color);
    if (u_face.y > 0.) color *= 1.-u_face.y*ringShadow(d,normal,depth);
    color = lightGlass(color,normal,depth,aa,lensRim);
    color = gradePressed(color);
    frag_color = vec4(color*coverage,coverage+rimAlpha)*presence;
}
