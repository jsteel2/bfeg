import("std.lua")

function scene1()
    scene_clear()
    scene_set_background(load_image("bg4.png"))
    scene_add_animation(load_image("trixie-lay.png"), 3, 3, 7, 300, 225, 1, {4, [4]=7, [7]=10, [10]=13, [13]=16, [16]=19, [19]=22, [22]=25, [25]=28, [28]=31, [31]=3, [3]=2, [2]=6, [6]=1})
    scene_add_arrow(0, 445, 315, scene2)
    scene_add_arrow(180, 0, 315, scene4)
    scene_add_arrow(270, 220, 215, scene5)
    return scene_play()
end

function scene2()
    scene_clear()
    scene_set_background(load_image("bg5.png"))
    scene_add_arrow(0, 445, 315, scene3)
    scene_add_arrow(180, 0, 315, scene1)
    return scene_play()
end

function scene3()
    scene_clear()
    scene_set_background(load_image("bg6.png"))
    scene_add_arrow(0, 445, 315, scene4)
    scene_add_arrow(180, 0, 315, scene2)
    return scene_play()
end

function scene4()
    scene_clear()
    scene_set_background(load_image("bg7.png"))
    scene_add_arrow(0, 445, 315, scene1)
    scene_add_arrow(180, 0, 315, scene3)
    return scene_play()
end

function scene5()
    scene_clear()
    scene_set_background(load_image("bg8.png"))
    scene_add_arrow(90, 220, 315, scene1)
    scene_add_clickable_rect(0, 230, 80, 138, scene6, hover_hand)
    return scene_play()
end

derpy_knocks = 0
function scene6()
    scene_clear()
    scene_set_background(load_image("bg9.png"))
    scene_add_arrow(90, 220, 315, scene5)
    scene_add_clickable_rect(70, 40, 320, 250, function()
        scene_clear()
        dialog('"#SAVEDERPY"\nCOOL GRAFFITI.', true)
        derpy_knocks = derpy_knocks + 1
        if derpy_knocks > 1 then
            dialog("[METALLIC KNOCKING]", true)
        end
        return scene6()
    end, hover_hand)
    return scene_play()
end

function intro()
    play_music("dream.mp3")
    scene_set_background(load_image("bg.png"))
    scene_add_animation(load_image("trixie1.png"), 4, 4, 10, 100, 0, 1, {2, 3, 5, 6, 4, 1})
    dialog("HEY, HEY!!! ARE YOU ASLEEP?\nC'MON! ANSWER THE GREAT TRIXIE!")
    scene_clear()
    scene_add_animation(load_image("trixie2.png"), 7, 7, 7, 100, 0, 1, {2, 3, 4, 5, 6, 7, 11, [11]=13, [13]=12, [12]=18, [18]=5})
    dialog("THAT'S BETTER. TRIXIE SHALL\nSTART EXPLAINING THE RULES.")
    scene_clear()
    scene_add_animation(load_image("trixie3.png"), 4, 4, 7, 100, 0, 1, {2, 3, 4, 5, 7, 1, 6})
    scene_add_animation(load_image("trixie-magic.png"), 13, 13, 10, 210, -40, 1, {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 11})
    dialog("THE SPELL THAT TURNS YOU INTO\nA PONY LASTS THREE DAYS.")
    local f = 0
    scene_add_animation(function(v, next)
        draw_rect(0xffffff00 | f, 0, 0, 496, 368)
        if next then f = math.min(0xff, f + 5) end
    end, 0, 0, 30, 0, 0, 1, {1})
    dialog("AFTER THAT, YOU'LL TURN BACK\nTO HUMAN. HAVE A GOOD TIME.")
    play_music("main_theme_start.mp3", 1)
    queue_music("main_theme.mp3")
    scene_clear()
    f = 0xff
    local function reveal(v, next)
        draw_rect(0xffffff00 | f, 0, 0, 496, 368)
        if next then f = math.max(0, f - 20) end
    end
    scene_set_background(load_image("ground.png"))
    scene_add_image(0, load_image("hooves.png"), 100, 0)
    scene_add_animation(load_image("hooves-magic.png"), 9, 9, 14, 0, 0, 1, {2, 3, 4, 5, 6, 7, 8, 9, nil})
    scene_add_animation(reveal, 0, 0, 30, 0, 0, 1, {1})
    scene_play()
    f = 0xff
    scene_clear()
    scene_set_background(load_image("bg2.png"))
    scene_add_animation(load_image("rumpa.png"), 9, 9, 14, 0, 0, 1, {2, 3, 4, 5, 6, 7, 8, 9, nil})
    scene_add_animation(reveal, 0, 0, 30, 0, 0, 1, {1})
    scene_play()
    f = 0xff
    scene_clear()
    scene_set_background(load_image("ground.png"))
    scene_add_image(0, load_image("hooves2.png"), 100, 0)
    scene_add_animation(load_image("tail.png"), 5, 5, 14, 0, 0, 1, {2, 3, 4, 5, nil})
    scene_add_animation(reveal, 0, 0, 30, 0, 0, 1, {1})
    scene_play()
    f = 0xff
    scene_clear()
    scene_set_background(load_image("bg3.png"))
    scene_add_animation(load_image("brian.png"), 15, 15, 14, 0, 0, 1, {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, nil})
    scene_add_animation(reveal, 0, 0, 30, 0, 0, 1, {1})
    scene_play()
    scene_clear()
    scene_set_background(load_image("bg4.png"))
    scene_add_animation(load_image("trixie4.png"), 17, 17, 14, 0, 0, 1, {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 13})
    dialog("CUTE. NOW GO. I WILL STAY\nAROUND HERE FOR A BIT.")
    dialog("THE GREAT AND POWERFUL TRIXIE\nSHALL SPEAK TO YOU LATER.")
    return scene1()
end

intro()