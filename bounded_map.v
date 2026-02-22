module gui

// BoundedMap is a map with maximum size. When full, oldest entries are
// evicted (FIFO). Used to prevent unbounded memory growth in view state.
struct BoundedMap[K, V] {
mut:
	data     map[K]V
	order    []K
	head     int
	max_size int = 100
}

const bounded_order_compact_min = 64

// set adds or updates key-value pair. Evicts oldest if at capacity.
fn (mut m BoundedMap[K, V]) set(key K, value V) {
	if m.max_size < 1 {
		return
	}
	if key in m.data {
		m.data[key] = value
		return
	}
	if m.data.len >= m.max_size && m.order.len > m.head {
		for m.head < m.order.len {
			oldest_key := m.order[m.head]
			m.head++
			if oldest_key in m.data {
				m.data.delete(oldest_key)
				break
			}
		}
	}
	m.order << key
	m.data[key] = value
	m.compact_order()
}

// get returns value for key, or none if not found.
fn (m &BoundedMap[K, V]) get(key K) ?V {
	return m.data[key] or { return none }
}

// delete removes key from map.
fn (mut m BoundedMap[K, V]) delete(key K) {
	if key !in m.data {
		return
	}
	m.data.delete(key)
	if m.data.len == 0 {
		array_clear(mut m.order)
		m.head = 0
		return
	}
	m.compact_order()
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
	array_clear(mut m.order)
	m.head = 0
}

// keys returns all keys in insertion order.
fn (m &BoundedMap[K, V]) keys() []K {
	if m.data.len == 0 || m.head >= m.order.len {
		return []K{}
	}
	mut out := []K{cap: m.data.len}
	for i in m.head .. m.order.len {
		k := m.order[i]
		if k in m.data {
			out << k
		}
	}
	return out
}

fn (mut m BoundedMap[K, V]) compact_order() {
	if m.head <= 0 {
		return
	}
	if m.head < bounded_order_compact_min && m.head * 2 < m.order.len {
		return
	}
	mut compact := []K{cap: m.data.len}
	for i in m.head .. m.order.len {
		k := m.order[i]
		if k in m.data {
			compact << k
		}
	}
	m.order = compact
	m.head = 0
}

// BoundedTreeState is a specialized bounded map for tree state
// (string -> map[string]bool). Maps require clone() when stored,
// which generic BoundedMap can't handle.
struct BoundedTreeState {
mut:
	data     map[string]map[string]bool
	order    []string
	head     int
	max_size int = 30
}

// set adds or updates tree state. Evicts oldest if at capacity.
fn (mut m BoundedTreeState) set(key string, value map[string]bool) {
	if m.max_size < 1 {
		return
	}
	if key in m.data {
		m.data[key] = value.clone()
		return
	}
	if m.data.len >= m.max_size && m.order.len > m.head {
		for m.head < m.order.len {
			oldest_key := m.order[m.head]
			m.head++
			if oldest_key in m.data {
				m.data.delete(oldest_key)
				break
			}
		}
	}
	m.order << key
	m.data[key] = value.clone()
	m.compact_order()
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
	array_clear(mut m.order)
	m.head = 0
}

fn (mut m BoundedTreeState) compact_order() {
	if m.head <= 0 {
		return
	}
	if m.head < bounded_order_compact_min && m.head * 2 < m.order.len {
		return
	}
	mut compact := []string{cap: m.data.len}
	for i in m.head .. m.order.len {
		key := m.order[i]
		if key in m.data {
			compact << key
		}
	}
	m.order = compact
	m.head = 0
}

// BoundedSvgCache is an LRU cache for SVG data.
// Uses lazy LRU via access counter for O(1) operations.
// Evicts least-recently-accessed entry when at capacity.
struct BoundedSvgCache {
mut:
	data         map[string]&CachedSvg
	access_time  map[string]u64 // Last access timestamp for LRU
	access_count u64            // Monotonic counter
	max_size     int = 100
}

// get returns cached SVG and updates access time (O(1) LRU).
fn (mut m BoundedSvgCache) get(key string) ?&CachedSvg {
	if key in m.data {
		// Update access time - O(1) instead of O(n) index rebuild
		m.access_count++
		m.access_time[key] = m.access_count
		return m.data[key] or { return none }
	}
	return none
}

// set adds SVG to cache. Evicts LRU entry if at capacity (O(n) scan only when full).
fn (mut m BoundedSvgCache) set(key string, value &CachedSvg) {
	if m.max_size < 1 {
		return
	}

	// Update existing entry
	if key in m.data {
		m.access_count++
		m.access_time[key] = m.access_count
		unsafe {
			m.data[key] = value
		}
		return
	}

	// Need to add new entry - evict LRU if at capacity
	if m.data.len >= m.max_size && m.max_size > 0 {
		// Find entry with oldest access time - O(n) but only when cache full
		mut oldest_key := ''
		mut oldest_time := m.access_count + 1
		for k, t in m.access_time {
			if t < oldest_time {
				oldest_time = t
				oldest_key = k
			}
		}
		if oldest_key.len > 0 {
			m.data.delete(oldest_key)
			m.access_time.delete(oldest_key)
		}
	}

	// Add new entry
	m.access_count++
	m.access_time[key] = m.access_count
	unsafe {
		m.data[key] = value
	}
}

// delete removes key from cache (O(1)).
fn (mut m BoundedSvgCache) delete(key string) {
	m.data.delete(key)
	m.access_time.delete(key)
}

// contains returns true if key exists.
fn (m &BoundedSvgCache) contains(key string) bool {
	return key in m.data
}

// keys returns all keys (no specific order).
fn (m &BoundedSvgCache) keys() []string {
	mut result := []string{cap: m.data.len}
	for k in m.data.keys() {
		result << k
	}
	return result
}

// len returns number of entries.
fn (m &BoundedSvgCache) len() int {
	return m.data.len
}

// clear removes all entries.
fn (mut m BoundedSvgCache) clear() {
	m.data.clear()
	m.access_time.clear()
	m.access_count = 0
}

// BoundedMarkdownCache is a FIFO cache for parsed markdown blocks.
struct BoundedMarkdownCache {
mut:
	data     map[int][]MarkdownBlock
	order    []int
	head     int
	max_size int = 50
}

// get returns cached blocks.
fn (m &BoundedMarkdownCache) get(key int) ?[]MarkdownBlock {
	return m.data[key] or { return none }
}

// set adds blocks to cache. Evicts oldest if at capacity.
fn (mut m BoundedMarkdownCache) set(key int, value []MarkdownBlock) {
	if m.max_size < 1 {
		return
	}
	if key in m.data {
		m.data[key] = value.clone()
		return
	}
	if m.data.len >= m.max_size && m.order.len > m.head {
		for m.head < m.order.len {
			oldest_key := m.order[m.head]
			m.head++
			if oldest_key in m.data {
				m.data.delete(oldest_key)
				break
			}
		}
	}
	m.order << key
	m.data[key] = value.clone()
	m.compact_order()
}

// len returns number of entries.
fn (m &BoundedMarkdownCache) len() int {
	return m.data.len
}

// clear removes all entries.
fn (mut m BoundedMarkdownCache) clear() {
	m.data.clear()
	array_clear(mut m.order)
	m.head = 0
}

fn (mut m BoundedMarkdownCache) compact_order() {
	if m.head <= 0 {
		return
	}
	if m.head < bounded_order_compact_min && m.head * 2 < m.order.len {
		return
	}
	mut compact := []int{cap: m.data.len}
	for i in m.head .. m.order.len {
		key := m.order[i]
		if key in m.data {
			compact << key
		}
	}
	m.order = compact
	m.head = 0
}
