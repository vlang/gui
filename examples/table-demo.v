import gui

// Table Demo
// =============================
// Demonstrates buiding a table using declarative layout and from CSV.

@[heap]
struct TableDemoApp {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		title:   'Table Demo (WIP)'
		state:   &TableDemoApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[TableDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_none
		content: [
			gui.column(
				id_scroll: 1
				sizing:    gui.fill_fill
				content:   [
					gui.text(text: 'Declarative Layout', text_style: gui.theme().m2),
					// vfmt off
					gui.table(
						text_style_head: gui.theme().b2
						window: window
						data:   [
							gui.tr([gui.th('First'), gui.th('Last'),     gui.th('Email')]),
							gui.tr([gui.td('Matt'),  gui.td('Williams'), gui.td('non.egestas.a@protonmail.org')]),
							gui.tr([gui.td('Clara'), gui.td('Nelson'),   gui.td('mauris.sagittis@icloud.net')]),
							gui.tr([gui.td('Frank'), gui.td('Johnson'),  gui.td('ac.libero.nec@aol.com')]),
							gui.tr([gui.td('Elmer'), gui.td('Fudd'),     gui.td('mus@aol.couk')]),
							gui.tr([gui.td('Roy'),   gui.td('Rogers'),   gui.td('amet.ultricies@yahoo.com')]),
						]
					),
					gui.text(text: 'Using CSV Data', text_style: gui.theme().m2)
					gui.table_from_csv_string(csv_data, mut window) or {gui.View(gui.text(text: err.msg()))}
					// vfmt on
				]
			),
		]
	)
}

const csv_data = 'name,phone,email,address,postalZip,region
Keelie Snow,1-164-548-3178,erat.vivamus@icloud.net,Ap #414-702 Libero Avenue,698863,Chernivtsi oblast
Anthony Keith,1-918-510-5824,pulvinar.arcu@google.ca,Ap #358-7921 Placerat. Street,S4V 2M4,Leinster
Carissa Larson,1-646-772-7793,enim.gravida@aol.couk,"667-994 Mi, St.",1231,Sardegna
Joseph Herrera,1-746-758-0438,posuere@hotmail.couk,Ap #638-5604 Adipiscing Ave,51262,Pará
Nerea Romero,1-425-458-5525,pretium.neque@google.edu,990-4951 Mauris St.,46317,Junín
Macey Reed,1-175-242-2264,massa.quisque@hotmail.couk,1239 Arcu. Av.,WI1 8TR,Lai Châu
Craig Roach,1-541-688-6830,lorem.sit@hotmail.ca,385-9173 Libero. Rd.,07132,Newfoundland and Labrador
Yardley Barlow,1-648-862-5647,sodales@hotmail.couk,893-8994 Aliquet. St.,97-286,Lambayeque
Shad Whitfield,1-525-513-5416,augue.id.ante@protonmail.org,Ap #560-3609 Lorem Ave,70666,North Jeolla
Eugenia Bell,1-578-560-1252,laoreet.ipsum@icloud.edu,"P.O. Box 922, 5077 Sed Ave",28133,Kon Tum
Nash Hernandez,1-897-393-7624,convallis.convallis.dolor@google.couk,5853 Diam. Rd.,734884,Tasmania
Rinah Woods,1-698-796-5903,dui.nec.urna@icloud.ca,252-4094 Neque. Avenue,17571,Northern Territory
Jescie Beasley,1-264-555-2460,sapien.cursus@google.org,"873-7406 At, Rd.",44324,Gyeonggi
Jordan Harrison,1-627-442-6681,scelerisque.scelerisque@hotmail.net,696-2283 Turpis Rd.,3709,Umbria
Abdul Rowe,1-384-151-2787,ornare.fusce.mollis@hotmail.edu,"Ap #856-6933 Ut, St.",25878,Mississippi
Simone Bullock,1-623-422-9718,sed.facilisis@outlook.couk,2620 Mattis St.,49275,Luxemburg
Lillian Montgomery,1-317-854-9787,ut@outlook.couk,Ap #132-4005 Enim Ave,571928,Leinster
Tanisha Rodriquez,1-217-655-3165,id@aol.couk,"P.O. Box 490, 1311 Et, Road",45133,Chiapas
Alexandra Dyer,1-442-662-6576,amet.consectetuer.adipiscing@protonmail.edu,Ap #474-4869 Malesuada St.,613696,Rajasthan
Gretchen Carr,1-465-576-3555,eu.nibh@yahoo.org,Ap #617-6465 Nascetur Rd.,872532,São Paulo
Patience Cobb,1-833-211-2532,sed@hotmail.couk,1431 Pellentesque Street,644218,Paraná
Jaquelyn Carlson,1-774-851-3274,amet.dapibus@aol.ca,"Ap #529-8389 Lectus, Av.",5680-5371,Central Region
Britanney Silva,1-281-414-9085,nascetur.ridiculus.mus@google.ca,429-6408 Nec Rd.,6132,Vorarlberg
Brennan Hooper,1-534-697-7689,nunc.pulvinar.arcu@aol.edu,Ap #425-8524 Pellentesque. Ave,8834,Morayshire
Eliana Fry,1-822-880-5214,orci.luctus.et@protonmail.edu,351-931 Non St.,731577,Viken
Freya Logan,1-698-782-9483,sed.diam.lorem@icloud.org,"296-3763 Nostra, Avenue",688512,Huntingdonshire
Caldwell Wells,1-814-192-2358,neque.nullam@yahoo.couk,"P.O. Box 157, 7223 Posuere, Av.",571261,South Chungcheong
Marah Calderon,1-647-321-0141,rutrum.eu@protonmail.org,"499-1223 Ut, St.",612264,Murcia
Uriel Gordon,1-577-316-3275,nisi@google.ca,Ap #774-5408 Et Ave,301183,South Island
Dieter Klein,1-750-515-6663,fusce@aol.com,Ap #299-6720 Lectus St.,67865,Free State
Garrett Solomon,1-331-598-7814,elit.elit@icloud.ca,Ap #869-3615 Ut St.,25594,Imo
Kuame Hart,1-462-876-8531,augue@google.couk,"Ap #581-8713 A, Av.",74905,Rostov Oblast
Vivien Berger,1-323-460-9588,scelerisque.scelerisque.dui@outlook.net,1565 Volutpat. Street,14483,Donetsk oblast
Maisie Rosales,1-785-748-8889,quis@yahoo.net,313-2813 Quis Ave,4013 VR,Novgorod Oblast
Keiko Moore,1-435-489-8761,non.sapien@yahoo.edu,776-2940 Dictum St.,889547,New Brunswick
Meredith Frost,1-262-758-8871,pharetra.nibh.aliquam@yahoo.edu,Ap #374-3381 Semper St.,8479,Limousin
Kyle Nichols,1-267-464-1380,et.magnis@aol.edu,Ap #854-8316 Lorem St.,52640-135,Noord Holland
Hadley Britt,1-102-424-1828,aliquam.nec.enim@aol.ca,191-1321 Velit St.,951286,Languedoc-Roussillon
Lara Wolfe,1-854-679-3078,sed@yahoo.org,"609-3327 Et, Street",42726,Lambayeque
Quinlan Vincent,1-911-461-1411,lobortis.nisi@outlook.edu,7907 Quisque Av.,438732,Rivne oblast
Astra Kaufman,1-680-249-4128,eleifend@icloud.org,"712-2664 In, Av.",60635,South Island
Quemby Stevenson,1-636-235-5717,phasellus.fermentum@aol.couk,2004 Aenean Street,4783,Castilla y León
Philip Berg,1-734-512-5985,ac.eleifend.vitae@yahoo.edu,"P.O. Box 566, 3565 Tristique St.",04-607,Delhi
Amos Nguyen,1-437-884-0125,nascetur@outlook.couk,"P.O. Box 131, 5516 Sodales St.",46646,Sucre
Gray Hahn,1-171-791-7542,ullamcorper@icloud.edu,"P.O. Box 399, 4539 At Road",1442,North West
Isabella Padilla,1-624-616-1052,nunc.interdum.feugiat@google.net,Ap #346-2376 Nec Av.,41279-23758,Northwest Territories
Devin Hancock,1-284-651-6434,orci.lacus@hotmail.net,596-1295 Nunc Av.,8269,Los Lagos
Declan Fisher,1-885-849-9482,nunc.commodo@outlook.ca,"P.O. Box 134, 9767 Mauris Street",2377,North-East Region
Karyn Tyson,1-863-251-5182,integer.vulputate@google.edu,Ap #611-9699 Cubilia Road,4282,Chihuahua
Candice Fitzpatrick,1-252-786-4106,eu.ultrices@protonmail.net,"P.O. Box 600, 4905 Libero. St.",7168,Long An
Cleo Farley,1-549-565-0235,suspendisse.aliquet.molestie@yahoo.edu,628-6146 Mauris Av.,5557,Friuli-Venezia Giulia
Axel Le,1-311-672-3634,vitae@aol.ca,3792 Amet St.,NE2 1HD,Nunavut
Shaine Reed,1-508-687-9353,odio.nam@outlook.com,"P.O. Box 365, 4955 Mauris Road",06354,Coquimbo
Caleb Butler,1-316-232-0744,enim.sit@hotmail.ca,"485-8554 Lacus, Av.",19221,Ceará
Colette French,1-210-596-3746,egestas.lacinia@protonmail.net,5544 Diam. Ave,01622,Île-de-France
Armand Swanson,1-943-176-2771,ultrices.duis@aol.edu,Ap #855-5154 Cras Rd.,3266 BB,Vestland
Mikayla Pruitt,1-311-632-7069,felis@hotmail.edu,"897-4681 Felis, Street",612444,South Chungcheong
Quentin Sanchez,1-260-342-1476,aliquet.phasellus.fermentum@outlook.edu,Ap #573-8573 Vivamus Avenue,23432,Poitou-Charentes
Uta Eaton,1-905-351-4299,quam.quis.diam@outlook.edu,1647 Lobortis. Rd.,4252,Bursa
Glenna Ruiz,1-458-433-8223,sem.egestas@hotmail.com,471 Ipsum Rd.,6979,Provence-Alpes-Côte d\'Azur
Sophia Ingram,1-825-268-3684,curabitur.egestas@outlook.ca,Ap #740-7943 Magnis Ave,323643,Vestland
Libby Emerson,1-590-455-8061,odio.sagittis.semper@icloud.ca,Ap #967-752 Nunc Av.,1658,Mazowieckie
Benjamin Black,1-203-685-7832,vel.est@hotmail.net,Ap #256-8712 Id Avenue,745455,Balochistan
Ryan Perkins,1-586-569-6001,sem.magna@outlook.ca,Ap #974-2432 A St.,644338,Quảng Nam
Maxine Short,1-422-821-0765,lobortis.nisi.nibh@google.org,837 Erat Avenue,34837989,Illinois
Colby Reed,1-278-666-2098,non.lacinia.at@outlook.net,"P.O. Box 310, 6790 Urna. St.",V56 3IB,Ivanovo Oblast
Reece Cote,1-457-694-3535,purus.ac@google.edu,"P.O. Box 950, 5934 Purus, Road",24735,Central Luzon
Lev Vaughn,1-494-539-7026,nulla@aol.net,483 Malesuada Road,5051,Prince Edward Island
Jared Gaines,1-518-267-2955,ac.mattis@protonmail.couk,"P.O. Box 853, 2806 Gravida Ave",65041,Gävleborgs län
Hop White,1-171-531-1847,mauris.magna.duis@aol.com,Ap #178-3762 Nulla Avenue,6230,Dōngběi
Remedios Dodson,1-523-817-0838,egestas.aliquam@outlook.org,4862 Molestie Street,27-364,Special Region of Yogyakarta
Cathleen Webster,1-952-989-8328,curabitur.massa.vestibulum@aol.couk,696-3058 Cras Street,6448,Brussels Hoofdstedelijk Gewest
Kiona Gonzalez,1-238-312-2295,risus.donec@yahoo.couk,"P.O. Box 279, 2707 Curabitur St.",88154,Uttarakhand
Upton Fischer,1-863-727-8275,malesuada.id.erat@aol.edu,Ap #142-4350 Mi Av.,37741,Tamaulipas
Arsenio Peters,1-381-644-7826,ligula.elit@yahoo.org,294-5875 Conubia St.,687519,Northern Cape
Clementine Farrell,1-863-702-6662,porttitor.eros@outlook.edu,476-5878 Donec Road,5646,Bicol Region
Thor Cole,1-764-316-8654,proin.vel@protonmail.net,Ap #138-9025 Cursus Street,8431,Anglesey
Preston Mclean,1-172-436-6222,iaculis.odio@hotmail.couk,Ap #259-5053 Vitae Ave,34349,Balochistan
Iola Gallegos,1-610-991-4420,vestibulum@aol.org,332-2801 Nullam Rd.,2896 BA,Magallanes y Antártica Chilena
Madeline Mcmahon,1-400-783-9623,duis.mi.enim@google.org,222-2746 Risus Rd.,8615,Cantabria
Leilani Jackson,1-242-618-7672,eget@protonmail.couk,"P.O. Box 435, 6180 Euismod Rd.",9516,Lviv oblast
Jason Mooney,1-771-383-6928,faucibus.lectus@yahoo.edu,Ap #286-5338 Mi Ave,573227,Liguria
Quail Stokes,1-666-644-4305,fermentum@protonmail.org,"Ap #778-8922 Et, St.",68-48,Huáběi
Marah Albert,1-773-249-9181,penatibus.et@icloud.com,Ap #326-8272 Ornare Rd.,16734,Mpumalanga
Otto George,1-575-868-3121,phasellus.in.felis@google.net,"P.O. Box 820, 1915 Consectetuer, St.",09324,Ogun
Clinton Fernandez,1-763-518-8817,vestibulum.accumsan.neque@protonmail.ca,Ap #321-3540 Curabitur Rd.,6215,Wielkopolskie
Mufutau Michael,1-420-651-7181,amet.consectetuer@icloud.com,463-1544 Sagittis Rd.,28240,South Island
Cherokee Duncan,1-707-895-6308,velit.quisque@aol.edu,Ap #693-8795 Libero. Rd.,53-94,Trentino-Alto Adige
Jasmine Rosales,1-424-165-8181,enim.condimentum.eget@yahoo.ca,425-9816 Et Street,65357-493,Ceuta
Francesca Stanton,1-835-721-1914,porta.elit@aol.org,Ap #160-5171 Ipsum. Rd.,47935,Leinster
Edan Joseph,1-387-561-4772,velit.sed@protonmail.com,Ap #477-6242 Amet Rd.,1117,Nordrhein-Westphalen
Ulla Noble,1-518-771-8772,pellentesque.a@protonmail.org,"P.O. Box 317, 3480 Phasellus Av.",633261,Aydın
Cally Larsen,1-937-148-7860,nibh@aol.org,"P.O. Box 671, 7795 Risus. Road",7654,Akwa Ibom
Kermit Murphy,1-646-652-7266,augue.sed@icloud.com,658-9836 Augue Ave,4299 CR,Hessen
Timon Mosley,1-629-488-3644,cubilia.curae@protonmail.couk,"934-9580 Posuere, Rd.",32846-00463,Kursk Oblast
Lucy Hansen,1-320-875-7143,sem.semper.erat@outlook.edu,"P.O. Box 601, 8529 Eget Ave",89640,Oslo
Akeem Yang,1-344-529-2287,sit@yahoo.net,140-5735 Ligula. Road,70771,Cà Mau
Fatima Hickman,1-730-621-1323,nam@icloud.net,773-7014 Dolor Av.,5434,Bayern
Hamilton Guthrie,1-228-786-1214,curabitur.ut.odio@google.org,718-6453 Enim. Road,7676 VC,Hessen
Lester Haynes,1-498-681-7938,cursus.non.egestas@icloud.couk,Ap #274-9826 Dui. Road,328428,Namen
'
