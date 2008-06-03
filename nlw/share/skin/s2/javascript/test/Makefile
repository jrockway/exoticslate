.PHONY: default runnable

default: $(EXTERNAL_JAVASCRIPT_SYMLINK) runnable

runnable: 
	make -C run all

force: clean runnable

clean:
	make -C run clean
