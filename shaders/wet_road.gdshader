shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float travel = 0.0;
uniform bool detailed = true;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = vec2(world_position.x, world_position.z - travel);
	float grain = noise(p * 45.0);
	float puddle = smoothstep(0.42, 0.72, noise(p * vec2(0.75, 0.18)));
	float ripple = sin(p.y * 31.0 + TIME * 3.0) * sin(p.x * 43.0 - TIME * 2.0);
	float wet = detailed ? puddle : 0.35;
	ALBEDO = mix(vec3(0.065, 0.079, 0.094), vec3(0.018, 0.030, 0.047), wet);
	ALBEDO *= 0.82 + grain * 0.35;
	ROUGHNESS = mix(0.72, 0.14, wet);
	METALLIC = wet * 0.5;
	float pools = pow(max(0.0, cos(p.y * 0.52)), 8.0);
	float left = exp(-pow((p.x + 3.9) * 1.5, 2.0));
	float right = exp(-pow((p.x - 3.9) * 1.5, 2.0));
	vec3 light = vec3(0.06, 0.42, 0.48) * left + vec3(0.55, 0.22, 0.06) * right;
	EMISSION = light * pools * (0.18 + wet * 0.5) * (0.85 + ripple * 0.15);
}
