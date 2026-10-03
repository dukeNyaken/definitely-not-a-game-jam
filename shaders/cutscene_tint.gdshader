shader_type canvas_item;
// Кадр сюжетных сцен: тонировка (сепия флешбэка, багрец дворца, тёплый рассвет), виньетка,
// зерно старой плёнки и мерцание. Зерно крупное, в пиксель ретро-кадра.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.55, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.5) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float grain_px = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, l * tint.rgb * 1.4, amount);
	// Виньетка — овал по кадру: края темнеют, центр не трогаем.
	float r = length(SCREEN_UV - 0.5);
	c *= 1.0 - smoothstep(0.3, 0.78, r) * vignette;
	float frame = floor(TIME * 16.0);
	c += (hash(floor(FRAGCOORD.xy / grain_px) + frame * 1.37) - 0.5) * grain * 0.14;
	c *= 1.0 + (hash(vec2(frame, 0.5)) - 0.5) * flicker * 0.14;
	COLOR = vec4(c, 1.0);
}
