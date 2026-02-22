import gui

const bacon_ipsum_1 = 'Bacon ipsum dolor sit amet tri-tip shoulder tenderloin drumstick, meatloaf corned beef. Kevin pastrami tri-tip prosciutto hamburger, pork chop shank corned beef tenderloin meatball short ribs. Tongue andouille strip steak tenderloin sausage chicken hamburger cow pig sirloin boudin rump meatball andouille chuck.'
const bacon_ipsum_2 = 'Pig meatloaf bresaola, spare ribs venison short loin salami ham hock. Landjaeger chicken fatback pork loin doner sirloin hamburger cow pastrami. Pork swine beef ribs t-bone flank filet mignon biltong beef shank beef shoulder bresaola tongue flank leberkase.'
const bacon_ipsum_3 = 'Filet mignon brisket pancetta fatback short ribs porchetta drumstick, pork chop pork beef ribs bresaola. Tongue beef ham hock ground round steak biltong. Corned beef pork loin cow pig shankle, fatback alcatra turkey prosciutto brisket rump capicola chuck ham drumstick.'

struct State {
mut:
	sidebar_open bool = true
}

fn main() {
	mut window := gui.window(
		title:   'Fancy Toggle Sidebar'
		state:   &State{}
		width:   900
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	state := window.state[State]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			gui.sidebar(mut window,
				id:      'nav'
				open:    state.sidebar_open
				width:   260
				color:   gui.Color{40, 44, 52, 255}
				content: [sidebar_panel()]
			),
			content_panel(state),
		]
	)
}

fn sidebar_panel() gui.View {
	return gui.column(
		sizing:  gui.fill_fill
		spacing: 0
		content: [
			// Brand header
			gui.column(
				sizing:  gui.fill_fit
				padding: gui.padding(10, 16, 10, 16)
				h_align: .center
				color:   gui.Color{33, 37, 43, 255}
				content: [
					gui.text(
						text:       'Brand'
						text_style: gui.TextStyle{
							...gui.theme().b2
							color: gui.white
						}
					),
				]
			),
			// Nav items
			gui.column(
				sizing:  gui.fill_fill
				spacing: 0
				padding: gui.padding_none
				content: [
					nav_item(gui.icon_home, 'Home'),
					nav_item(gui.icon_info, 'About'),
					nav_item(gui.icon_calendar, 'Events'),
					nav_item(gui.icon_users, 'Team'),
					nav_item(gui.icon_building, 'Works'),
					nav_item(gui.icon_wrench, 'Services'),
					nav_item(gui.icon_comment, 'Contact'),
					nav_item(gui.icon_heart, 'Follow me'),
				]
			),
		]
	)
}

fn nav_item(icon string, label string) gui.View {
	return gui.button(
		sizing:      gui.fill_fit
		h_align:     .start
		padding:     gui.padding_none
		radius:      0
		size_border: 0
		color:       gui.Color{0, 0, 0, 0}
		color_hover: gui.Color{255, 255, 255, 20}
		color_click: gui.Color{255, 255, 255, 35}
		content:     [
			gui.row(
				spacing: 12
				padding: gui.padding_small
				content: [
					gui.text(
						text:       icon
						text_style: gui.TextStyle{
							...gui.theme().icon3
							color: gui.Color{130, 140, 160, 255}
						}
					),
					gui.text(
						text:       label
						text_style: gui.TextStyle{
							...gui.theme().text_style
							color: gui.white
						}
					),
				]
			),
		]
		on_click:    fn [label] (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {
		}
	)
}

fn content_panel(state &State) gui.View {
	icon_style := gui.TextStyle{
		...gui.theme().icon1
		color: gui.Color{30, 30, 30, 255}
	}

	return gui.column(
		sizing:  gui.fill_fill
		color:   gui.Color{230, 230, 230, 255}
		content: [
			// Toolbar with hamburger/X
			gui.button(
				padding:     gui.padding(4, 8, 4, 8)
				size_border: 0
				color:       gui.Color{0, 0, 0, 0}
				color_hover: gui.Color{0, 0, 0, 20}
				content:     [
					gui.text(
						text:       if state.sidebar_open {
							gui.icon_close
						} else {
							gui.icon_bar
						}
						text_style: icon_style
					),
				]
				on_click:    fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut s := w.state[State]()
					s.sidebar_open = !s.sidebar_open
				}
			),
			// Body text
			gui.text(
				text:       'Fancy Toggle Sidebar'
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().b1
					color: gui.Color{30, 30, 30, 255}
				}
			),
			gui.text(
				text:       bacon_ipsum_1
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().text_style
					color: gui.Color{60, 60, 60, 255}
				}
			),
			gui.text(
				text:       bacon_ipsum_2
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().text_style
					color: gui.Color{60, 60, 60, 255}
				}
			),
			gui.text(
				text:       bacon_ipsum_3
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().text_style
					color: gui.Color{60, 60, 60, 255}
				}
			),
		]
	)
}
