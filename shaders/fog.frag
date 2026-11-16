#version 440
// The HUD coming over the windows like an old VHS tape: the screen first goes
// to snow under a grid in the accent colour, then the grid's tiles drop out
// one by one in a random order, each with a short flicker, showing the HUD
// beneath; colour bleed and line jitter fade as it settles.
// `reveal` 0 = all snow, 1 = the clean HUD.

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

void main() {
    vec2 uv = qt_TexCoord0;
    float settle = 1.0 - reveal;

    // The grid: square tiles, 18 across.
    float cols = 18.0, rows = floor(18.0 / aspect + 0.5);
    vec2 cell = uv * vec2(cols, rows);
    vec2 id = floor(cell), f = fract(cell);
    float order = hash(id + 7.0);                       // when this tile drops out
    float gone = smoothstep(order * 0.85, order * 0.85 + 0.06, reveal);
    // A tile flickers just as it goes.
    float flick = step(0.5, hash(id + floor(time * 30.0))) * step(abs(reveal - order * 0.85 - 0.03), 0.04);

    // The HUD under the tape: colour bleed and jittered lines while it settles.
    float jitter = (hash(vec2(floor(uv.y * lines * 0.5), floor(time * 20.0))) - 0.5) * 0.012 * settle
                 * step(0.85, hash(vec2(floor(uv.y * 40.0), floor(time * 12.0))));
    float bleed = 0.004 * settle;
    vec2 u = uv + vec2(jitter, 0.0);
    vec4 c = texture(source, u);
    float r = texture(source, u + vec2(bleed, 0.0)).r;
    float b = texture(source, u - vec2(bleed, 0.0)).b;
    vec4 hud = vec4(r, c.g, b, c.a);
    hud.rgb *= 1.0 - 0.25 * settle * step(0.5, fract(uv.y * lines));

    // The snow: grain, scan lines and a tracking band rolling down.
    float grain = hash(uv * vec2(1920.0, 1080.0) + floor(time * 30.0));
    float band = smoothstep(0.08, 0.0, abs(fract(uv.y - time * 0.35) - 0.5) - 0.42);
    float scan = 0.75 + 0.25 * step(0.5, fract(uv.y * lines));
    vec3 snow = vec3(grain * 0.55 + band * 0.25) * scan;
    snow += edgeColor.rgb * 0.08;
    vec4 snowC = vec4(snow, 0.94);

    // The grid's lines, over the snow and on the tiles still standing.
    vec2 g = min(f, 1.0 - f) * vec2(cols, rows) / vec2(cols, rows);
    float line = 1.0 - smoothstep(0.0, 0.03, min(f.x, min(f.y, min(1.0 - f.x, 1.0 - f.y))));
    vec4 gridC = vec4(edgeColor.rgb, 1.0) * line * 0.9;

    vec4 tile = mix(snowC, vec4(edgeColor.rgb * 0.6, 0.9), flick);
    tile = gridC + tile * (1.0 - gridC.a);
    vec4 outC = mix(tile, hud, gone);
    fragColor = outC * qt_Opacity;
}
