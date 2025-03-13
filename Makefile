.PHONY: run doc read

run:
	v run .

doc:
	v doc -m -f html -inline-assets -readme -o doc/html . gui

read:
	open doc/html/index.html