// Fitted fringe weights; depth and band are local points.
// See doc/native_controls_spec.md and doc/native_tab_bar_spec.md.
float chromaticWeight(float depth, float band) {
    return (1.-.085*min(depth,band)) *
           (1.-smoothstep(.62*band,band,depth));
}
vec2 chromaticDirection(vec2 normal) { return -normal.yx; }

float glyphFringeWeight(float depth, float band) {
    return exp(-max(depth-1.15*band,0.)/(.44*band));
}
