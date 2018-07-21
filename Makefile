LIB := librestybaseencoding.so
SRC := $(wildcard *.c)
OBJ := $(SRC:.c=.o)
CFLAGS := -O3 -g -Wall -Wextra -Werror -fpic
LDFLAGS := -shared

all : $(LIB)

${OBJ} : %.o : %.c
	$(CC) $(CFLAGS) $(CEXTRAFLAGS) -c $<

${LIB} : ${OBJ}
	$(CC) $^ $(LDFLAGS) -o $@

modp_b85_gen: modp_b85_gen.o arraytoc.o

clean:
	rm -f $(LIB) modp_b85_gen *.o

test: $(LIB)
	prove -r t/
