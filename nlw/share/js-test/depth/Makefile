.PHONY: default runnable

EXTERNAL_JAVASCRIPT_SYMLINK=../../js-modules

default: runnable

runnable: 
	make -C run all

force: clean runnable

clean:
	make -C run clean
