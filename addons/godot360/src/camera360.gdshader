shader_type spatial;
render_mode unshaded, cull_front;

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


vec3 latlon_to_ray(vec2 latlon) {
	float lat = latlon.x;
	float lon = latlon.y;
	return vec3(sin(lon) * cos(lat), sin(lat), -cos(lon) * cos(lat));
}

vec3 rectilinear_inverse(vec2 p) {
	float r = sqrt(p.x * p.x + p.y * p.y);
	float theta = atan(r);
	float s = sin(theta);
	return vec3(p.x / r * s, p.y / r * s, -cos(theta));
}
vec2 rectilinear_forward(vec2 latlon) {
	vec3 ray = latlon_to_ray(latlon);
	float theta = acos(-ray.z);
	float r = tan(theta);
	float c = r / length(ray.xy);
	return vec2(ray.x * c, ray.y * c);
}
vec3 rectilinear_ray(vec2 p) {
	float scale = rectilinear_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return rectilinear_inverse(p * scale);
}

vec3 panini_inverse(vec2 p) {
	float d = 1.0;
	float k = p.x * p.x / ((d + 1.0) * (d + 1.0));
	float dscr = k * k * d * d - (k + 1.0) * (k * d * d - 1.0);
	float clon = (-k * d + sqrt(dscr)) / (k + 1.0);
	float s = (d + 1.0) / (d + clon);
	float lon = atan(p.x, (s * clon));
	float lat = atan(p.y, s);
	return latlon_to_ray(vec2(lat, lon));
}
vec2 panini_forward(vec2 latlon) {
	float d = 1.0;
	float s = (d + 1.0) / (d + cos(latlon.y));
	float x = s * sin(latlon.y);
	float y = s * tan(latlon.x);
	return vec2(x, y);
}
vec3 panini_ray(vec2 p) {
	float scale = panini_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return panini_inverse(p * scale);
}

vec3 fisheye_inverse(vec2 p) {
	float r = sqrt(p.x * p.x + p.y * p.y);

	if (r > PI) {
		return vec3(0.0, 0.0, 0.0);
	}
	else {
		float theta = r;
		float s = sin(theta);
		return vec3(p.x / r * s, p.y / r * s, -cos(theta));
	}
}
vec2 fisheye_forward(vec2 latlon) {
	vec3 ray = latlon_to_ray(latlon);
	float theta = acos(-ray.z);
	float r = theta;
	float c = r / length(ray.xy);
	return vec2(ray.x * c, ray.y * c);
}
vec3 fisheye_ray(vec2 p) {
	float scale = fisheye_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return fisheye_inverse(p * scale);
}
vec3 fulldome(vec2 p) {
	// This will dezoom enough that we should get exactly
	// all of the fov in the viewport
	vec2 dezoomed = p * 2.0;
	// For fulldome output, we want to crop the ouput so that we only render
	// the circle corresponding to the fov
	if (length(dezoomed) > 1.0) {
		return vec3(0.0, 0.0, 0.0);
	}
	// If we are within the 1 unit circle, we want the fisheye perspective.
	return fisheye_ray(dezoomed);
}

vec3 stereographic_inverse(vec2 p) {
	float scale = 0.5;
	float r = sqrt(p.x * p.x + p.y * p.y);
	float theta = atan(r) / scale;
	float s = sin(theta);
	return vec3(p.x / r * s, p.y / r * s, -cos(theta));
}
vec2 stereographic_forward(vec2 latlon) {
	vec3 ray = latlon_to_ray(latlon);
	float theta = acos(-ray.z);
	float scale = 0.5;
	float r = tan(theta * scale);
	float c = r / length(ray.xy);
	return vec2(ray.x * c, ray.y * c);
}
vec3 stereographic_ray(vec2 p) {
	float scale = stereographic_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return stereographic_inverse(p * scale);
}

vec3 cylindrical_inverse(vec2 p) {
	if (abs(p.x) > PI) {
		return vec3(0.0, 0.0, 0.0);
	} else {
		float lon = p.x;
		float lat = atan(p.y);
		return latlon_to_ray(vec2(lat, lon));
	}
}
vec2 cylindrical_forward(vec2 latlon) {
	return(vec2(latlon.y, tan(latlon.x)));
}
vec3 cylindrical_ray(vec2 p) {
	float scale = cylindrical_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return cylindrical_inverse(p * scale);
}

vec3 equirectangular_inverse(vec2 p) {
	if (abs(p.y) > PI / 2.0 || abs(p.x) > PI) {
		return vec3(0.0, 0.0, 0.0);
	} else {
		float lon = p.x;
		float lat = p.y;
		return latlon_to_ray(vec2(lat, lon));
	}
}
vec2 equirectangular_forward(vec2 latlon) {
	return vec2(latlon.y, latlon.x);
}
vec3 equirectangular_ray(vec2 p) {
	float scale = equirectangular_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return equirectangular_inverse(p * scale);
}

vec3 mercator_inverse(vec2 p) {
	if (abs(p.x) > PI) {
		return vec3(0.0, 0.0, 0.0);
	} else {
		float lon = p.x;
		float lat = atan(sinh(p.y));
		return latlon_to_ray(vec2(lat, lon));
	}
}
vec2 mercator_forward(vec2 latlon) {
	return vec2(latlon.y, log(tan(PI / 4.0 + latlon.x / 2.0)));
}
vec3 mercator_ray(vec2 p) {
	float scale = mercator_forward(vec2(0.0, radians(fovx) / 2.0)).x;
	return mercator_inverse(p * scale);
}

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

vec3 srgb_to_linear(vec3 color) {
	return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

//enum CubeFace{FRONT, BACK, LEFT, RIGHT, BOTTOM, TOP}
const int FRONT = 0;
const int BACK = 1;
const int LEFT = 2;
const int RIGHT = 3;
const int BOTTOM = 4;
const int TOP = 5;

// Computes the blend factors for a face given base UV coordinates.
// Equivalent to trilinear interpolation around the corners.
// Undefined for width <= 0.
vec3 edge_blend_factors(vec2 uv, float width) {
	uv = uv * 2.0 - 1.0;
	uv = abs(uv);
	
	// Blend factors.
	vec3 q = vec3(max(uv.x, uv.y), uv.x, uv.y);
	
	// Remap, smooth and clamp the blend factors.
	q = smoothstep(1.0 - width, 1.0, q);
	
	q.x = 1.0 - q.x;
	
	// Ensure that each face blends evenly.
	q /= q.x + q.y + q.z;
	
	// We only want to blend half way. The other half belongs to the neighbouring faces.
	q = mix(vec3(0.5, 0.0, 0.0), vec3(1.0, 0.5, 0.5), q);
	
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

mat3 get_face_tangent_basis(int face) {
	mat3 tbn = mat3(1);
	
	switch(face){
		case FRONT:
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(dir.x / az, dir.y / az)) + 0.5)
		case BACK: 
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(-dir.x / az, dir.y / az)) + 0.5)
		case LEFT: 
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(-dir.z / ax, dir.y / ax)) + 0.5)
		case RIGHT: 
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(dir.z / ax, dir.y / ax)) + 0.5)
		case BOTTOM: 
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(dir.x / ay, dir.z / ay)) + 0.5);
		case TOP: 
			tbn[0] = vec3(1,0,0);
			tbn[1] = vec3(0,1,0);
			tbn[2] = cross(tbn[0], tbn[1]);
			//return vec2(fov_fix * 0.5 * (vec2(dir.x / ay, -dir.z / ay)) + 0.5);
	}
	
	return tbn;
	return tbn;
}

vec2 get_face_uv(vec3 dir, int face) {
	float ax = abs(dir.x);
	float ay = abs(dir.y);
	float az = abs(dir.z);
	
	float fov_fix = 1.0 / tan(radians(subcamera_fov / 2.0));
	
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
	}
	return vec4(0);
}

vec4 sample_cube_face(int face, vec2 uv) {
	vec4 face_color = get_face_color(face);
	vec4 grid_sample = texture(Grid, uv);
	float grid_alpha = 0.3;
	
	switch(face){
		case FRONT:
			vec4 face_sample = texture(Texture0, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case BACK: 
			vec4 face_sample = texture(Texture5, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case LEFT:
			vec4 face_sample = texture(Texture1, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case RIGHT:
			vec4 face_sample = texture(Texture2, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case BOTTOM:
			vec4 face_sample = texture(Texture3, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
		case TOP: 
			vec4 face_sample = texture(Texture4, uv);
			if (!show_grid) return face_sample;
			return mix(face_sample, face_sample * face_color * grid_sample, grid_alpha);
	}
	
	return vec4(0);
}

vec4 sample_cube_face_with_blending(int face, vec2 uv) {
	int x_face = face;
	int y_face = face;
	
	/*
	for (int i = 0; i < 6; i++) {
		
	}*/
	
	return sample_cube_face(face, uv) * edge_blend_factors(uv, 0.5).x;
}

vec4 sample_cube(vec3 dir, int exclude_face) {
	int face = get_face(dir);
	vec2 uv = get_face_uv(dir, face);
	
	if (feather_edges) {
		return sample_cube_face_with_blending(face, uv);
	}
	else {
		return sample_cube_face(face, uv);
	}
}

void fragment() {
	bool debug = false;

	vec2 uv = FRAGCOORD.xy / min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
	vec3 dir = get_ray_direction(uv, VIEWPORT_SIZE);
	
	ALBEDO = srgb_to_linear(sample_cube(dir, -1).rgb);
	
	if (debug) {
		int face = get_face(dir);
		uv = get_face_uv(dir, face);
		
		ALBEDO = vec3(uv.x, uv.y, 0.0); // debug UV display
		if (show_grid) {
			ALBEDO = ALBEDO * texture(Grid, uv).rgb;
		}
	}
}
