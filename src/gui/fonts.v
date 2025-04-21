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

pub fn font_path_list() []string {
	mut font_root_path := ''
	$if windows {
		font_root_path = 'C:/windows/fonts'
	}
	$if macos {
		font_root_path = '/System/Library/Fonts/*'
	}
	$if linux {
		font_root_path = '/usr/share/fonts/truetype/*'
	}
	$if android {
		font_root_path = '/system/fonts/*'
	}
	font_paths := os.glob('${font_root_path}/*.ttf') or { panic(err) }
	return font_paths
}
