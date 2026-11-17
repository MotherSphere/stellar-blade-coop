-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's table and rules, with no engine call (tests/lua/sky/rule_test.lua). Each map that shows the
-- cycle has a row: its horizon hz (the sun's light goes under it), its noon heading (from the map's main preset, so
-- noon shadows fall the way SB's artists drew them) and how its sky is dressed. A map with no row, or a fixed one,
-- keeps Stellar Blade's own light. The hour and the sun come from the native part's sky= status line (game/sky.h):
-- Lua never computes the clock.
local Rule={}

local BG='/Game/Art/BG/WorldMap/SubLevel/'
local NK='/Game/DLC_2/Art/BG/WorldMap_NK_MiniGame/SubLevel/'
local HALL={sun='Sun',sky='SkyLight'} -- SBO's halls: engine lights, manual exposure.

-- Keys: the world's package path lowercased, as U.map_of gives it. sky: real (the domes hidden, the SkyAtmosphere
-- draws the sky), creator (SB's SkyCreator turns its own sun, moon and stars), painted (Xion: a day dome and SB's
-- night dome) or engine (SBO's own maps: no SB env settings, Lua drives the Sun and SkyLight actors). stars: layer
-- (SBO's star layer on the first hidden dome), creator, night_dome or none.
Rule.MAPS={
    ['/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p']={cycle='on',hz=8,heading=0,sky='real',
        domes={'/Game/Art/BG/WorldMap/E03_WasteLand_P/E03_SubLevel_ENV/E03_ENV.E03_ENV:PersistentLevel.Sky_Sphere'},
        stars='layer'},
    ['/game/art/bg/worldmap/e05_greatdesert_p/e05_greatdesert_p']={cycle='on',hz=2,heading=200,sky='creator',
        stars='creator'},
    ['/game/art/bg/worldmap/level_p/f02']={cycle='on',hz=8,heading=88,sky='real',
        domes={BG..'F02/F02_ENV.F02_ENV:PersistentLevel.SM_SkySphere'},stars='creator'},
    ['/game/art/bg/worldmap/level_p/f01']={cycle='on',hz=8,heading=88,sky='real',
        domes={BG..'F01/F01_ENV.F01_ENV:PersistentLevel.SM_SkySphere'},stars='creator'},
    ['/game/art/bg/worldmap/level_p/e04']={cycle='on',hz=8,heading=205,sky='painted',stars='night_dome',
        day_dome=BG..'E04/E04_SkySphere_01.E04_SkySphere_01:PersistentLevel.SM_SkySphere2',
        night_dome=BG..'E04/E04_SkySphere_01.E04_SkySphere_01:PersistentLevel.SM_SkySphere_NIGHT',
        flag=BG..'E04/E04_ENV_VOL.E04_ENV_VOL:PersistentLevel.E04_Area_02_Global_ENV_01_NIGHT'},
    ['/game/art/bg/worldmap/dungeon_p/matrix_xi']={cycle='on',hz=8,heading=172,sky='real',
        domes={BG..'Matrix_XI/Matrix_XI_ENV.Matrix_XI_ENV:PersistentLevel.SM_SkySphere'},stars='layer'},
    ['/game/art/bg/worldmap/level_p/b07']={cycle='on',hz=8,heading=242,sky='real',stars='creator',domes={
        BG..'B07/B07_Skysphere_01.B07_Skysphere_01:PersistentLevel.SM_SkySphere3',
        BG..'B07/B07_Skysphere_02.B07_Skysphere_02:PersistentLevel.SM_SkySphere2',
        BG..'B07/B07_Skysphere_03.B07_Skysphere_03:PersistentLevel.SM_SkySphere4',
        BG..'B07/B07_Skysphere_04.B07_Skysphere_04:PersistentLevel.SM_SkySphere2'}},
    ['/game/dlc_2/art/bg/worldmap_nk_minigame/nk_minigame_p']={cycle='on',hz=8,heading=60,sky='real',
        domes={NK..'Waste/NK_MiniGame_Waste_ENV.NK_MiniGame_Waste_ENV:PersistentLevel.Sky_Sphere'},stars='layer'},
    ['/game/dlc_2/art/bg/worldmap_nk_minigame/nk_minigame_02_p']={cycle='on',hz=8,heading=76,sky='real',
        domes={NK..'City/NK_MiniGame_City_ENV.NK_MiniGame_City_ENV:PersistentLevel.City_Sky_Sphere_1'},stars='layer'},
    ['/game/art/bg/worldmap_dlc_01/level_p/mxiii_p']={cycle='on',hz=2,heading=85,sky='engine',
        engine={sun='Sun',sky='SkyLight',ppv='Z0_PPV_Desert'}}, -- Zone 0 runs auto exposure.
    ['/game/sbo_lobby/lobby_hotel']={cycle='on',hz=8,heading=308,sky='engine',engine=HALL},
    ['/game/sbo_lobby/lobby_station']={cycle='on',hz=8,heading=61,sky='engine',engine=HALL},
    ['/game/sbo_lobby/lobby_cloister']={cycle='on',hz=8,heading=230,sky='engine',engine=HALL},
    ['/game/sbo_lobby/lobby_foyer']={cycle='on',hz=8,heading=61,sky='engine',engine=HALL},
    ['/game/dlc_2/art/bg/worldmap_nk/nk_p']={cycle='fixed'}, -- Night by design; SBO's FFA arena.
    ['/game/art/bg/worldmap/level_p/g03']={cycle='fixed'}, -- The prologue's beach.
    ['/game/art/bg/worldmap/level_p/c05']={cycle='fixed'}, -- Covered; its ending sunset and night are story.
    ['/game/art/bg/worldmap/dungeon_p/alteslab_p']={cycle='fixed'}, -- No sunlit volume.
    ['/game/art/bg/worldmap/dungeon_p/abysslab_p']={cycle='fixed'},
    ['/game/art/bg/worldmap/dungeon_p/ending_p']={cycle='fixed'},
    ['/game/art/bg/worldmap/dungeon_p/epilogue_p']={cycle='fixed'},
    ['/game/sbo_lobby/lobby_terrace']={cycle='fixed'}, -- The night hall.
    ['/game/lobby/lobby']={cycle='fixed'}, -- The title world.
}
-- SB's star sky of the Nest's night ending, the material of SBO's star layer.
Rule.STARS='/Game/Art/BG/WorldMap/SubLevel/C05/C05_Material/Ending/001_A_MI_C05_Star_SKY.001_A_MI_C05_Star_SKY'
Rule.CREATOR='/Script/SkyCreatorPlugin.SkyCreator'
Rule.STARS_AT=-8 -- The sun's elevation under which the stars show: the sky is dark by then.
Rule.NIGHT_DOME_AT=-4 -- Where the moon takes over from the sun (game/sky.h).

function Rule.row(map) return map and Rule.MAPS[map] or nil end

-- The request for the native part with its reason, for s={setting, test ('on'|'off'|nil), pinned (minute|nil), map,
-- cutscene, screen, photo, night, lobby, story_night}. First match wins.
function Rule.decide(s)
    local row=Rule.row(s.map)
    local off=not s.setting and 'daynight=off' or s.test=='off' and 'coop daynight off' or not s.map and 'no map'
        or (not row or row.cycle~='on') and 'fixed map' or s.lobby and 'SBO lobby'
        or s.story_night and 'Xion story night' or s.cutscene and 'cutscene' or s.screen and "the game's menu"
    if off then return 'sky off',off end
    if s.photo then return 'sky hold','photo mode' end
    local tail=' '..row.hz..' '..row.heading
    if s.pinned then return 'sky hour '..s.pinned..tail,'pinned' end
    if s.night then return 'sky hour 0'..tail,'Night Operation' end
    return 'sky cycle'..tail,'clock'
end

-- The sky= line of the native status as a table (numbers, tint a list of 3, moon and seen booleans), or nil when the
-- text has none (an older DLL).
function Rule.native(text)
    local line=text and ('\n'..text):match('\nsky=([^\r\n]*)')
    if not line then return nil end
    local t={state=line:match('^(%S+)')}
    for k,v in line:gmatch('(%w+)=(%S+)') do
        if k=='tint' then
            t.tint={}
            for c in v:gmatch('[^,]+') do t.tint[#t.tint+1]=tonumber(c) end
        elseif k=='moon' or k=='seen' then
            t[k]=v=='1'
        else
            t[k]=tonumber(v)
        end
    end
    return t
end

local HOUR='hour: a number from 0 to under 24'
-- The command's hour as a minute of the game day: plain digits with a decimal point, 0 to under 24.
function Rule.minute(text)
    local h=type(text)=='string' and text:match('^%d+%.?%d*$') and tonumber(text)
    if not h or h>=24 then return nil,HOUR end
    return math.floor(h*60)
end

-- The sky dressing at the sun's elevation el: the domes to hide, whether SBO's star layer and SB's night dome show.
function Rule.dress(row,el)
    return {hide=row.sky=='real' and row.domes or {},stars=row.stars=='layer' and el<=Rule.STARS_AT,
        night_dome=row.night_dome~=nil and el<=Rule.NIGHT_DOME_AT}
end

-- How far the star layer has faded in: 0 at the moon's start (-4), 1 at full stars (-8).
function Rule.star_fade(el)
    return math.max(0,math.min(1,(Rule.NIGHT_DOME_AT-el)/(Rule.NIGHT_DOME_AT-Rule.STARS_AT)))
end

-- Our hour on a SkyCreator whose own day runs from rise to set: our 04:00 to 20:00 onto its rise to set, our night onto
-- the rest, so its stars and moon turn with our sun.
function Rule.creator_time(hour,rise,set)
    if hour>=4 and hour<20 then return rise+(hour-4)/16*(set-rise) end
    return (set+(hour-20)%24/8*(24-set+rise))%24
end

-- Real minutes until 20:00 (one game hour is 2.5 real minutes); 0 from 20:00 to 04:00.
function Rule.until_night(hour)
    if hour<4 or hour>=20 then return 0 end
    return math.floor((20-hour)/0.4+0.5)
end

-- The third-party "Activate Day Night Cycle" plugin's file, three folders up from the mod's (UE4SS's Win64 folder).
function Rule.cps(mod_folder)
    return mod_folder:gsub('[\\/]+$','')..'\\..\\..\\..\\CPS\\Plugins\\activate_day_night_cycle.cps'
end

return Rule
