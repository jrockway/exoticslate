.PHONY: all clean

ALL_T_HTML:=$(shell ls -1 t/*.t.js | perl -pe 's/js$$/html/;s/^t\///')
# ALL_T_JS := $(wildcard t/*t.js)
# ALL_T_HTML := $(T_JS:t/%.t.js=%.t.html)

ALL_TARGETS:=$(ALL_T_HTML) index.html

INCLUDE_PATH=template

all: $(ALL_TARGETS)
	@echo $(ALL_T_HTML)

$(ALL_T_HTML): config.yaml $(INCLUDE_PATH)/*
	perl bin/render-template test.html $@ $(INCLUDE_PATH) > $@

index.html: t/*.t.js
	perl bin/render-template index.html $@ $(INCLUDE_PATH) > $@

clean:
	rm -fr $(ALL_TARGETS)

html:
	mkdir html
