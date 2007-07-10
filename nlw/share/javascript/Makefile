.PHONY: all clean split-js

COMBINED_FILE=combined-source.js
EXTERNAL_JAVASCRIPT=../../../js-modules

# WIKIWYG_REPOSITORY=http://svn.wikiwyg.net/code/trunk/wikiwyg
# WIKIWYG_CHECKOUT_VERSION=Wikiwyg-trunk
# WIKIWYG_CHECKOUT_PATH=$(EXTERNAL_JAVASCRIPT)/src/$(WIKIWYG_CHECKOUT_VERSION)
# WIKIWYG_CHECKOUT_COMMAND=svn checkout $(WIKIWYG_REPOSITORY) $(WIKIWYG_CHECKOUT_PATH)

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(EXTERNAL_JAVASCRIPT)/Wikiwyg-copy

JEMPLATE_GENERATOR=bin/generate-widget-jemplate.pl
JEMPLATE_MODULE=Wikiwyg/Jemplate.js
WIDGETS_YAML=Widgets.yaml

ALL_EDIT_JEMPLATES:=$(shell perl -MYAML -e 'my $$y = YAML::LoadFile("$(WIDGETS_YAML)"); my $$w = $$y->{widgets}; print join " ", map "jemplate/widget_$${_}_edit.html", @$$w')

ALL_JS_SOURCE_FILES= \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Debug.js \
		main.js \
		$(EXTERNAL_JAVASCRIPT)/prototype/dist/prototype.js \
		$(EXTERNAL_JAVASCRIPT)/Ajax/lib/Ajax.js \
		$(EXTERNAL_JAVASCRIPT)/template.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Ready/lib/DOM/Ready.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Events/lib/DOM/Events.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-SortableTable/lib/Widget/SortableTable.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-Lightbox/lib/Widget/Lightbox.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-Lightbox/tests/lib/Effect/RoundedCorners.js \
		hacks.js \
		md5.js \
		Cookie.js \
		ArrayUtils.js \
		stlibrary.js \
		Jemplate.js \
		JSON.js \
		$(JEMPLATE_MODULE) \
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
		startup.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Toolbar.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Preview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wikitext.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wysiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/HTML.js \
		Wikiwyg/Socialtext.js \
		Wikiwyg/MessageCenter.js \
		Widgets.js \
		Wikiwyg/Widgets.js \
		Wikiwyg/DataValidator.js \
		l10ns.js \

all: $(COMBINED_FILE) Selection.htc Cyberbit.ttf

Cyberbit.ttf:
	cp /var/$@ $@

clean:
	rm -f $(COMBINED_FILE)

$(COMBINED_FILE): $(WIKIWYG_PATH) $(ALL_JS_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(ALL_JS_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

Jemplate.js:
	jemplate --runtime > $@

$(JEMPLATE_MODULE): jemplate $(ALL_EDIT_JEMPLATES)
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
	-e 'my $$text = `cat $(COMBINED_FILE)`;' \
	-e 'while($$text) {' \
	-e '    $$text =~ s/\/\/ BEGIN (.*?)\n(.*?)(?=\/\/ BEGIN |\z)//s' \
	-e '      or die "fubarred";' \
	-e '    open(OUT, "> $$1") or do {warn "Cannot open $$1 for output\n"; next};' \
	-e '    print OUT $$2;' \
	-e '    close OUT;' \
	-e '}'

WW:
	ln -fs $(WIKIWYG_PATH)/lib $@
