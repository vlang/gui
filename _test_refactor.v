module gui

fn test_shape_rich_text_ptr() {
	mut rtf_cfg := RtfCfg{
		rich_text: RichText{
			runs: [
				RichTextRun{
					text:  'Hello'
					style: TextStyle{}
				},
			]
		}
	}

	// Simulate the assignment done in view_rtf.v
	mut shape := Shape{
		rich_text: &rtf_cfg.rich_text
	}

	// Verify pointer is not nil
	assert shape.rich_text != unsafe { nil }

	// Verify data access via pointer (auto-dereference check)
	assert shape.rich_text.runs.len == 1
	assert shape.rich_text.runs[0].text == 'Hello'

	// Verify xtra_text.v usage pattern (calling method on pointer)
	// We need a dummy method call if possible, but to_vglyph_rich_text is internal?
	// It is NOT pub in xtra_rtf.v: fn (rt RichText) to_vglyph_rich_text()
	// So we can't call it from here if we are "outside"?
	// But we are `module gui`, so we can call it.

	vg_rt := shape.rich_text.to_vglyph_rich_text()
	assert vg_rt.runs.len == 1
}
