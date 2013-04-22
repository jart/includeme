# includeme.el --- Automatic C/C++ '#include' and 'using' in Emacs
# Copyright (c) 2013 Justine Tunney

REFDATE ?= 20121202

README.md: make-readme-markdown.el includeme.el
	emacs --script $< <includeme.el >$@ 2>/dev/null
make-readme-markdown.el:
	wget -q -O $@ https://raw.github.com/mgalgs/make-readme-markdown/master/make-readme-markdown.el
.INTERMEDIATE: make-readme-markdown.el

index:
	python generate.py cppreference-doc-$(REFDATE)

fetch:
	wget -q http://upload.cppreference.com/mwiki/images/2/25/cppreference-doc-$(REFDATE).tar.gz
	tar -xzf cppreference-doc-$(REFDATE).tar.gz

dev: index README.md
