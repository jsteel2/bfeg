#include <stdio.h>
#include <stdlib.h>
#include <zip.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_image.h>
#include "lua_fns.h"

int main(int argc, char *argv[])
{
    if (argc < 2) return printf("Usage: %s <BFE Archive>\n", argv[0]);

    zip_t *z;
    int err;
    if (!(z = zip_open(argv[1], 0, &err)))
    {
        zip_error_t error;
        zip_error_init_with_code(&error, err);
        fprintf(stderr, "Error opening %s: %s\n", argv[1], zip_error_strerror(&error));
        return -1;
    }

    if (SDL_Init(SDL_INIT_EVERYTHING))
    {
        fprintf(stderr, "SDL_Init error: %s\n", SDL_GetError());
        return -1;
    }

    SDL_Window *win = SDL_CreateWindow("BFEG", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 496, 368, 0);
    if (!win)
    {
        fprintf(stderr, "SDL_CreateWin error: %s\n", SDL_GetError());
        return -1;
    }

    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!win)
    {
        fprintf(stderr, "SDL_CreateRenderer error: %s\n", SDL_GetError());
        SDL_DestroyWindow(win);
        SDL_Quit();
        return -1;
    }

    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);
    SDL_SetRenderDrawColor(ren, 0, 0, 0, 0);
    SDL_RenderClear(ren);

    TTF_Init();
    IMG_Init(IMG_INIT_PNG);

    lua_State *L = luaL_newstate();
    def_lua_fns(L, ren, win, z);
    luaL_requiref(L, "_G", luaopen_base, 1);
    lua_pop(L, 1);
    luaL_requiref(L, LUA_TABLIBNAME, luaopen_table, 1);
    lua_pop(L, 1);
    luaL_requiref(L, LUA_STRLIBNAME, luaopen_string, 1);
    lua_pop(L, 1);
    luaL_requiref(L, LUA_MATHLIBNAME, luaopen_math, 1);
    lua_pop(L, 1);

    size_t size;
    char *main_s = read_file("main.lua", &size);
    if (!main_s) return -1;
    main_s[size] = 0;

    if (luaL_dostring(L, main_s))
    {
        fprintf(stderr, "Error running main.lua: %s\n", lua_tostring(L, -1));
        return -1;
    }

    quit();
}