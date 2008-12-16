.PHONY: all clean split-js

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript
S3_JAVASCRIPT=../../s3/javascript

EDITOR_FILE=socialtext-editor.js
EDITOR_SOURCE_FILES= \
		$(S2_JAVASCRIPT)/main.js \
		$(S2_JAVASCRIPT)/md5.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		$(JEMPLATE_MODULE) \
		lib/Wikiwyg.js \
		lib/Wikiwyg/Toolbar.js \
		lib/Wikiwyg/Preview.js \
		lib/Wikiwyg/Wysiwyg.js \
		lib/Wikiwyg/HTML.js \
		Wikiwyg/Socialtext.js \
		Widgets.js \
		Wikiwyg/Widgets.js \
		Wikiwyg/MessageCenter.js \
		Wikiwyg/Wikitext/Socialtext.js \
		Wikiwyg/DataValidator.js \
		wikiwyg.js \

JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js
ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)

WIDGETS_YAML=Widgets.yaml
ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')
ALL_JEMPLATES=$(ALL_EDIT_JEMPLATES) jemplate/insert_widget_menu
JEMPLATE_GENERATOR=bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=WikiwygJemplate.js

#-------------------------------------------------------------------------------
all: $(EDITOR_FILE)

clean:
	rm -f \
	    $(EDITOR_FILE) \
	    Widgets.js \
	    $(JEMPLATE_MODULE) \
	    $(JEMPLATE_WIKIWYG_MODULE) \
	    $(ALL_JEMPLATES) \

$(EDITOR_FILE): $(EDITOR_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(EDITOR_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(JEMPLATE_MODULE): jemplate $(ALL_JEMPLATES)
	jemplate --compile $< > $@

$(JEMPLATE_WIKIWYG_MODULE): jemplate_wikiwyg $(ALL_WIKIWYG_JEMPLATES)
	jemplate --compile $< > $@

$(ALL_EDIT_JEMPLATES): $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_edit.tt2
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_edit.tt2

jemplate/insert_widget_menu: $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_menu.tt2
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_menu.tt2

Widgets.js: $(WIDGETS_YAML)
	perl -MYAML -I../../../../lib -I../../../lib -MSocialtext::JSON -e 'print "Wikiwyg.Widgets =\n"; print encode_json(YAML::LoadFile(shift(@ARGV))); print ";\n"' \
		$< > $@

split-js:
	perl \
	-e 'my $$text = `cat $(EDITOR_FILE)`;' \
	-e 'while($$text) {' \
	-e '    $$text =~ s/\/\/ BEGIN (.*?)\n(.*?)(?=\/\/ BEGIN |\z)//s' \
	-e '      or die "fubarred";' \
	-e '    open(OUT, "> $$1") or do {warn "Cannot open $$1 for output\n"; next};' \
	-e '    print OUT $$2;' \
	-e '    close OUT;' \
	-e '}'

