module nativebridge

#include <stdlib.h>

$if windows {
	#flag windows -ld3d11
	#insert "@VMODROOT/nativebridge/readback_d3d11_warp_test.h"

	fn C.gui_readback_d3d11_warp_roundtrip_test() int
	fn C.gui_readback_d3d11_rejects_unsupported_format_test() int
	fn C.gui_readback_d3d11_rejects_msaa_test() int
}

fn C.malloc(size usize) &u8

fn test_readback_buffer_free_accepts_c_allocated_buffer() {
	$if macos || linux || windows {
		ptr := C.malloc(16)
		assert ptr != unsafe { nil }
		C.gui_readback_buffer_free(ptr)
	}
}

fn test_readback_buffer_free_accepts_null() {
	$if macos || linux || windows {
		C.gui_readback_buffer_free(unsafe { nil })
	}
}

fn test_readback_metal_rejects_invalid_native_args() {
	$if macos {
		readback_metal_texture(unsafe { nil }, unsafe { nil }, 0, 1) or {
			assert err.msg().contains('dimensions')
			return
		}
		assert false
	}
}

fn test_readback_metal_rejects_nil_native_handles() {
	$if macos {
		readback_metal_texture(unsafe { nil }, unsafe { nil }, 1, 1) or {
			assert err.msg().contains('texture and device')
			return
		}
		assert false
	}
}

fn test_readback_metal_reports_unsupported_off_macos() {
	$if !macos {
		readback_metal_texture(unsafe { nil }, unsafe { nil }, 1, 1) or {
			assert err.msg().contains('not available')
			return
		}
		assert false
	}
}

fn test_readback_gl_rejects_invalid_native_dimensions() {
	$if linux {
		readback_gl_framebuffer(0, 0, 1) or {
			assert err.msg().contains('dimensions')
			return
		}
		assert false
	}
}

fn test_readback_gl_reports_unsupported_off_linux() {
	$if !linux {
		readback_gl_framebuffer(0, 1, 1) or {
			assert err.msg().contains('not available')
			return
		}
		assert false
	}
}

fn test_readback_d3d11_rejects_invalid_native_dimensions() {
	$if windows {
		readback_d3d11_texture(unsafe { nil }, unsafe { nil }, unsafe { nil }, 0, 1) or {
			assert err.msg().contains('dimensions')
			return
		}
		assert false
	}
}

fn test_readback_d3d11_rejects_nil_native_handles() {
	$if windows {
		readback_d3d11_texture(unsafe { nil }, unsafe { nil }, unsafe { nil }, 1, 1) or {
			assert err.msg().contains('texture, device, and context')
			return
		}
		assert false
	}
}

fn test_readback_d3d11_c_rejects_invalid_native_args() {
	$if windows {
		assert C.gui_readback_d3d11_texture(unsafe { nil }, unsafe { nil }, unsafe { nil }, 0, 1) == unsafe { nil }
		assert C.gui_readback_d3d11_texture(unsafe { nil }, unsafe { nil }, unsafe { nil }, 1, 1) == unsafe { nil }
	}
}

fn test_readback_d3d11_warp_roundtrip() {
	$if windows {
		assert C.gui_readback_d3d11_warp_roundtrip_test() == 1
	}
}

fn test_readback_d3d11_rejects_unsupported_format() {
	$if windows {
		assert C.gui_readback_d3d11_rejects_unsupported_format_test() == 1
	}
}

fn test_readback_d3d11_rejects_msaa() {
	$if windows {
		assert C.gui_readback_d3d11_rejects_msaa_test() == 1
	}
}

fn test_readback_d3d11_reports_unsupported_off_windows() {
	$if !windows {
		readback_d3d11_texture(unsafe { nil }, unsafe { nil }, unsafe { nil }, 1, 1) or {
			assert err.msg().contains('not available')
			return
		}
		assert false
	}
}
