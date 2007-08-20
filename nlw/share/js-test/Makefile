.PHONY: default runnable

EXTERNAL_JAVASCRIPT_SYMLINK=../js-modules

default: $(EXTERNAL_JAVASCRIPT_SYMLINK) runnable

runnable: 
	make -C run all

force: clean runnable

clean:
	make -C run clean

$(EXTERNAL_JAVASCRIPT_SYMLINK):
	ln -s ../../js-modules $@
