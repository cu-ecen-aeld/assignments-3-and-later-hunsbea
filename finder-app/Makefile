CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -Wextra

all: writer

writer: writer.c
	$(CC) $(CFLAGS) -o writer writer.c

clean:
	rm -f writer *.o

.PHONY: all clean

