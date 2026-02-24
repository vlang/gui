module gui

fn test_grant_zero_is_noop() {
	g := Grant{}
	assert g.id == 0
}

fn test_accessible_path_fields() {
	ap := AccessiblePath{
		path:  '/tmp/test.txt'
		grant: Grant{
			id: 42
		}
	}
	assert ap.path == '/tmp/test.txt'
	assert ap.grant.id == 42
}

fn test_path_strings_empty() {
	r := NativeDialogResult{
		status: .ok
	}
	assert r.path_strings().len == 0
}

fn test_path_strings_extracts_paths() {
	r := NativeDialogResult{
		status: .ok
		paths:  [
			AccessiblePath{
				path:  '/a'
				grant: Grant{
					id: 1
				}
			},
			AccessiblePath{
				path:  '/b'
				grant: Grant{
					id: 2
				}
			},
		]
	}
	ps := r.path_strings()
	assert ps.len == 2
	assert ps[0] == '/a'
	assert ps[1] == '/b'
}

fn test_store_no_app_id_returns_grant() {
	mut state := FileAccessState{}
	mut w := Window{
		file_access: state
	}
	g := w.store_bookmark('/tmp/x', [])
	assert g.id == 1
	assert w.file_access.grants.len == 1
}

fn test_store_increments_id() {
	mut state := FileAccessState{}
	mut w := Window{
		file_access: state
	}
	g1 := w.store_bookmark('/a', [])
	g2 := w.store_bookmark('/b', [])
	assert g1.id == 1
	assert g2.id == 2
}

fn test_release_removes_grant() {
	mut state := FileAccessState{}
	mut w := Window{
		file_access: state
	}
	g := w.store_bookmark('/tmp/x', [])
	assert w.file_access.grants.len == 1
	w.release_file_access(g)
	assert w.file_access.grants.len == 0
}

fn test_release_zero_grant_is_noop() {
	mut state := FileAccessState{}
	mut w := Window{
		file_access: state
	}
	w.release_file_access(Grant{})
	assert w.file_access.grants.len == 0
}

fn test_release_all_clears_map() {
	mut state := FileAccessState{}
	mut w := Window{
		file_access: state
	}
	w.store_bookmark('/a', [])
	w.store_bookmark('/b', [])
	assert w.file_access.grants.len == 2
	w.release_all_file_access()
	assert w.file_access.grants.len == 0
}
