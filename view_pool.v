module gui

import datatypes

struct ViewPool {
mut:
	containers         datatypes.LinkedList[&ContainerView] = datatypes.LinkedList[&ContainerView]{}
	texts              datatypes.LinkedList[&TextView]      = datatypes.LinkedList[&TextView]{}
	rtfs               datatypes.LinkedList[&RtfView]       = datatypes.LinkedList[&RtfView]{}
	images             datatypes.LinkedList[&ImageView]     = datatypes.LinkedList[&ImageView]{}
	in_use             map[u64]bool
	containers_created u64
	containers_reused  u64
	texts_created      u64
	texts_reused       u64
}

fn (mut vp ViewPool) allocate_container_view() ContainerView {
	if vp.containers.len > 0 {
		cv := vp.containers.pop() or { panic('allocate_container_view') }
		vp.containers_reused += 1
		vp.in_use[cv.uid] = true
		return *cv
	}

	cv := ContainerView{}
	vp.containers_created += 1
	vp.in_use[cv.uid] = true
	return cv
}

fn (mut vp ViewPool) allocate_text_view() TextView {
	if vp.texts.len > 0 {
		tv := vp.texts.pop() or { panic('allocate_text_view') }
		vp.texts_reused += 1
		vp.in_use[tv.uid] = true
		return *tv
	}

	tv := TextView{}
	vp.texts_created += 1
	vp.in_use[tv.uid] = true
	return tv
}

fn (mut vp ViewPool) reclaim_view(mut view View) {
	for mut content in view.content {
		vp.reclaim_view(mut content)
	}
	match view.view_type {
		.container { vp.reclaim_container_view(mut view as ContainerView) }
		.text { vp.reclaim_text_view(mut view as TextView) }
		.rtf {}
		.image {}
	}
}

fn (mut vp ViewPool) reclaim_container_view(mut cv ContainerView) {
	if cv.uid !in vp.in_use {
		return
	}
	cv.reset_fields() // cv.uid never reset
	vp.in_use.delete(cv.uid)
	vp.containers.push(cv)
}

fn (mut vp ViewPool) reclaim_text_view(mut tv TextView) {
	if tv.uid !in vp.in_use {
		return
	}
	tv.reset_fields() // tv.uid never reset
	vp.in_use.delete(tv.uid)
	vp.texts.push(tv)
}

pub fn (vp &ViewPool) stats() string {
	title := 'View Pool Stats\n=============================='
	in_use_len := 'in_use remaining:     ${with_commas(u64(vp.in_use.len))}'
	containers_remaining := 'containers remaining: ${with_commas(u64(vp.containers.len))}'
	containers_created := 'containers created:   ${with_commas(vp.containers_created)}'
	containers_reused := 'containers reused:    ${with_commas(vp.containers_reused)}'
	containers := '${containers_remaining}\n${containers_created}\n${containers_reused}'

	texts_remaining := 'texts remaining:      ${with_commas(u64(vp.texts.len))}'
	texts_created := 'texts created:        ${with_commas(vp.texts_created)}'
	texts_reused := 'texts reused:         ${with_commas(vp.texts_reused)}'
	texts := '${texts_remaining}\n${texts_created}\n${texts_reused}'

	return '${title}\n${in_use_len}\n\n${containers}\n\n${texts}'
}

fn with_commas(num u64) string {
	if num < 1000 {
		return num.str()
	}
	return with_commas(num / 1000) + ',${(num % 1000):03u}'
}
