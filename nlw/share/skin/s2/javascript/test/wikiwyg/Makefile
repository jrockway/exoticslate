.PHONY: all all-stuff clean

ALL_T_HTML:=$(shell ls -1 t/*.t.js | perl -pe 's/js$$/html/;s/^t\///')
# ALL_T_JS := $(wildcard t/*t.js)
# ALL_T_HTML := $(T_JS:t/%.t.js=%.t.html)

ALL_TARGETS:=$(ALL_T_HTML) index.html

INCLUDE_PATH=template

all: all-stuff

include ../common/lib.mk

all-stuff: $(ALL_TARGETS) $(ALL_LIBS)

$(ALL_T_HTML): config.yaml $(INCLUDE_PATH)/*
	perl ../common/bin/render-template test.html $@ $(INCLUDE_PATH) > $@

index.html: t/*.t.js
	perl ../common/bin/render-template index.html $@ $(INCLUDE_PATH) > $@

clean::
	rm -fr $(ALL_TARGETS)

