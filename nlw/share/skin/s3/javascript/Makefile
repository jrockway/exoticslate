.PHONY: all clean split-js

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
MINIFY=cat

S3_FILE=socialtext-s3.js
S3_FILE_MINI=socialtext-s3-mini.js
S3_FILE_GZIP=$(S3_FILE).gz

EDITOR_FILE=socialtext-editor.js
EDITOR_FILE_MINI=socialtext-editor-mini.js
EDITOR_FILE_GZIP=$(EDITOR_FILE).gz

WIDGETS_YAML=$(S2_JAVASCRIPT)/Widgets.yaml
ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')
ALL_JEMPLATES=$(ALL_EDIT_JEMPLATES) jemplate/insert_widget_menu
ALL_WIKIWYG_JEMPLATES:=$(shell find $(S2_JAVASCRIPT)/jemplate_wikiwyg)
ALL_JEMPLATE_PLUGINS:=$(shell find $(S2_JAVASCRIPT)/JemplatePlugin -name \*.js)

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(COMMON_JAVASCRIPT)/Wikiwyg-2007-07-17

JEMPLATE_GENERATOR=$(S2_JAVASCRIPT)/bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=$(S2_JAVASCRIPT)/Wikiwyg/Jemplate.js
JEMPLATE_WIKIWYG_MODULE=$(S2_JAVASCRIPT)/jemplate_wikiwyg.js

ALL_WIKIWYG_JEMPLATES:=$(shell find $(S2_JAVASCRIPT)/jemplate_wikiwyg)

S3_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/jquery-1.2.3.js \
		$(S2_JAVASCRIPT)/loc.js \
		cookie.js \
		lightbox.js \
		s3.js \

EDITOR_SOURCE_FILES= \
		$(S2_JAVASCRIPT)/main.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		$(COMMON_JAVASCRIPT)/TrimPath-template-1.0.38.js \
		$(COMMON_JAVASCRIPT)/DOM.Ready-0.14/lib/DOM/Ready.js \
		$(COMMON_JAVASCRIPT)/DOM.Events-0.02/lib/DOM/Events.js \
		$(COMMON_JAVASCRIPT)/Widget.Lightbox-0.06/lib/Widget/Lightbox.js \
		$(COMMON_JAVASCRIPT)/Widget.Lightbox-0.06/tests/lib/Effect/RoundedCorners.js \
		$(S2_JAVASCRIPT)/Jemplate.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		$(ALL_JEMPLATE_PLUGINS) \
		$(JEMPLATE_MODULE) \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Debug.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Toolbar.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Preview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wysiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/HTML.js \
		wikiwyg.js \
		$(S2_JAVASCRIPT)/Wikiwyg/MessageCenter.js \
		$(S2_JAVASCRIPT)/Widgets.js \
		$(S2_JAVASCRIPT)/Wikiwyg/Widgets.js \
		$(S2_JAVASCRIPT)/Wikiwyg/Wikitext/Socialtext.js \
		$(S2_JAVASCRIPT)/Wikiwyg/DataValidator.js \
		$(S2_JAVASCRIPT)/ui-last-source.js \


all: $(S3_FILE_GZIP) $(EDITOR_FILE_GZIP) timestamp.js

clean:
	rm -f \
	    timestamp.js \
	    $(S3_FILE) \
	    $(S3_FILE_MINI) \
	    $(S3_FILE_GZIP) \
	    $(EDITOR_FILE) \
	    $(EDITOR_FILE_MINI) \
	    $(EDITOR_FILE_GZIP) \

.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

-mini.js.js.gz:
	gzip -c $< > $@

$(S3_FILE): $(S3_SOURCE_FILES) timestamp.js Makefile
	rm -f $@;
	for js in timestamp.js $(S3_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(EDITOR_FILE): $(EDITOR_SOURCE_FILES) timestamp.js Makefile
	rm -f $@;
	for js in $(EDITOR_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

timestamp.js: $(EDITOR_SOURCE_FILES) $(S3_SOURCE_FILES)
	echo 'var Socialtext = Socialtext || {};' > $@
	perl -le 'print "Socialtext.make_time = \"" . time . "\";"' >> $@
