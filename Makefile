.PHONY: doc read

doc:
	v doc -m -f html -inline-assets -readme -o ./doc/html ./src/gui

read:
	open doc/html/index.html