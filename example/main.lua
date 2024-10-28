import("std.lua")

inventory_init({name="ball", image=load_image("ball-inventory.png"), desc="SEEMS LIKE A NORMAL BALL."})

function intro()
    play_music("dream.mp3")
    scene_set_background(load_image("bg.png"))
    local alpha = 0xff
    local s
    s = scene_add_sprite{fn=function(next)
        if next then alpha = alpha - 5 end
        if alpha < 0 then
            alpha = 0
            scene_remove_sprite(s)
        end
        draw_rect{color=alpha, x=0, y=0, w=496, h=368}
        return 1000 / 30
    end, z=20}
    local zoom_p = 2
    scene_add_animation{fn=function(next, draw, v)
        if next then zoom_p = zoom_p - 0.025 end
        if zoom_p < 1 then zoom_p = 1 end
        draw(zoom(v, zoom_p))
        return zoom_p == 1 and (1000 / 10) or (1000 / 30)
    end, sheet=load_image("trixie1.png"), sheet_size=4, fps=10, x=100, y=0, frames={2, 3, 5, 6, 4, 1}}
    dialog{"HEY, HEY!!! ARE YOU ASLEEP?", "C'MON! ANSWER THE GREAT TRIXIE!"}
    scene_clear()
    scene_add_animation{sheet=load_image("trixie2.png"), sheet_size=7, fps=7, x=100, y=0, frames={2, 3, 4, 5, 6, 7, 11, [11]=13, [13]=12, [12]=18, [18]=5}}
    dialog{"THAT'S BETTER. TRIXIE SHALL", "START EXPLAINING THE RULES."}
    scene_clear()
    scene_add_animation{sheet=load_image("trixie3.png"), sheet_size=4, fps=7, x=100, y=0, frames={2, 3, 4, 5, 7, 1, 6}}
    scene_add_animation{sheet=load_image("trixie-magic.png"), sheet_size=13, fps=10, x=210, y=-40, frames={2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 11}}
    dialog{"THE SPELL THAT TURNS YOU INTO", "A PONY LASTS THREE DAYS."}
    alpha = 0
    scene_add_sprite{fn=function(next)
        if next then alpha = math.min(0xff, alpha + 5) end
        draw_rect{color=0xffffff00 | alpha, x=0, y=0, w=496, h=368}
        if alpha ~= 0xff then return 1000 / 30 end
    end, z=5}
    dialog{"AFTER THAT, YOU'LL TURN BACK", "TO HUMAN. HAVE A GOOD TIME."}
    form = form_earth
    play_music("main_theme_start.mp3", 1)
    queue_music("main_theme.mp3")
    scene_clear()
    alpha = 0xff
    local reveal = scene_add_sprite{fn=function(next)
        if next then alpha = math.max(0, alpha - 20) end
        draw_rect{color=0xffffff00 | alpha, x=0, y=0, w=496, h=368}
        if alpha ~= 0 then return 1000 / 30 end
    end, z=5, clear=false}
    scene_set_background(load_image("ground.png"))
    scene_add_image{img=load_image("hooves.png"), x=100, y=0}
    scene_add_animation{sheet=load_image("hooves-magic.png"), sheet_size=9, fps=14, x=0, y=0, frames={2, 3, 4, 5, 6, 7, 8, 9, nil}}
    scene_play()
    scene_clear()
    alpha = 0xff
    scene_set_background(load_image("bg2.png"))
    scene_add_animation{sheet=load_image("rumpa.png"), sheet_size=9, fps=14, x=0, y=0, frames={2, 3, 4, 5, 6, 7, 8, 9, nil}}
    scene_play()
    scene_clear()
    alpha = 0xff
    scene_set_background(load_image("ground.png"))
    scene_add_image{img=load_image("hooves2.png"), x=100, y=0}
    scene_add_animation{sheet=load_image("tail.png"), sheet_size=5, fps=14, x=0, y=0, frames={2, 3, 4, 5, nil}}
    scene_play()
    scene_clear()
    alpha = 0xff
    scene_set_background(load_image("bg3.png"))
    scene_add_animation{sheet=load_image("brian.png"), sheet_size=15, fps=14, x=0, y=0, frames={2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, nil}}
    scene_play()
    scene_remove_sprite(reveal)
    scene_clear()
    scene_set_background(load_image("bg4.png"))
    scene_add_animation{sheet=load_image("trixie4.png"), sheet_size=17, fps=14, x=0, y=0, frames={2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 13}}
    dialog{"CUTE. NOW GO. I WILL STAY", "AROUND HERE FOR A BIT."}
    dialog{"THE GREAT AND POWERFUL TRIXIE", "SHALL SPEAK TO YOU LATER."}
    return scene1()
end

function scene1()
    scene_clear()
    scene_set_background(load_image("bg4.png"))
    scene_add_animation{sheet=load_image("trixie-lay.png"), sheet_size=3, fps=7, x=300, y=225, frames={4, [4]=7, [7]=10, [10]=13, [13]=16, [16]=19, [19]=22, [22]=25, [25]=28, [28]=31, [31]=3, [3]=2, [2]=6, [6]=1}}
    scene_add_arrow(RIGHT, 445, 315, scene2)
    scene_add_arrow(LEFT, 0, 315, scene4)
    scene_add_arrow(UP, 220, 215, scene5)
    return scene_play()
end

function scene2()
    scene_clear()
    scene_set_background(load_image("bg5.png"))
    scene_add_arrow(RIGHT, 445, 315, scene3)
    scene_add_arrow(LEFT, 0, 315, scene1)
    scene_add_item{name="ball", x=75, y=200, img=load_image("ball-ground.png"), got_img=load_image("ball-get.png"), next=scene2}
    return scene_play()
end

function scene3()
    scene_clear()
    scene_set_background(load_image("bg6.png"))
    scene_add_arrow(RIGHT, 445, 315, scene4)
    scene_add_arrow(LEFT, 0, 315, scene2)
    return scene_play()
end

function scene4()
    scene_clear()
    scene_set_background(load_image("bg7.png"))
    scene_add_arrow(RIGHT, 445, 315, scene1)
    scene_add_arrow(LEFT, 0, 315, scene3)
    return scene_play()
end

function scene5()
    scene_clear()
    scene_set_background(load_image("bg8.png"))
    scene_add_arrow(DOWN, 220, 315, scene1)
    scene_add_clickable_area{x=0, y=230, w=80, h=138, cb=switch_scene(scene6)}
    return scene_play()
end

local derpy_knocks = 0
function scene6()
    scene_clear()
    scene_set_background(load_image("bg9.png"))
    scene_add_arrow(DOWN, 220, 315, scene5)
    scene_add_clickable_area{x=70, y=40, w=320, h=250, cb=switch_scene(function()
        scene_clear()
        derpy_knocks = derpy_knocks + 1
        if derpy_knocks <= 2 then dialog{'"#SAVEDERPY"', "COOL GRAFFITI.", instant=true} end
        if derpy_knocks == 2 then
            dialog{"[METALLIC KNOCKING]", instant=true}
        elseif derpy_knocks > 2 then
            dialog{"OH SHIT SOMEONE'S", "STUCK IN THERE!!!1", instant=true}
            return dialog{"TRY TO KICK THE PONY OUT?", options={{"YES!", derpy}, {"NO!", scene6}}, instant=true, dismiss=false}
        end
        return scene6()
    end)}
    return scene_play()
end

function derpy()
    scene_clear()
    dialog{"hrrrr"}
end

intro()