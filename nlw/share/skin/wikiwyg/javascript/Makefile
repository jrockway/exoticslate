.PHONY: all clean

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript

EDITOR_FILE=socialtext-editor.js
EDITOR_SOURCE_FILES= \
		$(S2_JAVASCRIPT)/main.js \
		$(S2_JAVASCRIPT)/md5.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		$(JEMPLATE_MODULE) \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Debug.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Toolbar.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Preview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wysiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/HTML.js \
		$(WIKIWYG_ST)/Wikiwyg/Socialtext.js \
		Widgets.js \
		$(WIKIWYG_ST)/Wikiwyg/Widgets.js \
		$(WIKIWYG_ST)/Wikiwyg/MessageCenter.js \
		$(WIKIWYG_ST)/Wikiwyg/Wikitext/Socialtext.js \
		$(S2_JAVASCRIPT)/Wikiwyg/DataValidator.js \
		wikiwyg.js \

JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js
ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)
ALL_JEMPLATE_PLUGINS:=$(shell find $(S2_JAVASCRIPT)/JemplatePlugin -name \*.js)

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(COMMON_JAVASCRIPT)/Wikiwyg-2007-07-17
WIKIWYG_ST=.

WIDGETS_YAML=$(WIKIWYG_ST)/Widgets.yaml
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

