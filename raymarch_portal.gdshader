shader_type spatial;

#include "sdf_noise.gdshaderinc"

render_mode unshaded;
render_mode depth_test_disabled, cull_front;

uniform sampler2D depth_tex : hint_depth_texture;

group_uniforms Color;

uniform float col_distance_scale = 1.0;
uniform vec3 col_near : source_color = vec3(1.0);
uniform vec3 col_far : source_color = vec3(0.0);
uniform float emission_boost = 1.0;

group_uniforms;

group_uniforms SDFNoise;

uniform float sphere_radius = 0.5;

uniform float noise_scale = 1.0;
uniform int detail = 4;
uniform float rough = 0.5;
uniform float inflate = 0.1;
uniform float smooth_fac = 0.2;

uniform float step_mult = 1.0;

group_uniforms;

mat3 y_rot(float angle) {
	return mat3(
		vec3(cos(angle), 0.0, -sin(angle)),
		vec3(0.0, 1.0, 0.0),
		vec3(sin(angle), 0.0, cos(angle))
	);
}

float sdf_map(vec3 pos) {
	float sphere_dist = length(pos) - sphere_radius;
	
	vec3 noise_offset = vec3(0.0, -TIME * 0.1, 0.0);
	
	pos = y_rot(pos.y * 10.0) * pos;
	
	pos = pos * noise_scale + noise_offset;
	
	sphere_dist = sdFbm(pos, detail, rough, inflate, smooth_fac, sphere_dist);
	
	return -sphere_dist;
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;
	
	vec4 wpos = INV_VIEW_MATRIX * (upos / upos.w);
	
	vec3 obj_position = -(inverse(MODEL_MATRIX) * wpos).xyz;
	vec3 obj_view_vec = inverse(mat3(MODEL_MATRIX)) * mat3(INV_VIEW_MATRIX) * VIEW;
	
	vec3 view_dir = normalize(obj_view_vec);
	
	vec3 cur_pos = obj_position;
	for (int i = 0; i < 50; i++) {
		
		float offset = sdf_map(cur_pos);
		
		if (offset < -0.005) {break;}
		
		cur_pos += view_dir * offset * step_mult;
	}
	
	float cur_dist = sdf_map(cur_pos);
	
	float alpha = 1.0 - clamp(cur_dist * -100.0, 0.0, 1.0);
	ALPHA = pow(alpha, 2.0);
	
	float vol_depth = distance(obj_position, cur_pos);
	
	float col_mix_fac = pow(1.0 - exp(-col_distance_scale * vol_depth), 2.0);
	
	vec3 vol_color = mix(col_near, col_far, col_mix_fac);
	
	ALBEDO.xyz = vol_color * emission_boost;
}
