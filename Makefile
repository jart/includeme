# includeme.el --- Automatic C/C++ '#include' and 'using' in Emacs
# Copyright (c) 2013 Justine Tunney

REFDATE ?= 20121202

all: includeme.elc includeme-index-c.elc includeme-index-cpp.elc

check: includeme.elc includeme-tests.elc
	emacs --batch -l ert -l includeme-tests -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc

includeme-index-c.el: index
includeme-index-cpp.el: index
index:
	python generate.py cppreference-doc-$(REFDATE)

fetch:
	wget -q http://upload.cppreference.com/mwiki/images/2/25/cppreference-doc-$(REFDATE).tar.gz
	tar -xzf cppreference-doc-$(REFDATE).tar.gz

README.md: make-readme-markdown.el
	emacs --script $< <includeme.el >$@ 2>/dev/null
make-readme-markdown.el:
	wget -q -O $@ https://raw.github.com/jart/make-readme-markdown/master/make-readme-markdown.el
.INTERMEDIATE: make-readme-markdown.el

%.elc: %.el
	emacs --batch --eval '(byte-compile-file "$<")'

.PHONY: index check clean README.md
