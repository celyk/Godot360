#ifndef GODOT360_PROJECTIONS
#define GODOT360_PROJECTIONS

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

#endif /*GODOT360_PROJECTIONS*/