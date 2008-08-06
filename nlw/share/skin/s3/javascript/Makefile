.PHONY: all clean split-js

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
# MINIFY=cat

S3_FILE=socialtext-s3.js
S3_FILE_MINI=socialtext-s3-mini.js
S3_FILE_GZIP=$(S3_FILE).gz

EDITOR_FILE=socialtext-editor.js
EDITOR_FILE_MINI=socialtext-editor-mini.js
EDITOR_FILE_GZIP=$(EDITOR_FILE).gz

ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)
ALL_JEMPLATE_PLUGINS:=$(shell find $(S2_JAVASCRIPT)/JemplatePlugin -name \*.js)

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(COMMON_JAVASCRIPT)/Wikiwyg-2007-07-17

WIDGETS_YAML=Widgets.yaml
ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')
ALL_JEMPLATES=$(ALL_EDIT_JEMPLATES) jemplate/insert_widget_menu
JEMPLATE_GENERATOR=bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=Wikiwyg/Jemplate.js
JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js

LIGHTBOX_FILE=socialtext-lightbox.js
LIGHTBOX_FILE_MINI=socialtext-lightbox-mini.js
LIGHTBOX_FILE_GZIP=$(LIGHTBOX_FILE).gz
LIGHTBOX_JEMPLATE=jemplate/lightboxes.js
LIGHTBOX_TEMPLATES= \
		     template/comment_lightbox.tt2 \
		     template/email_lightbox.tt2 \
		     template/duplicate_lightbox.tt2 \
		     template/rename_lightbox.tt2 \
		     template/copy_lightbox.tt2 \

S3_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/jquery-1.2.6.js \
		$(S2_JAVASCRIPT)/loc.js \
		cookie.js \
		lightbox.js \
		s3.js \

LIGHTBOX_SOURCE_FILES= \
		Jemplate.js \
		$(ALL_JEMPLATE_PLUGINS) \
		$(LIGHTBOX_JEMPLATE) \
		comment.js \
		email.js \
		rename.js \

EDITOR_SOURCE_FILES= \
		$(S2_JAVASCRIPT)/main.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		$(COMMON_JAVASCRIPT)/TrimPath-template-1.0.38.js \
		$(COMMON_JAVASCRIPT)/DOM.Ready-0.14/lib/DOM/Ready.js \
		$(COMMON_JAVASCRIPT)/DOM.Events-0.02/lib/DOM/Events.js \
		$(S2_JAVASCRIPT)/md5.js \
		Jemplate.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		$(ALL_JEMPLATE_PLUGINS) \
		$(JEMPLATE_MODULE) \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Debug.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Toolbar.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Preview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wysiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/HTML.js \
		Wikiwyg/Socialtext.js \
		Widgets.js \
		Wikiwyg/Widgets.js \
		$(S2_JAVASCRIPT)/Wikiwyg/MessageCenter.js \
		$(S2_JAVASCRIPT)/Wikiwyg/Wikitext/Socialtext.js \
		$(S2_JAVASCRIPT)/Wikiwyg/DataValidator.js \
		wikiwyg.js \


all: \
    $(S3_FILE_GZIP) \
    $(EDITOR_FILE_GZIP) \
    $(LIGHTBOX_FILE_GZIP) \
    timestamp.js \
    Selection.htc \

clean:
	rm -f \
	    timestamp.js \
	    Jemplate.js \
	    Widgets.js \
	    $(JEMPLATE_MODULE) \
	    $(JEMPLATE_WIKIWYG_MODULE) \
	    $(LIGHTBOX_JEMPLATE) \
	    $(ALL_JEMPLATES) \
	    $(S3_FILE) \
	    $(S3_FILE_MINI) \
	    $(S3_FILE_GZIP) \
	    $(EDITOR_FILE) \
	    $(EDITOR_FILE_MINI) \
	    $(EDITOR_FILE_GZIP) \
	    $(LIGHTBOX_FILE) \
	    $(LIGHTBOX_FILE_MINI) \
	    $(LIGHTBOX_FILE_GZIP) \

.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

-mini.js.js.gz:
	gzip -c $< > $@

Jemplate.js:
	jemplate --runtime=jquery > $@

$(JEMPLATE_MODULE): jemplate $(ALL_JEMPLATES)
	jemplate --compile $< > $@

$(JEMPLATE_WIKIWYG_MODULE): jemplate_wikiwyg $(ALL_WIKIWYG_JEMPLATES)
	jemplate --compile $< > $@

$(LIGHTBOX_JEMPLATE): $(LIGHTBOX_TEMPLATES)
	jemplate --compile $(LIGHTBOX_TEMPLATES) > $(LIGHTBOX_JEMPLATE)

$(ALL_EDIT_JEMPLATES): $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_edit.tt2 jemplate/save-cancel.html
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_edit.tt2

jemplate/insert_widget_menu: $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_menu.tt2
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_menu.tt2

Widgets.js: $(WIDGETS_YAML)
	perl -MYAML -I../../../../lib -I../../../lib -MSocialtext::JSON -e 'print "Wikiwyg.Widgets =\n"; print encode_json(YAML::LoadFile(shift(@ARGV))); print ";\n"' \
		$< > $@

Selection.htc:
	cp -f $(WIKIWYG_PATH)/lib/Selection.htc $@

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

$(LIGHTBOX_FILE): $(LIGHTBOX_SOURCE_FILES) timestamp.js Makefile
	rm -f $@;
	for js in $(LIGHTBOX_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

timestamp.js: $(EDITOR_SOURCE_FILES) $(S3_SOURCE_FILES) $(LIGHTBOX_SOURCE_FILES)
	echo 'var Socialtext = Socialtext || {};' > $@
	perl -le 'print "Socialtext.make_time = \"" . time . "\";"' >> $@
