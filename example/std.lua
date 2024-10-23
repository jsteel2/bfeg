set_font("bfed.ttf", 16)

function split(str, character)
    local result = {}
  
    local index = 1
    for s in string.gmatch(str, "[^"..character.."]+") do
      result[index] = s
      index = index + 1
    end
  
    return result
  end

callbacks = {}
function set_event_callback(ev, fn)
    if not callbacks[ev] then
        callbacks[ev] = {}
    end
    local id = #callbacks[ev] + 1
    callbacks[ev][id] = fn
    return id
end

function clear_event_callback(ev, id)
    callbacks[ev] = nil
end

cur_cursor = CURSOR_ARROW
function set_cursor(cursor)
    if cursor ~= cur_cursor then
        cur_cursor = cursor
        set_system_cursor(cursor)
    end
end

function handle_event(ev, data)
    if not callbacks[ev] then
         set_cursor(CURSOR_ARROW)
        return
    end
    for _, v in ipairs(callbacks[ev]) do
        if v and v(data) then return end
    end
    set_cursor(CURSOR_ARROW)
end

scene = {
    animations = {},
    clickables = {}
}
function scene_set_background(image)
    scene.background = image
end

function scene_add_image(z, ...)
    return scene_add_animation({...}, nil, nil, nil, nil, nil, nil, nil, z, true)
end

local scene_id = 1
function scene_add_animation(image, sheet_frames, anim_frames, fps, x, y, start, frames, z, still, perm)
    if not z then z = 0 end
    scene.animations[#scene.animations + 1] = {
        animated = not still,
        image = image,
        fps = fps,
        x = x,
        y = y,
        z = z,
        sheet_frames = sheet_frames,
        anim_frames = anim_frames,
        frames = frames,
        cur_frame = start,
        start_frame = start,
        last_time = nil,
        id = scene_id,
        perm = perm
    }
    scene_id = scene_id + 1
    table.sort(scene.animations, function(l, r) return l.z < r.z end)
    return scene_id - 1
end

function hover_hand(hover_toggle)
    if hover_toggle then set_cursor(CURSOR_HAND)
    else set_cursor(CURSOR_ARROW)
    end
end

local arrow = load_image("arrow.png")
function scene_add_arrow(rotation, x, y, callback)
    scene_add_image(2, arrow, x, y, rotation)
    scene_add_clickable_rect(x, y, image_w(arrow), image_h(arrow), callback, hover_hand)
end

function scene_add_clickable_rect(x, y, w, h, callback, hover_callback, dont_halt, perm)
    scene.clickables[#scene.clickables + 1] = {
        x = x,
        y = y,
        w = w,
        h = h,
        callback = callback,
        hover_callback = hover_callback,
        hover_toggle = false,
        halt_scene = not dont_halt,
        id = scene_id,
        perm = perm
    }
    scene_id = scene_id + 1
    return scene_id - 1
end

function scene_add_clickable_image(z, image, x, y, callback, hover_callback, dont_halt, perm)
    local a = scene_add_animation({image, x, y}, nil, nil, nil, nil, nil, nil, nil, z, true, perm)
    return a, scene_add_clickable_rect(x, y, image_w(image), image_h(image), callback, hover_callback, dont_halt, perm)
end

inventory = {}
function scene_add_item(name, z, image, got_image, inv_image, x, y, next)
    if inventory[name] and inventory[name].got then return end
    scene_add_clickable_image(z, image, x, y, function()
        inventory[name] = {got = true, has = true, image = inv_image}
        scene_clear()
        scene_add_image(4, got_image, 100, 100)
        dialog("YOU GOT:\n" .. name, true)
        return next()
    end, hover_hand)
end

function remove_if(arr, fn)
    local index = nil
    for i, v in ipairs(arr) do
        if fn(v) then
            index = i
            break
        end
    end
    if index then table.remove(arr, index) end
end

function scene_remove_clickable(id)
    remove_if(scene.clickables, function(v) return v.id == id end)
end

function scene_remove_animation(id)
    remove_if(scene.animations, function(v) return v.id == id end)
end

function scene_play(instant_dialog)
    local cl = #scene.clickables
    local go = true
    local text = nil
    local function cb()
        go = false
        set_cursor(CURSOR_ARROW)
        return true
    end
    local clickcb = nil
    local dialog_last_time = nil
    local dialog_line = 1
    local dialog_i = 1
    ::add_callbacks::
    local ids = {}
    for i = 1, #scene.clickables do
        local c = scene.clickables[#scene.clickables + 1 - i]
        ids[#ids + 1] = {EVENT_MOUSEMOTION, set_event_callback(EVENT_MOUSEMOTION, function(ev)
            if not c.hover_toggle and ev.x >= c.x and ev.y >= c.y and c.x + c.w >= ev.x and c.y + c.h >= ev.y then
                c.hover_toggle = true
                c.hover_callback(true)
            elseif c.hover_toggle and (ev.x < c.x or ev.y < c.y or ev.x > c.x + c.w or ev.y > c.y + c.h) then
                c.hover_toggle = false
                c.hover_callback(false)
            end
            return c.hover_toggle
        end)}
        ids[#ids + 1] = {EVENT_MOUSEBUTTONDOWN, set_event_callback(EVENT_MOUSEBUTTONDOWN, function(ev)
            if ev.x >= c.x and ev.y >= c.y and c.x + c.w >= ev.x and c.y + c.h >= ev.y then
                if c.halt_scene then clickcb = c.callback
                else c.callback()
                end
                set_cursor(CURSOR_ARROW)
                return true
            end
            return false
        end)}
        ids[#ids + 1] = {EVENT_MOUSEBUTTONUP, set_event_callback(EVENT_MOUSEBUTTONUP, function(ev)
            if ev.x >= c.x and ev.y >= c.y and c.x + c.w >= ev.x and c.y + c.h >= ev.y then
                set_cursor(CURSOR_HAND)
                return true
            end
            return false
        end)}
    end
    if scene.dialog then
        ids[#ids + 1] = {EVENT_MOUSEBUTTONDOWN, set_event_callback(EVENT_MOUSEBUTTONDOWN, cb)}
        ids[#ids + 1] = {EVENT_MOUSEBUTTONUP, set_event_callback(EVENT_MOUSEBUTTONUP, function()
            set_cursor(CURSOR_HAND)
            return true
        end)}
        ids[#ids + 1] = {EVENT_MOUSEMOTION, set_event_callback(EVENT_MOUSEMOTION, function()
            set_cursor(CURSOR_HAND)
            return true
        end)}
        text = split(scene.dialog, "\n")
    end
    if instant_dialog then
        dialog_line = #text
        dialog_i = text[dialog_line]:len()
    end
    local fuck = false
    while go do
        local min_sleep = 100000
        local start = nil
        draw_image(scene.background, 0, 0)

        for _, v in ipairs(scene.animations) do
            if v.z > 9 and text then
                draw_rect(0xffffff80, 0, 300, 496, 68)
                if not dialog_last_time or dialog_last_time + 1000 / 30 <= ticks() then
                    if dialog_last_time then
                        dialog_i = dialog_i + 1
                        if dialog_i > text[dialog_line]:len() then
                            dialog_line = dialog_line + 1
                            if dialog_line > #text then dialog_line = #text
                            else dialog_i = 1
                            end
                        end
                    end
                    dialog_last_time = ticks()
                end
                if not start or dialog_last_time > start then start = dialog_last_time end
                if 1000 / 30 < min_sleep then min_sleep = 1000 / 30 end
                for i=1, dialog_line do
                    local s
                    if i == dialog_line then s = text[i]:sub(1, dialog_i)
                    else s = text[i]
                    end
                    draw_text(0x000000ff, 496 // 2 - text[i]:len() * 16 // 2, 310 + (i - 1) * 24, s)
                end
                fuck = true
            end
            if not v.animated then
                draw_image(table.unpack(v.image))
                goto continue
            end
            local next = false
            if not v.last_time or v.last_time + 1000 / v.fps <= ticks() then
                if v.last_time then 
                    v.cur_frame = v.frames[v.cur_frame]
                    next = true
                end
                if not v.cur_frame then
                    go = false
                    goto fend
                end
                v.last_time = ticks()
            end
            if not start or v.last_time > start then start = v.last_time end
            if 1000 / v.fps < min_sleep then min_sleep = 1000 / v.fps end
            if type(v.image) == "function" then
                v.image(v, next)
            else
                draw_image(v.image, image_w(v.image) // v.sheet_frames * ((v.cur_frame - v.start_frame) % v.anim_frames), 0, image_w(v.image) // v.sheet_frames, image_h(v.image), v.x, v.y)
            end
            ::continue::
        end

        if text and not fuck then
            draw_rect(0xffffff80, 0, 300, 496, 68)
            if not dialog_last_time or dialog_last_time + 1000 / 30 <= ticks() then
                if dialog_last_time then
                    dialog_i = dialog_i + 1
                    if dialog_i > text[dialog_line]:len() then
                        dialog_line = dialog_line + 1
                        if dialog_line > #text then dialog_line = #text
                        else dialog_i = 1
                        end
                    end
                end
                dialog_last_time = ticks()
            end
            if not start or dialog_last_time > start then start = dialog_last_time end
            if 1000 / 30 < min_sleep then min_sleep = 1000 / 30 end
            for i=1, dialog_line do
                local s
                if i == dialog_line then s = text[i]:sub(1, dialog_i)
                else s = text[i]
                end
                draw_text(0x000000ff, 496 // 2 - text[i]:len() * 16 // 2, 310 + (i - 1) * 24, s)
            end
        end

        present()
        if start then 
            while go and ticks() - start < min_sleep do
                wait(math.ceil(min_sleep - (ticks() - start)))
                if cl ~= #scene.clickables then
                    cl = #scene.clickables
                    for _, v in ipairs(ids) do
                        clear_event_callback(table.unpack(v))
                    end
                    goto add_callbacks
                    end
                end
        else
            wait()
        end

        if not go and text and (dialog_line < #text or dialog_i < text[dialog_line]:len()) then
            dialog_line = #text
            dialog_i = text[dialog_line]:len()
            go = true
        end
        if clickcb then break end
        if cl ~= #scene.clickables then
            cl = #scene.clickables
            for _, v in ipairs(ids) do
                clear_event_callback(table.unpack(v))
            end
            goto add_callbacks
        end
    end

    ::fend::
    for _, v in ipairs(ids) do
        clear_event_callback(table.unpack(v))
    end

    if clickcb then return clickcb() end
end

function scene_clear()
    local a = {}
    local c = {}
    for _, v in ipairs(scene.animations) do
        if v.perm then a[#a + 1] = v end
    end
    for _, v in ipairs(scene.clickables) do
        if v.perm then c[#c + 1] = v end
    end
    scene.animations = a
    scene.clickables = c
    scene.dialog = nil
end
scene_clear()

local menu_button = load_image("menu-button.png")
local menu = load_image("menu.png")
scene_add_clickable_image(10, menu_button, 465, 10, function()
    local a = {}
    a[#a + 1] = scene_add_animation(function() draw_rect(0x00000030, 0, 0, 496, 368) end, 0, 0, 0, 0, 0, 1, {1}, 11, nil, true)
    a[#a + 1] = scene_add_animation({menu, -5, -10}, nil, nil, nil, nil, nil, nil, nil, 12, true, true)
    local c = {}
    for _, v in pairs(inventory) do
        if not v.has then goto continue end
        a[#a + 1] = scene_add_animation({v.image, 75, 230}, nil, nil, nil, nil, nil, nil, nil, 13, true, true)
        ::continue::
    end
    c[#c + 1] = scene_add_clickable_rect(0, 0, 496, 368, function()
        for _, v in ipairs(a) do
            scene_remove_animation(v)
        end
        for _, v in ipairs(c) do
            scene_remove_clickable(v)
        end
        return true
    end, hover_hand, true, true)
    return true
end, hover_hand, true, true)

function dialog(text, instant)
    scene.dialog = text
    scene_play(instant)
end