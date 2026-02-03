shader_type spatial;

// Debug flags to help with development.
//#define DEBUG_SHOW_WIREFRAME
//#define DEBUG_SHOW_FACE_COLORS
//#define DEBUG_SHOW_UV

render_mode unshaded;
render_mode cull_front;
render_mode fog_disabled;

uniform float subcamera_fov = 100.0;
uniform float fovx = 90.0;
uniform bool feather_edges = true;

uniform int lens = 0;
uniform vec2 camera_resolution = vec2(512.0, 512.0);
uniform bool show_grid = false;

uniform sampler2D Grid;
uniform sampler2D Texture0 : hint_default_black;
uniform sampler2D Texture1 : hint_default_black;
uniform sampler2D Texture2 : hint_default_black;
uniform sampler2D Texture3 : hint_default_black;
uniform sampler2D Texture4 : hint_default_black;
uniform sampler2D Texture5 : hint_default_black;

#include "projections.gdshaderinc"

//enum CubeFace{FRONT, BACK, LEFT, RIGHT, BOTTOM, TOP}
const int FRONT = 0;   // -Z
const int BACK = 1;    // +Z
const int LEFT = 2;    // -X
const int RIGHT = 3;   // +X
const int BOTTOM = 4;  // -Y
const int TOP = 5;     // +Y

vec3 get_transformation(vec2 uv) {
	switch (lens) {
		case 0: return(rectilinear_ray(uv));
		case 1: return(panini_ray(uv));
		case 2: return(fisheye_ray(uv));
		case 3: return(stereographic_ray(uv));
		case 4: return(cylindrical_ray(uv));
		case 5: return(equirectangular_ray(uv));
		case 6: return(mercator_ray(uv));
		case 7: return(fulldome(uv));
	}
}

// @TODO: Is this needed? The source_color hint could be used instead.
vec3 srgb_to_linear(vec3 color) {
	return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}

// Computes the blend factors for a face given base UV coordinates.
// Undefined for width <= 0.
vec3 edge_blend_factors(vec2 uv, float width) {
	uv = uv * 2.0 - 1.0;
	uv = abs(uv);
	
	// Blend factors.
	vec3 q = vec3(max(uv.x, uv.y), uv.x, uv.y);
	
	// Remap, smooth and clamp the blend factors.
	//q = smoothstep(1.0 - width, 1.0, q);
	q = q - (1.0 - width);
	q /= width;
	q = clamp(q, 0.0, 1.0);
	
	q.x = 1.0 - q.x;
	
	// We only want to blend half way. The other half belongs to the neighbouring faces.
	q = mix(vec3(0.5, 0.0, 0.0), vec3(1.0, 0.5, 0.5), q);
	
	// Ensure that each face blends evenly.
	q /= q.x + q.y + q.z;
	
	//q = smoothstep(0.0, 1.0, q);
	
	return q;
}

vec3 get_ray_direction(vec2 uv, vec2 resolution) {
	float view_ratio = resolution.x / resolution.y;
	vec3 dir = vec3(0.0, 0.0, 0.0);
	
	if (view_ratio > 1.0) {
		dir = get_transformation(vec2(uv.x - 0.5 * view_ratio, uv.y - 0.5) * 1.0);
	} else {
		dir = get_transformation(vec2(uv.x - 0.5, uv.y - 0.5 * view_ratio) * 1.0);
	}
	
	return dir;
}

int get_face(vec3 dir) {
	float ax = abs(dir.x);
	float ay = abs(dir.y);
	float az = abs(dir.z);
		
	if (az >= ax && az >= ay) {
		if (dir.z < 0.0) {
			return FRONT;
		} else {
			return BACK;
		}
	} else if (ax >= ay && ax >= az) {
		if (dir.x < 0.0) {
			return LEFT;
		} else {
			return RIGHT;
		}
	} else if (ay >= ax && ay >= az) {
		if (dir.y > 0.0) {
			return BOTTOM;
		} else {
			return TOP;
		}
	}
	
	return -1;
}

int get_opposite_face(int face) {
	switch (face) {
		case FRONT: return BACK;
		case BACK: return FRONT;
		case LEFT: return RIGHT;
		case RIGHT: return LEFT;
		case BOTTOM: return TOP;
		case TOP: return BOTTOM;
		default:
			break;
	}
	
	return -1;
}

int get_face_neighbour(int face, vec2 uv, bool other_face) {
	vec2 s = sign(uv - 0.5);
	
	int x_face = -1;
	int y_face = -1;
	
	if (face == FRONT) {
		x_face = RIGHT;
		y_face = BOTTOM;
	}
	if (face == BACK) {
		x_face = LEFT;
		y_face = BOTTOM;
	}
	if (face == LEFT) {
		x_face = FRONT;
		y_face = BOTTOM;
	}
	if (face == RIGHT) {
		x_face = BACK;
		y_face = BOTTOM;
	}
	if (face == BOTTOM) {
		x_face = RIGHT;
		y_face = BACK;
	}
	if (face == TOP) {
		x_face = RIGHT;
		y_face = FRONT;
	}
	
	if (s.x < 0.0) {
		x_face = get_opposite_face(x_face);
	}
	if (s.y < 0.0) {
		y_face = get_opposite_face(y_face);
	}
	
	if (other_face) {
		return y_face;
	}
	
	return x_face;
}

float fov_to_face_scale(float fov_degrees) {
	return tan(radians(fov_degrees) / 2.0);
}

vec2 get_face_uv(vec3 dir, int face) {
	float ax = abs(dir.x);
	float ay = abs(dir.y);
	float az = abs(dir.z);
	
	float face_scale = fov_to_face_scale(subcamera_fov);
	float fov_fix = 1.0 / face_scale;
	
	switch(face){
		case FRONT:
			return vec2(fov_fix * 0.5 * (vec2(dir.x / az, dir.y / az)) + 0.5);
		case BACK:
			return vec2(fov_fix * 0.5 * (vec2(-dir.x / az, dir.y / az)) + 0.5);
		case LEFT: 
			return vec2(fov_fix * 0.5 * (vec2(-dir.z / ax, dir.y / ax)) + 0.5);
		case RIGHT: 
			return vec2(fov_fix * 0.5 * (vec2(dir.z / ax, dir.y / ax)) + 0.5);
		case BOTTOM: 
			return vec2(fov_fix * 0.5 * (vec2(dir.x / ay, dir.z / ay)) + 0.5);
		case TOP: 
			return vec2(fov_fix * 0.5 * (vec2(dir.x / ay, -dir.z / ay)) + 0.5);
		default:
			break;
	}
	
	return vec2(-1);
}

vec4 get_face_color(int face) {
	vec3 color_front = vec3(1.0, 1.0, 1.0);
	vec3 color_back = vec3(1.0, 1.0, 0.0);
	vec3 color_left = vec3(1.0, 0.0, 0.0);
	vec3 color_right = vec3(1.0, 0.2, 0.0);
	vec3 color_bottom = vec3(0.0, 1.0, 0.0);
	vec3 color_top = vec3(0.0, 0.0, 1.0);
	
	//return vec4(1) * (sin(float(face) * vec4(3,4,5,1) + TIME) * 0.5 + 0.5);
	
	switch(face){
		case FRONT:
			return vec4(color_front, 1.0);
		case BACK: 
			return vec4(color_back, 1.0);
		case LEFT:
			return vec4(color_left, 1.0);
		case RIGHT:
			return vec4(color_right, 1.0);
		case BOTTOM:
			return vec4(color_bottom, 1.0);
		case TOP: 
			return vec4(color_top, 1.0);
		default:
			break;
	}
	
	return vec4(0);
}

vec4 sample_cube_face(int face, vec2 uv) {
	vec4 face_color = get_face_color(face);
	vec4 grid_sample = textureLod(Grid, uv, 0.0);
	float grid_alpha = 0.3;

#ifdef DEBUG_SHOW_FACE_COLORS
	return face_color;
#endif
	
	switch(face){
		case FRONT:
			vec4 face_sample = textureLod(Texture0, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case BACK: 
			vec4 face_sample = textureLod(Texture5, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case LEFT:
			vec4 face_sample = textureLod(Texture1, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case RIGHT:
			vec4 face_sample = textureLod(Texture2, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case BOTTOM:
			vec4 face_sample = textureLod(Texture3, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case TOP: 
			vec4 face_sample = textureLod(Texture4, uv, 0.0);
			face_sample.rgb = srgb_to_linear(face_sample.rgb);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		default:
			break;
	}
	
	return vec4(0);
}

vec4 sample_cube_face_with_blending(int face, vec2 uv, vec3 dir) {
	int x_face = get_face_neighbour(face, uv, false);
	int y_face = get_face_neighbour(face, uv, true);
	
	float face_scale = fov_to_face_scale(subcamera_fov);
	float blend_width = face_scale - 1.0;
	vec3 blend_factors = edge_blend_factors((uv - 0.5) * face_scale + 0.5, blend_width * 0.5);
	
	vec4 main_face_sample = sample_cube_face(face, uv);
	vec4 x_face_sample = sample_cube_face(x_face, get_face_uv(dir, x_face));
	vec4 y_face_sample = sample_cube_face(y_face, get_face_uv(dir, y_face));
	
	return main_face_sample * blend_factors.x 
			+ x_face_sample * blend_factors.y
			+ y_face_sample * blend_factors.z;
}

vec4 sample_cube(vec3 dir, int exclude_face) {
	int face = get_face(dir);
	vec2 uv = get_face_uv(dir, face);
	
	if (feather_edges) {
		return sample_cube_face_with_blending(face, uv, dir);
	}
	else {
		return sample_cube_face(face, uv);
	}
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = FRAGCOORD.xy / min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
	vec3 dir = get_ray_direction(uv, VIEWPORT_SIZE);
	
	ALBEDO = sample_cube(dir, -1).rgb;
	
	int face = get_face(dir);
	uv = get_face_uv(dir, face);
	
	
	// Debug options.
	if (show_grid) {
		ALBEDO = ALBEDO * texture(Grid, uv).rgb;
	}
	
#ifdef DEBUG_SHOW_UV
	ALBEDO = vec3(uv.x, uv.y, 0.0); // debug UV display
#endif

#ifdef DEBUG_SHOW_WIREFRAME
	float face_scale = fov_to_face_scale(subcamera_fov);
	float blend_width = face_scale - 1.0;
	uv = (uv - 0.5) * face_scale;
	uv = abs(uv);
	
	float d = 1e9;
	
	if (feather_edges){
		d = abs(0.5 - blend_width * 0.25 - max(uv.x, uv.y));
		ALBEDO = mix(vec3(0,0,1), ALBEDO, clamp(d / 0.005, 0.0, 1.0));
	}
	
	d = abs(0.5 - max(uv.x, uv.y));
	ALBEDO = mix(vec3(0,1,0), ALBEDO, clamp(d / 0.005, 0.0, 1.0));
#endif
}
