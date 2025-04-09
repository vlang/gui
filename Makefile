.PHONY: run doc read

doc:
	v doc -f html -inline-assets -readme -o ../../../doc/html ./src/gui gui

read:
	open doc/html/index.html