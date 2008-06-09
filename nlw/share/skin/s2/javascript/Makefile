.PHONY: all clean split-js

COMMON_JAVASCRIPT=../../common/javascript
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
# MINIFY=cat

DISPLAY_FILE=socialtext-display.js
DISPLAY_FILE_MINI=socialtext-display-mini.js
DISPLAY_FILE_GZIP=$(DISPLAY_FILE).gz

DISPLAY_UI_FILE=socialtext-display-ui.js
DISPLAY_UI_FILE_MINI=socialtext-display-ui-mini.js
DISPLAY_UI_FILE_GZIP=$(DISPLAY_UI_FILE).gz

OTHER_FILE=socialtext-other.js
OTHER_FILE_MINI=socialtext-other-mini.js
OTHER_FILE_GZIP=$(OTHER_FILE).gz

COMMENT_FILE=socialtext-comment.js
COMMENT_FILE_MINI=socialtext-comment-mini.js
COMMENT_FILE_GZIP=$(COMMENT_FILE).gz

STAX_FILE=socialtext-stax.js
STAX_FILE_MINI=socialtext-stax-mini.js
STAX_FILE_GZIP=$(STAX_FILE).gz

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(COMMON_JAVASCRIPT)/Wikiwyg-2007-07-17

JEMPLATE_GENERATOR=bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=Wikiwyg/Jemplate.js
JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js

WIDGETS_YAML=Widgets.yaml

ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')

ALL_JEMPLATES=$(ALL_EDIT_JEMPLATES) jemplate/insert_widget_menu

ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)

ALL_JEMPLATE_PLUGINS:=$(shell find JemplatePlugin -name \*.js)

DISPLAY_SOURCE_FILES= \
		timestamp.js \
		$(OTHER_DISPLAY_SOURCE_FILES) \

OTHER_DISPLAY_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/jquery-1.2.3.js \
		loc.js \
		bootstrap-ui.js \
		comment.js \
		Watchlist.js \

DISPLAY_UI_SOURCE_FILES= \
		main.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		$(COMMON_JAVASCRIPT)/TrimPath-template-1.0.38.js \
		$(COMMON_JAVASCRIPT)/DOM.Ready-0.14/lib/DOM/Ready.js \
		$(COMMON_JAVASCRIPT)/DOM.Events-0.02/lib/DOM/Events.js \
		$(COMMON_JAVASCRIPT)/Widget.Lightbox-0.06/lib/Widget/Lightbox.js \
		$(COMMON_JAVASCRIPT)/Widget.Lightbox-0.06/tests/lib/Effect/RoundedCorners.js \
		$(COMMON_JAVASCRIPT)/Widget.SortableTable-0.21/lib/Widget/SortableTable.js \
		hacks.js \
		Cookie.js \
		stlibrary.js \
		ArrayUtils.js \
		JSON-parse.js \
		pagetags.js \
		pageattachments.js \
		pageview.js \
		StTemplateField.js \
		tagqueue.js \
		Watchlist.js \
		comment.js \
		revisions.js \
		listview.js \
		LookaheadWidget.js \
		WorkspaceSupportLookahead.js \
		WorkspaceLookahead.js \
		PageNameLookahead.js \
		TagLookahead.js \
		WeblogLookahead.js \
		PageNameSupportLookahead.js \
		PageSectionLookahead.js \
		PageAttachmentLookahead.js \
        	settings.js \
		md5.js \
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
		Wikiwyg/MessageCenter.js \
		Widgets.js \
		Wikiwyg/Widgets.js \
		Wikiwyg/Wikitext/Socialtext.js \
		Wikiwyg/DataValidator.js \
		$(COMMON_JAVASCRIPT)/YAML-0.11/lib/YAML.js \
		Debug.js \
		ui-last-source.js

COMMENT_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/jquery-1.2.3.js \
		loc.js \
		bootstrap-ui.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		Browser.js \
		main.js \
		GuiEdit.js \
		comment_popup.js \
		email_page.js \

STAX_SOURCE_FILES= \
		stax-1.0.js \
		Jemplate.js \

OTHER_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/jquery-1.2.3.js \
		loc.js \
		bootstrap-ui.js \
		main.js \
		stlibrary.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		$(COMMON_JAVASCRIPT)/DOM.Ready-0.14/lib/DOM/Ready.js \
		$(COMMON_JAVASCRIPT)/DOM.Events-0.02/lib/DOM/Events.js \
		$(COMMON_JAVASCRIPT)/Widget.SortableTable-0.21/lib/Widget/SortableTable.js \
		pageview.js \
		Watchlist.js \
		listview.js \
        	settings.js \
		comment.js \

UNUSED_SOURCE_FILES= \
		$(COMMON_JAVASCRIPT)/WebToolkit-base64-2007-09-25.js \
		$(COMMON_JAVASCRIPT)/Ajax-0.11/lib/Ajax.js \

all: \
    	l10ns.js.gz \
	$(DISPLAY_FILE_GZIP) \
	$(DISPLAY_UI_FILE_GZIP) \
	$(COMMENT_FILE_GZIP) \
	$(STAX_FILE_GZIP) \
	$(OTHER_FILE_GZIP) \
	$(DISPLAY_FILE_MINI) \
	$(DISPLAY_UI_FILE_MINI) \
	$(COMMENT_FILE_MINI) \
	$(STAX_FILE_MINI) \
	$(OTHER_FILE_MINI) \
	Selection.htc \
	Cyberbit.ttf \

Cyberbit.ttf:
	cp /var/$@ $@

clean:
	rm -f \
		l10ns.js.gz \
		$(DISPLAY_FILE) \
		$(DISPLAY_UI_FILE) \
		$(COMMENT_FILE) \
		$(STAX_FILE) \
		$(OTHER_FILE) \
		$(DISPLAY_FILE_MINI) \
		$(DISPLAY_UI_FILE_MINI) \
		$(COMMENT_FILE_MINI) \
		$(STAX_FILE_MINI) \
		$(OTHER_FILE_MINI) \
		$(DISPLAY_FILE_GZIP) \
		$(DISPLAY_UI_FILE_GZIP) \
		$(COMMENT_FILE_GZIP) \
		$(STAX_FILE_GZIP) \
		$(OTHER_FILE_GZIP) \
		$(ALL_JEMPLATES) \
		Jemplate.js \
		$(JEMPLATE_MODULE) \
		$(JEMPLATE_WIKIWYG_MODULE) \
		Widgets.js \


.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

-mini.js.js.gz:
	gzip -c $< > $@

l10ns.js.gz: l10ns.js
	gzip -c $< > $@

$(DISPLAY_FILE): $(WIKIWYG_PATH) $(DISPLAY_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(DISPLAY_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(DISPLAY_UI_FILE): $(WIKIWYG_PATH) $(DISPLAY_UI_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(DISPLAY_UI_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(COMMENT_FILE): $(WIKIWYG_PATH) $(COMMENT_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(COMMENT_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(STAX_FILE): $(WIKIWYG_PATH) $(STAX_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(STAX_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(OTHER_FILE): $(WIKIWYG_PATH) $(OTHER_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(OTHER_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

Jemplate.js:
	jemplate --runtime > $@

$(JEMPLATE_MODULE): jemplate $(ALL_JEMPLATES)
	jemplate --compile $< > $@

$(JEMPLATE_WIKIWYG_MODULE): jemplate_wikiwyg $(ALL_WIKIWYG_JEMPLATES)
	jemplate --compile $< > $@

$(ALL_EDIT_JEMPLATES): $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_edit.tt2 jemplate/save-cancel.html
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_edit.tt2

jemplate/insert_widget_menu: $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_menu.tt2
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@ \
	    --template=widget_menu.tt2

Selection.htc:
	cp -f $(WIKIWYG_PATH)/lib/Selection.htc $@

Widgets.js: $(WIDGETS_YAML)
	perl -MYAML -I../../../../lib -MSocialtext::JSON -e 'print "Wikiwyg.Widgets =\n"; print encode_json(YAML::LoadFile(shift(@ARGV))); print ";\n"' \
		$< > $@

split-js:
	perl \
	-e 'my $$text = `cat $(DISPLAY_FILE) $(DISPLAY_UI_FILE) $(STAX_FILE) $(COMMENT_FILE) $(SOCIALCALC_FILE) $(OTHER_FILE)`;' \
	-e 'while($$text) {' \
	-e '    $$text =~ s/\/\/ BEGIN (.*?)\n(.*?)(?=\/\/ BEGIN |\z)//s' \
	-e '      or die "fubarred";' \
	-e '    open(OUT, "> $$1") or do {warn "Cannot open $$1 for output\n"; next};' \
	-e '    print OUT $$2;' \
	-e '    close OUT;' \
	-e '}'

WW:
	ln -fs $(WIKIWYG_PATH)/lib $@

timestamp.js: $(OTHER_DISIPLAY_SOURCE_FILES) $(DISPLAY_UI_SOURCE_FILES) $(STAX_SOURCE_FILES)
	perl -le 'print "Socialtext.make_time = \"" . time . "\";";' > $@

