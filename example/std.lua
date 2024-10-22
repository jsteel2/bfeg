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
    table.remove(callbacks[ev], id)
end

function handle_event(ev, data)
    if not callbacks[ev] then return end
    for _, v in ipairs(callbacks[ev]) do
        if v(data) then break end
    end
end

scene = {
    images = {},
    animations = {},
    clickables = {}
}
function scene_set_background(image)
    scene.background = image
end

function scene_add_image(...)
    scene.images[#scene.images + 1] = {...}
end

function scene_add_animation(image, sheet_frames, anim_frames, fps, x, y, start, frames)
    scene.animations[#scene.animations + 1] = {
        image = image,
        fps = fps,
        x = x,
        y = y,
        sheet_frames = sheet_frames,
        anim_frames = anim_frames,
        frames = frames,
        cur_frame = start,
        start_frame = start,
        last_time = nil
    }
end

local arrow = load_image("arrow.png")
function scene_add_arrow(rotation, x, y, callback)
    scene_add_image(arrow, x, y)
    scene_add_clickable_rect(x, y, image_w(arrow), image_h(arrow), callback, function(hover_toggle)
        if hover_toggle then set_cursor(CURSOR_HAND)
        else set_cursor(CURSOR_ARROW)
        end
    end)
end

function scene_add_clickable_rect(x, y, w, h, callback, hover_callback)
    scene.clickables[#scene.clickables + 1] = {
        x = x,
        y = y,
        w = w,
        h = h,
        callback = callback,
        hover_callback = hover_callback,
        hover_toggle = false
    }
end

function scene_play()
    local ids = {}
    local go = true
    local text = nil
    local function cb()
        go = false
        return true
    end
    local clickcb = nil
    if scene.dialog then
        ids[#ids + 1] = {EVENT_MOUSEBUTTONDOWN, set_event_callback(EVENT_MOUSEBUTTONDOWN, cb)}
        text = split(scene.dialog, "\n")
    end
    for _, c in ipairs(scene.clickables) do
        ids[#ids + 1] = {EVENT_MOUSEMOTION, set_event_callback(EVENT_MOUSEMOTION, function(ev)
            if not c.hover_toggle and ev.x >= c.x and ev.y >= c.y and c.x + c.w >= ev.x and c.y + c.h >= ev.y then
                c.hover_toggle = true
                c.hover_callback(true)
                return true
            elseif c.hover_toggle and (ev.x < c.x or ev.y < c.y or ev.x > c.x + c.w or ev.y > c.y + c.h) then
                c.hover_toggle = false
                c.hover_callback(false)
            end
            return false
        end)}
        ids[#ids + 1] = {EVENT_MOUSEBUTTONDOWN, set_event_callback(EVENT_MOUSEBUTTONDOWN, function(ev)
            if ev.x >= c.x and ev.y >= c.y and c.x + c.w >= ev.x and c.y + c.h >= ev.y then
                clickcb = c.callback
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
    local dialog_last_time = nil
    local dialog_line = 1
    local dialog_i = 1
    while go do
        local min_sleep = 100000
        local start = nil
        draw_image(scene.background, 0, 0)

        for _, v in ipairs(scene.images) do
            draw_image(table.unpack(v))
        end

        for _, v in ipairs(scene.animations) do
            if not v.last_time or v.last_time + 1000 / v.fps <= ticks() then
                if v.last_time then v.cur_frame = v.frames[v.cur_frame] end
                if not v.cur_frame then
                    go = false
                    return
                end
                v.last_time = ticks()
            end
            if not start or v.last_time > start then start = v.last_time end
            if 1000 / v.fps < min_sleep then min_sleep = 1000 / v.fps end
            draw_image(v.image, image_w(v.image) // v.sheet_frames * ((v.cur_frame - v.start_frame) % v.anim_frames), 0, image_w(v.image) // v.sheet_frames, image_h(v.image), v.x, v.y)
        end

        if text then
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
            while go and ticks() - start < min_sleep do wait(math.ceil(min_sleep - (ticks() - start))) end
        else
            wait()
        end

        if not go and text and (dialog_line < #text or dialog_i < text[dialog_line]:len()) then
            dialog_line = #text
            dialog_i = text[dialog_line]:len()
            go = true
        end
        if clickcb then break end
    end

    for _, v in ipairs(ids) do
        clear_event_callback(table.unpack(v))
    end

    if clickcb then return clickcb() end
end

function scene_clear()
    scene.images = {}
    scene.animations = {}
    scene.clickables = {}
    scene.dialog = nil
end

function dialog(text)
    scene.dialog = text
    scene_play()
end