ALL_JS = \
	 ../javascript/jquery-1.2.6.js \
	 javascript/separator.js \
	 javascript/noconflict.js \
	 javascript/separator.js \
	 Jemplate.js \
	 javascript/separator.js \
	 jemplates.js \
	 javascript/separator.js \
	 javascript/Cookie.js \
	 javascript/separator.js \
	 skins.js \
	 javascript/separator.js \
	 ../javascript/noJSAN.js \
	 ../javascript/DOM.Ready-0.14/lib/DOM/Ready.js \
	 ../javascript/DOM.Events-0.02/lib/DOM/Events.js \
	 ../javascript/Widget.Lightbox-0.06/lib/Widget/Lightbox.js \
	 javascript/separator.js \
	 javascript/select.js \

all: select.js

select.js: $(ALL_JS) Makefile
	cat $(ALL_JS) > $@

skins.js: ../.. bin/gen_skins_js.pl
	perl bin/gen_skins_js.pl > $@

Jemplate.js:
	jemplate --runtime > $@

jemplates.js: template/*
	jemplate --compile template > $@

