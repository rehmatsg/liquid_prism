// Fitted to iOS 27 stripe captures, not a reconstruction of glassForeground.
// Depth and band are in local points; split is the full red-blue distance.
float chromaticWeight(float depth, float band) {
    return (1.-.085*min(depth,band)) *
           (1.-smoothstep(.62*band,band,depth));
}
vec2 chromaticDirection(vec2 normal) { return -normal.yx; }
