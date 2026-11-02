-- Mila as a body in world 2800 (experimental, untested in game): matrix13/quest/zone_talks.lua says where she is, at the
-- shelf 1 recess from scene 4E on and on the drive room floor from scene 4N on. A display only, as race/doro.lua makes
-- them: a plain actor with one SkeletalMeshComponent, collision off, no SB character, no row, no AI, so nothing of her
-- can fight, die or reach a save. The mesh is CH_NPC_Kara, the game's model of Kaya's sister; the pose is the sitting
-- clip shipped for that skeleton (CH_NPC_ScavengerFemale_A_Skeleton), which is still: two frames, no breathing. Both
-- points are the cooked map's markers (Z4_LIFE_MK_Mila_NPC_*), on the floors at plan z -144.94 and -156.29; a marker's
-- yaw is where she faces, and a skeletal mesh faces its +Y [inference], so the mesh turns MESH_YAW more. One [LY] line a
-- change. A failure says so once a Lua load and leaves her a voice. Her actor's path is kept in FILE, so the next Lua
-- load (Ctrl+R) removes the one this load left. That sitting clip is dead Kara's corpse pose, so coop mxiii mila
-- (command()) picks another of POSES and her scale by hand, for this Lua load only; vanilla Kara stands at scale 0.9.
local Doro=require('race.doro')
local Mila={}
local DIR='/Game/Art/Character/NPC/'
Mila.MESH=DIR..'CH_NPC_Kara/CH_NPC_Kara.CH_NPC_Kara'
Mila.CLIP=DIR..'CH_NPC_ScavengerFemale_A/Animation/Env_Scavenger_Corpse_Sitting_01_Idle.'
    ..'Env_Scavenger_Corpse_Sitting_01_Idle'
-- The clips command() picks among, all four on CH_NPC_ScavengerFemale_A_Skeleton (read from their cooked imports): the
-- corpse sit looped (the default, the only sitting loop), two cutscene clips held still at the second asked, and a
-- standing idle looped.
local EVENT='/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/E04/'
local function asset(dir,name) return dir..name..'.'..name end
Mila.POSES={
    {name='corpse sit',path=Mila.CLIP,loop=true},
    {name='Enya music scene (34.2 s)',path=asset(EVENT..'MV_Quest_Sub_007_Enya_listeningtomusic/',
        'MV_Quest_Sub_007_Enya_listeningtomusic_ScavengerFemale_A')},
    {name='Quest_Sub_026_02 scene (70.6 s)',path=asset(EVENT..'MV_Seq_Quest_Sub_026_02/',
        'MV_Seq_Quest_Sub_026_02_Scavenger_C_01')},
    {name='standing idle',path=asset(DIR..'CH_NPC_ScavengerFemale_A/Animation/','N_Scavenger_Idle1'),loop=true},
}
Mila.SCALE=0.9 -- The vanilla Kara actor's.
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
    local pose,at,scale=1,0,Mila.SCALE -- command()'s choice: a key of POSES, where a held clip stops (s), her scale.
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
    local function clip()
        local p=Mila.POSES[pose]
        return assert(Doro.resolve(p.path),'the '..p.name..' clip is missing on this PC'),p
    end
    -- The chosen clip and scale on a body's mesh: a looped clip plays, a held one stops at its second.
    local function dress(d,c,p)
        d.mesh:PlayAnimation(c,p.loop==true)
        d.mesh:SetPlayRate(p.loop and 1 or 0) -- Back to 1 after a held clip.
        if not p.loop then d.mesh:SetPosition(at,false) end
        d.mesh:SetRelativeScale3D({X=scale,Y=scale,Z=scale})
    end
    local function spawn(where,eve)
        local p=Mila.PLACES[where]
        local c,pick=clip()
        local d=Doro.spawn(eve:GetWorld(),p.at,{Pitch=0,Yaw=p.yaw+Mila.MESH_YAW,Roll=0},{path=Mila.MESH})
        local ok,why=pcall(dress,d,c,pick)
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
    -- coop mxiii mila [<n> [<second>]] | scale <x>: her pose (a key of POSES; a held clip at that second, 0 unless
    -- given) or her scale (0.5 to 1.5), on her body at once when she is shown, else when she next appears. Kept for
    -- this Lua load only; a new choice also lets a body that failed try again.
    function self.command(what,value)
        local list={}
        for i,p in ipairs(Mila.POSES) do list[#list+1]=i..' '..p.name end
        local usage='Use: coop mxiii mila <n> [second] | scale <0.5-1.5>; poses: '..table.concat(list,', ')
        if what=='scale' then
            local x=tonumber(value)
            if not x or x<0.5 or x>1.5 then return false,usage end
            scale=x
        elseif what~=nil then
            local n,t=math.tointeger(tonumber(what)),tonumber(value or 0)
            if not (n and Mila.POSES[n]) or not t or t<0 or value~=nil and Mila.POSES[n].loop then
                return false,usage
            end
            pose,at=n,t
        end
        failed=false
        local p=Mila.POSES[pose]
        local text=string.format('Mila: pose %d, %s%s, scale %.2f',pose,p.name,
            p.loop and '' or string.format(' held at %.1f s',at),scale)
        if what==nil then return true,text..'. '..usage end
        if shown and Doro.same(shown.actor,shown.path) then
            local ok,why=pcall(function() dress(shown,clip()) end)
            if not ok then return false,'Mila: '..tostring(why) end
        else
            text=text..' (she shows in zone 4 from scene 4E)'
        end
        log(text)
        return true,text
    end
    return self
end
return Mila
