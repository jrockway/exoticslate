.PHONY: all clean split-js
    dom.innerHTML = html;

EXTERNAL_JAVASCRIPT=../../../js-modules
MINIFY=perl -MJavaScript::Minifier -0777 -e 'print JavaScript::Minifier::minify(input => <>);'

DISPLAY_FILE=socialtext-display.js
DISPLAY_FILE_MINI=socialtext-display-mini.js
DISPLAY_FILE_GZIP=$(DISPLAY_FILE).gz

OTHER_FILE=socialtext-other.js
OTHER_FILE_MINI=socialtext-other-mini.js
OTHER_FILE_GZIP=$(OTHER_FILE).gz

EDIT_FILE=socialtext-edit-wikiwyg.js
EDIT_FILE_MINI=socialtext-edit-wikiwyg-mini.js
EDIT_FILE_GZIP=$(EDIT_FILE).gz

COMMENT_FILE=socialtext-comment.js
COMMENT_FILE_MINI=socialtext-comment-mini.js
COMMENT_FILE_GZIP=$(COMMENT_FILE).gz

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(EXTERNAL_JAVASCRIPT)/Wikiwyg-copy

JEMPLATE_GENERATOR=bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=Wikiwyg/Jemplate.js
JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js

WIDGETS_YAML=Widgets.yaml

ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')

ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)

DISPLAY_SOURCE_FILES= \
		jquery-1.2.1.pack.js \
		l10ns.js \
		main.js \
		$(EXTERNAL_JAVASCRIPT)/prototype/dist/prototype.js \
		$(EXTERNAL_JAVASCRIPT)/template.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Ready/lib/DOM/Ready.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Events/lib/DOM/Events.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-Lightbox/lib/Widget/Lightbox.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-Lightbox/tests/lib/Effect/RoundedCorners.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-SortableTable/lib/Widget/SortableTable.js \
		Jemplate.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		hacks.js \
		Cookie.js \
		ArrayUtils.js \
		stlibrary.js \
		JSON-parse.js \
		pagetags.js \
		pageattachments.js \
		pageview.js \
		attachqueue.js \
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
		startup.js \
		bootstrap-wikiwyg.js \

EDIT_SOURCE_FILES= \
		md5.js \
		JemplatePlugin/html_encode.js \
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
		Debug.js \

COMMENT_SOURCE_FILES= \
		jquery-1.2.1.pack.js \
		$(EXTERNAL_JAVASCRIPT)/prototype/dist/prototype.js \
		l10ns.js \
		Browser.js \
		main.js \
		GuiEdit.js \
		comment_popup.js \
		email_page.js \

OTHER_SOURCE_FILES= \
		jquery-1.2.1.pack.js \
		l10ns.js \
		main.js \
		$(EXTERNAL_JAVASCRIPT)/prototype/dist/prototype.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Ready/lib/DOM/Ready.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Events/lib/DOM/Events.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-SortableTable/lib/Widget/SortableTable.js \
		pageview.js \
		Watchlist.js \
		listview.js \
        	settings.js \
		comment.js \
		startup.js \

UNUSED_SOURCE_FILES= \
		$(EXTERNAL_JAVASCRIPT)/YAML/lib/YAML.js \
		$(EXTERNAL_JAVASCRIPT)/Base64.js \
		$(EXTERNAL_JAVASCRIPT)/Ajax/lib/Ajax.js \

all: \
	$(DISPLAY_FILE_GZIP) \
	$(EDIT_FILE_GZIP) \
	$(COMMENT_FILE_GZIP) \
	$(OTHER_FILE_GZIP) \
	Selection.htc \
	Cyberbit.ttf \

Cyberbit.ttf:
	cp /var/$@ $@

clean:
	rm -f \
		$(DISPLAY_FILE) \
		$(EDIT_FILE) \
		$(COMMENT_FILE) \
		$(OTHER_FILE) \
		$(DISPLAY_FILE_MINI) \
		$(EDIT_FILE_MINI) \
		$(COMMENT_FILE_MINI) \
		$(OTHER_FILE_MINI) \
		$(DISPLAY_FILE_GZIP) \
		$(EDIT_FILE_GZIP) \
		$(COMMENT_FILE_GZIP) \
		$(OTHER_FILE_GZIP) \

$(DISPLAY_FILE_MINI): $(DISPLAY_FILE)
	$(MINIFY) $< > $@
$(EDIT_FILE_MINI): $(EDIT_FILE)
	$(MINIFY) $< > $@
$(COMMENT_FILE_MINI): $(COMMENT_FILE)
	$(MINIFY) $< > $@
$(OTHER_FILE_MINI): $(OTHER_FILE)
	$(MINIFY) $< > $@

$(DISPLAY_FILE_GZIP): $(DISPLAY_FILE_MINI)
	gzip -c $< > $@
$(EDIT_FILE_GZIP): $(EDIT_FILE_MINI)
	gzip -c $< > $@
$(COMMENT_FILE_GZIP): $(COMMENT_FILE_MINI)
	gzip -c $< > $@
$(OTHER_FILE_GZIP): $(OTHER_FILE_MINI)
	gzip -c $< > $@



$(DISPLAY_FILE): $(WIKIWYG_PATH) $(DISPLAY_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(DISPLAY_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(EDIT_FILE): $(WIKIWYG_PATH) $(EDIT_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(EDIT_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(COMMENT_FILE): $(WIKIWYG_PATH) $(COMMENT_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(COMMENT_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(OTHER_FILE): $(WIKIWYG_PATH) $(OTHER_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(OTHER_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

Jemplate.js:
	jemplate --runtime > $@

$(JEMPLATE_MODULE): jemplate $(ALL_EDIT_JEMPLATES)
	jemplate --compile $< > $@

$(JEMPLATE_WIKIWYG_MODULE): jemplate_wikiwyg $(ALL_WIKIWYG_JEMPLATES)
	jemplate --compile $< > $@

$(ALL_EDIT_JEMPLATES): $(WIDGETS_YAML) $(JEMPLATE_GENERATOR) template/widget_edit.tt2 jemplate/save-cancel.html
	$(JEMPLATE_GENERATOR) --yaml=$< --output=$@

Selection.htc:
	ln -fs $(WIKIWYG_PATH)/lib/Selection.htc $@

Widgets.js: $(WIDGETS_YAML)
	perl -MYAML -MJSON -e 'print "Wikiwyg.Widgets =\n"; print objToJson(YAML::LoadFile(shift(@ARGV))); print ";\n"' \
		$< > $@

split-js:
	perl \
	-e 'my $$text = `cat $(DISPLAY_FILE) $(EDIT_FILE) $(COMMENT_FILE) $(OTHER_FILE)`;' \
	-e 'while($$text) {' \
	-e '    $$text =~ s/\/\/ BEGIN (.*?)\n(.*?)(?=\/\/ BEGIN |\z)//s' \
	-e '      or die "fubarred";' \
	-e '    open(OUT, "> $$1") or do {warn "Cannot open $$1 for output\n"; next};' \
	-e '    print OUT $$2;' \
	-e '    close OUT;' \
	-e '}'

WW:
	ln -fs $(WIKIWYG_PATH)/lib $@
