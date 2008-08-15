.PHONY: all clean

COMMON_SRC=../common

ALL_T_HTML:=$(shell ls -1 t/*.t.js | perl -pe 's/js$$/html/;s/^t\///')
# ALL_T_JS := $(wildcard t/*t.js)
# ALL_T_HTML := $(T_JS:t/%.t.js=%.t.html)

ALL_TARGETS:=$(ALL_T_HTML) index.html
ALL_LIBS=\
	 lib/Test/Base.js \
	 lib/Test/Builder.js \
	 lib/Test/Harness.js \
	 lib/Test/Harness/Browser.js \

INCLUDE_PATH=template

all: $(ALL_TARGETS) $(ALL_LIBS)
	@echo $(ALL_T_HTML)

$(ALL_T_HTML): config.yaml $(INCLUDE_PATH)/*
	perl ../common/bin/render-template test.html $@ $(INCLUDE_PATH) > $@

index.html: t/*.t.js
	perl ../common/bin/render-template index.html $@ $(INCLUDE_PATH) > $@

lib/Test/Base.js:
	cp $(COMMON_SRC)/$@ $@

lib/Test/Builder.js:
	cp `js-cpan Test.Builder.js` $@

lib/Test/Harness.js:
	cp `js-cpan Test.Harness.js` $@

lib/Test/Harness/Browser.js: lib/Test/Harness
	cp `js-cpan Test.Harness.Browser.js` $@

lib/Test/Harness:
	mkdir -p $@

clean:
	rm -fr $(ALL_TARGETS) $(ALL_LIBS) lib/Test/Harness

html:
	mkdir html
