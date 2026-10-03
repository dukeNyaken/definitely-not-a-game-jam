shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Маленький пиксельный огонь; без источников света на каждом роге.
void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= scale;
}

void fragment() {
	vec2 p = floor(UV * vec2(16.0, 24.0)) / vec2(16.0, 24.0);
	float height = 1.0 - p.y;
	float sway = sin(height * 9.0 - floor(TIME * 10.0) * 0.8) * 0.08 * height;
	float x = abs(p.x - 0.5 + sway);
	float width = (1.0 - height) * 0.27 + 0.025;
	if (x > width || height < 0.08) { discard; }
	float core = step(x, width * 0.32) * (1.0 - height);
	ALBEDO = mix(vec3(1.0, 0.025, 0.012), vec3(1.0, 0.18, 0.12), core) * 1.8;
	ALPHA = (1.0 - height * 0.6) * 0.85;
}
