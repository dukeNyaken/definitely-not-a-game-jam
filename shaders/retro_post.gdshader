shader_type canvas_item;
// Постобработка поверх 3D (под интерфейсом): пикселизация, цветокоррекция, зерно, дизеринг.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel = 3.0;
uniform float levels = 24.0;
uniform float dither_amount = 1.0;
uniform float smooth_amount = 0.0;
uniform float bloom = 0.0;
uniform float grain = 0.0;
uniform float vignette = 0.4;
uniform float saturation = 0.75;
uniform float contrast = 1.1;
uniform vec3 shadow_tint = vec3(0.06, 0.03, 0.04);
uniform vec3 highlight_tint = vec3(1.04, 0.96, 0.86);
uniform float scanlines = 0.0;
uniform float seed = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return (m[i] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	vec2 uv = (cell + 0.5) * pixel * px;
	vec3 c = texture(screen_tex, uv).rgb;
	if (smooth_amount > 0.0) {
		vec2 o = px * pixel * 0.75;
		vec3 b = texture(screen_tex, uv + vec2(o.x, o.y)).rgb + texture(screen_tex, uv + vec2(-o.x, o.y)).rgb
			+ texture(screen_tex, uv + vec2(o.x, -o.y)).rgb + texture(screen_tex, uv + vec2(-o.x, -o.y)).rgb;
		c = mix(c, b * 0.25, smooth_amount);
	}
	if (bloom > 0.0) {
		vec3 g = vec3(0.0);
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785398;
			vec2 off = vec2(cos(a), sin(a)) * px * 7.0 * pixel;
			vec3 s = texture(screen_tex, uv + off).rgb;
			g += max(s - 0.55, vec3(0.0));
		}
		c += g * bloom / 8.0;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = c * highlight_tint + shadow_tint * (1.0 - clamp(l * 2.0, 0.0, 1.0));
	vec2 suv = FRAGCOORD.xy * px;
	float v = smoothstep(0.9, 0.25, distance(suv, vec2(0.5)) * 1.1);
	c *= mix(1.0 - vignette, 1.0, v);
	if (grain > 0.0) {
		c += (hash(suv * 997.0 + seed) - 0.5) * grain;
	}
	if (scanlines > 0.0) {
		c *= 1.0 - scanlines * step(0.5, fract(FRAGCOORD.y / max(pixel, 1.0) * 0.5));
	}
	float d = (bayer4(cell) - 0.5) * dither_amount;
	c = floor(clamp(c, 0.0, 1.0) * levels + d + 0.5) / levels;
	COLOR = vec4(c, 1.0);
}
