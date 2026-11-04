shader_type canvas_item;
// Transição "fenda": um rasgo vertical com bordas irregulares abre do centro
// e cobre a tela (progress 0→1), com borda luminosa.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.9, 1.0, 1.0);
uniform float seed = 0.0;

float hash(float x) { return fract(sin(x * 91.3458 + seed) * 47453.5453); }
float noise1(float x) { float i = floor(x); float f = fract(x); return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f)); }

void fragment() {
	float y = UV.y;
	float jag = (noise1(y * 18.0 + TIME * 6.0) - 0.5) * 0.10 + (noise1(y * 55.0 - TIME * 9.0) - 0.5) * 0.04;
	float bulge = sin(y * 3.14159);                      // mais largo no meio
	float half_w = progress * progress * 0.62 * (0.35 + 0.65 * bulge) + progress * 0.02;
	half_w = mix(half_w, 0.75, smoothstep(0.82, 1.0, progress));
	float d = abs(UV.x - 0.5 + jag * progress) - half_w;
	float inside = step(d, 0.0);
	float glow = smoothstep(0.035, 0.0, abs(d)) * step(0.001, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
	vec3 col = fill.rgb + edge_color.rgb * glow * 1.4;
	float a = max(inside * fill.a, glow);
	COLOR = vec4(col, a);
}
