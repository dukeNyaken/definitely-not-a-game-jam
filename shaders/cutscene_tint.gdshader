shader_type canvas_item;
// Тонировка сюжетных сцен: обесцвечивает кадр и красит его (сепия флешбэка).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.55, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 toned = l * tint.rgb * 1.2;
	COLOR = vec4(mix(c, toned, amount), 1.0);
}
