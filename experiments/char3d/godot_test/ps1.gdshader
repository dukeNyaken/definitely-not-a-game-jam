shader_type spatial;
// PS1 для запечённых моделей с UV: дрожь вершин, аффинная («плывущая») текстура,
// выборка без сглаживания. Свет по вершинам — как у консоли, и дешевле.
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
// Высота сетки, к которой прилипают вершины, в точках экрана. 240 — родное
// разрешение PS1; меньше — дрожь заметнее. 0 — без дрожи.
uniform float snap_res = 240.0;
// 1 — чисто аффинная текстура (сильно «плывёт» на крупных у камеры гранях),
// 0 — обычная перспективная. Промежуточные значения смешивают.
uniform float affine : hint_range(0.0, 1.0) = 1.0;

varying vec3 uv_w;   // UV, умноженные на w, и сам w: см. fragment()

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap_res > 0.0) {
		vec2 grid = vec2(snap_res * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_res) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	uv_w = vec3(UV * clip.w, clip.w);
}

void fragment() {
	// Видеокарта интерполирует с поправкой на перспективу. Для (UV*w) и w
	// поправка у числителя и знаменателя одна и та же и сокращается в делении —
	// остаётся линейная по экрану, то есть аффинная, интерполяция UV, как на PS1.
	vec2 uv = mix(UV, uv_w.xy / uv_w.z, affine);
	ALBEDO = texture(albedo_tex, uv).rgb;
}
