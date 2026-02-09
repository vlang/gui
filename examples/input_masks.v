// Input Masks Teaching Example
// ===========================
//
// Demonstrates:
// - Built-in mask presets (`phone_us`, `credit_card_16`, `expiry_mm_yy`, `cvc`)
// - Custom mask pattern (`AA-9999`)
// - Custom token definitions (`A` => uppercase letter)
// - Sanitized paste behavior for masked fields
//
// Run:
//   v run examples/input_masks.v
import gui

@[heap]
struct InputMasksApp {
pub mut:
	phone       string
	card        string
	expiry      string
	cvc         string
	license_key string
}

fn main() {
	mut window := gui.window(
		title:        'Input Masks'
		width:        700
		height:       700
		cursor_blink: true
		state:        &InputMasksApp{}
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[InputMasksApp]()
	w, h := window.window_size()
	label_width := f32(240)
	input_width := f32(260)

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_large
		spacing: gui.spacing_medium
		content: [
			gui.text(
				text:       'Input Masks'
				text_style: gui.theme().b2
			),
			gui.text(
				text:       'Paste noisy strings. Mask engine keeps valid chars and formats output.'
				text_style: gui.theme().b4
			),
			gui.text(
				text:       'Try phone paste: abc555-123-4567xyz'
				text_style: gui.theme().b4
			),
			gui.rectangle(height: 1, sizing: gui.fill_fixed, color: gui.theme().color_border),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(
						text:      'Phone (preset: .phone_us)'
						min_width: label_width
					),
					gui.input(
						id_focus:        1
						text:            app.phone
						mask_preset:     .phone_us
						placeholder:     '(555) 123-4567'
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[InputMasksApp]()
							app.phone = s
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(
						text:      'Card (preset: .credit_card_16)'
						min_width: label_width
					),
					gui.input(
						id_focus:        2
						text:            app.card
						mask_preset:     .credit_card_16
						placeholder:     '4242 4242 4242 4242'
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[InputMasksApp]()
							app.card = s
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(
						text:      'Expiry (preset: .expiry_mm_yy)'
						min_width: label_width
					),
					gui.input(
						id_focus:        3
						text:            app.expiry
						mask_preset:     .expiry_mm_yy
						placeholder:     '12/28'
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[InputMasksApp]()
							app.expiry = s
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(
						text:      'CVC (preset: .cvc)'
						min_width: label_width
					),
					gui.input(
						id_focus:        4
						text:            app.cvc
						mask_preset:     .cvc
						placeholder:     '123'
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[InputMasksApp]()
							app.cvc = s
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(
						text:      'Custom (mask: AA-9999, token A uppercases)'
						min_width: label_width
					),
					gui.input(
						id_focus:        5
						text:            app.license_key
						mask:            'AA-9999'
						mask_tokens:     license_mask_tokens()
						placeholder:     'AB-1234'
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[InputMasksApp]()
							app.license_key = s
						}
					),
				]
			),
			gui.rectangle(height: 1, sizing: gui.fill_fixed, color: gui.theme().color_border),
			gui.text(
				text:       'Formatted values sent by on_text_changed:'
				text_style: gui.theme().b4
			),
			gui.text(text: 'phone=${app.phone}'),
			gui.text(text: 'card=${app.card}'),
			gui.text(text: 'expiry=${app.expiry} cvc=${app.cvc}'),
			gui.text(text: 'custom=${app.license_key}'),
		]
	)
}

fn is_ascii_letter(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`)
}

fn to_upper_ascii(r rune) rune {
	if r >= `a` && r <= `z` {
		return r - 32
	}
	return r
}

fn license_mask_tokens() []gui.MaskTokenDef {
	return [
		gui.MaskTokenDef{
			symbol:    `A`
			matcher:   is_ascii_letter
			transform: to_upper_ascii
		},
	]
}
