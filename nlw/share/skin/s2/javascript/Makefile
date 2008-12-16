.PHONY: all clean split-js

COMMON_JAVASCRIPT=../../common/javascript
S3_JAVASCRIPT=../../s3/javascript
WIKIWYG_ST=../../wikiwyg/javascript
WIKIWYG_PATH=../../wikiwyg/javascript
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

EDITOR_FILE=$(WIKIWYG_ST)/socialtext-editor.js
JEMPLATE_WIKIWYG_MODULE=jemplate_wikiwyg.js

ALL_WIKIWYG_JEMPLATES:=$(shell find jemplate_wikiwyg)

ALL_EDITOR_FILES:=$(shell find $(WIKIWYG_ST)/ -type f | grep -v editor.js)
ALL_JEMPLATE_PLUGINS:=$(shell find $(S3_JAVASCRIPT)/JemplatePlugin -name \*.js)

JQUERY=$(COMMON_JAVASCRIPT)/jquery-1.2.6.js \
       $(COMMON_JAVASCRIPT)/jquery-noConflict.js


DISPLAY_SOURCE_FILES= \
		timestamp.js \
		$(S3_JAVASCRIPT)/Debug.js \
		$(JQUERY) \
		$(S3_JAVASCRIPT)/jquery-patch.js \
		$(S3_JAVASCRIPT)/jquery-plugin.js \
 		$(S3_JAVASCRIPT)/lightbox.js \
		$(S3_JAVASCRIPT)/loc.js \
		bootstrap-ui.js \
		comment.js \
		Watchlist.js \

DISPLAY_UI_SOURCE_FILES= \
		main.js \
		$(COMMON_JAVASCRIPT)/prototype-1.4.0/dist/prototype.js \
		$(COMMON_JAVASCRIPT)/TrimPath-template-1.0.38.js \
		$(COMMON_JAVASCRIPT)/DOM.Ready-0.14/lib/DOM/Ready.js \
		$(COMMON_JAVASCRIPT)/DOM.Events-0.02/lib/DOM/Events.js \
		$(COMMON_JAVASCRIPT)/Widget.SortableTable-0.21/lib/Widget/SortableTable.js \
		hacks.js \
		Cookie.js \
		stlibrary.js \
		ArrayUtils.js \
		JSON.js \
		pagetags.js \
		pageattachments.js \
		pageview.js \
		StTemplateField.js \
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
		$(EDITOR_FILE) \
		$(S3_JAVASCRIPT)/lookahead.js \
		$(COMMON_JAVASCRIPT)/YAML-0.11/lib/YAML.js \
		ui-last-source.js \

COMMENT_SOURCE_FILES= \
		$(JQUERY) \
		$(S3_JAVASCRIPT)/loc.js \
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
		$(JQUERY) \
		$(S3_JAVASCRIPT)/loc.js \
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

realclean: clean
	make -C ../../wikiwyg/javascript clean

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
		Jemplate.js \
		$(JEMPLATE_WIKIWYG_MODULE) \
		Selection.htc \
		build-semaphore \
		timestamp.js \

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

$(EDITOR_FILE): $(ALL_EDITOR_FILES)
	make -C $(WIKIWYG_ST) all

Jemplate.js:
	jemplate --runtime=jquery > $@

$(JEMPLATE_WIKIWYG_MODULE): jemplate_wikiwyg $(ALL_WIKIWYG_JEMPLATES)
	jemplate --compile $< > $@

Selection.htc:
	cp -f $(WIKIWYG_PATH)/lib/Selection.htc $@

split-js:
	perl \
	-e 'my $$text = `cat $(DISPLAY_FILE) $(DISPLAY_UI_FILE) $(STAX_FILE) $(COMMENT_FILE) $(OTHER_FILE)`;' \
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

