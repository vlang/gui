import gui

// System Font Example
// =============================

@[heap]
struct SystemFontApp {
pub mut:
	system            bool      = true
	system_font_theme gui.Theme = create_system_font_theme()
}

fn main() {
	mut window := gui.window(
		state:   &SystemFontApp{}
		width:   400
		height:  600
		on_init: fn (mut w gui.Window) {
			app := w.state[SystemFontApp]()
			w.set_theme(app.system_font_theme)
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SystemFontApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			theme_button(app),
			gui.text(
				text:       'Welcome to GUI'
				text_style: gui.theme().b1
			),
			gui.column(
				width:     w - gui.theme().padding_medium.width()
				id_scroll: 2
				id_focus:  2
				sizing:    gui.fixed_fill
				content:   [gui.text(text: story, mode: .wrap)]
			),
		]
	)
}

fn create_system_font_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_bordered_cfg
		text_style: gui.TextStyle{
			...gui.theme_dark_bordered_cfg.text_style
			family: ''
		}
	})
}

fn theme_button(app &SystemFontApp) gui.View {
	return gui.toggle(
		id_focus: 3
		select:   app.system
		label:    'System Font'
		on_click: fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[SystemFontApp]()
			app.system = !app.system
			w.set_theme(if app.system { app.system_font_theme } else { gui.theme_dark_bordered })
		}
	)
}

const story = "Fish and. Called it, earth great image, i set gathering blessed to of two every you'll and Their. Saw sea good. Called every and creeping have also. God cattle earth. Air thing subdue multiply of made land living bearing great. Our so yielding greater together whose third fly don't given bring creature. Seasons midst fowl Have man. Saw living signs. Air them signs. Very created. Of. She'd.

Firmament and in. Man. Green stars very. It dry created, said air day every fowl our their form which seed may land. He sea first yielding over abundantly set divided every let that doesn't hath place Let heaven subdue it to behold moving lesser a heaven. Likeness. So yielding moving bring lesser.

Behold waters our gathering moveth may kind saying itself shall fowl light i fruitful deep moved the seas don't you're be sea every face whales were the third seas replenish. Together moving. Deep evening a said winged Make heaven, replenish let green male likeness in multiply our, fruitful likeness and, fish replenish in evening Darkness life sea had was under Seed and blessed. Image creeping in sea they're male. First morning sixth rule fish spirit given, form grass night have you're You land so to gathering dry, fourth. From heaven.

Behold called let. You'll the green under void. Darkness living they're a she'd which. Face waters without given was first night can't rule upon. Thing likeness light multiply hath moveth. Thing meat together above unto blessed have. Abundantly beast lesser fly winged god saying beginning open Two together saw.

Two creepeth all spirit behold beginning bearing also. May very first behold sea she'd bearing deep abundantly given. Lesser whales. He itself replenish cattle second called life dominion together deep. Multiply upon over. Very heaven second god Cattle multiply God dry man divide their there. Fowl, moveth cattle itself fruitful beginning seed you let open dry give, lesser subdue. Fourth had land void beast, hath good. Face. Void likeness good darkness. You'll bring they're appear good appear light moved yielding itself don't man have let.

Created. ScrollAppear air fifth also is life had dry god set tree seasons, creepeth moving which to. You'll third over won't in creature. Years. Them subdue. Divided saying behold moving behold saw let. Bring. It light make life evening isn't, moved the let had meat which, were so she'd fly give beginning called, fruitful fruitful waters fish kind. Heaven.

And. Us Creepeth days spirit tree dominion signs appear made, kind. Shall to second give. God one. Heaven moveth shall above first set creepeth moveth firmament great blessed fish waters man. Don't good, isn't sixth upon every i said form land days. They're open morning morning without one moving Divide living made. Also have it very grass.

Winged above creeping herb herb days saw. The stars evening creature doesn't void days was after. Us doesn't divided cattle appear thing. Won't have. To. Sea face, creeping winged seasons bearing midst. Make be. You fruit first you'll man so waters for us lesser have won't. Fruitful land under every creepeth bring. Female Morning Lights. Replenish set seas face land.

Itself creepeth years don't his blessed sea earth kind A morning all fill she'd. Seas bring shall without darkness good male gathering appear. Them him yielding god creepeth for yielding were whales appear yielding above under you them image female our yielding darkness fruitful, seed cattle darkness cattle behold seasons darkness, tree saw brought that evening above dominion herb that. Said to. For, thing divide. First all called. Divided give heaven midst land. Our Bring wherein called us, rule place had."
