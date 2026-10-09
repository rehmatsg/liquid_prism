// Optical profile, spectral dispersion and lighting adapted from GPUI glass
// contributors (BSD-3-Clause). See THIRD_PARTY_NOTICES.md.
vec2 scenePoint(vec2 local) {
    return u_origin + mat2(u_transform.x, u_transform.z,
                          u_transform.y, u_transform.w) * local * u_geometry.y;
}
// The engine replaces the bound image with the live backdrop while preserving
// the linear sampler descriptor configured by the material's shader factory.
vec3 readScene(vec2 px) {
    vec2 uv = clamp(px, vec2(0.5), u_textureSize - 0.5) / u_textureSize;
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
    float stretch = max(length(dx), length(dy));
    if (stretch <= 1.5) return readScene(p);
    vec2 major = length(dx) > length(dy) ? dx : dy;
    vec2 minor = length(dx) > length(dy) ? dy : dx;
    // Bound a grazing footprint while retaining subpixel integration at the rim.
    major *= min(1., 16. / max(length(major), 0.0001));
    vec3 result = vec3(0.);
    for (int i = 0; i < 4; i++) {
        vec2 step = major * ((float(i) + 0.5) * 0.25 - 0.5);
        result += readScene(p + step + minor * 0.25);
        result += readScene(p + step - minor * 0.25);
    }
    return result * 0.125;
}

#include "superellipse.glsl"

// Distance and outward direction for a rounded rectangle/capsule.
vec3 shape(vec2 p) {
    if (u_tintBias.w > .5) return roundedSuperellipse(p);
    float radius = min(u_geometry.x, min(u_extent.x,u_extent.y) * 0.5);
    vec2 rel = p - u_extent * 0.5;
    vec2 q = abs(rel) - u_extent * 0.5 + radius;
    float d = min(max(q.x,q.y),0.) + length(max(q,0.)) - radius;
    vec2 n;
    if (q.x > 0. && q.y > 0.) {
        n = sign(rel) * normalize(max(q,vec2(0.0001)));
    } else {
        n = q.x > q.y ? vec2(sign(rel.x),0.) : vec2(0.,sign(rel.y));
        n *= smoothstep(0.,1.,abs(q.x-q.y));
    }
    return vec3(d,n);
}
float highlight(vec2 normal, float depth, float width,
                float spread, float focus, float softness, float aa) {
    float ramp = 1. - clamp(depth / width, 0., 1.);
    float core = mix(step(0.0001,ramp),ramp,softness);
    float band = core * clamp((width-depth)/aa+0.5,0.,1.)
                      * clamp(depth/aa+0.5,0.,1.);
    float direction = dot(normal,vec2(-0.70710678,-0.70710678));
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
    if (u_material.x > 0.5 && u_material.y < 0.5) {
        transformed = vec3(dot(color,vec3(1.2024,-1.0014,-0.1010)),
          dot(color,vec3(-0.2976,0.4987,-0.1011)),
          dot(color,vec3(-0.2977,-1.0012,1.3989))) + 0.9;
    }
    return mix(color,clamp(transformed,0.,1.),clamp(strength,0.,1.));
}
vec3 radiance(vec3 base, vec3 reflected, float weight) {
    float y = dot(base,vec3(0.2126,0.7152,0.0722));
    float peak = max(max(reflected.r,reflected.g),reflected.b);
    vec3 absorption = base * (vec3(peak)-reflected) * pow(y,4.) * 0.3;
    absorption *= min(1.,0.08/max(dot(absorption,vec3(0.2126,0.7152,0.0722)),0.0001));
    float response = weight / (1. + weight);
    return clamp(base + ((1.-base)*reflected*mix(1.,pow(1.-y,4.),0.65)-absorption)*response,0.,1.);
}
void shadeGlass() {
    vec2 screen = FlutterFragCoord().xy;
    float det = u_transform.x*u_transform.w - u_transform.y*u_transform.z;
    if (abs(det) < 0.00001) { frag_color = vec4(0.); return; }
    mat2 inv = mat2(u_transform.w,-u_transform.z,-u_transform.y,u_transform.x)/det;
    vec2 local = inv * (screen-u_origin) / u_geometry.y;
    vec3 field = shape(local);
    float d = field.x;
    vec2 normal = field.yz;
    float aa = 1. / u_geometry.y;
    float depth = max(-d,0.);
    // Restrict the lens band to the available thickness to preserve a flat center.
    float edge = min(u_optics.x,min(u_extent.x,u_extent.y)*0.49);
    float t = clamp(1.+d/max(edge,0.001),0.,1.);
    float profile = 1.-sqrt(max(1.-t*t,0.));
    vec2 centered = (local-u_extent*0.5)*vec2(1.,u_extent.x/u_extent.y);
    vec2 radial = centered/max(length(centered),0.0001);
    vec2 direction = mix(normal,radial,u_finish.w);
    direction = direction/max(length(direction),0.0001)*min(length(normal),1.);
    float displacement = min(u_optics.y, min(u_extent.x,u_extent.y)*0.55);
    vec2 samplePoint = scenePoint(local-direction*displacement*profile);
    vec2 dx = vec2(1., 0.);
    vec2 dy = vec2(0., 1.);
    #if defined(IMPELLER_GRAPHICS_BACKEND)
    // Evaluate before per-fragment coverage branches so derivatives stay defined.
    dx = dFdx(samplePoint);
    dy = dFdy(samplePoint);
    aa = max(fwidth(d), 0.0001);
    #endif
    float coverage = clamp(0.5-d/aa,0.,1.);
    if (coverage < 0.001) { frag_color = vec4(0.); return; }
    vec3 color;
    if (u_optics.w > 0.001 && profile > 0.001) {
        vec2 split = scenePoint(local + direction*u_optics.w*(2.+displacement*0.12)*profile) - scenePoint(local);
        color = filteredScene(samplePoint-split,dx,dy)*vec3(0.22,0.04,0.01)
              + filteredScene(samplePoint-split*0.5,dx,dy)*vec3(0.40,0.22,0.10)
              + filteredScene(samplePoint,dx,dy)*vec3(0.27,0.48,0.27)
              + filteredScene(samplePoint+split*0.5,dx,dy)*vec3(0.10,0.22,0.40)
              + filteredScene(samplePoint+split,dx,dy)*vec3(0.01,0.04,0.22);
    } else { color = filteredScene(samplePoint,dx,dy); }
    float luma = dot(color,vec3(0.2126,0.7152,0.0722));
    color = clamp(mix(vec3(luma),color,u_finish.x),0.,1.);
    color = clamp(mix(color,u_tint.rgb,u_tint.a) + u_geometry.w,0.,1.);
    if (u_finish.z > 0.001 && u_geometry.z > 0.001) {
        vec2 boundary = local-normal*d;
        vec2 tangent = vec2(-normal.y,normal.x);
        float reach = u_geometry.z;
        vec3 reflected = sampleLocal(boundary+normal*(1.+depth*reach/12.));
        vec3 diffuse = (sampleLocal(boundary+normal*reach)
                      + sampleLocal(boundary+normal*reach*0.5+tangent*reach*0.4)
                      + sampleLocal(boundary+normal*reach*0.5-tangent*reach*0.4))/3.;
        float rim = pow(max(1.-depth/4.,0.),1.5);
        float broad = pow(max(1.-depth/24.,0.),2.);
        color = radiance(color,reflected,u_finish.z*rim);
        color = radiance(color,diffuse,u_finish.z*broad*0.32);
    }
    if (u_material.x > 0.5 && u_material.x < 1.5) {
        bool dark = u_material.y > 0.5;
        bool button = u_material.z > 0.5 && u_material.z < 1.5;
        bool bar = u_material.z > 1.5 && u_material.z < 2.5;
        // Native face levels grade luminance while preserving independent chroma.
        // A scalar per-channel contrast would turn the material muddy gray.
        float value = dot(color,vec3(0.2126,0.7152,0.0722));
        vec3 center = sampleLocal(u_extent * 0.5);
        float adaptation = dot(center,vec3(0.2126,0.7152,0.0722));
        float buttonBlack = clamp(0.9 * adaptation - 0.09,0.2,0.6);
        float black = button ? buttonBlack : (dark ? (bar ? 0.1870968 : 0.2) : (bar ? 0.5741935 : 0.5));
        float white = dark ? (button ? min(black + 0.6,0.9) : (bar ? 0.8370968 : 0.6)) : 1.03;
        float fill = bar ? (dark ? 0. : 0.25) : (button ? (dark ? 0.303571 + black * 0.357143 : 0.675 - black * 0.5) : 0.4);
        float saturation = bar ? (dark ? 1.3 : 1.1) : 1.;
        vec3 graded = (color-vec3(value))*saturation + black + value*(white-black);
        color = clamp(mix(graded,vec3(dark ? 0. : 1.),fill),0.,1.);
    }
    if (u_material.w > 0.) {
        float value = dot(color,vec3(0.2126,0.7152,0.0722));
        vec3 tinted = clamp(u_tintBias.rgb + u_tintSlope.rgb * value,0.,1.);
        color = mix(color,tinted,u_material.w);
    }
    // Opposing diagonal lights use 1pt height, 90 degree spread and 0.7 radial curvature.
    // Apply its vibrant matrix under the lobe mask; there is no uniform stroke.
    float sharp = highlight(normal,depth,1.,0.,0.,0.7,aa);
    color = vibrantHighlight(color,sharp*u_finish.y);

    vec3 pressed = vec3(dot(color,vec3(1.1575,-0.1431,-0.0144)),
        dot(color,vec3(-0.0425,1.0570,-0.0145)),
        dot(color,vec3(-0.0426,-0.1430,1.1856))) + 0.05;
    color = mix(color,clamp(pressed,0.,1.),u_tintSlope.w * 0.9);
    frag_color = vec4(color*coverage,coverage);
}
