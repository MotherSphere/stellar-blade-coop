-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's NPCs (world/maps/sboxion/sboxion.lua starts this part at each arrival and ticks it each 250 ms pass while
-- EVE's map is SBO Xion, after the rooms). Experimental: none of this has run in game.
-- An NPC of LIST is a display body in a room, as world/maps/matrix13/level/mila.lua makes Mila: a plain actor with one
-- SkeletalMeshComponent that loops a clip (world.body, core/actors.lua's spawn), collision off, no SB character, no
-- row, no AI. So nothing of it can fight, die or reach a save, SB shows no Talk prompt on it and each game makes its
-- own. The mesh and every clip of a row are on one skeleton, read from the store entries of the game's pakchunk0
-- (build 26123051): CH_NPC_EngineerMale and its six clips all import CH_NPC_EngineerMale_Skeleton.
-- Where it stands: a row's place and yaw are world numbers, made from the room's frame in its layout (room origin
-- plus the spot turned by the room's inward yaw). A skeletal mesh of SB faces its +Y [inference, as Mila's], so the
-- mesh turns MESH_YAW more.
-- When it is there: EVE within NEAR cm and the room's level loaded and visible (world.levels, asked again each WAIT
-- passes while it is not). A room the pak does not hold (o.gate, asked at each arrival) has no NPC and reads no
-- level. The body goes when she is FAR cm away. A body the engine dropped is removed and made again, DROPS times a
-- stay at most. A map change takes the actor with the world. coop off removes it.
-- The talk: EVE inside the room (past its door wall, by the room's frame) and within TALK cm of a body gets its line
-- once (o.say, the feed or the line above EVE). She gets it again only after she went AGAIN cm away. From the street
-- a wall stands between them, so nothing is said there.
-- coop xion npc: the clip (a number of the row's clips) and a turn of the mesh in degrees, picked by hand for the NPC
-- nearest to EVE, for this Lua load only, on its body at once. A pick also lets a body that failed try again.
-- A body that cannot be made says so once and is not tried again until the next arrival or a pick. An error in a pass
-- turns the part off with one log line until the next arrival. Each body's actor path is kept in the store
-- (coop-xion-npcs.txt), so the next Lua load (Ctrl+R) removes the bodies this one left.
-- tests/lua/world/maps/sboxion/npcs/npcs_test.lua covers it.
local U=require('core.unreal')
local Keep=require('core.keep')
local Npcs={NEAR=3000,FAR=3500,TALK=300,AGAIN=600,WAIT=8,DROPS=3,MESH_YAW=-90}
local ENGINEER='/Game/Art/Character/NPC/CH_NPC_EngineerMale/'
local function asset(dir,name) return dir..name..'.'..name end
local function clips(dir,names)
    local out={}
    for i,name in ipairs(names) do out[i]=asset(dir,name) end
    return out
end
-- name: the key of its words (ui/text: xion.<name> and xion.<name>_hello). room: the level it stands in. frame: the
-- room's origin (the middle of its door wall) and its inward yaw, as its layout gives them.
Npcs.LIST={
    -- The repairer of the repair shop D011, at the workbench with the tool board: the spot (132, -347) of the room's
    -- layout, facing the bench.
    {name='repairer',room='Xion_Rooms_D011',mesh=asset(ENGINEER,'CH_NPC_EngineerMale'),
        clips=clips(ENGINEER..'Animation/',{'N_Engineer_Work1','N_Engineer_Work2','N_Engineer_Work3',
            'N_Engineer_Dusting','N_Engineer_Snooping','N_Engineer_Idle'}),
        at={X=-10931.7,Y=3145.4,Z=414.0},yaw=-70,frame={X=-10650.4,Y=3388.3,yaw=-70}},
}
do
    local paths={}
    for _,n in ipairs(Npcs.LIST) do
        paths[#paths+1]=n.mesh
        for _,c in ipairs(n.clips) do paths[#paths+1]=c end
    end
    Keep.want(paths)
end
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end
local function far(n,at) return math.sqrt((at.X-n.at.X)^2+(at.Y-n.at.Y)^2+(at.Z-n.at.Z)^2) end
local function short(path) return path:match('[^.]+$') end
-- Is a place inside the NPC's room: past the door wall along the room's inward yaw.
local function inside(n,at)
    local a=math.rad(n.frame.yaw)
    return (at.X-n.frame.X)*math.cos(a)+(at.Y-n.frame.Y)*math.sin(a)>=0
end

-- o: log(m), world, the engine calls (world/maps/sboxion/engine.lua's body, body_clip, body_turn, body_same,
-- body_gone, body_sweep and levels; a fake in the tests), say(name) (shows the NPC's line; optional), store
-- (core/link.lua's store for the bodies' actor paths: save(line), load(); optional) and gate(umap) (true when the pak
-- holds the room level of that game path; optional: without it every room counts as held).
function Npcs.new(o)
    local log,world=o.log,o.world
    local store=o.store or {save=function() return true end,load=function() end}
    local off=nil -- The error that turned the part off until the next arrival.
    -- By row: {shown=<world.body's display>, failed=, spoke=, shut=<said>, wait=<passes>, drops=, absent=<no room>}.
    local state={}
    local pick={} -- By row: {clip=<a number of its clips>, turn=<degrees>}, coop xion npc's choice.
    local last=nil -- Where EVE was at the last pass.
    local self={}
    for i in ipairs(Npcs.LIST) do state[i],pick[i]={},{clip=1,turn=0} end
    local function yaw_of(i) return Npcs.LIST[i].yaw+Npcs.MESH_YAW+pick[i].turn end
    -- The shown bodies' actor paths in the store, <name>=<path> each.
    local function save()
        local parts={}
        for i,n in ipairs(Npcs.LIST) do
            if state[i].shown then parts[#parts+1]=n.name..'='..tostring(state[i].shown.path) end
        end
        pcall(store.save,table.concat(parts,' '))
    end
    local function remove(i)
        local s=state[i]
        if not s.shown then return end
        local ok,why=pcall(world.body_gone,s.shown)
        if not ok then log('npcs: '..Npcs.LIST[i].name..': '..U.why(why)) end
        s.shown=nil
        save()
    end
    -- Is the room's level loaded and visible: true, or false and why.
    local function level_up(room)
        for _,l in ipairs(world.levels()) do
            if l.name==room then
                if l.loaded and l.visible then return true end
                return false,string.format('its level %s reads loaded %s visible %s',room,tostring(l.loaded),
                    tostring(l.visible))
            end
        end
        return false,'its level '..room..' is not on the streaming list'
    end
    local function show(i)
        local n,s=Npcs.LIST[i],state[i]
        s.wait=(s.wait or 0)-1
        if s.wait>0 then return end
        local up,why=level_up(n.room)
        if not up then
            s.wait=Npcs.WAIT
            if not s.shut then
                s.shut=true
                log('npcs: '..n.name..' stays away: '..why)
            end
            return
        end
        local clip=n.clips[pick[i].clip]
        local ok,d=pcall(world.body,n.at,yaw_of(i),n.mesh)
        if ok then
            local played,e=pcall(world.body_clip,d,clip)
            if not played then
                pcall(world.body_gone,d)
                ok,d=false,e
            end
        end
        if not ok then
            s.failed=true
            return log('npcs: '..n.name..' has no body: '..U.why(d))
        end
        s.shown=d
        save()
        log(string.format('npcs: %s stands in %s at %s, yaw %.0f, clip %s',n.name,n.room,place(n.at),yaw_of(i),
            short(clip)))
    end
    local function tick(at)
        last=at
        for i,n in ipairs(Npcs.LIST) do
            local s,d=state[i],far(n,at)
            if s.shown and not world.body_same(s.shown) then -- The engine dropped its actor.
                remove(i)
                s.drops=(s.drops or 0)+1
                if s.drops>=Npcs.DROPS then
                    s.failed=true
                    log(string.format('npcs: %s lost its body %d times: not made again in this stay',n.name,s.drops))
                end
            end
            if s.shown and d>Npcs.FAR then remove(i)
            elseif not s.shown and not s.failed and not s.absent and d<=Npcs.NEAR then show(i) end
            if s.shown and d<=Npcs.TALK and inside(n,at) then
                if not s.spoke then
                    s.spoke=true
                    if o.say then pcall(o.say,n.name) end
                    log(string.format('npcs: %s spoke, EVE %.0f cm away',n.name,d))
                end
            elseif d>Npcs.AGAIN then s.spoke=false end
        end
    end
    -- Each 250 ms pass while EVE's map is SBO Xion. at: where EVE is.
    function self.tick(at)
        if off or not at then return end
        local ok,e=pcall(tick,at)
        if ok then return end
        off=U.why(e)
        for i in ipairs(Npcs.LIST) do pcall(remove,i) end
        log('npcs: off until the next arrival: error ('..off..')')
    end
    -- Each arrival in SBO Xion: on, nothing kept of the stay before but the picks. The world of the stay before is
    -- gone with its actors. A body the store still names, left by an earlier Lua load, is removed.
    function self.arrive()
        off,last=nil,nil
        for i,n in ipairs(Npcs.LIST) do
            state[i]={}
            if o.gate then
                local asked,has=pcall(o.gate,'/Game/SBO_World/Rooms/'..n.room)
                if not (asked and has) then
                    state[i].absent=true
                    log('npcs: '..n.name..' stays away: this pak does not hold '..n.room)
                end
            end
        end
        local ok,line=pcall(store.load)
        if not ok then return end
        for name,path in (line or ''):gmatch('(%S-)=(%S+)') do
            for _,n in ipairs(Npcs.LIST) do
                if n.name==name then pcall(world.body_sweep,path,n.mesh) end
            end
        end
        save()
    end
    -- A map change or coop off: every body gone. A body of a world that is gone is not called.
    function self.stop()
        for i in ipairs(Npcs.LIST) do pcall(remove,i) end
        last=nil
    end
    -- One part of coop xion status.
    function self.status()
        if off then return 'npcs off' end
        local n=0
        for i in ipairs(Npcs.LIST) do if state[i].shown then n=n+1 end end
        return string.format('npcs %d of %d shown',n,#Npcs.LIST)
    end
    -- coop xion npc [<n> | turn <degrees>]: the clip or the turn of the NPC nearest to EVE.
    function self.command(what,value)
        local i,best=1,math.huge
        for k,n in ipairs(Npcs.LIST) do
            local d=last and far(n,last) or k
            if d<best then i,best=k,d end
        end
        local n,s,p=Npcs.LIST[i],state[i],pick[i]
        local names={}
        for k,c in ipairs(n.clips) do names[k]=k..' '..short(c) end
        local usage='Use: coop xion npc [<n> | turn <-180 to 180>]; clips of the '..n.name..': '
            ..table.concat(names,', ')
        if what=='turn' then
            local x=tonumber(value)
            if not x or x<-180 or x>180 then return false,usage end
            p.turn=x
        elseif what~=nil then
            local k=math.tointeger(tonumber(what))
            if not (k and n.clips[k]) or value~=nil then return false,usage end
            p.clip=k
        end
        local shown=s.shown and world.body_same(s.shown)
        local text=string.format('%s %s, clip %d %s, turned %.0f',n.name,
            shown and 'shown' or s.failed and 'has no body' or 'not shown',p.clip,short(n.clips[p.clip]),p.turn)
        if what==nil then return true,text..'. '..usage end
        s.failed,s.wait=false,nil
        if shown then
            local ok,why=pcall(function()
                if what=='turn' then world.body_turn(s.shown,n.at,yaw_of(i))
                else world.body_clip(s.shown,n.clips[p.clip]) end
            end)
            if not ok then return false,n.name..': '..U.why(why) end
        end
        log('npcs: '..text)
        return true,text
    end
    return self
end
return Npcs
