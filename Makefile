.PHONY: run doc read

doc:
	v doc -m -f html -inline-assets -readme -o doc/html . gui

read:
	open doc/html/index.html