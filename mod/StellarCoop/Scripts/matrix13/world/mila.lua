-- Mila as a body in world 2800 (experimental, untested in game): matrix13/quest/zone_talks.lua says where she is, at the
-- shelf 1 recess from scene 4E on and on the drive room floor from scene 4N on. A display only, as race/doro.lua makes
-- them: a plain actor with one SkeletalMeshComponent, collision off, no SB character, no row, no AI, so nothing of her
-- can fight, die or reach a save. The mesh is CH_NPC_Kara, the game's model of Kaya's sister; the pose is the sitting
-- clip shipped for that skeleton (CH_NPC_ScavengerFemale_A_Skeleton), which is still: two frames, no breathing. Both
-- points are the cooked map's markers (Z4_LIFE_MK_Mila_NPC_*), on the floors at plan z -144.94 and -156.29; a marker's
-- yaw is where she faces, and a skeletal mesh faces its +Y [inference], so the mesh turns MESH_YAW more. One [LY] line a
-- change. A failure says so once a Lua load and leaves her a voice. Her actor's path is kept in FILE, so the next Lua
-- load (Ctrl+R) removes the one this load left.
local Doro=require('race.doro')
local Mila={}
local DIR='/Game/Art/Character/NPC/'
Mila.MESH=DIR..'CH_NPC_Kara/CH_NPC_Kara.CH_NPC_Kara'
Mila.CLIP=DIR..'CH_NPC_ScavengerFemale_A/Animation/Env_Scavenger_Corpse_Sitting_01_Idle.'
    ..'Env_Scavenger_Corpse_Sitting_01_Idle'
Mila.MESH_YAW=-90
Mila.PLACES={
    shelf={at={X=42847.1,Y=52406.74,Z=-15433.0},yaw=-95.0}, -- Z4_LIFE_MK_Mila_NPC_Shelf1_S10c_Sitting
    floor={at={X=54211.84,Y=43818.56,Z=-16568.0},yaw=85.0}, -- Z4_LIFE_MK_Mila_NPC_DriveRoom_S15b_SitsByNoa
}
local FILE='coop-mxiii-mila.txt'
-- o: log, read(name) and write(name,text) (a file of ours beside coop-settings.txt).
function Mila.new(o)
    local log=o.log
    local self={}
    local shown,place=nil,nil -- Doro.spawn's display, and where it stands.
    local failed,swept=false,false
    local function say_stop(why)
        failed=true
        log('STOP: Mila has no body, she stays a voice: '..tostring(why))
    end
    local function remove()
        if shown then
            local ok,why=pcall(Doro.remove,shown)
            if not ok then log('Mila: '..tostring(why)) end
        end
        shown,place=nil,nil
    end
    local function spawn(where,eve)
        local p=Mila.PLACES[where]
        local clip=assert(Doro.resolve(Mila.CLIP),'the sitting clip is missing on this PC')
        local d=Doro.spawn(eve:GetWorld(),p.at,{Pitch=0,Yaw=p.yaw+Mila.MESH_YAW,Roll=0},{path=Mila.MESH})
        local ok,why=pcall(function() d.mesh:PlayAnimation(clip,true) end)
        if not ok then
            pcall(Doro.remove,d)
            error(why,0)
        end
        shown,place=d,where
        o.write(FILE,d.path)
        log('Mila sits at '..where)
    end
    -- Once a second from zone_talks.lua. where: 'shelf', 'floor' or nil; eve: EVE, when where is given.
    function self.set(where,eve)
        if not swept then
            swept=true
            local path=o.read(FILE)
            if path and path~='' then pcall(Doro.sweep,path,Mila.MESH) end
        end
        if shown and (place~=where or not Doro.same(shown.actor,shown.path)) then remove() end
        if not where or shown or failed then return end
        local ok,why=pcall(spawn,where,eve)
        if not ok then say_stop(why) end
    end
    return self
end
return Mila
