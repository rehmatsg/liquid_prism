// Rounded-superellipse geometry adapted from Flutter's Impeller renderer.
// Copyright 2013 The Flutter Authors. BSD-3-Clause; see THIRD_PARTY_NOTICES.md.
// Closest-point search adapted from Inigo Quilez (2015, MIT).
#ifndef SKIA_GRAPHICS_BACKEND
// cos^2 of the bisection angles k*pi/256; with the vertices in u_curve this
// forms the tangent predicate without per-pixel trigonometry or pow.
const float kCos2[65] = float[65](1.000000000, 0.999849409, 0.999397728, 0.998645228, 0.997592363, 0.996239767, 0.994588255, 0.992638821, 0.990392640, 0.987851065, 0.985015627, 0.981888033, 0.978470168, 0.974764090, 0.970772033, 0.966496399, 0.961939766, 0.957104878, 0.951994647, 0.946612151, 0.940960632, 0.935043496, 0.928864305, 0.922426783, 0.915734806, 0.908792407, 0.901603766, 0.894173214, 0.886505227, 0.878604423, 0.870475563, 0.862123541, 0.853553391, 0.844770272, 0.835779477, 0.826586421, 0.817196642, 0.807615795, 0.797849652, 0.787904096, 0.777785117, 0.767498810, 0.757051372, 0.746449096, 0.735698368, 0.724805665, 0.713777547, 0.702620657, 0.691341716, 0.679947518, 0.668444927, 0.656840870, 0.645142339, 0.633356379, 0.621490090, 0.609550620, 0.597545161, 0.585480944, 0.573365237, 0.561205338, 0.549008570, 0.536782282, 0.524533837, 0.512270614, 0.500000000);
vec2 curveVertex(int k, bool top) {
    vec4 v = u_curve[k];
    return top ? v.xy : v.zw;
}
float curveSide(vec2 q, int k, bool top) {
    vec2 e = curveVertex(k, top);
    float c2 = kCos2[k];
    return (q.x-e.x)*e.x*(1.-c2) - (q.y-e.y)*e.y*c2;
}
// The arc is the 64-chord polygon through the vertices held per geometry, so the
// angular bisection reads vertices instead of evaluating pow at each step.
vec3 superellipseField(vec2 p, bool top) {
    bool flip = p.y > p.x;
    vec2 q = flip ? p.yx : p;
    int lo = 0;
    int hi = 64;
    // Test the flat-side terminal segment before searching the full arc.
    // It is the same endpoint and predicate as six leftmost bisections.
    if (curveSide(q, 1, top) >= 0.) {
        hi = 1;
    } else {
        for (int i = 0; i < 6; i++) {
            int mid = (lo + hi) >> 1;
            if (curveSide(q, mid, top) < 0.) lo = mid; else hi = mid;
        }
    }
    vec2 a = curveVertex(lo, top);
    vec2 ba = curveVertex(hi, top) - a;
    vec2 delta = q - (a + ba*clamp(dot(q-a,ba)/max(dot(ba,ba),1e-12),0.,1.));
    float orientation = sign((q.x-a.x)*ba.y-(q.y-a.y)*ba.x);
    float distance = length(delta)*orientation;
    vec2 normal = delta*orientation/max(length(delta),1e-8);
    return vec3(distance,flip ? normal.yx : normal);
}
#else
// SkSL forbids computed array indices; Skia renders the frosted fallback, so
// this per-step pow search only keeps that target compiling.
vec3 superellipseField(vec2 p, bool top) {
    float degree = top ? u_shapeA.x : u_shapeA.y;
    bool flip = p.y > p.x;
    vec2 q = flip ? p.yx : p;
    float power = 2. / degree;
    vec2 left = vec2(1., 0.);
    vec2 right = vec2(0.7071067812);
    vec2 a = vec2(1., 0.);
    vec2 b = vec2(pow(0.7071067812, power));
    bool firstSegment = false;
    if (degree > 2.) {
        // Test the flat-side terminal segment before searching the full arc.
        // These are the same endpoint and predicate as six leftmost bisections.
        vec2 cs = right;
        for (int i = 0; i < 6; i++) cs = normalize(vec2(1., 0.) + cs);
        vec2 curve = pow(cs, vec2(power));
        float side = (q.x-curve.x)*curve.x*cs.y*cs.y
                   - (q.y-curve.y)*curve.y*cs.x*cs.x;
        firstSegment = side >= 0.;
        if (firstSegment) b = curve;
    }
    if (!firstSegment) {
        for (int i = 0; i < 6; i++) {
            // Unit-vector midpoint bisects the angle without per-pixel trigonometry.
            vec2 cs = normalize(left + right);
            vec2 curve = pow(cs, vec2(power));
            float side = (q.x-curve.x)*curve.x*cs.y*cs.y
                       - (q.y-curve.y)*curve.y*cs.x*cs.x;
            if (side < 0.) { left = cs; a = curve; }
            else { right = cs; b = curve; }
        }
    }
    vec2 ba = b-a;
    vec2 delta = q - (a + ba*clamp(dot(q-a,ba)/max(dot(ba,ba),1e-12),0.,1.));
    float orientation = sign((q.x-a.x)*ba.y-(q.y-a.y)*ba.x);
    float distance = length(delta)*orientation;
    vec2 normal = delta*orientation/max(length(delta),1e-8);
    return vec3(distance,flip ? normal.yx : normal);
}
#endif
vec3 roundedSuperellipse(vec2 local) {
    vec2 relative = local-u_extent*.5;
    vec2 p = abs(relative);
    float c = u_shapeA.z-u_shapeA.w;
    bool top = p.y+c > p.x;
    vec2 oct = top ? p+vec2(0.,c) : p.yx-vec2(0.,c);
    vec4 circle = top ? u_shapeB : u_shapeC;
    float axis = top ? u_shapeA.z : u_shapeA.w;
    float cosSpan = top ? u_shapeD.x : u_shapeD.y;
    vec2 delta = oct-circle.xy;
    float diagonal = dot(delta,vec2(0.7071067812));
    vec3 field;
    if (diagonal > length(delta)*cosSpan) {
        field = vec3(length(delta)-circle.z,delta/max(length(delta),1e-8));
    } else {
        field = superellipseField(oct/axis, top);
        field.x *= axis;
    }
    if (!top) field.yz = field.zy;
    field.yz *= sign(relative);
    return field;
}
