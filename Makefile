# includeme.el --- Automatic C/C++ '#include' and 'using' in Emacs
# Copyright (c) 2013 Justine Tunney

REFDATE ?= 20121202

dev: index README.md

index:
	python generate.py cppreference-doc-$(REFDATE)

fetch:
	wget -q http://upload.cppreference.com/mwiki/images/2/25/cppreference-doc-$(REFDATE).tar.gz
	tar -xzf cppreference-doc-$(REFDATE).tar.gz

README.md: make-readme-markdown.el
	emacs --script $< <includeme.el >$@ 2>/dev/null
make-readme-markdown.el:
	wget -q -O $@ https://raw.github.com/mgalgs/make-readme-markdown/master/make-readme-markdown.el
.INTERMEDIATE: make-readme-markdown.el

.PHONY: index README.md
