.PHONY: all manifest dist deps doc sample tests

all: deps doc sample tests manifest

manifest:
	find . -type f | perl -pe 's/..//' > MANIFEST

dist: doc manifest META.yml
	H=`pwd`; \
	N=`perl -MYAML -e 'print((YAML::LoadFile("META.yml"))->{name})'`; \
	V=`perl -MYAML -e 'print((YAML::LoadFile("META.yml"))->{version})'`; \
	D="$${N}-$${V}"; \
	rm -fr "/tmp/$$D"; \
	cat MANIFEST | cpio -dump "/tmp/$$D"; \
	cd /tmp; tar czvf "$${D}.tar.gz" $$D; rm -r $$D; \
	cd $$H; mv "/tmp/$${D}.tar.gz" ./

deps:
	cp ../Test-Simple/lib/Test/Builder.js lib/Test/Builder.js
	cp ../Test-Simple/lib/Test/Harness.js lib/Test/Harness.js
	cp ../Test-Simple/lib/Test/Harness/Browser.js lib/Test/Harness/Browser.js

doc:
	make -C doc

sample:
	cp lib/Test/Base.js sample/run/lib/Test/Base.js
	cp lib/Test/Builder.js sample/run/lib/Test/Builder.js
	cp lib/Test/Harness.js sample/run/lib/Test/Harness.js
	cp lib/Test/Harness/Browser.js sample/run/lib/Test/Harness/Browser.js

tests:
	cp -r sample/run/ tests/run/
