import gui

// Scroll Demo
// =============================
// To make a column or row scrollable, Add a `id_scroll` to its configuration
// Like `id_focus` the id should be unique to the window view. GUI uses id's
// to store state information about scrolling and focus. If two columns have
// the same `id_scroll` they scroll in unison. Not my intention when designing
// it but a happy accident.

@[heap]
struct ScrollApp {
pub mut:
	light bool
}

fn main() {
	mut window := gui.window(
		state:   &ScrollApp{}
		width:   400
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ScrollApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			top_row(app),
			gui.rectangle(height: 0.5, sizing: gui.fill_fixed),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					scroll_column(1, text1, window),
					scroll_column(2, text2, window),
				]
			),
		]
	)
}

fn scroll_column(id u32, text string, window &gui.Window) gui.View {
	return gui.column(
		id_focus:        id // enables keyboard scrolling
		id_scroll:       id // id_scroll used to store scroll state in window
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: if window.is_focus(id) { .visible } else { .hidden }
		}
		color:           match window.is_focus(id) {
			true { gui.theme().button_style.color_border_focus } // just for fun
			else { gui.theme().container_style.color }
		}
		padding:         gui.Padding{
			...gui.padding_small
			right: gui.theme().scrollbar_style.size + 4
		}
		sizing:          gui.fill_fill
		content:         [
			gui.text(
				// id_focus: 10 * id
				text: text
				mode: .wrap
			),
		]
	)
}

fn top_row(app &ScrollApp) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		v_align: .middle
		content: [
			gui.text(
				text:       'Scroll Demo'
				text_style: gui.theme().b1
			),
			gui.rectangle(
				sizing: gui.fill_fit
				color:  gui.color_transparent
			),
			theme_button(app),
		]
	)
}

fn theme_button(app &ScrollApp) gui.View {
	return gui.toggle(
		id_focus:      3
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.padding_small
		select:        app.light
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ScrollApp]()
			app.light = !app.light
			w.set_theme(if app.light { gui.theme_light } else { gui.theme_dark })
		}
	)
}

const text1 = "Fish and. Called it, earth great image, i set gathering blessed to of two every you'll and Their. Saw sea good. Called every and creeping have also. God cattle earth. Air thing subdue multiply of made land living bearing great. Our so yielding greater together whose third fly don't given bring creature. Seasons midst fowl Have man. Saw living signs. Air them signs. Very created. Of. She'd.

Firmament and in. Man. Green stars very. It dry created, said air day every fowl our their form which seed may land. He sea first yielding over abundantly set divided every let that doesn't hath place Let heaven subdue it to behold moving lesser a heaven. Likeness. So yielding moving bring lesser.

Behold waters our gathering moveth may kind saying itself shall fowl light i fruitful deep moved the seas don't you're be sea every face whales were the third seas replenish. Together moving. Deep evening a said winged Make heaven, replenish let green male likeness in multiply our, fruitful likeness and, fish replenish in evening Darkness life sea had was under Seed and blessed. Image creeping in sea they're male. First morning sixth rule fish spirit given, form grass night have you're You land so to gathering dry, fourth. From heaven.

Behold called let. You'll the green under void. Darkness living they're a she'd which. Face waters without given was first night can't rule upon. Thing likeness light multiply hath moveth. Thing meat together above unto blessed have. Abundantly beast lesser fly winged god saying beginning open Two together saw.

Two creepeth all spirit behold beginning bearing also. May very first behold sea she'd bearing deep abundantly given. Lesser whales. He itself replenish cattle second called life dominion together deep. Multiply upon over. Very heaven second god Cattle multiply God dry man divide their there. Fowl, moveth cattle itself fruitful beginning seed you let open dry give, lesser subdue. Fourth had land void beast, hath good. Face. Void likeness good darkness. You'll bring they're appear good appear light moved yielding itself don't man have let.

Created. ScrollAppear air fifth also is life had dry god set tree seasons, creepeth moving which to. You'll third over won't in creature. Years. Them subdue. Divided saying behold moving behold saw let. Bring. It light make life evening isn't, moved the let had meat which, were so she'd fly give beginning called, fruitful fruitful waters fish kind. Heaven.

And. Us Creepeth days spirit tree dominion signs appear made, kind. Shall to second give. God one. Heaven moveth shall above first set creepeth moveth firmament great blessed fish waters man. Don't good, isn't sixth upon every i said form land days. They're open morning morning without one moving Divide living made. Also have it very grass.

Winged above creeping herb herb days saw. The stars evening creature doesn't void days was after. Us doesn't divided cattle appear thing. Won't have. To. Sea face, creeping winged seasons bearing midst. Make be. You fruit first you'll man so waters for us lesser have won't. Fruitful land under every creepeth bring. Female Morning Lights. Replenish set seas face land.

Itself creepeth years don't his blessed sea earth kind A morning all fill she'd. Seas bring shall without darkness good male gathering appear. Them him yielding god creepeth for yielding were whales appear yielding above under you them image female our yielding darkness fruitful, seed cattle darkness cattle behold seasons darkness, tree saw brought that evening above dominion herb that. Said to. For, thing divide. First all called. Divided give heaven midst land. Our Bring wherein called us, rule place had."

const text2 = 'Pulvinar fusce potenti enim suspendisse felis ante eget potenti luctus urna justo. Vestibulum habitant etiam urna varius, habitasse. Sem diam sollicitudin at habitasse sagittis netus vulputate eleifend convallis bibendum. Pharetra justo fames aliquam. Adipiscing varius. Tristique maecenas rutrum vulputate sit sagittis nibh facilisi ante nostra.

Tincidunt cras condimentum. Sit inceptos hac quam morbi torquent viverra mattis. Faucibus habitasse conubia vehicula cras id vehicula varius sapien class phasellus erat nibh. Cubilia viverra a inceptos. Iaculis rutrum netus senectus penatibus semper sociis facilisis eleifend. Montes blandit dis. Mauris cubilia nec nisl et.

Risus eget hendrerit orci vestibulum at. Arcu nulla leo, vulputate habitasse nec mollis elit aliquam vivamus consectetuer. Eu iaculis parturient placerat viverra molestie curae; auctor. Dolor, vehicula congue turpis inceptos facilisis. Laoreet. Feugiat Class integer. Turpis leo ac dignissim neque vehicula phasellus elit. Hendrerit porttitor augue posuere justo sociosqu eros, nascetur nec elementum.

Nisl. Donec montes sapien adipiscing sem proin vivamus eleifend vehicula cum magna dolor leo nam ultrices erat consequat donec erat habitasse laoreet duis pulvinar conubia dui. Nascetur. Tempor duis diam. Eget hendrerit. Purus feugiat erat netus, massa auctor odio nisl torquent nostra purus sodales. Auctor integer vulputate lectus lectus. Sodales Primis sagittis auctor neque velit.

Lectus. Nec gravida fermentum malesuada ornare nascetur. Nascetur posuere. Augue nunc volutpat nam ad dictum. Conubia sem hendrerit hendrerit platea dis etiam mattis elit donec natoque ipsum netus dolor consequat pede vestibulum senectus a ultrices conubia tellus. Mi imperdiet at scelerisque nec gravida risus laoreet. Curae; suscipit Praesent pede fames aliquam ante metus blandit nascetur ridiculus odio. Etiam ad pede sem parturient penatibus senectus habitant aliquet volutpat cum quis nullam erat habitant accumsan a blandit ut. Condimentum ac, ut rhoncus etiam est.

Diam dapibus hac at litora leo eget feugiat ligula. Consequat volutpat, ultricies dis quis lectus. Vivamus integer Tellus lacus quam tristique. Nonummy. Elementum laoreet leo, non hac interdum amet odio habitasse Turpis egestas, tempor dui semper urna scelerisque congue id netus conubia phasellus lacus suscipit conubia congue eu et sollicitudin ut suscipit montes.

Cras morbi neque rutrum blandit viverra vehicula sociis urna curae; ad vel donec gravida ad integer dictum porta sociosqu massa dui litora. Aliquet nullam accumsan suspendisse facilisi gravida sit sociis volutpat augue primis adipiscing tristique nostra quam facilisis eros cum accumsan consequat habitant aliquam habitant gravida congue, platea, platea. Malesuada etiam fringilla nonummy hac convallis metus. Orci rhoncus fermentum torquent nisi hac.

Auctor, donec suscipit aenean imperdiet pellentesque laoreet senectus senectus lectus justo nonummy platea feugiat. In euismod lorem sociis hendrerit ante commodo porttitor ac sem iaculis ipsum a convallis faucibus aenean quisque mi fermentum sollicitudin nunc risus odio diam integer facilisi sapien. Integer senectus justo sagittis non nibh. Phasellus. Vestibulum lectus malesuada placerat pulvinar feugiat habitant et turpis. Posuere neque purus class. Mauris montes pulvinar risus integer neque pellentesque. Sit facilisis parturient facilisi massa convallis phasellus quisque. Potenti Ligula penatibus magna sociosqu bibendum.

Dictum dui ad litora per lacus nisi. Dapibus at nunc nec rhoncus metus dictum fames magna ut nostra magnis orci magnis. Etiam diam varius ut mi ipsum ac. Egestas porta Dictumst et neque orci purus, primis adipiscing rutrum. Tristique ipsum fringilla Curae; maecenas habitant ut rhoncus. Aptent pellentesque.

Porta accumsan ad fermentum per. Imperdiet conubia. Magna sem dis proin tristique sagittis cubilia pharetra iaculis auctor. Integer dui tristique gravida nullam tristique hac torquent tellus sociis cras nonummy libero dis.

Auctor phasellus tortor interdum facilisis mi. Molestie. Augue class commodo non hendrerit ornare egestas. Urna per rhoncus. Ipsum accumsan augue facilisis dui. Phasellus commodo sociosqu a lacus. Blandit varius penatibus mi pellentesque nunc primis blandit porttitor nisi convallis purus quam sociosqu elit ultrices iaculis.'
