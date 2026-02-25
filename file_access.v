module gui

import nativebridge

// Grant identifies a security-scoped bookmark. Release via
// Window.release_file_access when access is no longer needed.
pub struct Grant {
pub:
	id u64 // 0 = no grant (no-op on release)
}

// AccessiblePath pairs a filesystem path with an optional
// security-scoped grant. On macOS sandboxed apps the grant
// keeps the path accessible across relaunches.
pub struct AccessiblePath {
pub:
	path  string
	grant Grant
}

struct BookmarkGrant {
	path string
	data []u8 // macOS bookmark blob; empty on Linux
}

struct FileAccessState {
mut:
	app_id  string
	next_id u64 = 1
	grants  map[u64]BookmarkGrant
}

// restore_file_access loads and activates persisted
// security-scoped bookmarks. Call in on_init after setting
// app_id in WindowCfg.
pub fn (mut w Window) restore_file_access() {
	if w.file_access.app_id.len == 0 {
		return
	}
	$if macos {
		entries := nativebridge.bookmark_load_all(w.file_access.app_id)
		for entry in entries {
			if entry.path.len > 0 {
				w.store_bookmark(entry.path, entry.data)
			}
		}
	}
}

// release_file_access releases a single bookmark grant.
pub fn (mut w Window) release_file_access(g Grant) {
	if g.id == 0 {
		return
	}
	w.file_access_mutex.lock()
	bm := w.file_access.grants[g.id] or {
		w.file_access_mutex.unlock()
		return
	}
	w.file_access.grants.delete(g.id)
	data := bm.data
	w.file_access_mutex.unlock()
	if data.len > 0 {
		$if macos {
			nativebridge.bookmark_stop_access(data)
		}
	}
}

// release_all_file_access releases every active grant.
// Called automatically during window cleanup.
pub fn (mut w Window) release_all_file_access() {
	w.file_access_mutex.lock()
	mut grants := []BookmarkGrant{cap: w.file_access.grants.len}
	for _, bm in w.file_access.grants {
		grants << bm
	}
	w.file_access.grants = map[u64]BookmarkGrant{}
	w.file_access_mutex.unlock()
	for bm in grants {
		if bm.data.len > 0 {
			$if macos {
				nativebridge.bookmark_stop_access(bm.data)
			}
		}
	}
}

// store_bookmark records a bookmark grant internally and
// persists via nativebridge if app_id is set and data is
// non-empty.
fn (mut w Window) store_bookmark(path string, data []u8) Grant {
	w.file_access_mutex.lock()
	app_id := w.file_access.app_id
	id := w.file_access.next_id
	w.file_access.next_id++
	w.file_access.grants[id] = BookmarkGrant{
		path: path
		data: data
	}
	w.file_access_mutex.unlock()
	if app_id.len > 0 && data.len > 0 {
		$if macos {
			nativebridge.bookmark_store(app_id, path, data)
		}
	}
	return Grant{
		id: id
	}
}
