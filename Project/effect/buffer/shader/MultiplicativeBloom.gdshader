shader_type spatial;
render_mode blend_mul, unshaded, fog_disabled,
            depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D bloom_texture       : hint_default_white, filter_linear;
uniform sampler2D bloom_depth_texture : hint_default_white, filter_nearest;
uniform sampler2D depth_texture       : hint_depth_texture, filter_nearest;

uniform float strength : hint_range(0.0, 40.0, 0.1) = 6.0;
uniform float proximity_boost = 0.0;
uniform float far_plane = 80.0;

// Tolerance in world units. If the scene is more than this much closer than
// the cube, count it as foreground and reject. ~0.5 works well; raise if you
// see halo bleed onto foreground, lower if the halo gets clipped at edges.
uniform float foreground_epsilon : hint_range(0.0, 5.0, 0.05) = 0.5;

void vertex() {
    POSITION = vec4(sign(VERTEX.xy), 1.0, 1.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // ---- Per-pixel foreground rejection ----
    // bloom_depth_texture is a regular color texture rendered by DepthCamera.
    // Background = 1.0 (white clear), cube = depth_normalized in [0, ~1).
    float bloom_d_normalized = texture(bloom_depth_texture, uv).r;

    // 0.999 threshold: anything below means a cube actually rendered here.
    // (Pure background stays at 1.0 from the clear color.)
    if (bloom_d_normalized < 0.999) {
        // Decode the cube's view-space distance.
        float bloom_d_linear = bloom_d_normalized * far_plane;

        // Linearize the main scene's reversed-Z depth into world units.
        float raw_scene_d = texture(depth_texture, uv).r;
        vec3  ndc         = vec3(uv * 2.0 - 1.0, raw_scene_d);
        vec4  view_h      = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
        float scene_d_linear = -view_h.z / view_h.w;

        // Scene closer than the cube by more than epsilon = foreground occludes.
        if (scene_d_linear < bloom_d_linear - foreground_epsilon) {
            discard;
        }
    }

    // ---- 9x9 true 2D Gaussian blur ----
    const float W[9] = float[](
        0.00390625, 0.03125, 0.109375, 0.21875, 0.2734375,
        0.21875, 0.109375, 0.03125, 0.00390625
    );

    float spread  = strength * mix(1.0, 0.45, proximity_boost);
    vec2  step_uv = spread / VIEWPORT_SIZE;

    vec3 result = vec3(0.0);
    for (int x = -4; x <= 4; x++) {
        for (int y = -4; y <= 4; y++) {
            float w      = W[x + 4] * W[y + 4];
            vec2  offset = vec2(float(x), float(y)) * step_uv;
            result      += w * texture(bloom_texture, uv + offset).rgb;
        }
    }

    float intensity = mix(0.9, 1.0, proximity_boost);
    result = mix(vec3(1.0), result, intensity);

    ALBEDO = result;
}