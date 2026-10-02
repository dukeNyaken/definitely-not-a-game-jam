// Общая часть ретро-материала (PS1 / PS2). Подключается из retro_ps1 / retro_ps2.
// Текстура проецируется на каждую грань по её доминирующей оси (грани плоские — проекция ровная),
// поэтому модели из примитивов не нуждаются в UV-развёртке.

global uniform float retro_snap_res;
global uniform float retro_aspect;
global uniform float retro_pixel;

uniform vec4 albedo_color : source_color = vec4(1.0);
#ifdef RETRO_PS1
uniform sampler2D surface_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
#else
uniform sampler2D surface_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
#endif
uniform float tex_scale = 0.35;
uniform vec2 tex_offset = vec2(0.0);
uniform bool world_space = false;
// Плоская земля не дрожит: иначе сдвинутые треугольники прячут декали и телеграфы на полу.
uniform bool snap_vertices = true;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.9;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;
// 1 — непрозрачно; меньше — «решётчатая» прозрачность дизерингом, как на старых консолях.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 tri_pos;
varying vec3 tri_nrm;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return (m[i] + 0.5) / 16.0;
}

void vertex() {
	if (world_space) {
		tri_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		tri_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		tri_pos = VERTEX;
		tri_nrm = NORMAL;
	}
#ifdef RETRO_PS1
	// Дрожание вершин: позиция на экране округляется до сетки низкого разрешения.
	// POSITION пишется всегда: если писать его только в ветке, вне её позиция не определена.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (retro_snap_res > 0.0 && snap_vertices) {
		vec2 grid = vec2(retro_snap_res * retro_aspect, retro_snap_res) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
#endif
}

void fragment() {
	vec3 n = abs(tri_nrm);
	vec2 uv;
	if (n.x >= n.y && n.x >= n.z) {
		uv = tri_pos.zy;
	} else if (n.y >= n.z) {
		uv = tri_pos.xz;
	} else {
		uv = tri_pos.xy;
	}
	vec4 t = texture(surface_tex, uv * tex_scale + tex_offset);
	if (t.a < 0.5) {
		discard;
	}
	if (fade < 0.999) {
		vec2 cell = floor(FRAGCOORD.xy / max(retro_pixel, 1.0));
		if (fade < bayer4(cell)) {
			discard;
		}
	}
	ALBEDO = albedo_color.rgb * t.rgb;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
	EMISSION = emission_color.rgb * emission_energy;
}
