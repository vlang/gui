module gui

// Currently, `gg` only supports static font files like `.ttf`. If/when this
// changes, support for variable fonts like those in Google fonts will be used.
//
import log
import os
import os.font

// FontVariants are the paths of the font files used by Gui
pub struct FontVariants {
pub:
	normal string
	bold   string
	italic string
	mono   string
}

pub const font_file_regular = os.join_path(os.data_dir(), 'v_gui_deja-vu-sans-regular.ttf')
pub const font_file_bold = os.join_path(os.data_dir(), 'v_gui_deja-vu-sans-bold.ttf')
pub const font_file_italic = os.join_path(os.data_dir(), 'v_gui_deja-vu-sans-italic.ttf')
pub const font_file_mono = os.join_path(os.data_dir(), 'v_gui_deja-vu-sans-mono.ttf')
pub const font_file_icon = os.join_path(os.data_dir(), 'v_gui_feathericon.ttf')

// initialize_fonts ensures all required font files exist in the data directory by checking for
// each font file and writing the embedded font data if not found. It writes regular, bold,
// italic, mono and icon font files.
fn initialize_fonts() {
	if !os.exists(font_file_regular) {
		os.write_file(font_file_regular, $embed_file('assets/DejaVuSans-Regular.ttf').to_string()) or {
			log.error(err.msg())
		}
	}
	if !os.exists(font_file_bold) {
		os.write_file(font_file_bold, $embed_file('assets/DejaVuSans-Bold.ttf').to_string()) or {
			log.error(err.msg())
		}
	}
	if !os.exists(font_file_italic) {
		os.write_file(font_file_italic, $embed_file('assets/DejaVuSans-Italic.ttf').to_string()) or {
			log.error(err.msg())
		}
	}
	if !os.exists(font_file_mono) {
		os.write_file(font_file_mono, $embed_file('assets/DejaVuSans-Mono.ttf').to_string()) or {
			log.error(err.msg())
		}
	}
	if !os.exists(font_file_icon) {
		os.write_file(font_file_icon, $embed_file('assets/feathericon.ttf').to_string()) or {
			log.error(err.msg())
		}
	}
}

// font_variants retrieves the names of the files for the 4 font families in Gui. See [FontVariants](#FontVariants)
pub fn font_variants(text_style TextStyle) FontVariants {
	path := if text_style.family.len == 0 { font.default() } else { text_style.family }
	variants := FontVariants{
		normal: path
		bold:   path_variant(path, .bold)
		italic: path_variant(path, .italic)
		mono:   path_variant(path, .mono)
	}
	return variants
}

fn path_variant(path string, variant font.Variant) string {
	mut vpath := match variant {
		.normal { path }
		.bold { path.replace('-regular', '-bold') }
		.italic { path.replace('-regular', '-italic') }
		.mono { path.replace('-regular', '-mono') }
	}
	if !os.exists(vpath) {
		vpath = font.get_path_variant(path, variant)
	}
	if !os.exists(vpath) {
		vpath = font.get_path_variant(font.default(), variant)
	}
	return if os.exists(vpath) { vpath } else { path }
}

// Map of icons names to their unicode values. Describes only
// the icons included in `assets/feathericon.ttf`
pub const icons_map = {
	'icon_arrow_down':              icon_arrow_down
	'icon_arrow_left':              icon_arrow_left
	'icon_arrow_right':             icon_arrow_right
	'icon_arrow_up':                icon_arrow_up
	'icon_artboard':                icon_artboard
	'icon_bar':                     icon_bar
	'icon_bar_chart':               icon_bar_chart
	'icon_beer':                    icon_beer
	'icon_bell':                    icon_bell
	'icon_book':                    icon_book
	'icon_browser':                 icon_browser
	'icon_brush':                   icon_brush
	'icon_bug':                     icon_bug
	'icon_building':                icon_building
	'icon_calendar':                icon_calendar
	'icon_camera':                  icon_camera
	'icon_check':                   icon_check
	'icon_clock':                   icon_clock
	'icon_close':                   icon_close
	'icon_cloud':                   icon_cloud
	'icon_cocktail':                icon_cocktail
	'icon_code':                    icon_code
	'icon_columns':                 icon_columns
	'icon_comment':                 icon_comment
	'icon_commenting':              icon_commenting
	'icon_comments':                icon_comments
	'icon_desktop':                 icon_desktop
	'icon_diamond':                 icon_diamond
	'icon_disabled':                icon_disabled
	'icon_download':                icon_download
	'icon_drop_down':               icon_drop_down
	'icon_drop_left':               icon_drop_left
	'icon_drop_right':              icon_drop_right
	'icon_drop_up':                 icon_drop_up
	'icon_elipsis_h':               icon_elipsis_h
	'icon_elipsis_v':               icon_elipsis_v
	'icon_eye':                     icon_eye
	'icon_feed':                    icon_feed
	'icon_flag':                    icon_flag
	'icon_folder':                  icon_folder
	'icon_fork':                    icon_fork
	'icon_globe':                   icon_globe
	'icon_hash':                    icon_hash
	'icon_heart':                   icon_heart
	'icon_home':                    icon_home
	'icon_info':                    icon_info
	'icon_key':                     icon_key
	'icon_keyboard':                icon_keyboard
	'icon_laptop':                  icon_laptop
	'icon_layout':                  icon_layout
	'icon_line_chart':              icon_line_chart
	'icon_link':                    icon_link
	'icon_link_external':           icon_link_external
	'icon_location':                icon_location
	'icon_lock':                    icon_lock
	'icon_login':                   icon_login
	'icon_logout':                  icon_logout
	'icon_mail':                    icon_mail
	'icon_medal':                   icon_medal
	'icon_megaphone':               icon_megaphone
	'icon_minus':                   icon_minus
	'icon_mobile':                  icon_mobile
	'icon_mouse':                   icon_mouse
	'icon_pencil':                  icon_pencil
	'icon_phone':                   icon_phone
	'icon_pie_chart':               icon_pie_chart
	'icon_pizza':                   icon_pizza
	'icon_plus':                    icon_plus
	'icon_prototype':               icon_prototype
	'icon_question':                icon_question
	'icon_quote_left':              icon_quote_left
	'icon_quote_right':             icon_quote_right
	'icon_rocket':                  icon_rocket
	'icon_search':                  icon_search
	'icon_share':                   icon_share
	'icon_sitemap':                 icon_sitemap
	'icon_star':                    icon_star
	'icon_tablet':                  icon_tablet
	'icon_tag':                     icon_tag
	'icon_terminal':                icon_terminal
	'icon_ticket':                  icon_ticket
	'icon_tiled':                   icon_tiled
	'icon_trash':                   icon_trash
	'icon_trophy':                  icon_trophy
	'icon_upload':                  icon_upload
	'icon_user':                    icon_user
	'icon_user_plus':               icon_user_plus
	'icon_users':                   icon_users
	'icon_vector':                  icon_vector
	'icon_video':                   icon_video
	'icon_warning':                 icon_warning
	'icon_wine_glass':              icon_wine_glass
	'icon_wrench':                  icon_wrench
	'icon_birthday_cake':           icon_birthday_cake
	'icon_mention':                 icon_mention
	'icon_palette':                 icon_palette
	'icon_coffee':                  icon_coffee
	'icon_heart_o':                 icon_heart_o
	'icon_star_o':                  icon_star_o
	'icon_unlock':                  icon_unlock
	'icon_search_minus':            icon_search_minus
	'icon_search_plus':             icon_search_plus
	'icon_user_minus':              icon_user_minus
	'icon_map':                     icon_map
	'icon_export':                  icon_export
	'icon_import':                  icon_import
	'icon_bookmark':                icon_bookmark
	'icon_print':                   icon_print
	'icon_shield':                  icon_shield
	'icon_filter':                  icon_filter
	'icon_feather':                 icon_feather
	'icon_music':                   icon_music
	'icon_folder_open':             icon_folder_open
	'icon_magic':                   icon_magic
	'icon_paper_plane':             icon_paper_plane
	'icon_bold':                    icon_bold
	'icon_italic':                  icon_italic
	'icon_text_size':               icon_text_size
	'icon_list_bullet':             icon_list_bullet
	'icon_list_order':              icon_list_order
	'icon_list_task':               icon_list_task
	'icon_edit':                    icon_edit
	'icon_backward':                icon_backward
	'icon_compress':                icon_compress
	'icon_eject':                   icon_eject
	'icon_expand':                  icon_expand
	'icon_fast_backward':           icon_fast_backward
	'icon_fast_forward':            icon_fast_forward
	'icon_forward':                 icon_forward
	'icon_pause':                   icon_pause
	'icon_play':                    icon_play
	'icon_random':                  icon_random
	'icon_stop':                    icon_stop
	'icon_layer':                   icon_layer
	'icon_headphone':               icon_headphone
	'icon_plug':                    icon_plug
	'icon_usb':                     icon_usb
	'icon_gamepad':                 icon_gamepad
	'icon_loop':                    icon_loop
	'icon_sync':                    icon_sync
	'icon_align_center':            icon_align_center
	'icon_align_left':              icon_align_left
	'icon_align_right':             icon_align_right
	'icon_app_menu':                icon_app_menu
	'icon_audio_player':            icon_audio_player
	'icon_check_circle':            icon_check_circle
	'icon_check_circle_o':          icon_check_circle_o
	'icon_check_verified':          icon_check_verified
	'icon_cutlery':                 icon_cutlery
	'icon_delete_link':             icon_delete_link
	'icon_document':                icon_document
	'icon_equalizer':               icon_equalizer
	'icon_file_excel':              icon_file_excel
	'icon_file_powerpoint':         icon_file_powerpoint
	'icon_file_word':               icon_file_word
	'icon_gear':                    icon_gear
	'icon_insert_link':             icon_insert_link
	'icon_kitchen_cooker':          icon_kitchen_cooker
	'icon_money':                   icon_money
	'icon_picture':                 icon_picture
	'icon_pot':                     icon_pot
	'icon_speaker':                 icon_speaker
	'icon_table':                   icon_table
	'icon_timeline':                icon_timeline
	'icon_underline':               icon_underline
	'icon_watch':                   icon_watch
	'icon_watch_alt':               icon_watch_alt
	'icon_file':                    icon_file
	'icon_file_audio':              icon_file_audio
	'icon_file_image':              icon_file_image
	'icon_file_movie':              icon_file_movie
	'icon_file_zip':                icon_file_zip
	'icon_angry':                   icon_angry
	'icon_cry':                     icon_cry
	'icon_disappointed':            icon_disappointed
	'icon_frowing':                 icon_frowing
	'icon_open_mouth':              icon_open_mouth
	'icon_rage':                    icon_rage
	'icon_smile':                   icon_smile
	'icon_smile_alt':               icon_smile_alt
	'icon_tired':                   icon_tired
	'icon_align_bottom':            icon_align_bottom
	'icon_align_top':               icon_align_top
	'icon_align_vertically':        icon_align_vertically
	'icon_crop':                    icon_crop
	'icon_difference':              icon_difference
	'icon_distribute_vertically':   icon_distribute_vertically
	'icon_eraser':                  icon_eraser
	'icon_intersect':               icon_intersect
	'icon_mask':                    icon_mask
	'icon_scale':                   icon_scale
	'icon_subtract':                icon_subtract
	'icon_text_align_center':       icon_text_align_center
	'icon_text_align_left':         icon_text_align_left
	'icon_text_align_right':        icon_text_align_right
	'icon_union':                   icon_union
	'icon_distribute_horizontally': icon_distribute_horizontally
	'icon_step_backward':           icon_step_backward
	'icon_step_forward':            icon_step_forward
	'icon_comment_o':               icon_comment_o
	'icon_codepen':                 icon_codepen
	'icon_facebook':                icon_facebook
	'icon_git':                     icon_git
	'icon_github':                  icon_github
	'icon_github_alt':              icon_github_alt
	'icon_google':                  icon_google
	'icon_google_plus':             icon_google_plus
	'icon_instagram':               icon_instagram
	'icon_pinterest':               icon_pinterest
	'icon_pocket':                  icon_pocket
	'icon_twitter':                 icon_twitter
	'icon_wordpress':               icon_wordpress
	'icon_wordpress_alt':           icon_wordpress_alt
	'icon_youtube':                 icon_youtube
	'icon_messanger':               icon_messanger
	'icon_activity':                icon_activity
	'icon_bolt':                    icon_bolt
	'icon_picture_square':          icon_picture_square
	'icon_text_align_justify':      icon_text_align_justify
	'icon_add_cart':                icon_add_cart
	'icon_cage':                    icon_cage
	'icon_cart':                    icon_cart
	'icon_credit_card':             icon_credit_card
	'icon_gift':                    icon_gift
	'icon_remove_cart':             icon_remove_cart
	'icon_shopping_bag':            icon_shopping_bag
	'icon_truck':                   icon_truck
	'icon_wallet':                  icon_wallet
	'icon_moon':                    icon_moon
	'icon_sunny_o':                 icon_sunny_o
	'icon_sunrise':                 icon_sunrise
	'icon_umbrella':                icon_umbrella
	'icon_target':                  icon_target
	'icon_smile_plus':              icon_smile_plus
	'icon_smile_heart':             icon_smile_heart
	'icon_beginner':                icon_beginner
	'icon_train':                   icon_train
	'icon_donut':                   icon_donut
	'icon_rice_cracker':            icon_rice_cracker
	'icon_apron':                   icon_apron
	'icon_octpus':                  icon_octpus
	'icon_squid':                   icon_squid
	'icon_bus':                     icon_bus
	'icon_car':                     icon_car
	'icon_notice_active':           icon_notice_active
	'icon_notice_off':              icon_notice_off
	'icon_notice_on':               icon_notice_on
	'icon_notice_push':             icon_notice_push
	'icon_taxi':                    icon_taxi
	'icon_vr':                      icon_vr
	'icon_bread':                   icon_bread
	'icon_frying_pan':              icon_frying_pan
	'icon_mitarashi_dango':         icon_mitarashi_dango
	'icon_tumbler_glass':           icon_tumbler_glass
	'icon_yaki_dango':              icon_yaki_dango
}

pub const icon_arrow_down = '\uf100'
pub const icon_arrow_left = '\uf101'
pub const icon_arrow_right = '\uf102'
pub const icon_arrow_up = '\uf103'
pub const icon_artboard = '\uf104'
pub const icon_bar = '\uf105'
pub const icon_bar_chart = '\uf106'
pub const icon_beer = '\uf107'
pub const icon_bell = '\uf108'
pub const icon_book = '\uf109'
pub const icon_browser = '\uf10b'
pub const icon_brush = '\uf10c'
pub const icon_bug = '\uf10d'
pub const icon_building = '\uf10e'
pub const icon_calendar = '\uf10f'
pub const icon_camera = '\uf110'
pub const icon_check = '\uf111'
pub const icon_clock = '\uf113'
pub const icon_close = '\uf114'
pub const icon_cloud = '\uf115'
pub const icon_cocktail = '\uf116'
pub const icon_code = '\uf117'
pub const icon_columns = '\uf118'
pub const icon_comment = '\uf119'
pub const icon_commenting = '\uf11a'
pub const icon_comments = '\uf11b'
pub const icon_desktop = '\uf11d'
pub const icon_diamond = '\uf11e'
pub const icon_disabled = '\uf11f'
pub const icon_download = '\uf120'
pub const icon_drop_down = '\uf121'
pub const icon_drop_left = '\uf122'
pub const icon_drop_right = '\uf123'
pub const icon_drop_up = '\uf124'
pub const icon_elipsis_h = '\uf125'
pub const icon_elipsis_v = '\uf126'
pub const icon_eye = '\uf127'
pub const icon_feed = '\uf128'
pub const icon_flag = '\uf129'
pub const icon_folder = '\uf12a'
pub const icon_fork = '\uf12b'
pub const icon_globe = '\uf12c'
pub const icon_hash = '\uf12d'
pub const icon_heart = '\uf12e'
pub const icon_home = '\uf12f'
pub const icon_info = '\uf130'
pub const icon_key = '\uf131'
pub const icon_keyboard = '\uf132'
pub const icon_laptop = '\uf133'
pub const icon_layout = '\uf134'
pub const icon_line_chart = '\uf135'
pub const icon_link = '\uf136'
pub const icon_link_external = '\uf137'
pub const icon_location = '\uf138'
pub const icon_lock = '\uf139'
pub const icon_login = '\uf13a'
pub const icon_logout = '\uf13b'
pub const icon_mail = '\uf13c'
pub const icon_medal = '\uf13d'
pub const icon_megaphone = '\uf13e'
pub const icon_minus = '\uf140'
pub const icon_mobile = '\uf141'
pub const icon_mouse = '\uf142'
pub const icon_pencil = '\uf144'
pub const icon_phone = '\uf145'
pub const icon_pie_chart = '\uf146'
pub const icon_pizza = '\uf147'
pub const icon_plus = '\uf148'
pub const icon_prototype = '\uf149'
pub const icon_question = '\uf14a'
pub const icon_quote_left = '\uf14b'
pub const icon_quote_right = '\uf14c'
pub const icon_rocket = '\uf14d'
pub const icon_search = '\uf14e'
pub const icon_share = '\uf14f'
pub const icon_sitemap = '\uf150'
pub const icon_star = '\uf151'
pub const icon_tablet = '\uf152'
pub const icon_tag = '\uf153'
pub const icon_terminal = '\uf154'
pub const icon_ticket = '\uf155'
pub const icon_tiled = '\uf156'
pub const icon_trash = '\uf157'
pub const icon_trophy = '\uf158'
pub const icon_upload = '\uf159'
pub const icon_user = '\uf15a'
pub const icon_user_plus = '\uf15b'
pub const icon_users = '\uf15c'
pub const icon_vector = '\uf15d'
pub const icon_video = '\uf15e'
pub const icon_warning = '\uf15f'
pub const icon_wine_glass = '\uf161'
pub const icon_wrench = '\uf162'
pub const icon_birthday_cake = '\uf163'
pub const icon_mention = '\uf164'
pub const icon_palette = '\uf165'
pub const icon_coffee = '\uf166'
pub const icon_heart_o = '\uf167'
pub const icon_star_o = '\uf168'
pub const icon_unlock = '\uf169'
pub const icon_search_minus = '\uf16a'
pub const icon_search_plus = '\uf16b'
pub const icon_user_minus = '\uf16c'
pub const icon_map = '\uf16d'
pub const icon_export = '\uf16e'
pub const icon_import = '\uf16f'
pub const icon_bookmark = '\uf170'
pub const icon_print = '\uf171'
pub const icon_shield = '\uf172'
pub const icon_filter = '\uf173'
pub const icon_feather = '\uf174'
pub const icon_music = '\uf175'
pub const icon_folder_open = '\uf176'
pub const icon_magic = '\uf177'
pub const icon_paper_plane = '\uf178'
pub const icon_bold = '\uf179'
pub const icon_italic = '\uf17a'
pub const icon_text_size = '\uf17b'
pub const icon_list_bullet = '\uf17c'
pub const icon_list_order = '\uf17d'
pub const icon_list_task = '\uf17e'
pub const icon_edit = '\uf17f'
pub const icon_backward = '\uf180'
pub const icon_compress = '\uf181'
pub const icon_eject = '\uf182'
pub const icon_expand = '\uf183'
pub const icon_fast_backward = '\uf184'
pub const icon_fast_forward = '\uf185'
pub const icon_forward = '\uf186'
pub const icon_pause = '\uf187'
pub const icon_play = '\uf188'
pub const icon_random = '\uf189'
pub const icon_stop = '\uf18b'
pub const icon_layer = '\uf18c'
pub const icon_headphone = '\uf18e'
pub const icon_plug = '\uf18f'
pub const icon_usb = '\uf190'
pub const icon_gamepad = '\uf191'
pub const icon_loop = '\uf192'
pub const icon_sync = '\uf194'
pub const icon_align_center = '\uf195'
pub const icon_align_left = '\uf196'
pub const icon_align_right = '\uf197'
pub const icon_app_menu = '\uf198'
pub const icon_audio_player = '\uf199'
pub const icon_check_circle = '\uf19a'
pub const icon_check_circle_o = '\uf19b'
pub const icon_check_verified = '\uf19c'
pub const icon_cutlery = '\uf19d'
pub const icon_delete_link = '\uf19e'
pub const icon_document = '\uf19f'
pub const icon_equalizer = '\uf1a0'
pub const icon_file_excel = '\uf1a2'
pub const icon_file_powerpoint = '\uf1a3'
pub const icon_file_word = '\uf1a4'
pub const icon_gear = '\uf1a5'
pub const icon_insert_link = '\uf1a6'
pub const icon_kitchen_cooker = '\uf1a7'
pub const icon_money = '\uf1a8'
pub const icon_picture = '\uf1a9'
pub const icon_pot = '\uf1aa'
pub const icon_speaker = '\uf1ab'
pub const icon_table = '\uf1ac'
pub const icon_timeline = '\uf1ad'
pub const icon_underline = '\uf1ae'
pub const icon_watch = '\uf1af'
pub const icon_watch_alt = '\uf1b0'
pub const icon_file = '\uf1b1'
pub const icon_file_audio = '\uf1b2'
pub const icon_file_image = '\uf1b3'
pub const icon_file_movie = '\uf1b4'
pub const icon_file_zip = '\uf1b5'
pub const icon_angry = '\uf1b6'
pub const icon_cry = '\uf1b7'
pub const icon_disappointed = '\uf1b8'
pub const icon_frowing = '\uf1b9'
pub const icon_open_mouth = '\uf1ba'
pub const icon_rage = '\uf1bb'
pub const icon_smile = '\uf1bc'
pub const icon_smile_alt = '\uf1bd'
pub const icon_tired = '\uf1be'
pub const icon_align_bottom = '\uf1bf'
pub const icon_align_top = '\uf1c0'
pub const icon_align_vertically = '\uf1c1'
pub const icon_crop = '\uf1c2'
pub const icon_difference = '\uf1c3'
pub const icon_distribute_vertically = '\uf1c5'
pub const icon_eraser = '\uf1c6'
pub const icon_intersect = '\uf1c7'
pub const icon_mask = '\uf1c8'
pub const icon_scale = '\uf1c9'
pub const icon_subtract = '\uf1ca'
pub const icon_text_align_center = '\uf1cb'
pub const icon_text_align_left = '\uf1cc'
pub const icon_text_align_right = '\uf1cd'
pub const icon_union = '\uf1ce'
pub const icon_distribute_horizontally = '\uf1cf'
pub const icon_step_backward = '\uf1d0'
pub const icon_step_forward = '\uf1d1'
pub const icon_comment_o = '\uf1d2'
pub const icon_codepen = '\uf1d3'
pub const icon_facebook = '\uf1d4'
pub const icon_git = '\uf1d5'
pub const icon_github = '\uf1d6'
pub const icon_github_alt = '\uf1d7'
pub const icon_google = '\uf1d8'
pub const icon_google_plus = '\uf1d9'
pub const icon_instagram = '\uf1da'
pub const icon_pinterest = '\uf1db'
pub const icon_pocket = '\uf1dc'
pub const icon_twitter = '\uf1dd'
pub const icon_wordpress = '\uf1de'
pub const icon_wordpress_alt = '\uf1df'
pub const icon_youtube = '\uf1e0'
pub const icon_messanger = '\uf1e1'
pub const icon_activity = '\uf1e2'
pub const icon_bolt = '\uf1e3'
pub const icon_picture_square = '\uf1e4'
pub const icon_text_align_justify = '\uf1e5'
pub const icon_add_cart = '\uf1e6'
pub const icon_cage = '\uf1e7'
pub const icon_cart = '\uf1e8'
pub const icon_credit_card = '\uf1e9'
pub const icon_gift = '\uf1ea'
pub const icon_remove_cart = '\uf1eb'
pub const icon_shopping_bag = '\uf1ec'
pub const icon_truck = '\uf1ed'
pub const icon_wallet = '\uf1ee'
pub const icon_moon = '\uf1ef'
pub const icon_sunny_o = '\uf1f0'
pub const icon_sunrise = '\uf1f1'
pub const icon_umbrella = '\uf1f2'
pub const icon_target = '\uf1f3'
pub const icon_smile_plus = '\uf1f5'
pub const icon_smile_heart = '\uf1f6'
pub const icon_beginner = '\uf1f7'
pub const icon_train = '\uf1f8'
pub const icon_donut = '\uf1f9'
pub const icon_rice_cracker = '\uf1fa'
pub const icon_apron = '\uf1fb'
pub const icon_octpus = '\uf1fc'
pub const icon_squid = '\uf1fd'
pub const icon_bus = '\uf1fe'
pub const icon_car = '\uf1ff'
pub const icon_notice_active = '\uf200'
pub const icon_notice_off = '\uf201'
pub const icon_notice_on = '\uf202'
pub const icon_notice_push = '\uf203'
pub const icon_taxi = '\uf204'
pub const icon_vr = '\uf205'
pub const icon_bread = '\uf206'
pub const icon_frying_pan = '\uf207'
pub const icon_mitarashi_dango = '\uf208'
pub const icon_tumbler_glass = '\uf209'
pub const icon_yaki_dango = '\uf20a'
