module svg

import log
import math

// parse_group_animations scans <g> content for <animateTransform>
// and <animate> children, returning parsed SvgAnimation values.
pub fn parse_group_animations(content string, group_id string) []SvgAnimation {
	if group_id.len == 0 {
		return []
	}
	mut anims := []SvgAnimation{}
	mut pos := 0
	for pos < content.len {
		if anims.len >= max_animations {
			break
		}
		start := find_index(content, '<', pos) or { break }
		tag_end := find_tag_name_end(content, start + 1)
		if tag_end <= start + 1 {
			pos = start + 1
			continue
		}
		tag_name := content[start + 1..tag_end]
		elem_end := find_index(content, '>', start) or { break }
		elem := content[start..elem_end + 1]
		if tag_name == 'animateTransform' {
			if a := parse_animate_transform(elem, group_id) {
				anims << a
			}
		} else if tag_name == 'animate' {
			if a := parse_animate(elem, group_id) {
				anims << a
			}
		}
		pos = elem_end + 1
	}
	return anims
}

// parse_animate_transform extracts a SMIL <animateTransform> element.
fn parse_animate_transform(elem string, gid string) ?SvgAnimation {
	type_attr := find_attr(elem, 'type') or { return none }
	anim_type := match type_attr {
		'rotate' {
			SvgAnimationType.rotate
		}
		'scale' {
			SvgAnimationType.scale
		}
		'translate' {
			SvgAnimationType.translate
		}
		else {
			log.warn('svg: skipping unsupported animateTransform type="${type_attr}"')
			return none
		}
	}
	dur := if d := find_attr(elem, 'dur') {
		parse_smil_duration(d)
	} else {
		f32(0)
	}
	if dur <= 0 {
		return none
	}
	repeat_count := parse_repeat_count(elem)
	begin_time := if b := find_attr(elem, 'begin') {
		parse_smil_duration(b)
	} else {
		f32(0)
	}
	// Parse values (multi-step) or from/to
	values := if v := find_attr(elem, 'values') {
		parse_smil_float_lists(v)
	} else {
		[][]f32{}
	}
	from := if f := find_attr(elem, 'from') {
		parse_smil_values(f, ` `)
	} else {
		[]f32{}
	}
	to := if t := find_attr(elem, 'to') {
		parse_smil_values(t, ` `)
	} else {
		[]f32{}
	}
	return SvgAnimation{
		anim_type:    anim_type
		target_id:    gid
		from:         from
		to:           to
		values:       values
		dur:          dur
		repeat_count: repeat_count
		begin_time:   begin_time
	}
}

// parse_animate extracts a SMIL <animate> element.
// Currently only attributeName="opacity" is supported; other
// attributes (fill, stroke, visibility, etc.) are skipped.
fn parse_animate(elem string, gid string) ?SvgAnimation {
	attr_name := find_attr(elem, 'attributeName') or { return none }
	if attr_name != 'opacity' {
		log.warn('svg: skipping unsupported animate attributeName="${attr_name}"')
		return none
	}
	dur := if d := find_attr(elem, 'dur') {
		parse_smil_duration(d)
	} else {
		f32(0)
	}
	if dur <= 0 {
		return none
	}
	repeat_count := parse_repeat_count(elem)
	begin_time := if b := find_attr(elem, 'begin') {
		parse_smil_duration(b)
	} else {
		f32(0)
	}
	values := if v := find_attr(elem, 'values') {
		parse_smil_float_lists(v)
	} else {
		[][]f32{}
	}
	from := if f := find_attr(elem, 'from') {
		[f.f32()]
	} else {
		[]f32{}
	}
	to := if t := find_attr(elem, 'to') {
		[t.f32()]
	} else {
		[]f32{}
	}
	return SvgAnimation{
		anim_type:    .opacity
		target_id:    gid
		from:         from
		to:           to
		values:       values
		dur:          dur
		repeat_count: repeat_count
		begin_time:   begin_time
	}
}

// parse_repeat_count extracts repeatCount from an element.
// Returns -1 for "indefinite" (default).
fn parse_repeat_count(elem string) f32 {
	rc := find_attr(elem, 'repeatCount') or { return -1 }
	if rc == 'indefinite' {
		return -1
	}
	v := rc.f32()
	if v > 0 {
		return v
	}
	return -1
}

// parse_smil_duration parses SMIL duration strings.
// "1.5s" → 1.5, "500ms" → 0.5, "2" → 2.0 (seconds).
pub fn parse_smil_duration(s string) f32 {
	trimmed := s.trim_space()
	if trimmed.len == 0 {
		return 0
	}
	if trimmed.ends_with('ms') {
		return trimmed[..trimmed.len - 2].f32() / 1000.0
	}
	if trimmed.ends_with('s') {
		return trimmed[..trimmed.len - 1].f32()
	}
	return trimmed.f32()
}

// parse_smil_values splits a separator-delimited string of floats.
// "0.3;1;0.3" with sep=`;` → [0.3, 1.0, 0.3]
// "0 200 170" with sep=` ` → [0, 200, 170]
pub fn parse_smil_values(s string, sep u8) []f32 {
	mut result := []f32{}
	mut start := 0
	for i := 0; i <= s.len; i++ {
		if i == s.len || s[i] == sep {
			part := s[start..i].trim_space()
			if part.len > 0 {
				result << part.f32()
			}
			start = i + 1
		}
	}
	return result
}

// parse_smil_float_lists parses semicolon-separated lists of
// space-separated floats. "0 200 170;360 200 170" →
// [[0,200,170],[360,200,170]]
pub fn parse_smil_float_lists(s string) [][]f32 {
	mut result := [][]f32{}
	mut start := 0
	for i := 0; i <= s.len; i++ {
		if i == s.len || s[i] == `;` {
			part := s[start..i].trim_space()
			if part.len > 0 {
				result << parse_smil_values(part, ` `)
			}
			start = i + 1
		}
	}
	return result
}

// evaluate_animation computes the current animation value from
// elapsed time. Returns interpolated component values.
pub fn evaluate_animation(anim SvgAnimation, elapsed_s f32) []f32 {
	// Adjust for begin offset
	t := elapsed_s - anim.begin_time
	if t < 0 {
		return anim.default_value()
	}
	// Compute position within duration, handling repeat
	mut cycle_t := t
	if anim.dur > 0 {
		if anim.repeat_count < 0 {
			// Indefinite repeat
			cycle_t = f32(math.fmod(t, anim.dur))
		} else {
			total := anim.dur * anim.repeat_count
			if t >= total {
				// Animation ended: return final value
				return anim.final_value()
			}
			cycle_t = f32(math.fmod(t, anim.dur))
		}
	}
	frac := if anim.dur > 0 { cycle_t / anim.dur } else { f32(0) }
	return anim.interpolate(frac)
}

// evaluate_animation_into computes current animation value and writes
// components into `out`, reusing the provided scratch slice.
// Returns the number of written components.
pub fn evaluate_animation_into(anim SvgAnimation, elapsed_s f32, mut out []f32) int {
	t := elapsed_s - anim.begin_time
	if t < 0 {
		return copy_animation_values_into(anim.default_value(), mut out)
	}
	mut cycle_t := t
	if anim.dur > 0 {
		if anim.repeat_count < 0 {
			cycle_t = f32(math.fmod(t, anim.dur))
		} else {
			total := anim.dur * anim.repeat_count
			if t >= total {
				return copy_animation_values_into(anim.final_value(), mut out)
			}
			cycle_t = f32(math.fmod(t, anim.dur))
		}
	}
	frac := if anim.dur > 0 { cycle_t / anim.dur } else { f32(0) }
	return interpolate_animation_into(anim, frac, mut out)
}

// default_value returns the starting value of the animation.
fn (anim &SvgAnimation) default_value() []f32 {
	if anim.values.len > 0 {
		return anim.values[0]
	}
	if anim.from.len > 0 {
		return anim.from
	}
	return []f32{}
}

// final_value returns the last keyframe value.
fn (anim &SvgAnimation) final_value() []f32 {
	if anim.values.len > 0 {
		return anim.values[anim.values.len - 1]
	}
	if anim.to.len > 0 {
		return anim.to
	}
	return anim.default_value()
}

// interpolate computes value at fraction frac ∈ [0,1] of one cycle.
fn (anim &SvgAnimation) interpolate(frac f32) []f32 {
	if anim.values.len >= 2 {
		// Multi-keyframe interpolation
		n := anim.values.len - 1
		scaled := frac * f32(n)
		idx := int(scaled)
		seg_frac := scaled - f32(idx)
		i0 := if idx < n { idx } else { n }
		i1 := if idx + 1 <= n { idx + 1 } else { n }
		return lerp_floats(anim.values[i0], anim.values[i1], seg_frac)
	}
	// from/to interpolation
	if anim.from.len > 0 && anim.to.len > 0 {
		return lerp_floats(anim.from, anim.to, frac)
	}
	return anim.default_value()
}

// lerp_floats linearly interpolates between two float arrays.
fn lerp_floats(a []f32, b []f32, t f32) []f32 {
	n := if a.len < b.len { a.len } else { b.len }
	mut out := []f32{len: n}
	for i := 0; i < n; i++ {
		out[i] = a[i] + (b[i] - a[i]) * t
	}
	return out
}

fn copy_animation_values_into(src []f32, mut out []f32) int {
	out.clear()
	if src.len == 0 {
		return 0
	}
	if out.cap < src.len {
		out = []f32{cap: src.len}
	}
	out << src
	return src.len
}

fn interpolate_animation_into(anim SvgAnimation, frac f32, mut out []f32) int {
	if anim.values.len >= 2 {
		n := anim.values.len - 1
		scaled := frac * f32(n)
		idx := int(scaled)
		seg_frac := scaled - f32(idx)
		i0 := if idx < n { idx } else { n }
		i1 := if idx + 1 <= n { idx + 1 } else { n }
		return lerp_floats_into(anim.values[i0], anim.values[i1], seg_frac, mut out)
	}
	if anim.from.len > 0 && anim.to.len > 0 {
		return lerp_floats_into(anim.from, anim.to, frac, mut out)
	}
	return copy_animation_values_into(anim.default_value(), mut out)
}

fn lerp_floats_into(a []f32, b []f32, t f32, mut out []f32) int {
	n := if a.len < b.len { a.len } else { b.len }
	out.clear()
	if n == 0 {
		return 0
	}
	if out.cap < n {
		out = []f32{cap: n}
	}
	for i := 0; i < n; i++ {
		out << a[i] + (b[i] - a[i]) * t
	}
	return n
}

// build_rotation_matrix builds an affine rotation matrix around (cx,cy).
pub fn build_rotation_matrix(angle_deg f32, cx f32, cy f32) [6]f32 {
	rad := angle_deg * math.pi / 180.0
	cos_a := math.cosf(rad)
	sin_a := math.sinf(rad)
	return [
		cos_a,
		sin_a,
		-sin_a,
		cos_a,
		cx - cos_a * cx + sin_a * cy,
		cy - sin_a * cx - cos_a * cy,
	]!
}

// build_scale_matrix builds an affine scale matrix.
pub fn build_scale_matrix(sx f32, sy f32) [6]f32 {
	return [sx, f32(0), f32(0), sy, f32(0), f32(0)]!
}

// build_translate_matrix builds an affine translation matrix.
pub fn build_translate_matrix(tx f32, ty f32) [6]f32 {
	return [f32(1), f32(0), f32(0), f32(1), tx, ty]!
}
