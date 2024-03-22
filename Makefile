DIRS = curses-dummy linux misc posix ubase unix

all: $(DIRS)

$(DIRS): FORCE
	@+cd $@ && $(MAKE)

clean:
	for i in `ls -d */`; \
	do\
		cd $$i;\
		$(MAKE) clean;\
		cd -;\
	done
