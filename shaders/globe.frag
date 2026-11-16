#version 440
// The globe, on the GPU: an orthographic view of the Earth turned to
// (lon0, tilt), land as a grid of dots read from an equirectangular mask,
// lit by the real sun, with a graticule every 30 degrees and a glow
// around the limb. Colors come premultiplied-free; output is premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lon0;       // degrees, longitude at the centre
    float tilt;       // degrees, latitude at the centre
    float sunLon;     // degrees
    float sunLat;     // degrees
    float radius;     // globe radius as a fraction of the item's half size
    float dotStep;    // degrees between dots
    float hasLand;    // 0 when the mask is missing
    vec4 dayColor;
    vec4 nightColor;
    vec4 oceanColor;
    vec4 gridColor;
    vec4 rimColor;
    // Heat: up to ten places (lon, lat, weight 0..1, unused) and the ramp
    // they colour the land dots with, warm to hot.
    vec4 heatWarm;
    vec4 heatHot;
    vec4 h0; vec4 h1; vec4 h2; vec4 h3; vec4 h4;
    vec4 h5; vec4 h6; vec4 h7; vec4 h8; vec4 h9;
};
layout(binding = 1) uniform sampler2D land;

const float PI = 3.14159265358979;
const float D2R = PI / 180.0;

// Great-circle distance in degrees.
float arcDeg(float lon1, float lat1, float lon2, float lat2) {
    float c = sin(lat1 * D2R) * sin(lat2 * D2R) + cos(lat1 * D2R) * cos(lat2 * D2R) * cos((lon1 - lon2) * D2R);
    return acos(clamp(c, -1.0, 1.0)) / D2R;
}
// A place's warmth at a point: its weight, fading over about 10 degrees.
float warmth(vec4 h, float lon, float lat) {
    if (h.z <= 0.0) return 0.0;
    float d = arcDeg(lon, lat, h.x, h.y) / 9.0;
    return h.z * exp(-d * d);
}

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    p.y = -p.y;
    p /= radius;
    float r = length(p);
    float aa = fwidth(r);

    // Outside: the atmosphere.
    if (r > 1.0) {
        float g = 1.0 - smoothstep(1.0, 1.18, r);
        float a = rimColor.a * 0.35 * g * g;
        fragColor = vec4(rimColor.rgb * a, a) * qt_Opacity;
        return;
    }

    float z = sqrt(max(0.0, 1.0 - r * r));
    float ct = cos(tilt * D2R), st = sin(tilt * D2R);
    vec3 e = vec3(p.x, p.y * ct + z * st, -p.y * st + z * ct);
    float lat = asin(clamp(e.y, -1.0, 1.0));
    float lon = lon0 * D2R + atan(e.x, e.z);
    float latD = lat / D2R;
    float lonD = mod(lon / D2R + 180.0, 360.0) - 180.0;

    // Ocean, darker towards the limb.
    vec3 rgb = oceanColor.rgb * (0.65 + 0.35 * z);
    float alpha = oceanColor.a;

    // Graticule.
    float glat = abs(fract(latD / 30.0 + 0.5) - 0.5) * 30.0;
    float glon = abs(fract(lonD / 30.0 + 0.5) - 0.5) * 30.0 * cos(lat);
    float gd = min(glat, glon);
    float gw = fwidth(latD) * 0.8;
    float grid = (1.0 - smoothstep(gw * 0.5, gw * 1.5, gd)) * gridColor.a;
    rgb = mix(rgb, gridColor.rgb, grid);

    // Land as dots: rows of latitude, columns spaced to stay even on the sphere.
    if (hasLand > 0.5) {
        float row = floor((latD + 90.0) / dotStep);
        float rowLat = row * dotStep - 90.0 + dotStep * 0.5;
        float dlon = dotStep / max(0.25, cos(rowLat * D2R));
        float colIdx = floor((lonD + 180.0) / dlon);
        float cellLon = (colIdx + 0.5) * dlon - 180.0;
        vec2 dd = vec2((lonD - cellLon) * cos(lat), latD - rowLat) / dotStep;
        float d = length(dd);
        float w = fwidth(d);
        float dotA = 1.0 - smoothstep(0.26 - w, 0.26 + w, d);
        vec2 uv = vec2((cellLon + 180.0) / 360.0, (90.0 - rowLat) / 180.0);
        float isLand = step(0.5, texture(land, uv).r);
        float sun = sin(rowLat * D2R) * sin(sunLat * D2R)
                  + cos(rowLat * D2R) * cos(sunLat * D2R) * cos((cellLon - sunLon) * D2R);
        float day = smoothstep(-0.08, 0.08, sun);
        vec4 c = mix(nightColor, dayColor, day);
        // The heat of the data exchanged around: warm, then hot.
        float heat = warmth(h0, cellLon, rowLat) + warmth(h1, cellLon, rowLat) + warmth(h2, cellLon, rowLat)
                   + warmth(h3, cellLon, rowLat) + warmth(h4, cellLon, rowLat) + warmth(h5, cellLon, rowLat)
                   + warmth(h6, cellLon, rowLat) + warmth(h7, cellLon, rowLat) + warmth(h8, cellLon, rowLat)
                   + warmth(h9, cellLon, rowLat);
        heat = clamp(heat, 0.0, 1.0);
        if (heat > 0.02) {
            vec3 ramp = mix(heatWarm.rgb, heatHot.rgb, smoothstep(0.35, 1.0, heat));
            float lit = mix(0.55, 1.0, day);
            c = vec4(mix(c.rgb, ramp * lit, smoothstep(0.02, 0.3, heat)), max(c.a, 0.9));
        }
        float k = dotA * isLand * c.a;
        rgb = mix(rgb, c.rgb, k);
    }

    // The limb's thin ring.
    float rim = smoothstep(1.0 - aa * 2.5, 1.0 - aa * 0.5, r) * rimColor.a * 0.7;
    rgb = mix(rgb, rimColor.rgb, rim);

    // Soft edge.
    float edge = 1.0 - smoothstep(1.0 - aa, 1.0, r);
    float a = alpha * edge;
    fragColor = vec4(rgb * a, a) * qt_Opacity;
}
