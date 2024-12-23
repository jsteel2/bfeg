set_font("bfed.ttf", 16)

scene = {
    sprites = {},
    clickables = {}
}

function inventory_init(...)
    inventory = {}
    for _, v in ipairs{...} do
        inventory[v.name] = {got = false, has = false, image=v.image, desc=v.desc}
    end
end

day = 1
form_unknown = load_image("form-unknown.png")
form_earth = load_image("form-earth.png")
form_unicorn = load_image("form-unicorn.png")
form_pegasus = load_image("form-pegasus.png")
form = form_unknown

local global_id = 1
local callbacks = {}
local mouse = {
    x = 0,
    y = 0,
    cursor = CURSOR_ARROW
}

local sys_cursor = CURSOR_ARROW
function update_cursor()
    if mouse.cursor ~= sys_cursor then
        set_system_cursor(mouse.cursor)
        sys_cursor = mouse.cursor
    end
end

function handle_event(ev, data)
    if ev == EVENT_MOUSEMOTION then
        mouse.x = data.x
        mouse.y = data.y
        scene.hovering = false
    end
    if not callbacks[ev] then return end
    local r = {}
    for i, v in ipairs(callbacks[ev]) do
        if v.remove then r[#r + 1] = i end
    end
    for i, v in ipairs(r) do
        table.remove(callbacks[ev], v - i + 1)
    end
    for _, v in ipairs(callbacks[ev]) do
        if v.fn(data) then break end
    end
    update_cursor()
end

function set_cursor(cursor)
    mouse.cursor = cursor
end

function present()
    update_cursor()
    render()
end

function add_event_callback(ev, fn, z)
    if not callbacks[ev] then callbacks[ev] = {{fn=fn, id=global_id, z=z}}
    else callbacks[ev][#callbacks[ev] + 1] = {fn=fn, id=global_id, z=z}
    end
    table.sort(callbacks[ev], function(l, r) return l.z > r.z end)
    global_id = global_id + 1
    return global_id - 1
end

local scene_changed = false
function scene_add_sprite(v)
    if not v.z then v.z = 2 end
    if v.clear == nil then v.clear = true end
    local x = {
        fn = v.fn,
        clear = v.clear,
        z = v.z,
        id = global_id,
        v = v.v
    }
    scene.sprites[#scene.sprites + 1] = x 
    table.sort(scene.sprites, function(l, r) return l.z < r.z end)
    global_id = global_id + 1
    scene_changed = true
    return x
end

function scene_remove_sprite(s)
    for i, x in ipairs(scene.sprites) do  
        if s.id == x.id then
            scene.sprites[i].remove = true
            scene_changed = true
            return
        end
    end
end

function remove_event_callback(id)
    for i, x in pairs(callbacks) do
        for j, y in ipairs(x) do
            if id == y.id then
                x[j].remove = true
                if #x == 0 then callbacks[i] = nil end
                return
            end
        end
    end
end

function scene_add_animation(v)
    local start_frame = v.start_frame or 1
    local cur_frame = start_frame
    local anim_size = v.row_width or v.anim_size or v.sheet_size
    local rows = v.rows or 1
    local w = image_w(v.sheet)
    v.w = image_w(v.sheet) // (v.row_width or v.sheet_size)
    v.h = image_h(v.sheet) // rows
    local function draw(x)
        local a = {img=v.sheet, x=v.x, y=v.y, srcx=((cur_frame - start_frame) % anim_size * v.w) % w, srcy=((cur_frame - start_frame) % (v.anim_size or v.sheet_size) * v.w) // w * v.h, w=v.w, h=v.h}
        if x then
            for k, v in pairs(x) do a[k] = v end
        end
        draw_image(a)
    end
    local anim_next_tick = nil
    return scene_add_sprite{fn=function(next)
        local r = 1000 / v.fps
        if anim_next_tick and ticks() >= anim_next_tick then
            if not v.frames[cur_frame] then scene.playing = false
            else cur_frame = v.frames[cur_frame]
            end
            if type(cur_frame) == "table" then
                r = cur_frame[1]
                cur_frame = cur_frame[2]
            end
            if type(cur_frame) == "function" then
                cur_frame = cur_frame()
            end
            anim_next_tick = ticks() + r
        end
        if not anim_next_tick then
            if type(cur_frame) == "table" then
                r = cur_frame[1]
                cur_frame = cur_frame[2]
                start_frame = cur_frame
            end
            anim_next_tick = ticks() + r
        end
        local r2 = r
        if v.fn then r2 = v.fn(next, draw, v) or r else draw() end
        return r2
    end, table.unpack(v)}
end

function scene_add_image(v)
    local s
    s = scene_add_sprite{fn=function(next)
        draw_image(s.v)
    end, z=v.z, clear=v.clear, v=v}
    return s
end

local bg = nil
function scene_set_background(image)
    if bg then scene_remove_sprite(bg) end
    bg = scene_add_image{img=image, x=0, y=0, z=1, clear=false}
end

function scene_add_clickable_area(v)
    if not v.z then v.z = 2 end
    if mouse.x >= v.x and mouse.y >= v.y and mouse.x <= v.x + v.w and mouse.y <= v.y + v.h then
        set_cursor(CURSOR_HAND)
    end
    local toggle = false
    local function mouse_event(ev)
        if ev.x >= v.x and ev.y >= v.y and ev.x <= v.x + v.w and ev.y <= v.y + v.h then
            set_cursor(CURSOR_HAND)
            scene.hovering = true
            if v.hover and not toggle then v.hover(true) end
            toggle = true
        else
            if not scene.hovering then set_cursor(CURSOR_ARROW) end
            if v.hover and toggle then v.hover(false) end
            toggle = false
        end
    end
    mouse_event(mouse)
    local x = {
        callbacks = {
            add_event_callback(EVENT_MOUSEBUTTONDOWN, function(ev)
                if ev.x >= v.x and ev.y >= v.y and ev.x <= v.x + v.w and ev.y <= v.y + v.h then
                    v.cb()
                    return true
                end
            end, v.z),
            add_event_callback(EVENT_MOUSEBUTTONUP, mouse_event, v.z),
            add_event_callback(EVENT_MOUSEMOTION, mouse_event, v.z)
        },
        area = v,
        clear = v.clear == nil and true or v.clear,
        id = global_id
    }
    scene.clickables[#scene.clickables + 1] = x
    global_id = global_id + 1
    return x
end

function scene_add_clickable_image(v)
    v.w = image_w(v.img)
    v.h = image_h(v.img)
    local toggle = false
    v.fn = function()
        local i = v.img
        if v.hover_keep and toggle then draw_image(v) end
        v.img = toggle and v.hover_img or v.img
        draw_image(v)
        v.img = i
    end
    v.hover = v.hover_img and function(t)
        toggle = t
        scene_draw()
    end
    v.v = v
    return scene_add_sprite(v), scene_add_clickable_area(v)
end

function scene_add_clickable_animation(v)
    return scene_add_animation(v), scene_add_clickable_area{x=v.x, y=v.y, w=image_w(v.sheet) // v.sheet_size, h=image_h(v.sheet), cb=v.cb}
end

function scene_add_clickable_sprite(v)
    return scene_add_sprite(v), scene_add_clickable_area(v)
end

function scene_remove_clickable_area(x)
    for _, id in ipairs(x.callbacks) do
        remove_event_callback(id)
    end
    for i, v in ipairs(scene.clickables) do
        if x.id == v.id then
            table.remove(scene.clickables, i)
            break
        end
    end

    local arrow = true
    for _, v in ipairs(scene.clickables) do
        if mouse.x >= v.area.x and mouse.y >= v.area.y and mouse.x <= v.area.x + v.area.w and mouse.y <= v.area.y + v.area.h then
            arrow = false
        end
    end
    if arrow then set_cursor(CURSOR_ARROW) end
end

local dialog_button = load_image("dialog-button.png")
function dialog(v)
    if v.stop == nil then v.stop = true end
    if v.dismiss == nil then v.dismiss = true end
    local dialog_line = v.instant and #v or 1
    local dialog_i = v.instant and v[#v]:len() or 1
    local r = 1000 / 20
    local s = {}
    local c = {}
    local buttons = false
    s[#s + 1] = scene_add_sprite{fn=function(next)
        if next then
            dialog_i = dialog_i + 1
            if dialog_i > v[dialog_line]:len() then
                dialog_line = dialog_line + 1
                if dialog_line > #v then
                    dialog_line = #v
                    r = nil
                else
                    dialog_i = 1
                end
            end
        end
        if not buttons and v.options and dialog_line == #v and dialog_i == v[dialog_line]:len() then
            buttons = true
            for i, d in ipairs(v.options) do
                local x = 100 + (i - 1) * 200
                local y = 340
                local w = image_w(dialog_button)
                local h = image_h(dialog_button)
                local toggle = false
                s[#s + 1], c[#c + 1] = scene_add_clickable_sprite{fn=function()
                    draw_image{img=dialog_button, x=x, y=y}
                    draw_text{color=toggle and 0xffffffff or 0x333333ff, x=x + w - w // 2 - d[1]:len() * 16 // 2, y=y + h - h // 2 - 10, text=d[1]}
                end, hover=function(t)
                    toggle = t
                    scene_draw()
                end, cb=switch_scene(function()
                    for _, v in ipairs(s) do scene_remove_sprite(v) end
                    for _, v in ipairs(c) do scene_remove_clickable_area(v) end
                    return d[2]()
                end), x=x, y=y, z=(v.z or 10) + 1, w=w, h=h}
            end
            scene_draw()
            return r
        end
        draw_rect{color=0xffffff80, x=0, y=310, w=496, h=58}
        for i=1, dialog_line do
            local s
            if i == dialog_line then s = v[i]:sub(1, dialog_i)
            else s = v[i]
            end
            draw_text{color=0x000000ff, x=496 // 2 - v[i]:len() * 16 // 2, y=320 + (i - 1) * 24, text=s}
        end
        return r
    end, z=v.z or 10}
    if v.dismiss then
        c[#c + 1] = scene_add_clickable_area{x=0, y=0, w=496, h=368, cb=function()
            if dialog_line < #v or dialog_i <= v[dialog_line]:len() then
                dialog_line = #v
                dialog_i = v[dialog_line]:len()
                scene_draw()
            else
                for _, v in ipairs(s) do scene_remove_sprite(v) end
                for _, v in ipairs(c) do scene_remove_clickable_area(v) end
                if v.stop then scene.playing = false
                else scene_draw()
                end
            end
        end, z=v.z}
    end
    return scene_play()
end

function scene_play()
    scene.playing = true
    scene.next = nil
    while scene.playing do
        local t = ticks()
        local s = scene_draw(true)
        while scene.playing and ticks() - t < 1000 / 30 do
            if not s then wait()
            else wait(math.ceil(1000 / 30 - (ticks() - t)))
            end
        end
    end
    if scene.next then return scene.next() end
end

function scene_draw(next)
    scene_changed = false
    local s = false
    local r = {}
    for i, v in ipairs(scene.sprites) do
        if v.remove then r[#r + 1] = i end
    end
    for i, v in ipairs(r) do
        table.remove(scene.sprites, v - i + 1)
    end
    for _, sprite in ipairs(scene.sprites) do
        if next and (not sprite.last_tick or sprite.next_tick and ticks() >= sprite.next_tick) then
            sprite.last_tick = ticks()
        end
        local x = sprite.fn(next and sprite.next_tick and ticks() >= sprite.next_tick)
        if x then
            s = true
            if next then sprite.next_tick = sprite.last_tick + x end
        elseif next then
            sprite.next_tick = nil
        end
        if scene_changed then
            return scene_draw()
        end
    end
    present()
    return s
end

function zoom(v, times)
    if not v.startx then v.startx = v.x end
    if not v.starty then v.starty = v.y end
    v.destw = math.floor(v.w * times)
    v.desth = math.floor(v.h * times)
    v.x = (v.startx - (v.destw - v.w) // 2)
    v.y = (v.starty - (v.desth - v.h) // 2)
    return v
end

function scene_clear()
    local remove = {}
    for _, v in ipairs(scene.clickables) do
        if v.clear then remove[#remove + 1] = v end
    end
    for _, v in ipairs(remove) do
        scene_remove_clickable_area(v)
    end

    remove = {}
    for i, v in ipairs(scene.sprites) do
        if v.clear then remove[#remove + 1] = i end
    end
    for i, v in ipairs(remove) do
        table.remove(scene.sprites, v - i + 1)
    end
end

RIGHT = 0
DOWN = 90
LEFT = 180
UP = 270
local arrow = load_image("arrow.png")
local arrow_hover = load_image("arrow-hover.png")

function switch_scene(next)
    return function()
        scene.playing = false
        scene.next = next
    end
end

function scene_add_arrow(rotation, x, y, next_scene)
    scene_add_clickable_image{img=arrow, hover_img=arrow_hover, hover_keep=true, x=x, y=y, z=5, cb=switch_scene(next_scene), degrees=rotation}
end

function scene_add_item(v)
    if inventory[v.name] and inventory[v.name].got then return end
    scene_add_clickable_image{cb=switch_scene(function()
        inventory[v.name].got = true
        inventory[v.name].has = true
        scene_clear()
        scene_add_image{img=v.got_img, x=100, y=100}
        dialog{"YOU GOT:", v.name, instant=true}
        return v.next()
    end), x=v.x, y=v.y, img=v.img}
end

function sex(x)
    local bar = 0
    local rate = x[1].rate
    local s = {}
    local c = {}
    scene_clear()
    for i, v in ipairs(x) do
        s[#s + 1], c[#c + 1] = scene_add_clickable_image{img=v.img, hover_img=v.hover_img, x=20 + (i - 1) * 50, y=20, z=10, clear=false, cb=switch_scene(function()
            scene_clear()
            rate = v.rate
            v.fn()
            return scene_play()
        end)}
        if i == 1 then v.fn() end
    end
    s[#s + 1] = scene_add_sprite{fn=function(next)
        if next then bar = math.min(100, bar + 1) end
        if next and bar == 100 then
            s[#s + 1], c[#c + 1] = scene_add_clickable_image{img=x.nut.img, hover_img=x.nut.hover_img, x=20 + #x * 50, y=20, z=10, clear=false, cb=switch_scene(function()
                scene_clear()
                x.nut.fn()
                return scene_play()
            end)}
        end
        draw_image{img=x.bar.inside, x=304, y=23, w=bar}
        return bar < 100 and rate or nil
    end, z=10, clear=false}
    s[#s + 1] = scene_add_image{img=x.bar.outside, x=300, y=20, z=11, clear=false}
    scene_play()
    for _, v in ipairs(s) do scene_remove_sprite(v) end
    for _, v in ipairs(c) do scene_remove_clickable_area(v) end
end

local empty_slot = load_image("empty-inventory.png")
local muted = false
scene_add_clickable_image{img=load_image("menu-button.png"), x=465, y=10, clear=false, cb=function()
    local s = {}
    local c = {}
    local menu = load_image("menu.png")
    s[#s + 1] = scene_add_sprite{fn=function()
        draw_rect{color=0x00000030, x=0, y=0, w=496, h=368}
        draw_image{img=menu, x=-5, y=-10}
        draw_text{color=0xffffffff, x=30, y=30, text="DAY " .. day}
        draw_text{color=0xffffffff, x=350, y=30, text="FORM:"}
        draw_image{img=form, x=330, y=70}
    end, z=32, clear=false}
    local i = 0
    local m
    m , c[#c + 1] = scene_add_clickable_image{cb=function()
        muted = not muted
        if muted then
            set_volume(0)
            m.v.img = load_image("muted-button.png")
            m.v.hover_img = load_image("muted-button-hover.png")
        else
            set_volume(128)
            m.v.img = load_image("unmuted-button.png")
            m.v.hover_img = load_image("unmuted-button-hover.png")
        end
        scene_draw()
    end, img=load_image(muted and "muted-button.png" or "unmuted-button.png"), hover_img=load_image(muted and "muted-button-hover.png" or "unmuted-button-hover.png"), x=430, y=60, clear=false, z=33}
    s[#s + 1] = m
    for _, v in pairs(inventory) do
        s[#s + 1], c[#c + 1] = scene_add_clickable_image{cb=function()
            if v.has then dialog{v.desc, instant=true, stop=false, z=35} end
        end, img=v.has and v.image or empty_slot, x=75 + i * 60, y=230, z=34, clear=false}
        i = i + 1
    end
    c[#c + 1] = scene_add_clickable_area{x=0, y=0, w=496, h=368, z=32, clear=false, cb=function()
        for _, v in ipairs(s) do scene_remove_sprite(v) end
        for _, v in ipairs(c) do scene_remove_clickable_area(v) end
        scene_draw()
    end}
    scene_draw()
end, hover_img=load_image("menu-button-hover.png"), z=30}