.PHONY: default runnable

all: $(EXTERNAL_JAVASCRIPT_SYMLINK) runnable

runnable: 
	make -C run all

force: clean runnable

clean:
	make -C run clean
