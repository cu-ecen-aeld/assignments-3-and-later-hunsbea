CC := gcc
CFLAGS := -Wall -Wextra

ifdef CROSS_COMPILE
	CC := $(CROSS_COMPILE)gcc
endif

all: writer

writer: writer.c
	$(CC) $(CFLAGS) -o writer writer.c

clean:
	rm -f writer *.o

.PHONY: all clean

