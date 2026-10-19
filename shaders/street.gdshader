shader_type spatial;
// Street level: dark asphalt with glowing dashed centre lines along every street.

uniform float cell_size = 34.0;
uniform vec3 asphalt : source_color = vec3(0.03, 0.032, 0.04);
uniform vec3 line_color : source_color = vec3(1.0, 0.75, 0.3);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = asphalt;
	ROUGHNESS = 0.9;
	// distance to the nearest street centre line (streets run along the cell borders)
	vec2 d = abs(fract(world_pos.xz / cell_size + 0.5) - 0.5) * cell_size;
	float along_x = step(d.x, 0.18) * step(0.5, fract(world_pos.z / 6.0));
	float along_z = step(d.y, 0.18) * step(0.5, fract(world_pos.x / 6.0));
	EMISSION = line_color * clamp(along_x + along_z, 0.0, 1.0) * 1.6;
}
