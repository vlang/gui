module gui

import os
import os.font

struct FontVariants {
	normal string
	bold   string
	italic string
	mono   string
}

fn font_variants(text_style TextStyle) FontVariants {
	path := if text_style.family.len == 0 { font.default() } else { text_style.family }
	variants := FontVariants{
		normal: path_variant(path, .normal)
		bold:   path_variant(path, .bold)
		italic: path_variant(path, .italic)
		mono:   path_variant(path, .mono)
	}
	// println(variants)
	return variants
}

fn path_variant(path string, variant font.Variant) string {
	vpath := font.get_path_variant(path, variant)
	if os.exists(vpath) {
		return vpath
	}
	fallback_mac := '/System/Library/Fonts/SFNSRounded.ttf'
	if os.exists(fallback_mac) {
		return fallback_mac
	}
	// TODO: add other os systems
	return path
}
