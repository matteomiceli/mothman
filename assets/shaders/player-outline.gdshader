shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, blend_premul_alpha;

uniform vec4 outline_color = vec4(0.0, 1.0, 0.0, 1.0);

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA  = outline_color.a;
}