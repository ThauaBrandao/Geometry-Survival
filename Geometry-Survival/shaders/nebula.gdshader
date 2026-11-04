shader_type canvas_item;
// Fundo espacial: nebulosa em fbm + campo de estrelas em duas camadas + vinheta.
uniform vec4 col_a : source_color = vec4(0.02, 0.04, 0.1, 1.0);
uniform vec4 col_b : source_color = vec4(0.05, 0.16, 0.3, 1.0);
uniform vec4 col_c : source_color = vec4(0.06, 0.37, 0.48, 1.0);
uniform vec2 parallax = vec2(0.0);
uniform float motion = 1.0;
uniform float danger = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
float stars(vec2 uv, float density, float size, float seed) {
	vec2 grid = uv * density;
	vec2 cell = floor(grid);
	float h = hash(cell + seed);
	vec2 pos = vec2(hash(cell + seed + 3.1), hash(cell + seed + 7.7)) - 0.5;
	float d = length(fract(grid) - 0.5 - pos * 0.6);
	float tw = 0.65 + 0.35 * sin(TIME * motion * (1.0 + h * 3.0) + h * 60.0);
	return step(0.93, h) * smoothstep(size, 0.0, d) * tw;
}
void fragment() {
	vec2 uv = UV;
	vec2 asp = vec2(1.7778, 1.0);
	float t = TIME * 0.015 * motion;
	vec2 p = uv * asp * 2.2 + parallax * 0.15;
	float n = fbm(p + vec2(t, -t * 0.6));
	float n2 = fbm(p * 1.6 - vec2(t * 1.4, t * 0.8) + n);
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.25, 0.85, n));
	c = mix(c, col_c.rgb, smoothstep(0.55, 0.95, n2) * 0.7);
	c += col_c.rgb * pow(n2, 4.0) * 0.35;
	// estrelas: camada distante (pouco parallax) e próxima (mais parallax)
	float s1 = stars(uv * asp + parallax * 0.02, 60.0, 0.12, 1.0);
	float s2 = stars(uv * asp + parallax * 0.06, 24.0, 0.07, 17.0);
	c += vec3(0.8, 0.9, 1.0) * s1 * 0.8 + vec3(1.0) * s2;
	// alerta de entropia (tinge as bordas de vermelho)
	float edge = length((uv - 0.5) * vec2(1.3, 1.0));
	c = mix(c, vec3(0.6, 0.02, 0.08), danger * smoothstep(0.35, 0.8, edge));
	// vinheta
	c *= mix(0.45, 1.0, smoothstep(0.95, 0.25, edge));
	COLOR = vec4(c, 1.0);
}
