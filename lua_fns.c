#include <stdio.h>
#include <stdbool.h>
#include <SDL_ttf.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <lauxlib.h>
#include "lua_fns.h"

static SDL_Renderer *ren;
static SDL_Window *win;
static zip_t *zip;
static TTF_Font *font = NULL;
static SDL_Cursor *cursor = NULL;
static Mix_Music *music = NULL;
static Mix_Music *music_q = NULL;

void quit(void)
{
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    IMG_Quit();
    TTF_Quit();
    Mix_CloseAudio();
    SDL_Quit();
    exit(0);
}

char *read_file(const char *filename, size_t *size)
{
    zip_file_t *f;
    if (!(f = zip_fopen(zip, filename, 0)))
    {
        fprintf(stderr, "Error opening \"%s\" from archive: %s\n", filename, zip_error_strerror(zip_get_error(zip)));
        return NULL;
    }

    zip_stat_t stat;
    if (zip_stat(zip, filename, 0, &stat))
    {
        fprintf(stderr, "Error stat'ing \"%s\" from archive: %s\n", filename, zip_error_strerror(zip_get_error(zip)));
        return NULL;
    }
    *size = stat.size;

    char *r = malloc(stat.size + 1);
    if (zip_fread(f, r, stat.size) == -1)
    {
        fprintf(stderr, "Error reading \"%s\" from archive: %s\n", filename, zip_error_strerror(zip_get_error(zip)));
        return NULL;
    }

    zip_fclose(f);
    return r;
}

static int l_read_file(lua_State *L)
{
    size_t size;
    char *x = read_file(lua_tostring(L, 1), &size);
    lua_pushlstring(L, x, size);
    return 1;
}

static SDL_Color hex2col(uint32_t x)
{
    return (SDL_Color){.r = x >> 24, .g = (x >> 16) & 0xff, .b = (x >> 8) & 0xff, .a = x & 0xff};
}

static int l_import(lua_State *L)
{
    size_t size;
    char *s = read_file(lua_tostring(L, 1), &size);
    if (!s)
    {
        lua_pushboolean(L, false);
        return 1;
    }
    s[size] = 0;
    if (luaL_dostring(L, s))
    {
        fprintf(stderr, "Error running \"%s\": %s\n", lua_tostring(L, 1), lua_tostring(L, -1));
        return -1;
    }
    free(s);
    lua_pushboolean(L, true);
    return 1;
}

static void handle_event(lua_State *L, SDL_Event *e)
{
    switch (e->type)
    {
        case SDL_QUIT:
            quit();
        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP:
            lua_getglobal(L, "handle_event");
            lua_pushinteger(L, e->type);
            lua_createtable(L, 0, 3);
            lua_pushstring(L, "x");
            lua_pushinteger(L, e->button.x);
            lua_settable(L, -3);
            lua_pushstring(L, "y");
            lua_pushinteger(L, e->button.y);
            lua_settable(L, -3);
            lua_pushstring(L, "button");
            lua_pushinteger(L, e->button.button);
            lua_settable(L, -3);
            lua_call(L, 2, 0);
            break;
        case SDL_MOUSEMOTION:
            lua_getglobal(L, "handle_event");
            lua_pushinteger(L, e->type);
            lua_createtable(L, 0, 2);
            lua_pushstring(L, "x");
            lua_pushinteger(L, e->motion.x);
            lua_settable(L, -3);
            lua_pushstring(L, "y");
            lua_pushinteger(L, e->motion.y);
            lua_settable(L, -3);
            lua_call(L, 2, 0);
            break;
    }
}

static int l_sleep(lua_State *L)
{
    SDL_Event e;
    int time = lua_tointeger(L, 1);
    while (time > 0)
    {
        int prev = SDL_GetTicks();
        if (SDL_WaitEventTimeout(&e, time)) handle_event(L, &e);
        int cur = SDL_GetTicks();
        time -= cur - prev;
    }
    return 0;
}

static int l_wait(lua_State *L)
{
    SDL_Event e;
    int r;
    if (lua_gettop(L) > 0) r = SDL_WaitEventTimeout(&e, lua_tointeger(L, 1));
    else r = SDL_WaitEvent(&e);
    if (r) handle_event(L, &e);
    return 0;
}

static int l_set_font(lua_State *L)
{
    size_t size;
    char *f = read_file(lua_tostring(L, 1), &size);
    if (!f)
    {
        fprintf(stderr, "Error loading font \"%s\"\n", lua_tostring(L, 1));
        lua_pushboolean(L, false);
        return 1;
    }

    if (font) TTF_CloseFont(font);

    SDL_RWops *rwfont = SDL_RWFromConstMem(f, size);
    font = TTF_OpenFontRW(rwfont, 1, lua_tointeger(L, 2));

    lua_pushboolean(L, true);
    return 1;
}

static bool getfield_into(lua_State *L, char *key, int *value)
{
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    bool r = lua_isinteger(L, -1);
    *value = lua_tointeger(L, -1);
    lua_pop(L, 1);
    return r;
}

static int getfield_int(lua_State *L, char *key)
{
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    int r = lua_tointeger(L, -1);
    lua_pop(L, 1);
    return r;
}

static const char *getfield_string(lua_State *L, char *key)
{
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    const char *r = lua_tostring(L, -1);
    lua_pop(L, 1);
    return r;
}

static void *getfield_userdata(lua_State *L, char *key)
{
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    void *r = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return r;
}

static int l_draw_text(lua_State *L)
{
    SDL_Color color = hex2col(getfield_int(L, "color"));
    SDL_Surface *s = TTF_RenderText_Blended(font, getfield_string(L, "text"), color);
    SDL_Texture *t = SDL_CreateTextureFromSurface(ren, s);
    SDL_RenderCopy(ren, t, NULL, &(SDL_Rect){.x = getfield_int(L, "x"), .y = getfield_int(L, "y"), .w = s->w, .h = s->h});
    SDL_FreeSurface(s);
    SDL_DestroyTexture(t);
    return 0;
}

static int l_draw_rect(lua_State *L)
{
    SDL_Color color = hex2col(getfield_int(L, "color"));
    SDL_SetRenderDrawColor(ren, color.r, color.g, color.b, color.a);
    SDL_RenderFillRect(ren, &(SDL_Rect){.x = getfield_int(L, "x"), .y = getfield_int(L, "y"), .w = getfield_int(L, "w"), .h = getfield_int(L, "h")});
    return 0;
}

static int l_load_image(lua_State *L)
{
    size_t size;
    char *p = read_file(lua_tostring(L, 1), &size);
    if (!p)
    {
        lua_pushnil(L);
        return 1;
    }

    SDL_RWops *rwimg = SDL_RWFromConstMem(p, size);
    SDL_Surface *img = IMG_Load_RW(rwimg, 1);
    SDL_Texture *t = SDL_CreateTextureFromSurface(ren, img);
    SDL_FreeSurface(img);

    SDL_Texture **x = lua_newuserdata(L, sizeof(SDL_Texture *));
    *x = t;
    luaL_getmetatable(L, "LuaBook.load_image");
    lua_setmetatable(L, -2);

    return 1;
}

static int l_texture_gc(lua_State *L)
{
    SDL_Texture *t = *(SDL_Texture **)lua_touserdata(L, 1);
    if (t) SDL_DestroyTexture(t);
    return 0;
}

static int l_render(lua_State *L)
{
    SDL_RenderPresent(ren);
    return 0;
}

static int l_draw_image(lua_State *L)
{
    SDL_Texture *t = *(SDL_Texture **)getfield_userdata(L, "img");
    int w, h;
    int srcx;
    int destw, desth;
    bool x;
    x = getfield_into(L, "srcx", &srcx);
    if (!getfield_into(L, "w", &w)) SDL_QueryTexture(t, NULL, NULL, &w, NULL);
    if (!getfield_into(L, "h", &h)) SDL_QueryTexture(t, NULL, NULL, NULL, &h);
    SDL_RenderCopyEx(ren, t, x ? &(SDL_Rect){.x = srcx, .y = getfield_int(L, "srcy"), .w = w, .h = h} : NULL, &(SDL_Rect){.x = getfield_int(L, "x"), .y = getfield_int(L, "y"), .w = getfield_into(L, "destw", &destw) ? destw : w, .h = getfield_into(L, "desth", &desth) ? desth : h}, getfield_int(L, "degrees"), NULL, getfield_int(L, "flip"));

    return 0;
}

static int l_ticks(lua_State *L)
{
    lua_pushinteger(L, SDL_GetTicks());
    return 1;
}

static int l_image_w(lua_State *L)
{
    SDL_Texture *t = *(SDL_Texture **)lua_touserdata(L, 1);
    int w;
    SDL_QueryTexture(t, NULL, NULL, &w, NULL);
    lua_pushinteger(L, w);
    return 1;
}

static int l_image_h(lua_State *L)
{
    SDL_Texture *t = *(SDL_Texture **)lua_touserdata(L, 1);
    int h;
    SDL_QueryTexture(t, NULL, NULL, NULL, &h);
    lua_pushinteger(L, h);
    return 1;
}

static int l_set_cursor(lua_State *L)
{
    if (cursor) SDL_FreeCursor(cursor);
    cursor = SDL_CreateSystemCursor(lua_tointeger(L, 1));
    SDL_SetCursor(cursor);
    return 0;
}

static Mix_Music *load_music(const char *filename)
{
    size_t size;
    char *p = read_file(filename, &size);
    if (!p) return NULL;
    SDL_RWops *rw = SDL_RWFromConstMem(p, size);
    return Mix_LoadMUS_RW(rw, 1);
}

static int l_play_music(lua_State *L)
{
    if (music) Mix_FreeMusic(music);
    music = load_music(lua_tostring(L, 1));
    if (!music) return 0;
    Mix_PlayMusic(music, lua_gettop(L) > 1 ? lua_tointeger(L, 2) : -1);
    return 0;
}

static void music_finished(void)
{
    if (music) Mix_FreeMusic(music);
    music = music_q;
    music_q = NULL;
    Mix_HookMusicFinished(NULL);
    Mix_PlayMusic(music, -1);
}

static int l_queue_music(lua_State *L)
{
    if (music_q) Mix_FreeMusic(music_q);
    music_q = load_music(lua_tostring(L, 1));
    if (!music_q) return 0;
    Mix_HookMusicFinished(music_finished);
    return 0;
}

static int l_stop_music(lua_State *L)
{
    Mix_HookMusicFinished(NULL);
    Mix_HaltMusic();
    return 0;
}

static int l_load_sound(lua_State *L)
{
    size_t size;
    char *p = read_file(lua_tostring(L, 1), &size);
    if (!p)
    {
        lua_pushnil(L);
        return 1;
    }

    SDL_RWops *rw = SDL_RWFromConstMem(p, size);
    Mix_Chunk *chunk = Mix_LoadWAV_RW(rw, 1);

    Mix_Chunk **x = lua_newuserdata(L, sizeof(Mix_Chunk *));
    *x = chunk;
    luaL_getmetatable(L, "LuaBook.load_sound");
    lua_setmetatable(L, -2);

    return 1;
}

static int l_chunk_gc(lua_State *L)
{
    Mix_Chunk *chunk = *(Mix_Chunk **)lua_touserdata(L, 1);
    if (chunk) Mix_FreeChunk(chunk);
    return 0;
}

static int l_play_sound(lua_State *L)
{
    lua_pushinteger(L, Mix_PlayChannel(-1, *(Mix_Chunk **)lua_touserdata(L, 1), lua_tointeger(L, 2)));
    return 1;
}

static int l_stop_sound(lua_State *L)
{
    Mix_HaltChannel(lua_tointeger(L, 1));
    return 0;
}

static int l_set_volume(lua_State *L)
{
    int v = lua_tointeger(L, 1);
    Mix_VolumeMusic(v);
    Mix_Volume(-1, v);
    return 0;
}

void def_lua_fns(lua_State *L, SDL_Renderer *r, SDL_Window *w, zip_t *z)
{
    ren = r;
    win = w;
    zip = z;
    lua_pushcfunction(L, l_import);
    lua_setglobal(L, "import");
    lua_pushcfunction(L, l_sleep);
    lua_setglobal(L, "sleep");
    lua_pushcfunction(L, l_wait);
    lua_setglobal(L, "wait");
    lua_pushcfunction(L, l_set_font);
    lua_setglobal(L, "set_font");
    lua_pushcfunction(L, l_draw_text);
    lua_setglobal(L, "draw_text");
    lua_pushcfunction(L, l_draw_rect);
    lua_setglobal(L, "draw_rect");
    lua_pushcfunction(L, l_read_file);
    lua_setglobal(L, "read_file");

    luaL_newmetatable(L, "LuaBook.load_image");
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, l_texture_gc);
    lua_settable(L, -3);

    lua_pushcfunction(L, l_load_image);
    lua_setglobal(L, "load_image");

    luaL_newmetatable(L, "LuaBook.load_sound");
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, l_chunk_gc);
    lua_settable(L, -3);

    lua_pushcfunction(L, l_load_sound);
    lua_setglobal(L, "load_sound");

    lua_pushcfunction(L, l_set_volume);
    lua_setglobal(L, "set_volume");
    lua_pushcfunction(L, l_play_sound);
    lua_setglobal(L, "play_sound");
    lua_pushcfunction(L, l_stop_sound);
    lua_setglobal(L, "stop_sound");

    lua_pushcfunction(L, l_play_music);
    lua_setglobal(L, "play_music");
    lua_pushcfunction(L, l_queue_music);
    lua_setglobal(L, "queue_music");
    lua_pushcfunction(L, l_stop_music);
    lua_setglobal(L, "stop_music");
    lua_pushcfunction(L, l_render);
    lua_setglobal(L, "render");
    lua_pushcfunction(L, l_draw_image);
    lua_setglobal(L, "draw_image");
    lua_pushcfunction(L, l_ticks);
    lua_setglobal(L, "ticks");
    lua_pushcfunction(L, l_image_w);
    lua_setglobal(L, "image_w");
    lua_pushcfunction(L, l_image_h);
    lua_setglobal(L, "image_h");

    lua_pushinteger(L, SDL_MOUSEBUTTONDOWN);
    lua_setglobal(L, "EVENT_MOUSEBUTTONDOWN");
    lua_pushinteger(L, SDL_MOUSEBUTTONUP);
    lua_setglobal(L, "EVENT_MOUSEBUTTONUP");
    lua_pushinteger(L, SDL_MOUSEMOTION);
    lua_setglobal(L, "EVENT_MOUSEMOTION");

    lua_pushcfunction(L, l_set_cursor);
    lua_setglobal(L, "set_system_cursor");
    lua_pushinteger(L, SDL_SYSTEM_CURSOR_ARROW);
    lua_setglobal(L, "CURSOR_ARROW");
    lua_pushinteger(L, SDL_SYSTEM_CURSOR_HAND);
    lua_setglobal(L, "CURSOR_HAND");
}