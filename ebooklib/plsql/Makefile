CFLAGS = -O2 -fomit-frame-pointer -W -Wall -Werror -I`pg_config --includedir-server`

.phony: all clean

all: is_valid_isbn.so is_valid_isbn

is_valid_isbn: is_valid_isbn.c
	$(CC) $(CFLAGS) -DTEST -DCHECK_VALID_DIGITS is_valid_isbn.c -o is_valid_isbn

is_valid_isbn.so: is_valid_isbn.c
	$(CC) $(CFLAGS) -shared is_valid_isbn.c -o is_valid_isbn.so

clean:
	rm is_valid_isbn is_valid_isbn.so
	
