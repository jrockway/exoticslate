.PHONY: all clean

ALL_TARGETS:=TestSuite.html

ALL_TEST_FILES=$(shell ls tests/*.html)

all: $(ALL_TARGETS)

TestSuite.html: $(ALL_TEST_FILES)
	rm -f $@;
	perl bin/render-template TestSuite.html $@

clean:
	rm -fr $(ALL_TARGETS)
