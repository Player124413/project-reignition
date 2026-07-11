shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Albedo;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec3 diffuse_color : source_color = vec3(0.8, 0.8, 0.8);
uniform vec2 uv_scale  = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Normals;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D normal1_tex : hint_normal;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;
uniform float detail_normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform bool normal_flip_y = true;

group_uniforms PRM;
uniform bool use_prm = true;
uniform sampler2D prm_tex : hint_default_white;
uniform bool prm_roughness_invert = false;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;

group_uniforms Iridescence;
uniform sampler2D reflection_tex : source_color, hint_default_black;
uniform vec2 iridescence_offset = vec2(0.25, 0.75);
uniform float falloff_power : hint_range(0.1, 8.0) = 1.5;
uniform float iridescence_strength : hint_range(0.0, 4.0) = 1.0;
uniform bool iridescence_to_emission = true;
uniform float parallax_scale : hint_range(0.0, 0.2) = 0.02;

group_uniforms Emission;
uniform sampler2D emission_tex : source_color, hint_default_black;
uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float luminance = 1.0;

group_uniforms VAT;
uniform bool vat_enabled = false;
uniform sampler2D vat_position_tex : hint_default_black;
uniform sampler2D vat_normal_tex : hint_default_black;
uniform bool vat_animate_normals = false;
uniform int vat_column_source : hint_range(0, 1) = 0;
uniform int vat_vcount_override = 0;
uniform float vat_pos_min = -10.402690;
uniform float vat_pos_max = 9.959630;
uniform float vat_global_scale = 0.1;
uniform float vat_speed = 30.0;
uniform bool vat_loop = true;
uniform bool vat_flip_v = false;
uniform bool vat_interpolate = false;
uniform bool vat_use_uv2_v_offset = false;

void vertex() {
    if (vat_enabled) {
        ivec2 dims = textureSize(vat_position_tex, 0);
        int vcount = dims.x;
        int frames = dims.y;
        int vc = vat_vcount_override > 0 ? vat_vcount_override : vcount;
        int col;
        if (vat_column_source == 0) {
            col = int(floor(UV2.x * float(vc)));
        } else {
            col = VERTEX_ID;
        }
        col = clamp(col, 0, vcount - 1);
        float fn = TIME * vat_speed / float(max(frames, 1));
        fn = vat_loop ? fract(fn) : clamp(fn, 0.0, 1.0);
        float v = vat_flip_v ? (1.0 - fn) : fn;
        if (vat_use_uv2_v_offset) v += UV2.y;
        v = fract(v);
        int f0 = int(floor(v * float(max(frames, 1)))) % max(frames, 1);
        int f1 = (f0 + 1) % max(frames, 1);
        float blend = fract(v * float(max(frames, 1)));
        vec3 raw;
        if (vat_interpolate) {
            raw = mix(texelFetch(vat_position_tex, ivec2(col, f0), 0).xyz,
                      texelFetch(vat_position_tex, ivec2(col, f1), 0).xyz, blend);
        } else {
            raw = texelFetch(vat_position_tex, ivec2(col, f0), 0).xyz;
        }
        // Matches the game vertex shader: samples position as t0.xzyw (R,B,G)->(X,Y,Z).
        vec3 off = mix(vec3(vat_pos_min), vec3(vat_pos_max), raw.rbg) * vat_global_scale;
        VERTEX += off;
        if (vat_animate_normals) {
            vec3 nraw;
            if (vat_interpolate) {
                nraw = mix(texelFetch(vat_normal_tex, ivec2(col, f0), 0).xyz,
                           texelFetch(vat_normal_tex, ivec2(col, f1), 0).xyz, blend);
            } else {
                nraw = texelFetch(vat_normal_tex, ivec2(col, f0), 0).xyz;
            }
            vec3 n = nraw.rbg * 2.0 - 1.0;
            if (length(n) > 0.001) NORMAL = normalize(n);
        }
    }
}

void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;

    vec3 view_ts = normalize(VIEW);
    vec2 puv = uv + view_ts.xy * parallax_scale;

    vec4 alb = texture(albedo_tex, uv);
    vec3 base = alb.rgb * diffuse_color;

    vec3 nb = texture(normal_tex, uv).rgb;
    vec3 nd = texture(normal1_tex, puv).rgb;
    if (normal_flip_y) { nb.g = 1.0 - nb.g; nd.g = 1.0 - nd.g; }
    vec3 nbv = nb * 2.0 - 1.0;
    vec3 ndv = (nd * 2.0 - 1.0) * vec3(detail_normal_scale, detail_normal_scale, 1.0);
    vec3 nrm = normalize(vec3(nbv.xy + ndv.xy, nbv.z));
    NORMAL_MAP = nrm * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = normal_scale;

    if (use_prm) {
        vec4 prm = texture(prm_tex, uv);
        SPECULAR = prm.r;
        ROUGHNESS = prm_roughness_invert ? (1.0 - prm.g) : prm.g;
        METALLIC = prm.b;
        AO = prm.a;
        AO_LIGHT_AFFECT = ao_light_affect;
    } else {
        METALLIC = metallic;
        ROUGHNESS = roughness;
        SPECULAR = specular;
    }

    float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float fres = pow(1.0 - ndotv, falloff_power);
    vec3 irid0 = texture(reflection_tex, vec2(iridescence_offset.x, fres)).rgb;
    vec3 irid1 = texture(reflection_tex, vec2(iridescence_offset.y, fres)).rgb;
    vec3 iridescence = irid0 * irid1 * fres * iridescence_strength;

    ALBEDO = base + iridescence;

    vec3 ems = texture(emission_tex, uv).rgb * emission_color * luminance;
    if (iridescence_to_emission) ems += iridescence;
    EMISSION = ems;
}
