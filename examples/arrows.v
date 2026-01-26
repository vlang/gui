import gui

// Arrows Demo
// =============================
// Demonstrates a collection of arrow symbols with Grid and List views.

@[heap]
struct ArrowsApp {
pub mut:
	view_mode      string = 'grid' // 'grid' or 'list'
	arrows         []ArrowSymbol
	sorted         [][]string // For table view
	sort_by        int        // For table sort
	all_groups     []string
	selected_group string
}

struct ArrowSymbol {
	symbol string
	name   string
	hex    string
	group  string
}

fn main() {
	mut window := gui.window(
		title:   'Arrow Symbols'
		state:   &ArrowsApp{}
		width:   1000
		height:  800
		on_init: fn (mut w gui.Window) {
			mut app := w.state[ArrowsApp]()
			app.arrows = get_arrows()
			// Prepare table data and groups
			mut groups_seen := map[string]bool{}
			for arrow in app.arrows {
				app.sorted << [arrow.symbol, arrow.get_code(), arrow.name, arrow.group]
				if arrow.group !in groups_seen {
					groups_seen[arrow.group] = true
					app.all_groups << arrow.group
				}
			}
			if app.all_groups.len > 0 {
				app.selected_group = app.all_groups[0]
			}
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn (a ArrowSymbol) get_code() string {
	// Basic placeholder, in V utf8 string handling can get hex code
	// For now we will return a placeholder or calculate if easy
	return a.hex
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[ArrowsApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			header(mut window),
			gui.row(
				sizing:  gui.fill_fill
				spacing: 0
				content: [
					sidebar(mut window),
					match app.view_mode {
						'list' { list_view(mut window) }
						else { grid_view(mut window) }
					},
				]
			),
		]
	)
}

fn sidebar(mut w gui.Window) gui.View {
	mut app := w.state[ArrowsApp]()
	mut toggles := []gui.View{}

	toggles << gui.text(text: 'Groups', text_style: gui.theme().b1)

	for group in app.all_groups {
		toggles << group_select(group, app)
	}

	return gui.column(
		sizing:    gui.fit_fill
		padding:   gui.padding_large
		spacing:   gui.spacing_small
		color:     gui.theme().color_interior
		id:        'sidebar-scroll'
		id_scroll: 3
		content:   toggles
	)
}

fn group_select(group string, app &ArrowsApp) gui.View {
	color := if app.selected_group == group {
		gui.theme().color_active
	} else {
		gui.color_transparent
	}
	return gui.row(
		color:    color
		padding:  gui.theme().padding_small
		content:  [gui.text(text: group, text_style: gui.theme().n3)]
		on_click: fn [group] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ArrowsApp]()
			app.selected_group = group
			w.scroll_to_view('group-${group}')
		}
		on_hover: fn (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
			layout.shape.color = gui.theme().color_hover
			w.set_mouse_cursor_pointing_hand()
		}
	)
}

fn header(mut w gui.Window) gui.View {
	mut app := w.state[ArrowsApp]()
	return gui.row(
		id:      'header'
		color:   gui.theme().color_interior
		sizing:  gui.fill_fit
		padding: gui.padding_medium
		spacing: gui.spacing_large
		v_align: .middle
		content: [
			gui.text(text: 'Arrow Symbols', text_style: gui.theme().b1),
			gui.row(sizing: gui.fill_fit), // Spacer
			gui.radio_button_group_row(
				options:   [
					gui.radio_option('Grid', 'grid'),
					gui.radio_option('List', 'list'),
				]
				value:     app.view_mode
				on_select: fn (value string, mut w gui.Window) {
					mut app := w.state[ArrowsApp]()
					app.view_mode = value
					w.update_view(main_view)
				}
			),
		]
	)
}

fn grid_view(mut w gui.Window) gui.View {
	mut app := w.state[ArrowsApp]()

	// Group arrows
	mut groups := map[string][]ArrowSymbol{}
	// Preserve order of groups
	mut group_names := []string{}

	for arrow in app.arrows {
		if arrow.group !in groups {
			groups[arrow.group] = []ArrowSymbol{}
			group_names << arrow.group
		}
		groups[arrow.group] << arrow
	}

	mut content := []gui.View{}

	for group_name in group_names {
		content << gui.column(
			id:      'group-${group_name}'
			padding: gui.padding(24, 0, 10, 8)
			content: [gui.text(text: group_name, text_style: gui.theme().b2)]
		)

		// Chunk arrows into rows
		arrows := groups[group_name]

		// Responsive-ish: fixed width items, wrap automatically?
		// V-GUI doesn't have flow layout yet (wrap), so we must calculate chunks.
		// Let's assume a grid of 6 items per row for now.

		mut current_row := []gui.View{}
		for arrow in arrows {
			current_row << arrow_card(arrow)
			if current_row.len >= 6 {
				content << gui.row(spacing: gui.spacing_medium, content: current_row)
				current_row = []gui.View{}
			}
		}
		if current_row.len > 0 {
			content << gui.row(spacing: gui.spacing_medium, content: current_row)
		}
	}

	return gui.column(
		id:        'grid-scroll'
		on_scroll: fn (_ &gui.Layout, mut w gui.Window) {
			update_active_scroll_group(mut w)
		}
		id_scroll: 1
		sizing:    gui.fill_fill
		padding:   gui.padding_large
		spacing:   gui.spacing_medium
		content:   content
	)
}

fn arrow_card(arrow ArrowSymbol) gui.View {
	return gui.column(
		width:   60
		height:  60
		sizing:  gui.fixed_fixed
		padding: gui.padding_small
		v_align: .middle
		content: [
			gui.text(text: arrow.symbol, text_style: gui.theme().b1),
		]
	)
}

fn list_view(mut w gui.Window) gui.View {
	mut app := w.state[ArrowsApp]()

	// Group arrows
	mut groups := map[string][]ArrowSymbol{}
	// Preserve order of groups
	mut group_names := []string{}

	for arrow in app.arrows {
		if arrow.group !in groups {
			groups[arrow.group] = []ArrowSymbol{}
			group_names << arrow.group
		}
		groups[arrow.group] << arrow
	}

	mut content := []gui.View{}

	for group_name in group_names {
		content << gui.column(
			id:      'group-${group_name}'
			padding: gui.padding(24, 0, 10, 8)
			content: [gui.text(text: group_name, text_style: gui.theme().b2)]
		)

		mut rows := []gui.TableRowCfg{}
		rows << gui.tr([gui.th('Symbol'), gui.th('Name')])

		for arrow in groups[group_name] {
			rows << gui.tr([
				gui.td(arrow.symbol),
				gui.td(arrow.name),
			])
		}

		content << w.table(
			data:            rows
			text_style_head: gui.theme().b3
			text_style:      gui.theme().n2
		)
	}

	return gui.column(
		id:        'list-scroll'
		on_scroll: fn (_ &gui.Layout, mut w gui.Window) {
			update_active_scroll_group(mut w)
		}
		id_scroll: 1
		sizing:    gui.fill_fill
		padding:   gui.padding(0, 0, 15, 15)
		content:   content
	)
}

fn get_arrows() []ArrowSymbol {
	// This function populates the huge list of arrows.
	// I am pasting the parsed data here.
	mut arrows := []ArrowSymbol{cap: 750}

	// Right Arrows
	arrows << ArrowSymbol{'→', 'Rightwards Arrow', '2192', 'Right Arrows'}
	arrows << ArrowSymbol{'➔', 'Heavy Wide-Headed Rightwards Arrow', '2794', 'Right Arrows'}
	arrows << ArrowSymbol{'➜', 'Heavy Round-Tipped Rightwards Arrow', '279C', 'Right Arrows'}
	arrows << ArrowSymbol{'»', 'Right-Pointing Double Angle Quotation Mark', '00BB', 'Right Arrows'}
	arrows << ArrowSymbol{'➤', 'Black Rightwards Arrowhead', '27A4', 'Right Arrows'}
	arrows << ArrowSymbol{'🠒', 'Rightwards Arrow with Small Equilateral Arrowhead', '1F812', 'Right Arrows'}
	arrows << ArrowSymbol{'➞', 'Heavy Triangle-Headed Rightwards Arrow', '279E', 'Right Arrows'}
	arrows << ArrowSymbol{'❯', 'Heavy Right-Pointing Angle Quotation Mark Ornament', '276F', 'Right Arrows'}
	arrows << ArrowSymbol{'⟶', 'Long Rightwards Arrow', '27F6', 'Right Arrows'}
	arrows << ArrowSymbol{'ᐅ', 'Canadian Syllabics O', '1405', 'Right Arrows'}
	arrows << ArrowSymbol{'›', 'Single Right-Pointing Angle Quotation Mark', '203A', 'Right Arrows'}
	arrows << ArrowSymbol{'☞', 'White Right Pointing Index', '261E', 'Right Arrows'}
	arrows << ArrowSymbol{'>', 'Greater-Than Sign', '003E', 'Right Arrows'}
	arrows << ArrowSymbol{'🠖', 'Rightwards Arrow with Equilateral Arrowhead', '1F816', 'Right Arrows'}
	arrows << ArrowSymbol{'➳', 'White-Feathered Rightwards Arrow', '27B3', 'Right Arrows'}
	arrows << ArrowSymbol{'➣', 'Three-D Bottom-Lighted Rightwards Arrowhead', '27A3', 'Right Arrows'}
	arrows << ArrowSymbol{'☛', 'Black Right Pointing Index', '261B', 'Right Arrows'}
	arrows << ArrowSymbol{'➝', 'Triangle-Headed Rightwards Arrow', '279D', 'Right Arrows'}
	arrows << ArrowSymbol{'➥', 'Heavy Black Curved Downwards and Rightwards Arrow', '27A5', 'Right Arrows'}
	arrows << ArrowSymbol{'ᐳ', 'Canadian Syllabics Po', '1550', 'Right Arrows'}
	arrows << ArrowSymbol{'⃗', 'Combining Right Arrow Above', '20D7', 'Right Arrows'}
	arrows << ArrowSymbol{'⇨', 'Rightwards White Arrow', '21E8', 'Right Arrows'}
	arrows << ArrowSymbol{'➠', 'Heavy Dashed Triangle-Headed Rightwards Arrow', '279F', 'Right Arrows'}
	arrows << ArrowSymbol{'➢', 'Three-D Top-Lighted Rightwards Arrowhead', '27A2', 'Right Arrows'}
	arrows << ArrowSymbol{'❱', 'Heavy Right-Pointing Angle Bracket Ornament', '2771', 'Right Arrows'}
	arrows << ArrowSymbol{'➪', 'Left-Shaded White Rightwards Arrow', '27AA', 'Right Arrows'}
	arrows << ArrowSymbol{'➟', 'Dashed Triangle-Headed Rightwards Arrow', '279F', 'Right Arrows'}
	arrows << ArrowSymbol{'➺', 'Teardrop-Barbed Rightwards Arrow', '27BA', 'Right Arrows'}
	arrows << ArrowSymbol{'⇒', 'Rightwards Double Arrow', '21D2', 'Right Arrows'}
	arrows << ArrowSymbol{'➦', 'Heavy Black Curved Upwards and Rightwards Arrow', '27A6', 'Right Arrows'}
	arrows << ArrowSymbol{'⃕', 'Combining Clockwise Arrow Above', '20D5', 'Right Arrows'}
	arrows << ArrowSymbol{'↝', 'Rightwards Wave Arrow', '219D', 'Right Arrows'}
	arrows << ArrowSymbol{'↠', 'Rightwards Two Headed Arrow', '21A0', 'Right Arrows'}
	arrows << ArrowSymbol{'➯', 'Notched Lower Right-Shadowed White Rightwards Arrow', '27AF', 'Right Arrows'}
	arrows << ArrowSymbol{'➽', 'Heavy Wedge-Tailed Rightwards Arrow', '27BD', 'Right Arrows'}
	arrows << ArrowSymbol{'➙', 'Heavy Rightwards Arrow', '2799', 'Right Arrows'}
	arrows << ArrowSymbol{'➛', 'Drafting Point Rightwards Arrow', '279B', 'Right Arrows'}
	arrows << ArrowSymbol{'˃', 'Modifier Letter Right Arrowhead', '02C3', 'Right Arrows'}
	arrows << ArrowSymbol{'↬', 'Rightwards Arrow with Loop', '21AC', 'Right Arrows'}
	arrows << ArrowSymbol{'➩', 'Right-Shaded White Rightwards Arrow', '27AB', 'Right Arrows'}
	arrows << ArrowSymbol{'➨', 'Heavy Concave-Pointed Black Rightwards Arrow', '27BC', 'Right Arrows'}
	arrows << ArrowSymbol{'➼', 'Wedge-Tailed Rightwards Arrow', '27BC', 'Right Arrows'}
	arrows << ArrowSymbol{'➧', 'Squat Black Rightwards Arrow', '27A7', 'Right Arrows'}
	arrows << ArrowSymbol{'➭', 'Heavy Lower Right-Shadowed White Rightwards Arrow', '27AD', 'Right Arrows'}
	arrows << ArrowSymbol{'➸', 'Heavy Black-Feathered Rightwards Arrow', '27BC', 'Right Arrows'}
	arrows << ArrowSymbol{'⇾', 'Rightwards Open-Headed Arrow', '21FE', 'Right Arrows'}
	arrows << ArrowSymbol{'➵', 'Black-Feathered Rightwards Arrow', '27B5', 'Right Arrows'}
	arrows << ArrowSymbol{'⇝', 'Rightwards Squiggle Arrow', '21DD', 'Right Arrows'}
	arrows << ArrowSymbol{'➲', 'Circled Heavy White Rightwards Arrow', '27B2', 'Right Arrows'}
	arrows << ArrowSymbol{'➫', 'Back-Tilted Shadowed White Rightwards Arrow', '27AC', 'Right Arrows'}
	arrows << ArrowSymbol{'➻', 'Heavy Teardrop-Shanked Rightwards Arrow', '27BB', 'Right Arrows'}
	arrows << ArrowSymbol{'➮', 'Heavy Upper Right-Shadowed White Rightwards Arrow', '27AE', 'Right Arrows'}
	arrows << ArrowSymbol{'⇢', 'Rightwards Dashed Arrow', '21E2', 'Right Arrows'}
	arrows << ArrowSymbol{'⟴', 'Right Arrow with Circled Plus', '27F4', 'Right Arrows'}
	arrows << ArrowSymbol{'⟿', 'Long Rightwards Squiggle Arrow', '27FF', 'Right Arrows'}
	arrows << ArrowSymbol{'⟹', 'Long Rightwards Double Arrow', '27F9', 'Right Arrows'}
	arrows << ArrowSymbol{'⤑', 'Rightwards Arrow with Dotted Stem', '2911', 'Right Arrows'}
	arrows << ArrowSymbol{'➾', 'Open-Outlined Rightwards Arrow', '27BE', 'Right Arrows'}
	arrows << ArrowSymbol{'⟼', 'Long Rightwards Arrow from Bar', '27FC', 'Right Arrows'}
	arrows << ArrowSymbol{'˲', 'Modifier Letter Low Right Arrowhead', '02F2', 'Right Arrows'}
	arrows << ArrowSymbol{'↦', 'Rightwards Arrow from Bar', '21A6', 'Right Arrows'}
	arrows << ArrowSymbol{'⇁', 'Rightwards Harpoon with Barb Downwards', '21C1', 'Right Arrows'}
	arrows << ArrowSymbol{'➬', 'Front-Tilted Shadowed White Rightwards Arrow', '27AC', 'Right Arrows'}
	arrows << ArrowSymbol{'➱', 'Notched Upper Right-Shadowed White Rightwards Arrow', '27B1', 'Right Arrows'}
	arrows << ArrowSymbol{'⇀', 'Rightwards Harpoon with Barb Upwards', '21C0', 'Right Arrows'}
	arrows << ArrowSymbol{'⇶', 'Three Rightwards Arrows', '21F6', 'Right Arrows'}
	arrows << ArrowSymbol{'↛', 'Rightwards Arrow with Stroke', '219B', 'Right Arrows'}
	arrows << ArrowSymbol{'ᗒ', 'Canadian Syllabics Carrier We', '15D2', 'Right Arrows'}
	arrows << ArrowSymbol{'⤳', 'Wave Arrow Pointing Directly Right', '2933', 'Right Arrows'}
	arrows << ArrowSymbol{'↣', 'Rightwards Arrow with Tail', '21A3', 'Right Arrows'}
	arrows << ArrowSymbol{'⤐', 'Rightwards Two-Headed Triple Dash Arrow', '2910', 'Right Arrows'}
	arrows << ArrowSymbol{'⇛', 'Rightwards Triple Arrow', '21DB', 'Right Arrows'}
	arrows << ArrowSymbol{'⇥', 'Rightwards Arrow To Bar', '21E5', 'Right Arrows'}
	arrows << ArrowSymbol{'⇏', 'Rightwards Double Arrow with Stroke', '21CF', 'Right Arrows'}
	arrows << ArrowSymbol{'⥅', 'Rightwards Arrow with Plus Below', '2945', 'Right Arrows'}
	arrows << ArrowSymbol{'⥰', 'Right Double Arrow with Rounded Head', '2970', 'Right Arrows'}
	arrows << ArrowSymbol{'⇉', 'Rightwards Paired Arrows', '21C9', 'Right Arrows'}
	arrows << ArrowSymbol{'⍈', 'Apl Functional Symbol Quad Rightwards Arrow', '2348', 'Right Arrows'}
	arrows << ArrowSymbol{'ᐉ', 'Canadian Syllabics Carrier I', '140C', 'Right Arrows'}
	arrows << ArrowSymbol{'⤜', 'Rightwards Double Arrow-Tail', '291C', 'Right Arrows'}
	arrows << ArrowSymbol{'⤚', 'Rightwards Arrow-Tail', '291A', 'Right Arrows'}
	arrows << ArrowSymbol{'⟾', 'Long Rightwards Double Arrow from Bar', '27FE', 'Right Arrows'}
	arrows << ArrowSymbol{'⤠', 'Rightwards Arrow from Bar To Black Diamond', '2920', 'Right Arrows'}
	arrows << ArrowSymbol{'⇸', 'Rightwards Arrow with Vertical Stroke', '21F8', 'Right Arrows'}
	arrows << ArrowSymbol{'⤀', 'Rightwards Two-Headed Arrow with Vertical Stroke', '2900', 'Right Arrows'}
	arrows << ArrowSymbol{'⥤', 'Rightwards Harpoon with Barb Up Above Rightwards Harpoon with Barb Down', '21CC', 'Right Arrows'}
	arrows << ArrowSymbol{'⥲', 'Tilde Operator Above Rightwards Arrow', '2972', 'Right Arrows'}
	arrows << ArrowSymbol{'⇰', 'Rightwards White Arrow from Wall', '21E6', 'Right Arrows'}
	arrows << ArrowSymbol{'⤇', 'Rightwards Double Arrow from Bar', '2907', 'Right Arrows'}
	arrows << ArrowSymbol{'⥹', 'Subset Above Rightwards Arrow', '2979', 'Right Arrows'}
	arrows << ArrowSymbol{'⍄', 'Apl Functional Symbol Quad Greater-Than', '2344', 'Right Arrows'}
	arrows << ArrowSymbol{'⤍', 'Rightwards Double Dash Arrow', '290D', 'Right Arrows'}
	arrows << ArrowSymbol{'⥱', 'Equals Sign Above Rightwards Arrow', '2971', 'Right Arrows'}
	arrows << ArrowSymbol{'⥴', 'Rightwards Arrow Above Tilde Operator', '2974', 'Right Arrows'}
	arrows << ArrowSymbol{'⤅', 'Rightwards Two-Headed Arrow from Bar', '2905', 'Right Arrows'}
	arrows << ArrowSymbol{'⤏', 'Rightwards Triple Dash Arrow', '290F', 'Right Arrows'}
	arrows << ArrowSymbol{'⤗', 'Rightwards Two-Headed Arrow with Tail with Vertical Stroke', '2917', 'Right Arrows'}
	arrows << ArrowSymbol{'⇴', 'Right Arrow with Small Circle', '21F4', 'Right Arrows'}
	arrows << ArrowSymbol{'⥇', 'Rightwards Arrow Through X', '2947', 'Right Arrows'}
	arrows << ArrowSymbol{'⥭', 'Rightwards Harpoon with Barb Down Below Long Dash', '296D', 'Right Arrows'}
	arrows << ArrowSymbol{'⥵', 'Rightwards Arrow Above Almost Equal To', '2975', 'Right Arrows'}
	arrows << ArrowSymbol{'⇻', 'Rightwards Arrow with Double Vertical Stroke', '21FB', 'Right Arrows'}
	arrows << ArrowSymbol{'⤘', 'Rightwards Two-Headed Arrow with Tail with Double Vertical Stroke', '2918', 'Right Arrows'}
	arrows << ArrowSymbol{'⤖', 'Rightwards Two-Headed Arrow with Tail', '2916', 'Right Arrows'}
	arrows << ArrowSymbol{'⤞', 'Rightwards Arrow To Black Diamond', '291E', 'Right Arrows'}
	arrows << ArrowSymbol{'⍆', 'Apl Functional Symbol Rightwards Vane', '2346', 'Right Arrows'}
	arrows << ArrowSymbol{'⥓', 'Rightwards Harpoon with Barb Up To Bar', '2953', 'Right Arrows'}
	arrows << ArrowSymbol{'⥸', 'Greater-Than Above Rightwards Arrow', '2978', 'Right Arrows'}
	arrows << ArrowSymbol{'⤕', 'Rightwards Arrow with Tail with Double Vertical Stroke', '2915', 'Right Arrows'}
	arrows << ArrowSymbol{'⤃', 'Rightwards Double Arrow with Vertical Stroke', '2903', 'Right Arrows'}
	arrows << ArrowSymbol{'⤁', 'Rightwards Two-Headed Arrow with Double Vertical Stroke', '2901', 'Right Arrows'}
	arrows << ArrowSymbol{'⤔', 'Rightwards Arrow with Tail with Vertical Stroke', '2914', 'Right Arrows'}
	arrows << ArrowSymbol{'⥟', 'Rightwards Harpoon with Barb Down from Bar', '295F', 'Right Arrows'}
	arrows << ArrowSymbol{'⥗', 'Rightwards Harpoon with Barb Down To Bar', '2957', 'Right Arrows'}
	arrows << ArrowSymbol{'⥛', 'Rightwards Harpoon with Barb Up from Bar', '295B', 'Right Arrows'}
	arrows << ArrowSymbol{'⥬', 'Rightwards Harpoon with Barb Up Above Long Dash', '296C', 'Right Arrows'}

	// Left Arrows
	arrows << ArrowSymbol{'«', 'Left-Pointing Double Angle Quotation Mark', '00AB', 'Left Arrows'}
	arrows << ArrowSymbol{'🠔', 'Leftwards Arrow with Equilateral Arrowhead', '1F814', 'Left Arrows'}
	arrows << ArrowSymbol{'❮', 'Heavy Left-Pointing Angle Quotation Mark Ornament', '276E', 'Left Arrows'}
	arrows << ArrowSymbol{'←', 'Leftwards Arrow', '2190', 'Left Arrows'}
	arrows << ArrowSymbol{'<', 'Less-Than Sign', '003C', 'Left Arrows'}
	arrows << ArrowSymbol{'☚', 'Black Left Pointing Index', '261A', 'Left Arrows'}
	arrows << ArrowSymbol{'‹', 'Single Left-Pointing Angle Quotation Mark', '2039', 'Left Arrows'}
	arrows << ArrowSymbol{'ᐊ', 'Canadian Syllabics A', '140A', 'Left Arrows'}
	arrows << ArrowSymbol{'❰', 'Heavy Left-Pointing Angle Bracket Ornament', '2770', 'Left Arrows'}
	arrows << ArrowSymbol{'🠐', 'Leftwards Arrow with Small Equilateral Arrowhead', '1F810', 'Left Arrows'}
	arrows << ArrowSymbol{'ᐸ', 'Canadian Syllabics Pa', '1438', 'Left Arrows'}
	arrows << ArrowSymbol{'⇦', 'Leftwards White Arrow', '21E6', 'Left Arrows'}
	arrows << ArrowSymbol{'⟸', 'Long Leftwards Double Arrow', '27F8', 'Left Arrows'}
	arrows << ArrowSymbol{'⟵', 'Long Leftwards Arrow', '27F5', 'Left Arrows'}
	arrows << ArrowSymbol{'ᑉ', 'Canadian Syllabics P', '1449', 'Left Arrows'}
	arrows << ArrowSymbol{'↫', 'Leftwards Arrow with Loop', '21AB', 'Left Arrows'}
	arrows << ArrowSymbol{'⇜', 'Leftwards Squiggle Arrow', '21DC', 'Left Arrows'}
	arrows << ArrowSymbol{'˂', 'Modifier Letter Left Arrowhead', '02C2', 'Left Arrows'}
	arrows << ArrowSymbol{'⟻', 'Long Leftwards Arrow from Bar', '27FB', 'Left Arrows'}
	arrows << ArrowSymbol{'⃖', 'Combining Left Arrow Above', '20D6', 'Left Arrows'}
	arrows << ArrowSymbol{'⇚', 'Leftwards Triple Arrow', '21DA', 'Left Arrows'}
	arrows << ArrowSymbol{'⇐', 'Leftwards Double Arrow', '21D0', 'Left Arrows'}
	arrows << ArrowSymbol{'⇽', 'Leftwards Open-Headed Arrow', '21FD', 'Left Arrows'}
	arrows << ArrowSymbol{'↚', 'Leftwards Arrow with Stroke', '219A', 'Left Arrows'}
	arrows << ArrowSymbol{'↜', 'Leftwards Wave Arrow', '219C', 'Left Arrows'}
	arrows << ArrowSymbol{'↢', 'Leftwards Arrow with Tail', '21A2', 'Left Arrows'}
	arrows << ArrowSymbol{'⥳', 'Leftwards Arrow Above Tilde Operator', '2973', 'Left Arrows'}
	arrows << ArrowSymbol{'↤', 'Leftwards Arrow from Bar', '21A4', 'Left Arrows'}
	arrows << ArrowSymbol{'⇠', 'Leftwards Dashed Arrow', '21E0', 'Left Arrows'}
	arrows << ArrowSymbol{'ᗕ', 'Canadian Syllabics Carrier Wa', '15D5', 'Left Arrows'}
	arrows << ArrowSymbol{'↞', 'Leftwards Two Headed Arrow', '219E', 'Left Arrows'}
	arrows << ArrowSymbol{'⇤', 'Leftwards Arrow To Bar', '21E4', 'Left Arrows'}
	arrows << ArrowSymbol{'⤙', 'Leftwards Arrow-Tail', '2919', 'Left Arrows'}
	arrows << ArrowSymbol{'⥷', 'Leftwards Arrow Through Less-Than', '2977', 'Left Arrows'}
	arrows << ArrowSymbol{'⟽', 'Long Leftwards Double Arrow from Bar', '27FD', 'Left Arrows'}
	arrows << ArrowSymbol{'⍇', 'Apl Functional Symbol Quad Leftwards Arrow', '2347', 'Left Arrows'}
	arrows << ArrowSymbol{'⤂', 'Leftwards Double Arrow with Vertical Stroke', '2902', 'Left Arrows'}
	arrows << ArrowSymbol{'⤟', 'Leftwards Arrow from Bar To Black Diamond', '291F', 'Left Arrows'}
	arrows << ArrowSymbol{'⍅', 'Apl Functional Symbol Leftwards Vane', '2345', 'Left Arrows'}
	arrows << ArrowSymbol{'⤌', 'Leftwards Double Dash Arrow', '290C', 'Left Arrows'}
	arrows << ArrowSymbol{'⥆', 'Leftwards Arrow with Plus Below', '2946', 'Left Arrows'}
	arrows << ArrowSymbol{'⥖', 'Leftwards Harpoon with Barb Down To Bar', '2956', 'Left Arrows'}
	arrows << ArrowSymbol{'⤆', 'Leftwards Double Arrow from Bar', '2906', 'Left Arrows'}
	arrows << ArrowSymbol{'⥢', 'Leftwards Harpoon with Barb Up Above Leftwards Harpoon with Barb Down', '2962', 'Left Arrows'}
	arrows << ArrowSymbol{'⤛', 'Leftwards Double Arrow-Tail', '291B', 'Left Arrows'}
	arrows << ArrowSymbol{'⇍', 'Leftwards Double Arrow with Stroke', '21CD', 'Left Arrows'}
	arrows << ArrowSymbol{'⥪', 'Leftwards Harpoon with Barb Up Above Long Dash', '296A', 'Left Arrows'}
	arrows << ArrowSymbol{'⥫', 'Leftwards Harpoon with Barb Down Below Long Dash', '296B', 'Left Arrows'}
	arrows << ArrowSymbol{'⤝', 'Leftwards Arrow To Black Diamond', '291D', 'Left Arrows'}
	arrows << ArrowSymbol{'↼', 'Leftwards Harpoon with Barb Upwards', '21BC', 'Left Arrows'}
	arrows << ArrowSymbol{'⇇', 'Leftwards Paired Arrows', '21C7', 'Left Arrows'}
	arrows << ArrowSymbol{'⥶', 'Less-Than Above Leftwards Arrow', '2976', 'Left Arrows'}
	arrows << ArrowSymbol{'⥺', 'Leftwards Arrow Through Subset', '297A', 'Left Arrows'}
	arrows << ArrowSymbol{'⍃', 'Apl Functional Symbol Quad Less-Than', '2343', 'Left Arrows'}
	arrows << ArrowSymbol{'↽', 'Leftwards Harpoon with Barb Downwards', '21BD', 'Left Arrows'}
	arrows << ArrowSymbol{'˱', 'Modifier Letter Low Left Arrowhead', '02F1', 'Left Arrows'}
	arrows << ArrowSymbol{'⇷', 'Leftwards Arrow with Vertical Stroke', '21F7', 'Left Arrows'}
	arrows << ArrowSymbol{'⥞', 'Leftwards Harpoon with Barb Down from Bar', '295E', 'Left Arrows'}
	arrows << ArrowSymbol{'⤎', 'Leftwards Triple Dash Arrow', '290E', 'Left Arrows'}
	arrows << ArrowSymbol{'⥒', 'Leftwards Harpoon with Barb Up To Bar', '2952', 'Left Arrows'}
	arrows << ArrowSymbol{'⥚', 'Leftwards Harpoon with Barb Up from Bar', '295A', 'Left Arrows'}
	arrows << ArrowSymbol{'⇺', 'Leftwards Arrow with Double Vertical Stroke', '21FA', 'Left Arrows'}

	// Up Arrows
	arrows << ArrowSymbol{'▲', 'Black Up-Pointing Triangle', '25B2', 'Up Arrows'}
	arrows << ArrowSymbol{'↑', 'Upwards Arrow', '2191', 'Up Arrows'}
	arrows << ArrowSymbol{'🠕', 'Upwards Arrow with Equilateral Arrowhead', '1F815', 'Up Arrows'}
	arrows << ArrowSymbol{'^', 'Circumflex Accent', '005E', 'Up Arrows'}
	arrows << ArrowSymbol{'⤒', 'Upwards Arrow To Bar', '2912', 'Up Arrows'}
	arrows << ArrowSymbol{'̑', 'Combining Inverted Breve', '0311', 'Up Arrows'}
	arrows << ArrowSymbol{'⇧', 'Upwards White Arrow', '21E7', 'Up Arrows'}
	arrows << ArrowSymbol{'🠑', 'Upwards Arrow with Small Equilateral Arrowhead', '1F811', 'Up Arrows'}
	arrows << ArrowSymbol{'˄', 'Modifier Letter Up Arrowhead', '02C4', 'Up Arrows'}
	arrows << ArrowSymbol{'ˆ', 'Modifier Letter Circumflex Accent', '02C6', 'Up Arrows'}
	arrows << ArrowSymbol{'↟', 'Upwards Two Headed Arrow', '219F', 'Up Arrows'}
	arrows << ArrowSymbol{'˰', 'Modifier Letter Low Up Arrowhead', '02F0', 'Up Arrows'}
	arrows << ArrowSymbol{'⇑', 'Upwards Double Arrow', '21D1', 'Up Arrows'}
	arrows << ArrowSymbol{'ᛣ', 'Runic Letter Calc', '16E3', 'Up Arrows'}
	arrows << ArrowSymbol{'⇪', 'Upwards White Arrow from Bar', '21EA', 'Up Arrows'}
	arrows << ArrowSymbol{'̭', 'Combining Circumflex Accent Below', '032D', 'Up Arrows'}
	arrows << ArrowSymbol{'⇡', 'Upwards Dashed Arrow', '21E1', 'Up Arrows'}
	arrows << ArrowSymbol{'⇞', 'Upwards Arrow with Double Stroke', '21DE', 'Up Arrows'}
	arrows << ArrowSymbol{'⥉', 'Upwards Two-Headed Arrow from Small Circle', '2949', 'Up Arrows'}
	arrows << ArrowSymbol{'ᐃ', 'Canadian Syllabics I', '1403', 'Up Arrows'}
	arrows << ArrowSymbol{'↿', 'Upwards Harpoon with Barb Leftwards', '21BF', 'Up Arrows'}
	arrows << ArrowSymbol{'ᐱ', 'Canadian Syllabics Pi', '1431', 'Up Arrows'}
	arrows << ArrowSymbol{'↥', 'Upwards Arrow from Bar', '21A5', 'Up Arrows'}
	arrows << ArrowSymbol{'⇫', 'Upwards White Arrow On Pedestal', '21EB', 'Up Arrows'}
	arrows << ArrowSymbol{'⤉', 'Upwards Arrow with Horizontal Stroke', '2909', 'Up Arrows'}
	arrows << ArrowSymbol{'⇈', 'Upwards Paired Arrows', '21C8', 'Up Arrows'}
	arrows << ArrowSymbol{'⤊', 'Upwards Triple Arrow', '290A', 'Up Arrows'}
	arrows << ArrowSymbol{'⇮', 'Upwards White Double Arrow', '21EE', 'Up Arrows'}
	arrows << ArrowSymbol{'⍓', 'Apl Functional Symbol Quad Up Caret', '2353', 'Up Arrows'}
	arrows << ArrowSymbol{'⥠', 'Upwards Harpoon with Barb Left from Bar', '2960', 'Up Arrows'}
	arrows << ArrowSymbol{'⟰', 'Upwards Quadruple Arrow', '27F0', 'Up Arrows'}
	arrows << ArrowSymbol{'⍐', 'Apl Functional Symbol Quad Upwards Arrow', '2350', 'Up Arrows'}
	arrows << ArrowSymbol{'⥣', 'Upwards Harpoon with Barb Left Beside Upwards Harpoon with Barb Right', '2963', 'Up Arrows'}
	arrows << ArrowSymbol{'⍍', 'Apl Functional Symbol Quad Delta', '234D', 'Up Arrows'}
	arrows << ArrowSymbol{'ᐞ', 'Canadian Syllabics Glottal Stop', '141E', 'Up Arrows'}
	arrows << ArrowSymbol{'⇯', 'Upwards White Double Arrow On Pedestal', '21EF', 'Up Arrows'}
	arrows << ArrowSymbol{'↾', 'Upwards Harpoon with Barb Rightwards', '21BE', 'Up Arrows'}
	arrows << ArrowSymbol{'ᗑ', 'Canadian Syllabics Carrier Wo', '15D1', 'Up Arrows'}
	arrows << ArrowSymbol{'⇭', 'Upwards White Arrow On Pedestal with Vertical Bar', '21ED', 'Up Arrows'}
	arrows << ArrowSymbol{'⇬', 'Upwards White Arrow On Pedestal with Horizontal Bar', '21EC', 'Up Arrows'}
	arrows << ArrowSymbol{'⥔', 'Upwards Harpoon with Barb Right To Bar', '2954', 'Up Arrows'}
	arrows << ArrowSymbol{'⍏', 'Apl Functional Symbol Upwards Vane', '234F', 'Up Arrows'}
	arrows << ArrowSymbol{'⥜', 'Upwards Harpoon with Barb Right from Bar', '295C', 'Up Arrows'}
	arrows << ArrowSymbol{'⥘', 'Upwards Harpoon with Barb Left To Bar', '2958', 'Up Arrows'}

	// Down Arrows
	arrows << ArrowSymbol{'▼', 'Black Down-Pointing Triangle', '25BC', 'Down Arrows'}
	arrows << ArrowSymbol{'↓', 'Downwards Arrow', '2193', 'Down Arrows'}
	arrows << ArrowSymbol{'↧', 'Downwards Arrow from Bar', '21A7', 'Down Arrows'}
	arrows << ArrowSymbol{'🠗', 'Downwards Arrow with Equilateral Arrowhead', '1F817', 'Down Arrows'}
	arrows << ArrowSymbol{'ˇ', 'Caron', '02C7', 'Down Arrows'}
	arrows << ArrowSymbol{'☟', 'White Down Pointing Index', '261F', 'Down Arrows'}
	arrows << ArrowSymbol{'̬', 'Combining Caron Below', '032C', 'Down Arrows'}
	arrows << ArrowSymbol{'🠓', 'Downwards Arrow with Small Equilateral Arrowhead', '1F813', 'Down Arrows'}
	arrows << ArrowSymbol{'⇩', 'Downwards White Arrow', '21E9', 'Down Arrows'}
	arrows << ArrowSymbol{'˅', 'Modifier Letter Down Arrowhead', '02C5', 'Down Arrows'}
	arrows << ArrowSymbol{'ᐯ', 'Canadian Syllabics Pe', '142F', 'Down Arrows'}
	arrows << ArrowSymbol{'⇊', 'Downwards Paired Arrows', '21CA', 'Down Arrows'}
	arrows << ArrowSymbol{'⇣', 'Downwards Dashed Arrow', '21E3', 'Down Arrows'}
	arrows << ArrowSymbol{'↡', 'Downwards Two Headed Arrow', '21A1', 'Down Arrows'}
	arrows << ArrowSymbol{'ˬ', 'Modifier Letter Voicing', '02EC', 'Down Arrows'}
	arrows << ArrowSymbol{'ᐁ', 'Canadian Syllabics E', '1401', 'Down Arrows'}
	arrows << ArrowSymbol{'⤓', 'Downwards Arrow To Bar', '2913', 'Down Arrows'}
	arrows << ArrowSymbol{'⇓', 'Downwards Double Arrow', '21D3', 'Down Arrows'}
	arrows << ArrowSymbol{'⇟', 'Downwards Arrow with Double Stroke', '21DF', 'Down Arrows'}
	arrows << ArrowSymbol{'⟱', 'Downwards Quadruple Arrow', '27F1', 'Down Arrows'}
	arrows << ArrowSymbol{'⇂', 'Downwards Harpoon with Barb Rightwards', '21C2', 'Down Arrows'}
	arrows << ArrowSymbol{'⥥', 'Downwards Harpoon with Barb Left Beside Downwards Harpoon with Barb Right', '2965', 'Down Arrows'}
	arrows << ArrowSymbol{'⇃', 'Downwards Harpoon with Barb Leftwards', '21C3', 'Down Arrows'}
	arrows << ArrowSymbol{'⤋', 'Downwards Triple Arrow', '290B', 'Down Arrows'}
	arrows << ArrowSymbol{'ᗐ', 'Canadian Syllabics Carrier Wu', '15D0', 'Down Arrows'}
	arrows << ArrowSymbol{'⍖', 'Apl Functional Symbol Downwards Vane', '2356', 'Down Arrows'}
	arrows << ArrowSymbol{'⍔', 'Apl Functional Symbol Quad Del', '2354', 'Down Arrows'}
	arrows << ArrowSymbol{'⤈', 'Downwards Arrow with Horizontal Stroke', '2908', 'Down Arrows'}
	arrows << ArrowSymbol{'⍗', 'Apl Functional Symbol Quad Downwards Arrow', '2357', 'Down Arrows'}
	arrows << ArrowSymbol{'⥝', 'Downwards Harpoon with Barb Right from Bar', '295D', 'Down Arrows'}
	arrows << ArrowSymbol{'⥡', 'Downwards Harpoon with Barb Left from Bar', '2961', 'Down Arrows'}
	arrows << ArrowSymbol{'⍌', 'Apl Functional Symbol Quad Down Caret', '234C', 'Down Arrows'}
	arrows << ArrowSymbol{'⥙', 'Downwards Harpoon with Barb Left To Bar', '2959', 'Down Arrows'}
	arrows << ArrowSymbol{'⥕', 'Downwards Harpoon with Barb Right To Bar', '2955', 'Down Arrows'}

	// Left Right Arrows
	arrows << ArrowSymbol{'⇄', 'Rightwards Arrow Over Leftwards Arrow', '21C4', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⬌', 'Left Right Black Arrow', '2B0C', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇆', 'Leftwards Arrow Over Rightwards Arrow', '21C6', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⟷', 'Long Left Right Arrow', '27F7', 'Left Right Arrows'}
	arrows << ArrowSymbol{'↭', 'Left Right Wave Arrow', '21AD', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇌', 'Rightwards Harpoon Over Leftwards Harpoon', '21CC', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇋', 'Leftwards Harpoon Over Rightwards Harpoon', '21CB', 'Left Right Arrows'}
	arrows << ArrowSymbol{'↹', 'Leftwards Arrow To Bar Over Rightwards Arrow To Bar', '21B9', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇔', 'Left Right Double Arrow', '21D4', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥂', 'Rightwards Arrow Above Short Leftwards Arrow', '2942', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⬄', 'Left Right White Arrow', '2B04', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥈', 'Left Right Arrow Through Small Circle', '2948', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇿', 'Left Right Open-Headed Arrow', '21FF', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⤄', 'Left Right Double Arrow with Vertical Stroke', '2904', 'Left Right Arrows'}
	arrows << ArrowSymbol{'↮', 'Left Right Arrow with Stroke', '21AE', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥋', 'Left Barb Down Right Barb Up Harpoon', '294B', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥐', 'Left Barb Down Right Barb Down Harpoon', '2950', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥃', 'Leftwards Arrow Above Short Rightwards Arrow', '2943', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥊', 'Left Barb Up Right Barb Down Harpoon', '294A', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇼', 'Left Right Arrow with Double Vertical Stroke', '21FC', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥦', 'Leftwards Harpoon with Barb Up Above Rightwards Harpoon with Barb Up', '2966', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⇹', 'Left Right Arrow with Vertical Stroke', '21F9', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥎', 'Left Barb Up Right Barb Up Harpoon', '294E', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥄', 'Short Rightwards Arrow Above Leftwards Arrow', '2944', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥧', 'Leftwards Harpoon with Barb Down Above Rightwards Harpoon with Barb Down', '2967', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥨', 'Rightwards Harpoon with Barb Up Above Leftwards Harpoon with Barb Up', '2968', 'Left Right Arrows'}
	arrows << ArrowSymbol{'⥩', 'Rightwards Harpoon with Barb Down Above Leftwards Harpoon with Barb Down', '2969', 'Left Right Arrows'}

	// Up Down Arrows
	arrows << ArrowSymbol{'⇅', 'Upwards Arrow Leftwards of Downwards Arrow', '21C5', 'Up Down Arrows'}
	arrows << ArrowSymbol{'↨', 'Up Down Arrow with Base', '21A8', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⬍', 'Up Down Black Arrow', '2B0D', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⇳', 'Up Down White Arrow', '21F3', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⇕', 'Up Down Double Arrow', '21D5', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥮', 'Upwards Harpoon with Barb Left Beside Downwards Harpoon with Barb Right', '296E', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥍', 'Up Barb Left Down Barb Right Harpoon', '294D', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥑', 'Up Barb Left Down Barb Left Harpoon', '2951', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⇵', 'Downwards Arrow Leftwards of Upwards Arrow', '21F5', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥏', 'Up Barb Right Down Barb Right Harpoon', '294F', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥯', 'Downwards Harpoon with Barb Left Beside Upwards Harpoon with Barb Right', '296F', 'Up Down Arrows'}
	arrows << ArrowSymbol{'⥌', 'Up Barb Right Down Barb Left Harpoon', '294C', 'Up Down Arrows'}

	// Diagonal Arrows
	arrows << ArrowSymbol{'➶', 'Black-Feathered North East Arrow', '27B6', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬈', 'North East Black Arrow', '2B08', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'➷', 'Heavy Black-Feathered South East Arrow', '27B8', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'➚', 'Heavy North East Arrow', '279A', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'➴', 'Black-Feathered South East Arrow', '27B7', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'➘', 'Heavy South East Arrow', '2798', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬊', 'South East Black Arrow', '2B0A', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'➹', 'Heavy Black-Feathered North East Arrow', '27B9', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬋', 'South West Black Arrow', '2B0B', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬉', 'North West Black Arrow', '2B09', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬀', 'North East White Arrow', '2B00', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇱', 'North West Arrow To Corner', '21F1', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤦', 'South West Arrow with Hook', '2924', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤡', 'North West and South East Arrow', '2921', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤥', 'South East Arrow with Hook', '2925', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇘', 'South East Double Arrow', '21D8', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇙', 'South West Double Arrow', '21D9', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇗', 'North East Double Arrow', '21D7', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬂', 'South East White Arrow', '2B02', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬃', 'South West White Arrow', '2B03', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤯', 'Falling Diagonal Crossing North East Arrow', '292F', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤢', 'North East and South West Arrow', '2922', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇖', 'North West Double Arrow', '21D6', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⇲', 'South East Arrow To Corner', '21F2', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤮', 'North East Arrow Crossing South East Arrow', '292E', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⬁', 'North West White Arrow', '2B01', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤪', 'South West Arrow and North West Arrow', '292A', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤣', 'North West Arrow with Hook', '2923', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤨', 'North East Arrow and South East Arrow', '2928', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤤', 'North East Arrow with Hook', '2924', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤱', 'North East Arrow Crossing North West Arrow', '2931', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤧', 'North West Arrow and North East Arrow', '2927', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤰', 'Rising Diagonal Crossing South East Arrow', '2930', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤲', 'North West Arrow Crossing North East Arrow', '2932', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤩', 'South East Arrow and South West Arrow', '2929', 'Diagonal Arrows'}
	arrows << ArrowSymbol{'⤭', 'South East Arrow Crossing North East Arrow', '292D', 'Diagonal Arrows'}

	// Heavy Arrows
	arrows << ArrowSymbol{'➜', 'Heavy Round-Tipped Rightwards Arrow', '279C', 'Heavy Arrows'}
	arrows << ArrowSymbol{'❱', 'Heavy Right-Pointing Angle Bracket Ornament', '2771', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡅', 'Upwards Heavy Arrow', '1F845', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡇', 'Downwards Heavy Arrow', '1F847', 'Heavy Arrows'}
	arrows << ArrowSymbol{'➽', 'Heavy Wedge-Tailed Rightwards Arrow', '27BD', 'Heavy Arrows'}
	arrows << ArrowSymbol{'➨', 'Heavy Concave-Pointed Black Rightwards Arrow', '27BC', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡆', 'Rightwards Heavy Arrow', '1F846', 'Heavy Arrows'}
	arrows << ArrowSymbol{'❰', 'Heavy Left-Pointing Angle Bracket Ornament', '2770', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡸', 'Wide-Headed Leftwards Heavy Barb Arrow', '1F878', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡻', 'Wide-Headed Downwards Heavy Barb Arrow', '1F87B', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡄', 'Leftwards Heavy Arrow', '1F844', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡽', 'Wide-Headed North East Heavy Barb Arrow', '1F87D', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢅', 'Wide-Headed North East Very Heavy Barb Arrow', '1F885', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡺', 'Wide-Headed Rightwards Heavy Barb Arrow', '1F87A', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢁', 'Wide-Headed Upwards Very Heavy Barb Arrow', '1F881', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🠹', 'Upwards Squared Arrow', '1F839', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢃', 'Wide-Headed Downwards Very Heavy Barb Arrow', '1F883', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢂', 'Wide-Headed Rightwards Very Heavy Barb Arrow', '1F882', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡾', 'Wide-Headed South East Heavy Barb Arrow', '1F87E', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢀', 'Wide-Headed Leftwards Very Heavy Barb Arrow', '1F880', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢇', 'Wide-Headed South West Very Heavy Barb Arrow', '1F887', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🠺', 'Rightwards Squared Arrow', '1F83A', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡿', 'Wide-Headed South West Heavy Barb Arrow', '1F87F', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢆', 'Wide-Headed South East Very Heavy Barb Arrow', '1F886', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🠸', 'Leftwards Squared Arrow', '1F838', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🠻', 'Downwards Squared Arrow', '1F83B', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡹', 'Wide-Headed Upwards Heavy Barb Arrow', '1F879', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🢄', 'Wide-Headed North West Very Heavy Barb Arrow', '1F884', 'Heavy Arrows'}
	arrows << ArrowSymbol{'🡼', 'Wide-Headed North West Heavy Barb Arrow', '1F87C', 'Heavy Arrows'}

	// Heavy Compressed Arrows
	arrows << ArrowSymbol{'🠾', 'Rightwards Compressed Arrow', '1F83E', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🡃', 'Downwards Heavy Compressed Arrow', '1F843', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🡂', 'Rightwards Heavy Compressed Arrow', '1F842', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🠽', 'Upwards Compressed Arrow', '1F83D', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🡀', 'Leftwards Heavy Compressed Arrow', '1F840', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🠿', 'Downwards Compressed Arrow', '1F83F', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🡁', 'Upwards Heavy Compressed Arrow', '1F841', 'Heavy Compressed Arrows'}
	arrows << ArrowSymbol{'🠼', 'Leftwards Compressed Arrow', '1F83C', 'Heavy Compressed Arrows'}

	// Curved Arrows
	arrows << ArrowSymbol{'➥', 'Heavy Black Curved Downwards and Rightwards Arrow', '27A5', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮩', 'Black Curved Downwards and Rightwards Arrow', '2BA9', 'Curved Arrows'}
	arrows << ArrowSymbol{'➦', 'Heavy Black Curved Upwards and Rightwards Arrow', '27A6', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮯', 'Black Curved Rightwards and Downwards Arrow', '2BAF', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮨', 'Black Curved Downwards and Leftwards Arrow', '2BA8', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮭', 'Black Curved Rightwards and Upwards Arrow', '2BAD', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮫', 'Black Curved Upwards and Rightwards Arrow', '2BAB', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮪', 'Black Curved Upwards and Leftwards Arrow', '2BAA', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮮', 'Black Curved Leftwards and Downwards Arrow', '2BAE', 'Curved Arrows'}
	arrows << ArrowSymbol{'⮬', 'Black Curved Leftwards and Upwards Arrow', '2BAC', 'Curved Arrows'}

	// Shadowed Arrows
	arrows << ArrowSymbol{'➪', 'Left-Shaded White Rightwards Arrow', '27AA', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➯', 'Notched Lower Right-Shadowed White Rightwards Arrow', '27AF', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➩', 'Right-Shaded White Rightwards Arrow', '27AB', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➭', 'Heavy Lower Right-Shadowed White Rightwards Arrow', '27AD', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➫', 'Back-Tilted Shadowed White Rightwards Arrow', '27AC', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➮', 'Heavy Upper Right-Shadowed White Rightwards Arrow', '27AE', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➬', 'Front-Tilted Shadowed White Rightwards Arrow', '27AC', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'➱', 'Notched Upper Right-Shadowed White Rightwards Arrow', '27B1', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢥', 'Rightwards Right-Shaded White Arrow', '1F8A5', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢡', 'Rightwards Bottom Shaded White Arrow', '1F8A1', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢨', 'Leftwards Back-Tilted Shadowed White Arrow', '1F8A8', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢧', 'Rightwards Left-Shaded White Arrow', '1F8A7', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢪', 'Leftwards Front-Tilted Shadowed White Arrow', '1F8AA', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢤', 'Leftwards Left-Shaded White Arrow', '1F8A4', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢦', 'Leftwards Right-Shaded White Arrow', '1F8A6', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢢', 'Leftwards Top Shaded White Arrow', '1F8A2', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢣', 'Rightwards Top Shaded White Arrow', '1F8A3', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢩', 'Rightwards Back-Tilted Shadowed White Arrow', '1F8A9', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢠', 'Leftwards Bottom-Shaded White Arrow', '1F8A0', 'Shadowed Arrows'}
	arrows << ArrowSymbol{'🢫', 'Rightwards Front-Tilted Shadowed White Arrow', '1F8AB', 'Shadowed Arrows'}

	// Arrow to/from Bar
	arrows << ArrowSymbol{'↧', 'Downwards Arrow from Bar', '21A7', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤒', 'Upwards Arrow To Bar', '2912', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⟼', 'Long Rightwards Arrow from Bar', '27FC', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'↦', 'Rightwards Arrow from Bar', '21A6', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'↨', 'Up Down Arrow with Base', '21A8', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⟻', 'Long Leftwards Arrow from Bar', '27FB', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤓', 'Downwards Arrow To Bar', '2913', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⇥', 'Rightwards Arrow To Bar', '21E5', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'↥', 'Upwards Arrow from Bar', '21A5', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⇱', 'North West Arrow To Corner', '21F1', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤠', 'Rightwards Arrow from Bar To Black Diamond', '2920', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭹', 'South West Triangle-Headed Arrow To Bar', '2B79', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'↤', 'Leftwards Arrow from Bar', '21A4', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭷', 'North East Triangle-Headed Arrow To Bar', '2B77', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⇤', 'Leftwards Arrow To Bar', '21E4', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭸', 'South East Triangle-Headed Arrow To Bar', '2B78', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⬶', 'Leftwards Two-Headed Arrow from Bar', '2B36', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'↸', 'North West Arrow To Long Bar', '21B8', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭲', 'Rightwards Triangle-Headed Arrow To Bar', '2B72', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭳', 'Downwards Triangle-Headed Arrow To Bar', '2B73', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭶', 'North West Triangle-Headed Arrow To Bar', '2B76', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤅', 'Rightwards Two-Headed Arrow from Bar', '2905', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⇲', 'South East Arrow To Corner', '21F2', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤟', 'Leftwards Arrow from Bar To Black Diamond', '291F', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤞', 'Rightwards Arrow To Black Diamond', '291E', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⤝', 'Leftwards Arrow To Black Diamond', '291D', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭱', 'Upwards Triangle-Headed Arrow To Bar', '2B71', 'Arrow to/from Bar'}
	arrows << ArrowSymbol{'⭰', 'Leftwards Triangle-Headed Arrow To Bar', '2B70', 'Arrow to/from Bar'}

	// Navigation Arrows
	arrows << ArrowSymbol{'🡢', 'Wide-Headed Rightwards Light Barb Arrow', '1F862', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡥', 'Wide-Headed North East Light Barb Arrow', '1F865', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡸', 'Wide-Headed Leftwards Heavy Barb Arrow', '1F878', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡻', 'Wide-Headed Downwards Heavy Barb Arrow', '1F87B', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡽', 'Wide-Headed North East Heavy Barb Arrow', '1F87D', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡪', 'Wide-Headed Rightwards Barb Arrow', '1F86A', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢅', 'Wide-Headed North East Very Heavy Barb Arrow', '1F885', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡲', 'Wide-Headed Rightwards Medium Barb Arrow', '1F872', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡺', 'Wide-Headed Rightwards Heavy Barb Arrow', '1F87A', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢁', 'Wide-Headed Upwards Very Heavy Barb Arrow', '1F881', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡭', 'Wide-Headed North East Barb Arrow', '1F86D', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢃', 'Wide-Headed Downwards Very Heavy Barb Arrow', '1F883', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢂', 'Wide-Headed Rightwards Very Heavy Barb Arrow', '1F882', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡾', 'Wide-Headed South East Heavy Barb Arrow', '1F87E', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢀', 'Wide-Headed Leftwards Very Heavy Barb Arrow', '1F880', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡦', 'Wide-Headed South East Light Barb Arrow', '1F866', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢇', 'Wide-Headed South West Very Heavy Barb Arrow', '1F887', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡿', 'Wide-Headed South West Heavy Barb Arrow', '1F87F', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢆', 'Wide-Headed South East Very Heavy Barb Arrow', '1F886', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡩', 'Wide-Headed Upwards Barb Arrow', '1F869', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡧', 'Wide-Headed South West Light Barb Arrow', '1F867', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡹', 'Wide-Headed Upwards Heavy Barb Arrow', '1F879', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡤', 'Wide-Headed North West Light Barb Arrow', '1F864', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡵', 'Wide-Headed North East Medium Barb Arrow', '1F875', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡨', 'Wide-Headed Leftwards Barb Arrow', '1F868', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡮', 'Wide-Headed South East Barb Arrow', '1F86E', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡰', 'Wide-Headed Leftwards Medium Barb Arrow', '1F870', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡡', 'Wide-Headed Upwards Light Barb Arrow', '1F861', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🢄', 'Wide-Headed North West Very Heavy Barb Arrow', '1F884', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡷', 'Wide-Headed South West Medium Barb Arrow', '1F877', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡼', 'Wide-Headed North West Heavy Barb Arrow', '1F87C', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡫', 'Wide-Headed Downwards Barb Arrow', '1F86B', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡳', 'Wide-Headed Downwards Medium Barb Arrow', '1F873', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡴', 'Wide-Headed North West Medium Barb Arrow', '1F874', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡬', 'Wide-Headed North West Barb Arrow', '1F86C', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡶', 'Wide-Headed South East Medium Barb Arrow', '1F876', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡣', 'Wide-Headed Downwards Light Barb Arrow', '1F863', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡠', 'Wide-Headed Leftwards Light Barb Arrow', '1F860', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡱', 'Wide-Headed Upwards Medium Barb Arrow', '1F871', 'Navigation Arrows'}
	arrows << ArrowSymbol{'🡯', 'Wide-Headed South West Barb Arrow', '1F86F', 'Navigation Arrows'}

	// Hand Pointing Index
	arrows << ArrowSymbol{'☞', 'White Right Pointing Index', '261E', 'Hand Pointing Index'}
	arrows << ArrowSymbol{'☛', 'Black Right Pointing Index', '261B', 'Hand Pointing Index'}
	arrows << ArrowSymbol{'☟', 'White Down Pointing Index', '261F', 'Hand Pointing Index'}
	arrows << ArrowSymbol{'☚', 'Black Left Pointing Index', '261A', 'Hand Pointing Index'}

	// 90 Degree Arrows
	arrows << ArrowSymbol{'↳', 'Downwards Arrow with Tip Rightwards', '21B3', '90 Degree Arrows'}
	arrows << ArrowSymbol{'↴', 'Rightwards Arrow with Corner Downwards', '21B4', '90 Degree Arrows'}
	arrows << ArrowSymbol{'☇', 'Lightning', '2607', '90 Degree Arrows'}
	arrows << ArrowSymbol{'↲', 'Downwards Arrow with Tip Leftwards', '21B2', '90 Degree Arrows'}
	arrows << ArrowSymbol{'↵', 'Downwards Arrow with Corner Leftwards', '21B5', '90 Degree Arrows'}
	arrows << ArrowSymbol{'↱', 'Upwards Arrow with Tip Rightwards', '21B1', '90 Degree Arrows'}
	arrows << ArrowSymbol{'↰', 'Upwards Arrow with Tip Leftwards', '21B0', '90 Degree Arrows'}

	// Circle Circular Arrows
	arrows << ArrowSymbol{'↻', 'Clockwise Open Circle Arrow', '21BB', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⤷', 'Arrow Pointing Downwards Then Curving Rightwards', '2937', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'↺', 'Anticlockwise Open Circle Arrow', '21BA', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⃕', 'Combining Clockwise Arrow Above', '20D5', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'🗘', 'Clockwise Right and Left Semicircle Arrows', '1F5D8', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'↷', 'Clockwise Top Semicircle Arrow', '21B7', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⤸', 'Right-Side Arc Clockwise Arrow', '2938', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⟳', 'Clockwise Gapped Circle Arrow', '27F3', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⤹', 'Left-Side Arc Anticlockwise Arrow', '2939', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'↶', 'Anticlockwise Top Semicircle Arrow', '21B6', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⮌', 'Anticlockwise Triangle-Headed Right U-Shaped Arrow', '2B8C', 'Circle Circular Arrows'}
	arrows << ArrowSymbol{'⭮', 'Clockwise Triangle-Headed Open Circle Arrow', '2B6E', 'Circle Circular Arrows'}

	// Clockwise Vertical Arrows
	arrows << ArrowSymbol{'⤻', 'Bottom Arc Anticlockwise Arrow', '293B', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⮔', 'Four Corner Arrows Circling Anticlockwise', '2B94', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤿', 'Lower Left Semicircular Anticlockwise Arrow', '293F', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤶', 'Arrow Pointing Downwards Then Curving Leftwards', '2936', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤺', 'Top Arc Anticlockwise Arrow', '293A', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⭯', 'Anticlockwise Triangle-Headed Open Circle Arrow', '2B6F', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⥀', 'Anticlockwise Closed Circle Arrow', '2940', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⟲', 'Anticlockwise Gapped Circle Arrow', '27F2', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤼', 'Top Arc Clockwise Arrow with Minus', '293C', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⮍', 'Anticlockwise Triangle-Headed Bottom U-Shaped Arrow', '2B8D', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⥁', 'Clockwise Closed Circle Arrow', '2941', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⮎', 'Anticlockwise Triangle-Headed Left U-Shaped Arrow', '2B8E', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤾', 'Lower Right Semicircular Clockwise Arrow', '293E', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⮏', 'Anticlockwise Triangle-Headed Top U-Shaped Arrow', '2B8F', 'Clockwise Vertical Arrows'}
	arrows << ArrowSymbol{'⤽', 'Top Arc Anticlockwise Arrow with Plus', '293D', 'Clockwise Vertical Arrows'}

	// Circled Arrows
	arrows << ArrowSymbol{'➲', 'Circled Heavy White Rightwards Arrow', '27B2', 'Circled Arrows'}
	arrows << ArrowSymbol{'⮊', 'Rightwards Black Circled White Arrow', '2B8A', 'Circled Arrows'}
	arrows << ArrowSymbol{'⮉', 'Upwards Black Circled White Arrow', '2B89', 'Circled Arrows'}
	arrows << ArrowSymbol{'⮋', 'Downwards Black Circled White Arrow', '2B8B', 'Circled Arrows'}
	arrows << ArrowSymbol{'⮈', 'Leftwards Black Circled White Arrow', '2B88', 'Circled Arrows'}

	// Ribbon Arrows
	arrows << ArrowSymbol{'⮷', 'Ribbon Arrow Right Down', '2BB7', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮱', 'Ribbon Arrow Down Right', '2BB1', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮳', 'Ribbon Arrow Up Right', '2BB3', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮵', 'Ribbon Arrow Right Up', '2BB5', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮰', 'Ribbon Arrow Down Left', '2BB0', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮶', 'Ribbon Arrow Left Down', '2BB6', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮴', 'Ribbon Arrow Left Up', '2BB4', 'Ribbon Arrows'}
	arrows << ArrowSymbol{'⮲', 'Ribbon Arrow Up Left', '2BB2', 'Ribbon Arrows'}

	// Paired Twin Two Arrows
	arrows << ArrowSymbol{'⇄', 'Rightwards Arrow Over Leftwards Arrow', '21C4', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇆', 'Leftwards Arrow Over Rightwards Arrow', '21C6', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇊', 'Downwards Paired Arrows', '21CA', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇅', 'Upwards Arrow Leftwards of Downwards Arrow', '21C5', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇉', 'Rightwards Paired Arrows', '21C9', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮅', 'Upwards Triangle-Headed Paired Arrows', '2B85', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇈', 'Upwards Paired Arrows', '21C8', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮂', 'Rightwards Triangle-Headed Arrow Over Leftwards Triangle-Headed Arrow', '2B82', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮁', 'Upwards Triangle-Headed Arrow Leftwards of Downwards Triangle-Headed Arrow', '2B81', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮀', 'Leftwards Triangle-Headed Arrow Over Rightwards Triangle-Headed Arrow', '2B80', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇵', 'Downwards Arrow Leftwards of Upwards Arrow', '21F5', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮇', 'Downwards Triangle-Headed Paired Arrows', '2B87', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮃', 'Downwards Triangle-Headed Arrow Leftwards of Upwards Triangle-Headed Arrow', '2B83', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⇇', 'Leftwards Paired Arrows', '21C7', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮆', 'Rightwards Triangle-Headed Paired Arrows', '2B86', 'Paired Twin Two Arrows'}
	arrows << ArrowSymbol{'⮄', 'Leftwards Triangle-Headed Paired Arrows', '2B84', 'Paired Twin Two Arrows'}

	// Triple Three Arrows
	arrows << ArrowSymbol{'⇶', 'Three Rightwards Arrows', '21F6', 'Triple Three Arrows'}
	arrows << ArrowSymbol{'⇚', 'Leftwards Triple Arrow', '21DA', 'Triple Three Arrows'}
	arrows << ArrowSymbol{'⟱', 'Downwards Quadruple Arrow', '27F1', 'Triple Three Arrows'}
	arrows << ArrowSymbol{'⇛', 'Rightwards Triple Arrow', '21DB', 'Triple Three Arrows'}
	arrows << ArrowSymbol{'⤊', 'Upwards Triple Arrow', '290A', 'Triple Three Arrows'}

	// Keyboard Arrows
	arrows << ArrowSymbol{'→', 'Rightwards Arrow', '2192', 'Keyboard Arrows'}
	arrows << ArrowSymbol{'↓', 'Downwards Arrow', '2193', 'Keyboard Arrows'}
	arrows << ArrowSymbol{'↑', 'Upwards Arrow', '2191', 'Keyboard Arrows'}
	arrows << ArrowSymbol{'←', 'Leftwards Arrow', '2190', 'Keyboard Arrows'}
	arrows << ArrowSymbol{'⭾', 'Horizontal Tab Key', '2B7E', 'Keyboard Arrows'}
	arrows << ArrowSymbol{'⭿', 'Vertical Tab Key', '2B7F', 'Keyboard Arrows'}

	// Bow and Arrows
	arrows << ArrowSymbol{'➶', 'Black-Feathered North East Arrow', '27B6', 'Bow and Arrows'}
	arrows << ArrowSymbol{'➷', 'Heavy Black-Feathered South East Arrow', '27B8', 'Bow and Arrows'}
	arrows << ArrowSymbol{'➴', 'Black-Feathered South East Arrow', '27B7', 'Bow and Arrows'}
	arrows << ArrowSymbol{'➹', 'Heavy Black-Feathered North East Arrow', '27B9', 'Bow and Arrows'}

	// Waved Arrows
	arrows << ArrowSymbol{'↝', 'Rightwards Wave Arrow', '219D', 'Waved Arrows'}
	arrows << ArrowSymbol{'⇝', 'Rightwards Squiggle Arrow', '21DD', 'Waved Arrows'}
	arrows << ArrowSymbol{'⟿', 'Long Rightwards Squiggle Arrow', '27FF', 'Waved Arrows'}
	arrows << ArrowSymbol{'⇜', 'Leftwards Squiggle Arrow', '21DC', 'Waved Arrows'}
	arrows << ArrowSymbol{'⤳', 'Wave Arrow Pointing Directly Right', '2933', 'Waved Arrows'}
	arrows << ArrowSymbol{'⬳', 'Long Leftwards Squiggle Arrow', '2B33', 'Waved Arrows'}
	arrows << ArrowSymbol{'↜', 'Leftwards Wave Arrow', '219C', 'Waved Arrows'}
	arrows << ArrowSymbol{'⬿', 'Wave Arrow Pointing Directly Left', '2B3F', 'Waved Arrows'}

	// Harpoon Arrows
	arrows << ArrowSymbol{'⇁', 'Rightwards Harpoon with Barb Downwards', '21C1', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⇌', 'Rightwards Harpoon Over Leftwards Harpoon', '21CC', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⇀', 'Rightwards Harpoon with Barb Upwards', '21C0', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⇋', 'Leftwards Harpoon Over Rightwards Harpoon', '21CB', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⇂', 'Downwards Harpoon with Barb Rightwards', '21C2', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'↿', 'Upwards Harpoon with Barb Leftwards', '21BF', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥥', 'Downwards Harpoon with Barb Left Beside Downwards Harpoon with Barb Right', '2965', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⇃', 'Downwards Harpoon with Barb Leftwards', '21C3', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥤', 'Rightwards Harpoon with Barb Up Above Rightwards Harpoon with Barb Down', '21CC', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥠', 'Upwards Harpoon with Barb Left from Bar', '2960', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥣', 'Upwards Harpoon with Barb Left Beside Upwards Harpoon with Barb Right', '2963', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥋', 'Left Barb Down Right Barb Up Harpoon', '294B', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥐', 'Left Barb Down Right Barb Down Harpoon', '2950', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥭', 'Rightwards Harpoon with Barb Down Below Long Dash', '296D', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥮', 'Upwards Harpoon with Barb Left Beside Downwards Harpoon with Barb Right', '296E', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'↾', 'Upwards Harpoon with Barb Rightwards', '21BE', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥖', 'Leftwards Harpoon with Barb Down To Bar', '2956', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥊', 'Left Barb Up Right Barb Down Harpoon', '294A', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥍', 'Up Barb Left Down Barb Right Harpoon', '294D', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥓', 'Rightwards Harpoon with Barb Up To Bar', '2953', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥢', 'Leftwards Harpoon with Barb Up Above Leftwards Harpoon with Barb Down', '2962', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥑', 'Up Barb Left Down Barb Left Harpoon', '2951', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥝', 'Downwards Harpoon with Barb Right from Bar', '295D', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥦', 'Leftwards Harpoon with Barb Up Above Rightwards Harpoon with Barb Up', '2966', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥪', 'Leftwards Harpoon with Barb Up Above Long Dash', '296A', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥫', 'Leftwards Harpoon with Barb Down Below Long Dash', '296B', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥎', 'Left Barb Up Right Barb Up Harpoon', '294E', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥏', 'Up Barb Right Down Barb Right Harpoon', '294F', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'↼', 'Leftwards Harpoon with Barb Upwards', '21BC', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥟', 'Rightwards Harpoon with Barb Down from Bar', '295F', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥗', 'Rightwards Harpoon with Barb Down To Bar', '2957', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥔', 'Upwards Harpoon with Barb Right To Bar', '2954', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥛', 'Rightwards Harpoon with Barb Up from Bar', '295B', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'↽', 'Leftwards Harpoon with Barb Downwards', '21BD', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥞', 'Leftwards Harpoon with Barb Down from Bar', '295E', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥡', 'Downwards Harpoon with Barb Left from Bar', '2961', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥜', 'Upwards Harpoon with Barb Right from Bar', '295C', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥧', 'Leftwards Harpoon with Barb Down Above Rightwards Harpoon with Barb Down', '2967', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥯', 'Downwards Harpoon with Barb Left Beside Upwards Harpoon with Barb Right', '296F', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥌', 'Up Barb Right Down Barb Left Harpoon', '294C', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥬', 'Rightwards Harpoon with Barb Up Above Long Dash', '296C', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥒', 'Leftwards Harpoon with Barb Up To Bar', '2952', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥚', 'Leftwards Harpoon with Barb Up from Bar', '295A', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥨', 'Rightwards Harpoon with Barb Up Above Leftwards Harpoon with Barb Up', '2968', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥙', 'Downwards Harpoon with Barb Left To Bar', '2959', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥘', 'Upwards Harpoon with Barb Left To Bar', '2958', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥩', 'Rightwards Harpoon with Barb Down Above Leftwards Harpoon with Barb Down', '2969', 'Harpoon Arrows'}
	arrows << ArrowSymbol{'⥕', 'Downwards Harpoon with Barb Right To Bar', '2955', 'Harpoon Arrows'}

	// Stroked Arrows
	arrows << ArrowSymbol{'⇟', 'Downwards Arrow with Double Stroke', '21DF', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇞', 'Upwards Arrow with Double Stroke', '21DE', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤉', 'Upwards Arrow with Horizontal Stroke', '2909', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇸', 'Rightwards Arrow with Vertical Stroke', '21F8', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤀', 'Rightwards Two-Headed Arrow with Vertical Stroke', '2900', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⭻', 'Upwards Triangle-Headed Arrow with Double Horizontal Stroke', '2B7B', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤗', 'Rightwards Two-Headed Arrow with Tail with Vertical Stroke', '2917', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤈', 'Downwards Arrow with Horizontal Stroke', '2908', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇻', 'Rightwards Arrow with Double Vertical Stroke', '21FB', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤘', 'Rightwards Two-Headed Arrow with Tail with Double Vertical Stroke', '2918', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤖', 'Rightwards Two-Headed Arrow with Tail', '2916', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇼', 'Left Right Arrow with Double Vertical Stroke', '21FC', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤕', 'Rightwards Arrow with Tail with Double Vertical Stroke', '2915', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬻', 'Leftwards Two-Headed Arrow with Tail', '2B3B', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇹', 'Left Right Arrow with Vertical Stroke', '21F9', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬴', 'Leftwards Two-Headed Arrow with Vertical Stroke', '2B34', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⭽', 'Downwards Triangle-Headed Arrow with Double Horizontal Stroke', '2B7D', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⭺', 'Leftwards Triangle-Headed Arrow with Double Horizontal Stroke', '2B7A', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬼', 'Leftwards Two-Headed Arrow with Tail with Vertical Stroke', '2B3C', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤁', 'Rightwards Two-Headed Arrow with Double Vertical Stroke', '2901', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⤔', 'Rightwards Arrow with Tail with Vertical Stroke', '2914', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬺', 'Leftwards Arrow with Tail with Double Vertical Stroke', '2B3A', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬹', 'Leftwards Arrow with Tail with Vertical Stroke', '2B39', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬵', 'Leftwards Two-Headed Arrow with Double Vertical Stroke', '2B35', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇷', 'Leftwards Arrow with Vertical Stroke', '21F7', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⇺', 'Leftwards Arrow with Double Vertical Stroke', '21FA', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⭼', 'Rightwards Triangle-Headed Arrow with Double Horizontal Stroke', '2B7C', 'Stroked Arrows'}
	arrows << ArrowSymbol{'⬽', 'Leftwards Two-Headed Arrow with Tail with Double Vertical Stroke', '2B3D', 'Stroked Arrows'}

	// Double Head Arrows
	arrows << ArrowSymbol{'↠', 'Rightwards Two Headed Arrow', '21A0', 'Double Head Arrows'}
	arrows << ArrowSymbol{'↟', 'Upwards Two Headed Arrow', '219F', 'Double Head Arrows'}
	arrows << ArrowSymbol{'↡', 'Downwards Two Headed Arrow', '21A1', 'Double Head Arrows'}
	arrows << ArrowSymbol{'⯮', 'Rightwards Two-Headed Arrow with Tringle Arrowheads', '2BEE', 'Double Head Arrows'}
	arrows << ArrowSymbol{'⯯', 'Downwards Two-Headed Arrow with Tringle Arrowheads', '2BEF', 'Double Head Arrows'}
	arrows << ArrowSymbol{'⯭', 'Upwards Two-Headed Arrow with Tringle Arrowheads', '2BED', 'Double Head Arrows'}
	arrows << ArrowSymbol{'↞', 'Leftwards Two Headed Arrow', '219E', 'Double Head Arrows'}
	arrows << ArrowSymbol{'⯬', 'Leftwards Two-Headed Arrow with Tringle Arrowheads', '2BEC', 'Double Head Arrows'}

	// Miscellaneous Arrows
	arrows << ArrowSymbol{'↯', 'Downwards Zigzag Arrow', '21AF', 'Miscellaneous Arrows'}
	arrows << ArrowSymbol{'☈', 'Thunderstorm', '2608', 'Miscellaneous Arrows'}
	arrows << ArrowSymbol{'⥽', 'Right Fish Tail', '297D', 'Miscellaneous Arrows'}
	arrows << ArrowSymbol{'⥼', 'Left Fish Tail', '297C', 'Miscellaneous Arrows'}
	arrows << ArrowSymbol{'⥾', 'Up Fish Tail', '297E', 'Miscellaneous Arrows'}
	arrows << ArrowSymbol{'⥿', 'Down Fish Tail', '297F', 'Miscellaneous Arrows'}

	// Arrows Within Triangle Arrowhead
	arrows << ArrowSymbol{'🢖', 'Rightwards White Arrow Within Triangle Arrowhead', '1F896', 'Arrows Within Triangle Arrowhead'}
	arrows << ArrowSymbol{'🢗', 'Downwards White Arrow Within Triangle Arrowhead', '1F897', 'Arrows Within Triangle Arrowhead'}
	arrows << ArrowSymbol{'🢔', 'Leftwards White Arrow Within Triangle Arrowhead', '1F894', 'Arrows Within Triangle Arrowhead'}
	arrows << ArrowSymbol{'🢕', 'Upwards White Arrow Within Triangle Arrowhead', '1F895', 'Arrows Within Triangle Arrowhead'}

	// Arrow Heads
	arrows << ArrowSymbol{'➤', 'Black Rightwards Arrowhead', '27A4', 'Arrow Heads'}
	arrows << ArrowSymbol{'▲', 'Black Up-Pointing Triangle', '25B2', 'Arrow Heads'}
	arrows << ArrowSymbol{'➣', 'Three-D Bottom-Lighted Rightwards Arrowhead', '27A3', 'Arrow Heads'}
	arrows << ArrowSymbol{'➢', 'Three-D Top-Lighted Rightwards Arrowhead', '27A2', 'Arrow Heads'}
	arrows << ArrowSymbol{'🢒', 'Rightwards Triangle Arrowhead', '1F892', 'Arrow Heads'}
	arrows << ArrowSymbol{'⌃', 'Up Arrowhead', '2303', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮜', 'Black Leftwards Equilateral Arrowhead', '2B9C', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮞', 'Black Rightwards Equilateral Arrowhead', '2B9E', 'Arrow Heads'}
	arrows << ArrowSymbol{'⌄', 'Down Arrowhead', '2304', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮟', 'Black Downwards Equilateral Arrowhead', '2B9F', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮚', 'Three-D Top-Lighted Rightwards Equilateral Arrowhead', '2B9A', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮝', 'Black Upwards Equilateral Arrowhead', '2B9D', 'Arrow Heads'}
	arrows << ArrowSymbol{'🢓', 'Downwards Triangle Arrowhead', '1F893', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮘', 'Three-D Top-Lighted Leftwards Equilateral Arrowhead', '2B98', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮛', 'Three-D Left-Lighted Downwards Equilateral Arrowhead', '2B9B', 'Arrow Heads'}
	arrows << ArrowSymbol{'⮙', 'Three-D Right-Lighted Upwards Equilateral Arrowhead', '2B99', 'Arrow Heads'}
	arrows << ArrowSymbol{'🢐', 'Leftwards Triangle Arrowhead', '1F890', 'Arrow Heads'}
	arrows << ArrowSymbol{'🢑', 'Upwards Triangle Arrowhead', '1F891', 'Arrow Heads'}

	// Arrow Shafts
	arrows << ArrowSymbol{'■', 'Black Square', '25A0', 'Arrow Shafts'}
	arrows << ArrowSymbol{'□', 'White Square', '25A1', 'Arrow Shafts'}
	arrows << ArrowSymbol{'▤', 'Square with Horizontal Fill', '25A4', 'Arrow Shafts'}
	arrows << ArrowSymbol{'⧈', 'Squared Square', '29C8', 'Arrow Shafts'}
	arrows << ArrowSymbol{'▦', 'Square with Orthogonal Crosshatch Fill', '25A6', 'Arrow Shafts'}
	arrows << ArrowSymbol{'▨', 'Square with Upper Right To Lower Left Fill', '25A8', 'Arrow Shafts'}
	arrows << ArrowSymbol{'▧', 'Square with Upper Left To Lower Right Fill', '25A7', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🞓', 'Extremely Heavy White Square', '1F793', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢝', 'Heavy Arrow Shaft Width Two Thirds', '1F89D', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢜', 'Heavy Arrow Shaft Width One', '1F89C', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢬', 'White Arrow Shaft Width One', '1F8AC', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🞒', 'Very Heavy White Square', '1F792', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🞑', 'Heavy White Square', '1F791', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢭', 'White Arrow Shaft Width Two Thirds', '1F8AD', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢞', 'Heavy Arrow Shaft Width One Half', '1F89E', 'Arrow Shafts'}
	arrows << ArrowSymbol{'🢟', 'Heavy Arrow Shaft Width One Third', '1F89F', 'Arrow Shafts'}

	// Fedex Logo Arrow
	arrows << ArrowSymbol{'🡆', 'Rightwards Heavy Arrow', '1F846', 'Fedex Logo Arrow'}

	return arrows
}

fn update_active_scroll_group(mut w gui.Window) {
	mut app := w.state[ArrowsApp]()
	// ID of the main content scrollview
	scroll_id := if app.view_mode == 'list' { 'list-scroll' } else { 'grid-scroll' }

	// We need to find the scroll container to get its Y position
	container := w.find_layout_by_id(scroll_id) or { return }
	container_y := container.shape.y + container.shape.padding.top

	mut active_group := ''
	// Iterate through groups in reverse order to find the first one that is above the fold?
	// No, we want the one that is closest to the top but not too far down.
	// Actually, standard spy logic: last header that has (y <= container_y)

	for group in app.all_groups {
		if group_layout := w.find_layout_by_id('group-${group}') {
			// Check if the group header is at or above the top of the container
			// We give it a little threshold (e.g. 10px) so it selects as soon as it's near top
			if group_layout.shape.y <= container_y + 10 {
				active_group = group
			} else {
				// Since groups are ordered, once we find one below the fold, we can stop
				// The previous one (stored in active_group) is the correct one.
				break
			}
		}
	}

	if active_group != '' && active_group != app.selected_group {
		app.selected_group = active_group
		// State changed, ensure window updates next frame
		w.update_window()
	}
}
