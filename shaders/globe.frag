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
};
layout(binding = 1) uniform sampler2D land;

const float PI = 3.14159265358979;
const float D2R = PI / 180.0;

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
