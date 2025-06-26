.PHONY: doc read

doc:
	printf '\n' > nl
	mv README.md README.xx
	cat README.xx \
	        nl doc/01-Introduction.md \
	        nl doc/02-Getting-Started.md \
		nl doc/03-Views.md \
		nl doc/04-Rows-Columns.md \
		nl doc/05-Themes-Styles.md \
		nl doc/06-Fonts.md \
		> README.md
	v doc -f html -inline-assets -readme -o ./doc/html .
	mv README.xx README.md
	rm nl
	cp gui.png doc/html

read:
	open doc/html/gui.html