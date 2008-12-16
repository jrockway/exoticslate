.PHONY: all clean

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript
WIKIWYG_ST=../../wikiwyg/javascript
WIKIWYG_PATH=../../wikiwyg/javascript
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
#MINIFY=cat

S3_FILE=socialtext-s3.js
S3_FILE_MINI=socialtext-s3-mini.js
S3_FILE_GZIP=$(S3_FILE).gz

ST_EDITOR_FILE=$(WIKIWYG_ST)/socialtext-editor.js
EDITOR_FILE=socialtext-editor.js
EDITOR_FILE_MINI=socialtext-editor-mini.js
EDITOR_FILE_GZIP=socialtext-editor.js.gz

LIGHTBOX_FILE=socialtext-lightbox.js
LIGHTBOX_FILE_MINI=socialtext-lightbox-mini.js
LIGHTBOX_FILE_GZIP=$(LIGHTBOX_FILE).gz

LIGHTBOX_JEMPLATE=jemplateLightboxes.js
LIGHTBOX_TEMPLATES= \
		     template/comment_lightbox.tt2 \
		     template/email_lightbox.tt2 \
		     template/duplicate_lightbox.tt2 \
		     template/rename_lightbox.tt2 \
		     template/copy_lightbox.tt2 \
		     template/create_content_lightbox.tt2 \
		     template/attachment_lightbox.tt2 \

ALL_EDITOR_FILES:=$(shell find $(WIKIWYG_ST) $(COMMON_JAVASCRIPT) -type f | grep -v .svn | grep -v editor.js)
ALL_JEMPLATE_PLUGINS:=$(shell find JemplatePlugin -name \*.js)

S3_SOURCE_FILES= \
		timestamp.js \
		info.js \
		Debug.js \
		$(COMMON_JAVASCRIPT)/jquery-1.2.6.js \
		jquery-patch.js \
		jquery-plugin.js \
		jquery.tablesorter.js \
		Jemplate.js \
		$(ALL_JEMPLATE_PLUGINS) \
		loc.js \
		cookie.js \
		lookahead.js \
		pageview.js \
		email.js \
		s3.js \

LIGHTBOX_SOURCE_FILES= \
		lightbox.js \
		timestamp.js \
		$(LIGHTBOX_JEMPLATE) \
		comment.js \
		email-lightbox.js \
		move.js \
		create_content.js \
		pageattachments.js \

all: \
    timestamp.js \
    $(S3_FILE_GZIP) \
    $(EDITOR_FILE_GZIP) \
    $(LIGHTBOX_FILE_GZIP) \
    Selection.htc \

clean:
	rm -f \
	    info.js \
	    timestamp.js \
	    Jemplate.js \
	    $(JEMPLATE_MODULE) \
	    $(LIGHTBOX_JEMPLATE) \
	    $(S3_FILE) \
	    $(S3_FILE_MINI) \
	    $(S3_FILE_GZIP) \
	    $(EDITOR_FILE) \
	    $(EDITOR_FILE_MINI) \
	    $(EDITOR_FILE_GZIP) \
	    $(LIGHTBOX_FILE) \
	    $(LIGHTBOX_FILE_MINI) \
	    $(LIGHTBOX_FILE_GZIP) \
	    build-semaphore \
	    Selection.htc \

.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

$(EDITOR_FILE): $(LIGHTBOX_FILE) $(ST_EDITOR_FILE)
	rm -f $@;
	cat $(LIGHTBOX_FILE) $(ST_EDITOR_FILE) >> $@

$(EDITOR_FILE_MINI): $(EDITOR_FILE)
	$(MINIFY) $< > $@

-mini.js.js.gz:
	gzip -c $< > $@

Jemplate.js:
	jemplate --runtime=jquery > $@

$(LIGHTBOX_JEMPLATE): $(LIGHTBOX_TEMPLATES)
	jemplate --compile $(LIGHTBOX_TEMPLATES) > $(LIGHTBOX_JEMPLATE)

$(S3_FILE): $(S3_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(S3_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(ST_EDITOR_FILE): $(ALL_EDITOR_FILES)
	make -C $(WIKIWYG_ST) all

$(LIGHTBOX_FILE): $(LIGHTBOX_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(LIGHTBOX_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

info.js: ../info.yaml
	perl -MYAML -MTemplate -e \
	    'Template->new->process("template/$@", YAML::LoadFile("$<"))' > $@

timestamp.js: $(ST_EDITOR_FILE) $(S3_SOURCE_FILES:timestamp.js%=%) $(LIGHTBOX_SOURCE_FILES:timestamp.js%=%)
	echo 'var Socialtext = Socialtext || {};' > $@
	perl -le 'print "Socialtext.make_time = \"" . time . "\";"' >> $@

Selection.htc:
	cp -f $(WIKIWYG_PATH)/lib/Selection.htc $@

