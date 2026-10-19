shader_type spatial;
// Night-city building: dark walls with a grid of windows, some lit warm or cool,
// and a glowing roofline trim on some buildings. Everything is derived from world
// position and the mesh transform, so one material serves every building.

uniform vec3 wall_color : source_color = vec3(0.045, 0.05, 0.075);
uniform vec3 roof_color : source_color = vec3(0.11, 0.11, 0.14);
uniform vec3 warm_light : source_color = vec3(1.0, 0.72, 0.38);
uniform vec3 cool_light : source_color = vec3(0.45, 0.85, 1.0);
uniform float window_glow = 2.4;
uniform float trim_glow = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float local_y;
varying vec2 local_xz;
varying vec2 building_size_xz;
varying vec3 building_center;
varying float building_height;

float rand(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_y = VERTEX.y;
	local_xz = VERTEX.xz;
	building_size_xz = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	building_center = MODEL_MATRIX[3].xyz;
	building_height = length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	ROUGHNESS = 0.75;
	METALLIC = 0.15;
	float id = rand(floor(building_center * 0.37) + 0.5);
	if (abs(world_normal.y) > 0.5) {
		// Roof: faint tile grid plus a glowing edge line, so landings are easy to judge
		vec2 tiles = abs(fract(world_pos.xz / 4.0) - 0.5);
		float grid = 1.0 - step(0.03, min(tiles.x, tiles.y) * 4.0);
		vec2 to_edge = (0.5 - abs(local_xz)) * building_size_xz;
		float edge = 1.0 - step(0.35, min(to_edge.x, to_edge.y));
		ALBEDO = roof_color + grid * 0.03;
		vec3 edge_color = id < 0.78 ? vec3(0.1, 0.95, 0.9) : vec3(1.0, 0.45, 0.1);
		EMISSION = edge_color * edge * 1.2 + vec3(0.4, 0.5, 0.7) * grid * 0.12;
	} else {
		float u = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
		vec2 grid = vec2(u / 3.2, world_pos.y / 3.8);
		vec2 f = fract(grid);
		vec2 cell = floor(grid);
		float window = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.78);
		float lit_share = mix(0.25, 0.7, id);
		float lit = step(1.0 - lit_share, rand(vec3(cell, dot(world_normal, vec3(3.0, 0.0, 7.0)) + id * 13.0)));
		vec3 light = mix(warm_light, cool_light, step(0.6, rand(vec3(cell.yx + 4.0, id))));
		ALBEDO = wall_color + window * 0.05;
		vec3 glow = light * window * lit * window_glow * step(3.0, world_pos.y);
		float from_top = (0.5 - local_y) * building_height;
		vec3 trim_color = id < 0.78 ? vec3(0.1, 0.95, 0.9) : vec3(1.0, 0.45, 0.1);
		glow += trim_color * step(from_top, 0.6) * step(0.55, id) * trim_glow;
		EMISSION = glow;
	}
}
