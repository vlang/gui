module gui

// Runtime GC and resource-leak tests. Verifies that layout_clear,
// view_clear, bounded containers, and scratch pools behave within
// expected bounds. See CLAUDE.md "GC / Boehm False-Retention Rules".

fn test_layout_clear_zeroes_tree() {
	// 3 levels, fanout 5 → 1 + 5 + 25 + 125 = 156 nodes
	mut root := build_deep_layout(3, 5)
	assert root.children.len == 5
	assert !isnil(root.shape)

	layout_clear(mut root)

	// Use isnil() — assert on &Shape triggers V codegen for
	// FreeType types via str() which fails to compile.
	assert isnil(root.shape)
	assert isnil(root.parent)
	assert root.children.len == 0
}

fn test_view_clear_zeroes_tree() {
	mut inner := &ContainerView{
		content: [
			View(&ContainerView{
				content: [View(&ContainerView{})]
			}),
			View(&ContainerView{}),
		]
	}
	assert inner.content.len == 2

	mut v := View(inner)
	view_clear(mut v)

	assert inner.content.len == 0
}

fn test_bounded_map_capacity() {
	cap := 10
	mut m := BoundedMap[string, int]{
		max_size: cap
	}
	for i in 0 .. cap * 2 {
		m.set('k${i}', i)
		assert m.len() <= cap
	}
	assert m.len() == cap
}

fn test_bounded_markdown_cache_capacity() {
	cap := 10
	mut cache := BoundedMarkdownCache{
		max_size: cap
	}
	for i in 0 .. cap * 2 {
		cache.set(i, []MarkdownBlock{})
		assert cache.len() <= cap
	}
	assert cache.len() == cap
}

fn test_scratch_pool_shrinks() {
	mut pools := ScratchPools{}

	mut scratch := pools.take_svg_transform_tris()
	// Grow well past retain_max
	for _ in 0 .. scratch_svg_tris_retain_max + 1000 {
		scratch << 1.0
	}
	pools.put_svg_transform_tris(mut scratch)

	// After put, pool should have shrunk to shrink_to cap
	fresh := pools.take_svg_transform_tris()
	assert fresh.cap <= scratch_svg_tris_shrink_to
}

fn test_layout_rebuild_memory_bounded() {
	// 500 cycles of build + clear. Assert heap growth is bounded.
	// depth=2, fanout=5 → 31 nodes per cycle.
	baseline := gc_memory_use()

	for _ in 0 .. 500 {
		mut tree := build_deep_layout(2, 5)
		layout_clear(mut tree)
	}
	gc_collect()

	after := gc_memory_use()
	growth := if after > baseline { after - baseline } else { usize(0) }
	max_growth := usize(2 * 1024 * 1024) // 2 MB
	assert growth < max_growth
}
