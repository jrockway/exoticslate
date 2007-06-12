.PHONY: all clean split-js

COMBINED_FILE=combined-source.js
EXTERNAL_JAVASCRIPT=../../../js-modules

WIKIWYG_REPOSITORY=http://svn.wikiwyg.net/code/trunk/wikiwyg
WIKIWYG_CHECKOUT_VERSION=Wikiwyg-trunk
WIKIWYG_CHECKOUT_PATH=$(EXTERNAL_JAVASCRIPT)/src/$(WIKIWYG_CHECKOUT_VERSION)
WIKIWYG_CHECKOUT_COMMAND=svn co $(WIKIWYG_REPOSITORY) $(WIKIWYG_CHECKOUT_PATH)

# Use Wikiwyg-dev when developing Wikiwyg
WIKIWYG_PATH=$(EXTERNAL_JAVASCRIPT)/src/Wikiwyg-09-26-06
# WIKIWYG_PATH=$(EXTERNAL_JAVASCRIPT)/Wikiwyg-dev

ALL_JS_SOURCE_FILES= \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Debug.js \
		main.js \
		$(EXTERNAL_JAVASCRIPT)/prototype/dist/prototype.js \
		$(EXTERNAL_JAVASCRIPT)/Ajax/lib/Ajax.js \
		$(EXTERNAL_JAVASCRIPT)/template.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Ready/lib/DOM/Ready.js \
		$(EXTERNAL_JAVASCRIPT)/DOM-Events/lib/DOM/Events.js \
		$(EXTERNAL_JAVASCRIPT)/Widget-SortableTable/lib/Widget/SortableTable.js \
		JSON.js \
		Cookie.js \
		ArrayUtils.js \
		stlibrary.js \
		Lightbox.js \
		pageview.js \
		attachqueue.js \
		StTemplateField.js \
		tagqueue.js \
		Watchlist.js \
		comment.js \
		revisions.js \
		listview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Toolbar.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Preview.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wikitext.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/Wysiwyg.js \
		$(WIKIWYG_PATH)/lib/Wikiwyg/HTML.js \
		Wikiwyg/Socialtext.js \
		Wikiwyg/MessageCenter.js \
		Wikiwyg/DataValidator.js \
		l10ns.js \

all: $(COMBINED_FILE) Selection.htc

clean:
	rm -f $(COMBINED_FILE)

$(COMBINED_FILE): $(WIKIWYG_PATH) $(ALL_JS_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(ALL_JS_SOURCE_FILES); do       \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

# $(WIKIWYG_PATH): $(WIKIWYG_CHECKOUT_PATH)
#	ln -s src/$(WIKIWYG_CHECKOUT_VERSION) $@

$(WIKIWYG_CHECKOUT_PATH):
	$(WIKIWYG_CHECKOUT_COMMAND)

$(JEMPLATE_MODULE): $(ALL_JEMPLATES)
	@make -C jemplate

Selection.htc:
	ln -s $(WIKIWYG_PATH)/lib/Selection.htc $@

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
	ln -s $(WIKIWYG_PATH)/lib $@
