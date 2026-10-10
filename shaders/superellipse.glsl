// Rounded-superellipse geometry adapted from Flutter's Impeller renderer.
// Copyright 2013 The Flutter Authors. BSD-3-Clause; see THIRD_PARTY_NOTICES.md.
// Closest-point search adapted from Inigo Quilez (2015, MIT).
vec3 superellipseField(vec2 p, float degree) {
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
vec3 roundedSuperellipse(vec2 local) {
    vec2 relative = local-u_extent*.5;
    vec2 p = abs(relative);
    float c = u_shapeA.z-u_shapeA.w;
    bool top = p.y+c > p.x;
    vec2 oct = top ? p+vec2(0.,c) : p.yx-vec2(0.,c);
    vec4 circle = top ? u_shapeB : u_shapeC;
    float axis = top ? u_shapeA.z : u_shapeA.w;
    float degree = top ? u_shapeA.x : u_shapeA.y;
    vec2 delta = oct-circle.xy;
    float diagonal = dot(delta,vec2(0.7071067812));
    vec3 field;
    if (diagonal > length(delta)*cos(circle.w)) {
        field = vec3(length(delta)-circle.z,delta/max(length(delta),1e-8));
    } else {
        field = superellipseField(oct/axis,degree);
        field.x *= axis;
    }
    if (!top) field.yz = field.zy;
    field.yz *= sign(relative);
    return field;
}
