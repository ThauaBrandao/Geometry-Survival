shader_type canvas_item;
// Desfoque + escurecimento da tela atrás de sobreposições (pausa, diálogos).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.08, 1.0);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 2.5 * amount).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g), 0.35 * amount);
	c = mix(c, tint.rgb, 0.55 * amount);
	COLOR = vec4(c, 1.0);
}
