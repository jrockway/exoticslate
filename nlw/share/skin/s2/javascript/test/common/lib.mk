COMMON_SRC=../common

ALL_LIBS=\
	 lib/Test/Base.js \
	 lib/Test/Builder.js \
	 lib/Test/Harness.js \
	 lib/Test/Harness/Browser.js \

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

clean::
	rm -fr $(ALL_LIBS) lib/Test/Harness

