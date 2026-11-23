float chromaticWeight(float depth, float band) {
    return 0.55 * (1.-.085*min(depth,band)) *
           (1.-smoothstep(.62*band,band,depth));
}
vec2 chromaticDirection(vec2 normal) { return -normal.yx; }

float glyphFringeWeight(float depth, float band) {
    return exp(-max(depth-1.15*band,0.)/(.44*band));
}
