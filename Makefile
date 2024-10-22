LIBS+=`pkg-config --libs lua5.3 libzip sdl2 SDL2_ttf SDL2_image`
CFLAGS+=`pkg-config --cflags lua5.3 libzip sdl2 SDL2_ttf SDL2_image`

OBJ=main.o lua_fns.o

bfeg: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS)

.PHONY: clean run example.bfe

example.bfe:
	rm -f example.bfe
	cd example && zip -r ../$@ *

clean:
	rm -rf bfeg $(OBJ) example.bfe

run: bfeg example.bfe
	./bfeg example.bfe