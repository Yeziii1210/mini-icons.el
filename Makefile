EMACS ?= emacs
NVIM ?= nvim
MINI_ICONS ?=

CORE = mini-icons-data.el mini-icons.el mini-icons-completion.el mini-icons-corfu.el

.PHONY: test compile generate clean

test:
	$(EMACS) -Q --batch -L . -l test/mini-icons-test.el -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile $(CORE)

generate:
	$(NVIM) --headless -u NONE -l scripts/generate.lua $(MINI_ICONS)

clean:
	rm -f *.elc test/*.elc
