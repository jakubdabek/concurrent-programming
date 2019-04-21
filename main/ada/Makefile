all: main

main: src/*
	gnatmake -D obj/ src/main.adb

clean:
	$(RM) obj/* main

.PHONY: all clean
