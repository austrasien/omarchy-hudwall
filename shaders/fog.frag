#version 440
// The HUD coming up over the windows like a fog of war lifting in a fighter
// jet's display: from the middle outwards through a ragged noise front, the
// front burning in the accent colour, scan lines and a flicker while it
// powers up. `reveal` 0 = nothing shown (the windows), 1 = the whole HUD.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float reveal;
    float time;
    float aspect;     // width / height
    float lines;      // scan lines over the height
    vec4 edgeColor;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 src = texture(source, uv);
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    float d = length(p) / length(vec2(aspect, 1.0) * 0.5);          // 0 middle, 1 corners
    float n = fbm(uv * vec2(aspect, 1.0) * 5.0 + vec2(time * 0.15, -time * 0.1));
    float front = d * 0.7 + n * 0.45;                                  // where the fog still stands
    float r = reveal * 1.2;
    float shown = smoothstep(r, r - 0.06, front);                      // 1 behind the front
    float edge = smoothstep(0.07, 0.0, abs(front - r)) * step(0.001, reveal) * (1.0 - step(0.999, reveal));
    // Scan lines and a flicker while it powers up, fading as it settles.
    float settle = 1.0 - reveal;
    float scan = 1.0 - 0.35 * settle * step(0.5, fract(uv.y * lines));
    float flicker = 1.0 - 0.25 * settle * step(0.7, hash(vec2(floor(time * 24.0), 3.0)));
    vec4 hud = src * shown * scan * flicker;
    vec4 glow = vec4(edgeColor.rgb, 1.0) * edge * 0.9;
    fragColor = (hud + glow * (1.0 - hud.a)) * qt_Opacity;
}
