module svg

import math

fn test_parse_smil_duration_seconds() {
	assert parse_smil_duration('1.5s') == f32(1.5)
	assert parse_smil_duration('2s') == f32(2.0)
	assert parse_smil_duration('0.5s') == f32(0.5)
}

fn test_parse_smil_duration_milliseconds() {
	assert parse_smil_duration('500ms') == f32(0.5)
	assert parse_smil_duration('1200ms') == f32(1.2)
	assert parse_smil_duration('100ms') == f32(0.1)
}

fn test_parse_smil_duration_bare_number() {
	assert parse_smil_duration('2') == f32(2.0)
	assert parse_smil_duration('0.75') == f32(0.75)
}

fn test_parse_smil_duration_empty() {
	assert parse_smil_duration('') == f32(0)
	assert parse_smil_duration('  ') == f32(0)
}

fn test_parse_smil_values_semicolon() {
	vals := parse_smil_values('0.3;1;0.3', `;`)
	assert vals.len == 3
	assert vals[0] == f32(0.3)
	assert vals[1] == f32(1.0)
	assert vals[2] == f32(0.3)
}

fn test_parse_smil_values_space() {
	vals := parse_smil_values('0 200 170', ` `)
	assert vals.len == 3
	assert vals[0] == f32(0)
	assert vals[1] == f32(200)
	assert vals[2] == f32(170)
}

fn test_parse_smil_float_lists() {
	lists := parse_smil_float_lists('0 200 170;360 200 170')
	assert lists.len == 2
	assert lists[0].len == 3
	assert lists[0][0] == f32(0)
	assert lists[0][2] == f32(170)
	assert lists[1][0] == f32(360)
}

fn test_evaluate_animation_from_to_at_start() {
	anim := SvgAnimation{
		anim_type: .rotate
		target_id: 'ring'
		from:      [f32(0), 200, 170]
		to:        [f32(360), 200, 170]
		dur:       1.5
	}
	vals := evaluate_animation(anim, 0.0)
	assert vals.len == 3
	assert vals[0] == f32(0)
}

fn test_evaluate_animation_from_to_at_mid() {
	anim := SvgAnimation{
		anim_type: .rotate
		target_id: 'ring'
		from:      [f32(0), 200, 170]
		to:        [f32(360), 200, 170]
		dur:       1.5
	}
	vals := evaluate_animation(anim, 0.75)
	assert vals.len == 3
	assert math.abs(vals[0] - 180.0) < 0.1
	// cx/cy remain constant
	assert vals[1] == f32(200)
	assert vals[2] == f32(170)
}

fn test_evaluate_animation_from_to_at_end() {
	anim := SvgAnimation{
		anim_type: .rotate
		target_id: 'ring'
		from:      [f32(0), 200, 170]
		to:        [f32(360), 200, 170]
		dur:       1.5
	}
	// Indefinite repeat: at exactly dur, wraps to 0
	vals := evaluate_animation(anim, 1.5)
	assert vals.len == 3
	assert vals[0] < 1.0 // near 0 after wrap
}

fn test_evaluate_animation_looped() {
	anim := SvgAnimation{
		anim_type: .rotate
		target_id: 'ring'
		from:      [f32(0), 200, 170]
		to:        [f32(360), 200, 170]
		dur:       1.5
	}
	// At 2.25s = 1.5 cycles, frac=0.5
	vals := evaluate_animation(anim, 2.25)
	assert vals.len == 3
	assert math.abs(vals[0] - 180.0) < 0.1
}

fn test_evaluate_animation_values_multi_keyframe() {
	anim := SvgAnimation{
		anim_type: .opacity
		target_id: 'dot-0'
		values:    [[f32(0.3)], [f32(1.0)], [f32(0.3)]]
		dur:       1.2
	}
	// At t=0: 0.3
	v0 := evaluate_animation(anim, 0.0)
	assert v0.len == 1
	assert math.abs(v0[0] - 0.3) < 0.01
	// At t=0.3 (25% of 1.2): between 0.3 and 1.0
	v1 := evaluate_animation(anim, 0.3)
	assert v1[0] > 0.3 && v1[0] < 1.0
	// At t=0.6 (50% of 1.2): 1.0
	v2 := evaluate_animation(anim, 0.6)
	assert math.abs(v2[0] - 1.0) < 0.01
}

fn test_evaluate_animation_with_begin_offset() {
	anim := SvgAnimation{
		anim_type:  .opacity
		target_id:  'dot-1'
		values:     [[f32(0.3)], [f32(1.0)], [f32(0.3)]]
		dur:        1.2
		begin_time: 0.15
	}
	// Before begin: return default (first keyframe)
	v0 := evaluate_animation(anim, 0.1)
	assert math.abs(v0[0] - 0.3) < 0.01
	// At begin: start of animation
	v1 := evaluate_animation(anim, 0.15)
	assert math.abs(v1[0] - 0.3) < 0.01
}

fn test_evaluate_animation_finite_repeat() {
	anim := SvgAnimation{
		anim_type:    .rotate
		target_id:    'test'
		from:         [f32(0)]
		to:           [f32(360)]
		dur:          1.0
		repeat_count: 2.0
	}
	// Past 2 cycles: returns final value
	vals := evaluate_animation(anim, 3.0)
	assert vals.len == 1
	assert math.abs(vals[0] - 360.0) < 0.1
}

fn test_build_rotation_matrix() {
	m := build_rotation_matrix(90, 0, 0)
	// 90 deg: cos=0, sin=1 → [0,1,-1,0,0,0]
	assert math.abs(m[0]) < 0.001
	assert math.abs(m[1] - 1.0) < 0.001
	assert math.abs(m[2] + 1.0) < 0.001
	assert math.abs(m[3]) < 0.001
}

fn test_build_rotation_matrix_with_center() {
	m := build_rotation_matrix(360, 200, 170)
	// Full rotation = identity equivalent
	assert math.abs(m[0] - 1.0) < 0.001
	assert math.abs(m[3] - 1.0) < 0.001
	assert math.abs(m[4]) < 0.1
	assert math.abs(m[5]) < 0.1
}

fn test_build_scale_matrix() {
	m := build_scale_matrix(2.0, 3.0)
	assert m[0] == f32(2.0)
	assert m[3] == f32(3.0)
	assert m[4] == f32(0)
	assert m[5] == f32(0)
}

fn test_build_translate_matrix() {
	m := build_translate_matrix(10.0, 20.0)
	assert m[0] == f32(1.0)
	assert m[3] == f32(1.0)
	assert m[4] == f32(10.0)
	assert m[5] == f32(20.0)
}

fn test_parse_group_animations_rotate() {
	content := '
		<circle cx="200" cy="170" r="120"/>
		<animateTransform attributeName="transform" type="rotate" from="0 200 170" to="360 200 170" dur="1.5s" repeatCount="indefinite"/>
	'
	anims := parse_group_animations(content, 'ring')
	assert anims.len == 1
	assert anims[0].anim_type == .rotate
	assert anims[0].target_id == 'ring'
	assert anims[0].dur == f32(1.5)
	assert anims[0].from.len == 3
	assert anims[0].from[0] == f32(0)
	assert anims[0].to[0] == f32(360)
}

fn test_parse_group_animations_opacity() {
	content := '
		<circle cx="200" cy="125" r="5" fill="#3399cc"/>
		<animate attributeName="opacity" values="0.3;1;0.3" dur="1.2s" begin="0.15s" repeatCount="indefinite"/>
	'
	anims := parse_group_animations(content, 'dot-1')
	assert anims.len == 1
	assert anims[0].anim_type == .opacity
	assert anims[0].target_id == 'dot-1'
	assert anims[0].dur == f32(1.2)
	assert anims[0].begin_time == f32(0.15)
	assert anims[0].values.len == 3
	assert anims[0].values[0][0] == f32(0.3)
	assert anims[0].values[1][0] == f32(1.0)
}

fn test_parse_group_animations_empty_group_id() {
	content := '<animate attributeName="opacity" values="1;0;1" dur="1s"/>'
	anims := parse_group_animations(content, '')
	assert anims.len == 0
}

fn test_round_trip_smil_svg() {
	svg_content := '
	<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
		<g id="spinner">
			<circle cx="50" cy="50" r="40" fill="red"/>
			<animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="1s" repeatCount="indefinite"/>
		</g>
	</svg>'
	vg := parse_svg(svg_content) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert vg.animations.len == 1
	assert vg.animations[0].anim_type == .rotate
	assert vg.animations[0].target_id == 'spinner'
	assert vg.animations[0].dur == f32(1.0)
	// Paths should have group_id set
	assert vg.paths.len > 0
	assert vg.paths[0].group_id == 'spinner'
}
