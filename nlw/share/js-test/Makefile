.PHONY: default runnable

EXTERNAL_JAVASCRIPT_SYMLINK=../js-modules

default: $(EXTERNAL_JAVASCRIPT_SYMLINK) runnable

runnable: 
	make -C run clean all

$(EXTERNAL_JAVASCRIPT_SYMLINK):
	ln -s ../../js-modules $@
