module gui

// BoundedMap is a map with maximum size. When full, oldest entries are
// evicted (FIFO). Used to prevent unbounded memory growth in view state.
struct BoundedMap[K, V] {
mut:
	data     map[K]V
	order    []K
	max_size int = 100
}

// set adds or updates key-value pair. Evicts oldest if at capacity.
fn (mut m BoundedMap[K, V]) set(key K, value V) {
	if key !in m.data {
		if m.data.len >= m.max_size && m.order.len > 0 {
			oldest := m.order[0]
			m.data.delete(oldest)
			m.order.delete(0)
		}
		m.order << key
	}
	m.data[key] = value
}

// get returns value for key, or none if not found.
fn (m &BoundedMap[K, V]) get(key K) ?V {
	return m.data[key] or { return none }
}

// delete removes key from map.
fn (mut m BoundedMap[K, V]) delete(key K) {
	if key in m.data {
		m.data.delete(key)
		idx := m.order.index(key)
		if idx >= 0 {
			m.order.delete(idx)
		}
	}
}

// contains returns true if key exists in map.
fn (m &BoundedMap[K, V]) contains(key K) bool {
	return key in m.data
}

// len returns number of entries in map.
fn (m &BoundedMap[K, V]) len() int {
	return m.data.len
}

// clear removes all entries from map.
fn (mut m BoundedMap[K, V]) clear() {
	m.data.clear()
	m.order.clear()
}

// keys returns all keys in insertion order.
fn (m &BoundedMap[K, V]) keys() []K {
	return m.order
}

// BoundedTreeState is a specialized bounded map for tree state (string -> map[string]bool).
// Maps require clone() when stored, which generic BoundedMap can't handle.
struct BoundedTreeState {
mut:
	data     map[string]map[string]bool
	order    []string
	max_size int = 30
}

// set adds or updates tree state. Evicts oldest if at capacity.
fn (mut m BoundedTreeState) set(key string, value map[string]bool) {
	if key !in m.data {
		if m.data.len >= m.max_size && m.order.len > 0 {
			oldest := m.order[0]
			m.data.delete(oldest)
			m.order.delete(0)
		}
		m.order << key
	}
	m.data[key] = value.clone()
}

// get returns tree state for key, or none if not found.
fn (m &BoundedTreeState) get(key string) ?map[string]bool {
	return m.data[key] or { return none }
}

// contains returns true if key exists.
fn (m &BoundedTreeState) contains(key string) bool {
	return key in m.data
}

// len returns number of entries.
fn (m &BoundedTreeState) len() int {
	return m.data.len
}

// clear removes all entries.
fn (mut m BoundedTreeState) clear() {
	m.data.clear()
	m.order.clear()
}

// BoundedSvgCache is an LRU cache for SVG data.
// Access moves item to end; evicts oldest on capacity.
struct BoundedSvgCache {
mut:
	data     map[string]&CachedSvg
	order    []string
	max_size int = 100
}

// get returns cached SVG and moves to end (LRU).
fn (mut m BoundedSvgCache) get(key string) ?&CachedSvg {
	if key in m.data {
		// Move to end for LRU
		idx := m.order.index(key)
		if idx >= 0 {
			m.order.delete(idx)
			m.order << key
		}
		return m.data[key] or { return none }
	}
	return none
}

// set adds SVG to cache. Evicts oldest if at capacity.
fn (mut m BoundedSvgCache) set(key string, value &CachedSvg) {
	if key !in m.data {
		if m.data.len >= m.max_size && m.order.len > 0 {
			oldest := m.order[0]
			m.data.delete(oldest)
			m.order.delete(0)
		}
		m.order << key
	}
	unsafe {
		m.data[key] = value
	}
}

// delete removes key from cache.
fn (mut m BoundedSvgCache) delete(key string) {
	if key in m.data {
		m.data.delete(key)
		idx := m.order.index(key)
		if idx >= 0 {
			m.order.delete(idx)
		}
	}
}

// contains returns true if key exists.
fn (m &BoundedSvgCache) contains(key string) bool {
	return key in m.data
}

// keys returns all keys (for iteration).
fn (m &BoundedSvgCache) keys() []string {
	return m.order
}

// len returns number of entries.
fn (m &BoundedSvgCache) len() int {
	return m.data.len
}

// clear removes all entries.
fn (mut m BoundedSvgCache) clear() {
	m.data.clear()
	m.order.clear()
}

// BoundedMarkdownCache is a FIFO cache for parsed markdown blocks.
struct BoundedMarkdownCache {
mut:
	data     map[int][]MarkdownBlock
	order    []int
	max_size int = 50
}

// get returns cached blocks.
fn (m &BoundedMarkdownCache) get(key int) ?[]MarkdownBlock {
	return m.data[key] or { return none }
}

// set adds blocks to cache. Evicts oldest if at capacity.
fn (mut m BoundedMarkdownCache) set(key int, value []MarkdownBlock) {
	if key !in m.data {
		if m.data.len >= m.max_size && m.order.len > 0 {
			oldest := m.order[0]
			m.data.delete(oldest)
			m.order.delete(0)
		}
		m.order << key
	}
	m.data[key] = value.clone()
}

// len returns number of entries.
fn (m &BoundedMarkdownCache) len() int {
	return m.data.len
}

// clear removes all entries.
fn (mut m BoundedMarkdownCache) clear() {
	m.data.clear()
	m.order.clear()
}
