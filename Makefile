.PHONY: doc read

doc:
	v doc -f html -inline-assets -readme -o ./doc/html .

read:
	open doc/html/gui.html