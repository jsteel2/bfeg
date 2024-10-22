#ifndef __LUA_FNS_H
#define __LUA_FNS_H

#include <lua.h>
#include <SDL.h>
#include <zip.h>

void quit(void);
char *read_file(const char *filename, size_t *size);
void def_lua_fns(lua_State *L, SDL_Renderer *r, SDL_Window *w, zip_t *z);

#endif