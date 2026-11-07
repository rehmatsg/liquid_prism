// Fitted to iOS 27 stripe captures, not a reconstruction of glassForeground.
// Depth and band are in local points; split is the full red-blue distance.
float chromaticWeight(float depth, float band) {
    return (1.-.085*min(depth,band)) *
           (1.-smoothstep(.62*band,band,depth));
}
vec2 chromaticDirection(vec2 normal) { return -normal.yx; }

// Glyph fringe weight, measured on iOS 27 tab glyphs held under the rim
// (doc/native_tab_bar_spec.md): the red-blue split stays flat to 1.15 band
// deep, then falls by e every 0.44 band (5.5 and 2.1 points on the tab).
// Past 3.1 band it is under 2% and the caller skips it.
float glyphFringeWeight(float depth, float band) {
    return exp(-max(depth-1.15*band,0.)/(.44*band));
}
