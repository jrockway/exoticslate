.PHONY: all clean

SOURCE=pod/YAML.pod

all: html/YAML.html text/YAML.text

html/YAML.html: $(SOURCE) html
	pod2html $< > $@
	rm pod2htm*.tmp

text/YAML.text: $(SOURCE) text
	pod2text $< > $@

html text:
	mkdir -p $@

clean:
	rm -fr html text
