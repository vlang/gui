import gui

// Expand Panel Demo
// =============================

@[heap]
struct ExpandPanelApp {
pub mut:
	light_theme bool
	auto_close  bool
	open_titles []string
}

fn main() {
	mut window := gui.window(
		title:   'Expand Panels'
		state:   &ExpandPanelApp{}
		width:   500
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[ExpandPanelApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			toggle_theme(app),
			gui.column(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					gui.column(
						id_scroll: 1
						sizing:    gui.fill_fill
						content:   [
							expander('BRAZIL', brazil_text, mut app),
							expander('CHILE', chile_text, mut app),
							expander('COLUMBIA', columbia_text, mut app),
							expander('EQUADOR', equador_text, mut app),
							expander('GUYANA', guyana_text, mut app),
						]
					),
				]
			),
		]
	)
}

fn expander(title string, description string, mut app ExpandPanelApp) gui.View {
	b_text_style := gui.TextStyle{
		...gui.theme().n3
	}
	return gui.expand_panel(
		open:      title in app.open_titles
		sizing:    gui.fill_fit
		head:      gui.row(
			padding: gui.theme().padding_medium
			sizing:  gui.fill_fit
			v_align: .middle
			content: [
				gui.text(text: title, text_style: b_text_style),
				gui.row(sizing: gui.fill_fit),
				gui.text(text: 'South America', text_style: gui.theme().n4),
			]
		)
		content:   gui.column(
			sizing:  gui.fill_fit
			content: [
				gui.text(
					text:       description
					text_style: gui.theme().n4
					mode:       .wrap
				),
			]
		)
		on_toggle: fn [title] (mut w gui.Window) {
			mut app := w.state[ExpandPanelApp]()
			if app.auto_close {
				match title in app.open_titles {
					true { app.open_titles.clear() }
					else { app.open_titles = [title] }
				}
			} else {
				match title in app.open_titles {
					true { app.open_titles = app.open_titles.filter(it != title) }
					else { app.open_titles << title }
				}
			}
		}
	)
}

const brazil_text = 'The word "Brazil" likely comes from the Portuguese word for brazilwood, a tree that once grew plentifully along the Brazilian coast. In Portuguese, brazilwood is called pau-brasil, with the word brasil commonly given the etymology "red like an ember", formed from brasa ("ember") and the suffix -il (from -iculum or -ilium). As brazilwood produces a deep red dye, it was highly valued by the European textile industry and was the earliest commercially exploited product from Brazil. Throughout the 16th century, massive amounts of brazilwood were harvested by indigenous peoples (mostly Tupi) along the Brazilian coast, who sold the timber to European traders (mostly Portuguese, but also French) in return for assorted European consumer goods.'

const chile_text = 'There are various theories about the origin of the word Chile. According to 17th-century Spanish chronicler Diego de Rosales, the Incas called the valley of the Aconcagua Chili by corruption of the name of a Picunche tribal chief (cacique) called Tili, who ruled the area at the time of the Incan conquest in the 15th century. Another theory points to the similarity of the valley of the Aconcagua with that of the Casma Valley in Peru, where there was a town and valley named Chili.'

const columbia_text = 'The name "Colombia" is derived from the last name of the Italian navigator Christopher Columbus. It was conceived by the Venezuelan revolutionary Francisco de Miranda as a reference to all of the New World, but especially to those portions under Spanish law. The name was later adopted by the Republic of Colombia of 1819, formed from the territories of the old Viceroyalty of New Granada (modern-day Colombia, Panama, Venezuela, Ecuador, and northwest Brazil).'

const equador_text = 'The origin of the name of Ecuador is from Spain. When the Spaniards colonized the land they called it "el ecuador" which translated means "the equator".'

const guyana_text = 'The name "Guyana" derives from Guiana, the original name for the region that formerly included Guyana (British Guiana), Suriname (Dutch Guiana), French Guiana, and parts of Colombia, Venezuela and Brazil. According to the Oxford English Dictionary, "Guyana" comes from an indigenous Amerindian language and means "land of many waters".'

fn toggle_theme(app &ExpandPanelApp) gui.View {
	return gui.row(
		h_align: .right
		sizing:  gui.fill_fit
		padding: gui.pad_tblr(0, gui.pad_medium)
		content: [
			gui.toggle(
				label:    'auto close'
				select:   app.auto_close
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ExpandPanelApp]()
					app.auto_close = !app.auto_close
					if app.auto_close {
						app.open_titles.clear()
					}
				}
			),
			gui.row(sizing: gui.fill_fit),
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon5
				select:        app.light_theme
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ExpandPanelApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_bordered
					} else {
						gui.theme_dark_bordered
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
