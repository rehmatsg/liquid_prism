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

float readAlpha(vec2 px) {
    vec2 uv = clamp(px, vec2(0.5), u_textureSize - 0.5) * (1. / u_textureSize);
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return texture(u_backdrop, uv).a;
}
// The blur fill stored in the backdrop's alpha by shaders/frost_fill.frag:
// one marker column in four, followed by red, green and blue. Without exactly
// one marker the pixels carry no fill and [fallback] is returned.
vec3 readFill(vec2 px, vec3 fallback) {
    vec2 c = floor(px) + .5;
    vec4 a = vec4(readAlpha(c-vec2(1.,0.)), readAlpha(c),
                  readAlpha(c+vec2(1.,0.)), readAlpha(c+vec2(2.,0.)));
    vec4 m = step(.95, a);
    if (abs(m.x+m.y+m.z+m.w-1.) > .5) return fallback;
    vec3 fill = m.x > .5 ? a.yzw : (m.y > .5 ? a.zwx : (m.z > .5 ? a.wxy : a.xyz));
    return fill * (1./.9);
}
// Whether the pixels around [px] hold a stored fill.
bool hasFill(vec2 px) {
    vec2 c = floor(px) + .5;
    return max(max(readAlpha(c-vec2(1.,0.)), readAlpha(c)),
               max(readAlpha(c+vec2(1.,0.)), readAlpha(c+vec2(2.,0.)))) > .5;
}
// Pixels the glass does not cover outright still hold the stored fill in
// their alpha; completing them with the backdrop leaves them opaque.
vec4 completeFill(vec4 color, vec2 screen) {
    if (u_frost.w < 0. || color.a > .999 || !hasFill(screen)) return color;
    return color + (1.-color.a)*vec4(readScene(screen),1.);
}
// Native regular frost: the fill blended lighten (darken in dark appearance)
// at the directional opacity, then normally at the normal opacity. The fill
// is read a few pixels inside the contour, where every column is stored, and
// displaced by [bend] with the backdrop so the lens refracts it too.
vec3 fillGlass(vec3 color, vec2 local, vec2 bend, vec2 normal, float d, float aa) {
    if (u_frost.w < 0.) return color;
    float len = length(normal);
    vec2 inner = local
        - (len > 0.0001 ? normal/len*max(d+3.5*aa,0.) : vec2(0.));
    vec3 fill = readFill(scenePoint(inner+bend), vec3(-1.));
    if (fill.r < 0.) fill = readFill(scenePoint(inner), color);
    vec3 directional = u_material.y > .5 ? min(color,fill) : max(color,fill);
    color = mix(color, directional, u_frost.x);
    return mix(color, fill, u_frost.y);
}
// Dark regular glass lightens toward its surroundings: native blurs them
// wider than the fill, which four fills a bleed radius apart stand in for
// (kept inside the face, where the fill is stored). The result goes through
// the native bleed matrix and fades out over the last 1.5 points.
vec3 bleedGlass(vec3 color, vec2 local, float d, float aa) {
    if (u_frost.z <= 0.) return color;
    vec2 inset = vec2(.3*u_derived[2].w + 4.*aa);
    vec2 high = max(u_extent-inset, inset);
    vec3 fill = vec3(0.);
    for (int i = 0; i < 4; i++) {
        vec2 tap = vec2(i < 2 ? 1. : -1., mod(float(i),2.) < .5 ? 1. : -1.)
            * (u_frost.w*.70710678);
        fill += readFill(scenePoint(clamp(local+tap,inset,high)), vec3(0.));
    }
    vec3 bleed = .125 + .24*min(fill*.4, 1.);
    return mix(color, max(color,bleed), u_frost.z*clamp(-d/1.5,0.,1.));
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
float faceWhite();
vec3 vibrantHighlight(vec3 color, float strength) {
    vec3 r = vec3(2.6492,-1.1803,-0.1189);
    vec3 g = vec3(-0.3507,1.8199,-0.1192);
    vec3 b = vec3(-0.3509,-1.1799,2.8809);
    float bias = 0.15;
    if (u_material.x > 2.5 || (u_material.x > 0.5 && u_material.x < 1.5)) {
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
    return mix(color,clamp(transformed,0.,faceWhite()),clamp(strength,0.,1.));
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
float hdrAmount() { return clamp((u_headroom-1.)/.3,0.,1.); }
// Light glass keeps its unclamped face white when the surface has headroom:
// 1.03 encoded (about 1.07 linear) for regular and 1.08 (about 1.19) for
// clear. Dark glass, lenses and custom optics stop at 1.
float faceWhite() {
    if (u_material.y > .5 || u_material.x < .5 || u_material.x > 2.5) return 1.;
    return 1.+(u_material.x > 1.5 ? .08 : .03)*hdrAmount();
}
// [limit] is u_face.z: the dark SDR luma limit or the light contrast gain.
vec3 gradeFaceAt(vec3 color, float limit) {
    if (u_material.x > .5 && u_material.x < 2.5) {
        bool dark = u_material.y > .5;
        bool clear = u_material.x > 1.5;
        float value = dot(color,vec3(.2126,.7152,.0722));
        float black = clear || dark ? .125 : .4000000059604645;
        float white = clear ? 1.0800000429153442 :
            (dark ? 1.125 : 1.0299999713897705);
        float saturation = clear ? 1.059999942779541 :
            (dark ? 1.2999999523162842 : 1.2000000476837158);
        float tone = mix(black,white,value);
        // Light-regular face curve measured on surfaces without depth terms.
        if (!clear && !dark) tone = .4 + value*(.627-.035*value);
        // With headroom the native face follows the linear matrix through
        // white instead of the SDR rolloff (measured 1.07 linear over white).
        if (!clear && !dark && u_headroom > 1.)
            tone = mix(tone,.4+.63*value,hdrAmount());
        // Fitted SDR tone rolloff; the limit and gray fill are measured inputs.
        if (!clear && dark) tone = .125 + value*(.97+(limit-.97)*value);
        color = (color-vec3(value))*saturation + tone;
        float fill = clear ? 0. : u_face.x;
        color = mix(color,vec3(u_face.w),fill);
        // Larger light surfaces gain face contrast about the black point.
        if (!clear && !dark) color = .4 + (color-.4)*limit;
        color = clamp(color,0.,faceWhite());
    }
    if (u_material.w > 0.) {
        vec4 inputColor = vec4(color,1.);
        vec3 tinted = clamp(vec3(dot(u_tintRed,inputColor),
            dot(u_tintGreen,inputColor),dot(u_tintBlue,inputColor)),0.,1.);
        color = mix(color,tinted,u_material.w);
    }
    return color;
}
vec3 gradeFace(vec3 color) { return gradeFaceAt(color,u_face.z); }
vec3 shadeInnerRing(vec3 color, float d, vec2 normal, float depth) {
    float opacity = u_face.y;
    return opacity > 0. ? color*(1.-opacity*ringShadow(d,normal,depth)) : color;
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
// Premultiplied exterior edge line. Clear glass and lenses draw a black line;
// regular glass follows the native measurements: in dark appearance a black
// line at .6 alpha (stronger on larger surfaces), in light appearance the
// backdrop lowered by .3 on the sides and .04 above and below.
vec4 exteriorRim(float d, vec2 normal, float aa, float coverage, vec2 local) {
    if (u_material.x > 1.5 && u_material.x < 3.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        float facing = clamp((abs(normal.x)-0.258819)/0.741181,0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float outerCoverage = clamp(0.5-(d-0.533333)/aa,0.,1.);
        float strength = u_material.x > 2.5 ? 0.46 : 0.3;
        return vec4(0.,0.,0.,clamp(side*u_finish.y*strength,0.,1.)
                             *max(outerCoverage-coverage,0.));
    }
    if (u_material.x > .5 && u_material.x < 1.5 &&
        u_finish.y > 0. && d > -0.5*aa) {
        bool dark = u_material.y > .5;
        float spread = dark ? 0.2588190451 : -0.2756373558;
        float facing = clamp((abs(normal.x)-spread)/(1.-spread),0.,1.);
        float side = facing/(1.+0.5*(1.-facing));
        float size = clamp((min(u_extent.x,u_extent.y)-64.)/40.,0.,1.);
        float width = 0.46 + (dark ? 0.07*size : 0.);
        float hdr = dark ? 0. : hdrAmount();
        // Matched-device HDR fit: a slightly wider side band with a softer
        // key/fill at the vertical poles. Preserve the SDR and dark recipes.
        width += .04*hdr*abs(normal.x);
        float line = max(clamp(0.5-(d-width)/aa,0.,1.)-coverage,0.);
        if (dark) {
            return vec4(0.,0.,0.,
                clamp(side*u_finish.y*(0.6+0.15*size),0.,1.)*line);
        }
        side = max(side, 0.13);
        side *= mix(1.,mix(2./3.,1.,abs(normal.x)),hdr);
        vec3 lowered = max(readScene(scenePoint(local))
                           -0.3*side*u_finish.y,0.);
        return vec4(lowered*line,line);
    }
    return vec4(0.);
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

// The surroundings beside the rim, averaged along the edge with Gaussian
// weights over +-halfWindow (sigma halfWindow/2), so the rim reads as one
// continuous line: detail outside the glass becomes gradual changes in
// brightness and colour, and where bright surroundings end the line ramps out
// along the kernel instead of breaking off. Alternate taps step +-across along
// the normal so thin features outside never line up with the tap grid.
// Arguments are in scene pixels.
vec3 readAlongEdge(vec2 center, vec2 tangent, vec2 normal, float across) {
    vec3 sum = vec3(0.);
    float total = 0.;
    for (int i = -4; i <= 4; i++) {
        float x = float(i) * .25;
        float w = exp(-2.*x*x);
        float side = mod(float(i + 4), 2.) * 2. - 1.;
        sum += readScene(center + tangent*x + normal*(side*across)) * w;
        total += w;
    }
    return sum / total;
}

// Half the window the rim averages its surroundings over: wide enough on a
// small control that the reflection is a smooth line, narrower relative to a
// large surface so it keeps some sense of what is around it.
float edgeWindow() {
    return clamp(.15*min(u_extent.x,u_extent.y), 3., 12.);
}

// Reflection lives on the rim only: the surroundings just outside the contour
// mirrored into a band at most 4 points (and a quarter of the short side)
// wide, so no surface reflects across its interior.
vec3 reflectGlass(vec3 color, vec2 local, vec2 normal, float d, float depth) {
    if (depth < u_derived[3].x) {
        float rimWidth = u_derived[2].x;
        mat2 toScene = mat2(u_transform.x,u_transform.z,u_transform.y,u_transform.w)*u_geometry.y;
        vec2 sceneBoundary = scenePoint(local-normal*d);
        vec2 sceneNormal = toScene*normal;
        vec2 sceneTangent = toScene*vec2(-normal.y,normal.x);
        float reach = u_geometry.z;
        float edge = max(1.-depth/rimWidth,0.);
        float rim = edge*sqrt(edge);
        vec2 tap = sceneBoundary+sceneNormal*(1.+depth*reach/12.);
        vec3 reflected = readAlongEdge(tap, sceneTangent*edgeWindow(),
            sceneNormal, max(1.5,u_derived[2].z));
        color = radiance(color,reflected,u_finish.z*rim);
    }
    return color;
}

// Regular glass shows its surroundings in the outermost point of the face:
// native mixes in the backdrop from outside the contour (its outer refraction
// amount, a quarter of the shortest side and at least 16 points, less 4) at
// .6 opacity on the contour, falling to nothing one point in. Native mirrors
// point for point; here the surroundings are averaged along the edge
// (readAlongEdge) so a small surface shows one continuous line rather than
// broken pieces of nearby detail. Measured on
// device with white content at set distances outside the surface.
vec3 mirrorSurroundings(vec3 color, vec2 local, vec2 normal, float depth) {
    if (u_material.x < .5 || u_material.x > 1.5 || depth >= 1.) return color;
    float len = length(normal);
    if (len < 0.0001) return color;
    vec2 n = normal/len;
    float reach = max(16.,0.25*min(min(u_extent.x,u_extent.y),150.)) - 4.;
    mat2 toScene = mat2(u_transform.x,u_transform.z,u_transform.y,u_transform.w)*u_geometry.y;
    vec3 outside = readAlongEdge(scenePoint(local + n*reach),
        toScene*vec2(-n.y,n.x)*edgeWindow(), toScene*n, 3.);
    // The mirrored surroundings keep a small surface's grade at any size.
    outside = gradeFaceAt(gradeInput(outside),u_material.y > .5 ? .6 : 1.);
    return mix(color,outside,0.6*(1.-depth)*min(len,1.)*u_finish.y);
}
vec3 lightGlass(vec3 color, vec2 normal, float depth, float aa, float lensRim) {
    if (depth < (u_material.x > .5 ? 8. : 1.) + aa) {
        float light;
        float edge = 0.;
        if (u_material.x > .5 && u_material.x < 1.5) {
            // Regular glass: the diffuse lobe grades the face; the sharp rim
            // is added on top, .18 at the contour falling off over 1.31
            // points whatever the face colour (measured on device).
            light = highlight(-normal.y,depth,8.,0.593419,11.333333,1.,aa);
            float lobe = clamp((abs(normal.y)-0.130526)/0.869474,0.,1.);
            edge = 0.18*lobe*clamp(1.-depth/1.31,0.,1.);
        } else if (u_material.x > .5) {
            float sharp = highlight(-normal.y,depth,1.,0.130526,0.,0.75,aa);
            float diffuse = highlight(-normal.y,depth,8.,0.593419,11.333333,1.,aa);
            light = sharp + diffuse;
        } else {
            light = highlight(dot(normal,vec2(-0.70710678,-0.70710678)),depth,1.,0.,0.,0.7,aa);
        }
        if (light*u_finish.y > 0.) color = vibrantHighlight(color,light*u_finish.y);
        color = clamp(color+edge*u_finish.y,0.,faceWhite());
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

// Fit to the HDR reference, not an extracted Apple operator. Keep the existing
// SDR face/lighting path, then add only the rim's linear-light radiance. Flutter's
// XR output is nonlinear extended sRGB, so 1.3 linear white encodes as ~1.12.
vec3 hdrRim(vec3 color, vec2 normal, float depth) {
    if (u_headroom <= 1. || u_material.x < .5 || u_material.x > 2.5
        || depth >= 1. || u_finish.y <= 0.) return color;
    bool clear = u_material.x > 1.5;
    bool dark = u_material.y > .5;
    if (dark && !clear) return color;
    // Rounded renderer parameters, checked against HDR angular/radial profiles;
    // this is not a recovered Apple lighting operator.
    float n2 = normal.y*normal.y;
    float n4 = n2*n2;
    float n8 = n4*n4;
    float n32 = n8*n8*n8*n8;
    // Confine emission to the rim. Treating the reference's broad pixel
    // shoulder as additive light created an unwanted inner glow.
    float band = 1.-smoothstep(.5,1.,depth);
    float radiance;
    if (dark) {
        // Dark clear: a one-pixel glint at the poles and along flat edges.
        radiance = .15*n32*(1.-smoothstep(.2,.6,depth));
    } else if (clear) {
        // Light clear: the lifted face carries the brightness; the rim adds
        // only a faint glint toward the poles.
        radiance = .025*n8*band;
    } else {
        // Light regular: broad cosine-squared light plus a narrow glint at
        // the poles, added over the lifted face (about 1.3 linear in all).
        radiance = (.01+.09*n2+.12*n32)*band;
    }
    radiance *= hdrAmount()*clamp(u_finish.y,0.,1.);
    vec3 linear = mix(color/12.92, pow((color+.055)/1.055,vec3(2.4)),
                      step(vec3(.04045),color));
    linear = min(linear+radiance,vec3(u_headroom));
    return mix(12.92*linear,1.055*pow(linear,vec3(1./2.4))-.055,
               step(vec3(.0031308),linear));
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
    // The lens band only needs the full path when it bends or disperses.
    float lensEnd = (u_derived[0].y > 0. || u_optics.w > 0.001)
        ? 1./u_derived[0].x : 0.;
    float interiorEnd = max(lensEnd, u_derived[3].x);
    interiorEnd = max(interiorEnd, (u_material.x > .5 ? 8. : 1.) + aa);
    if (u_material.x > 2.5 && u_material.x < 3.5) {
        if (underlay) interiorEnd = max(interiorEnd, 36.);
        interiorEnd = max(interiorEnd, 16.*u_extent.y/70.);
        interiorEnd = max(interiorEnd, u_shapeD.z);
    }
    if (depth > interiorEnd + aa) {
        vec3 face = fillGlass(readScene(scenePoint(local)),local,vec2(0.),normal,d,aa);
        face = gradeFace(gradeInput(face));
        if (u_face.y > 0.) face = shadeInnerRing(face,d,normal,depth);
        face = bleedGlass(face,local,d,aa);
        face = gradePressed(face);
        frag_color = completeFill(
            vec4(face, 1.) * clamp(1.-u_state.z,0.,1.), screen);
        return;
    }
    float coverage = clamp(0.5-d/aa,0.,1.);
    vec4 rim = exteriorRim(d,normal,aa,coverage,local);
    float presence = clamp(1.-u_state.z,0.,1.);
    if (coverage < 0.001) {
        frag_color = rim*presence;
        if (d < 2.*aa) frag_color = completeFill(frag_color, screen);
        return;
    }
    bool lens = u_material.x > 2.5 && u_material.x < 3.5;
    float lensRim = lens ? u_state.w : 0.; // Tab glint, independent of split.
    vec3 color = sampleGlass(
        samplePoint,dx,dy,direction,normal,profile,d,depth,lens);
    color = fillGlass(color,local,underlayOffset-offset,normal,d,aa);
    color = gradeInput(color);
    color = reflectGlass(color,local,normal,d,depth);
    color = gradeFace(color);
    if (u_face.y > 0.) color = shadeInnerRing(color,d,normal,depth);
    color = mirrorSurroundings(color,local,normal,depth);
    color = lightGlass(color,normal,depth,aa,lensRim);
    color = bleedGlass(color,local,d,aa);
    color = gradePressed(color);
    color = hdrRim(color,normal,depth);
    frag_color = completeFill(
        vec4(color*coverage+rim.rgb,coverage+rim.a)*presence, screen);
}
