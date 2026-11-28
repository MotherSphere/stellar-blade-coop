-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's NPCs (world/maps/sboxion/npcs/npcs.lua) over a fake world: lua5.4 tests/lua/world/maps/sboxion/npcs/
-- npcs_test.lua
-- The list: each NPC has a name with its words in every language, a room level, a mesh, clips the keep takes and a
-- line that fits the feed's 200 bytes. Its own spot is on its side of its frame. The repairer stands at the spot of
-- D011's layout. Ten NPCs of the underground district's plate follow, each at the plate layout's place and yaw, on
-- the level of the floor it stands on (Under_P1_Streets or Under_P1_Shops), inside the district's box of data.lua and
-- over its floor. The five in a room have that room's door wall as their frame, the five in the open the plate's
-- edge. A district NPC is made once EVE is near and its own level is there. It talks to her beside it.
-- The body: none while EVE is far or the room's level is not there (said once, asked again each WAIT passes), none
-- for a room the pak does not hold (one line an arrival, no read of the levels). Within NEAR with the level up it is
-- made at the row's place, turned by MESH_YAW, on the first clip. Its actor path goes to the store. Past FAR it
-- goes. A body the engine dropped is removed and made again, DROPS times a stay at most. A body or a clip that fails
-- says so once, leaves nothing behind and is not tried again in the stay.
-- The talk: the line once within TALK inside the room, again only after EVE went past AGAIN. Nothing is said to
-- EVE on the street side of the door wall.
-- coop xion npc: the state with no word, a clip by its number and a turn in degrees, on the body at once and on the
-- next one; a pick lets a failed body try again; anything else is refused with the usage.
-- An arrival removes the bodies an earlier Lua load left in the store. stop() removes every body. An error in a
-- pass turns the part off with one line until the next arrival.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Npcs=require('world.maps.sboxion.npcs.npcs')
local Keep=require('core.keep')
local T=require('ui.text')
assert(Npcs.NEAR==3000 and Npcs.FAR==3500 and Npcs.TALK==300 and Npcs.AGAIN==600 and Npcs.WAIT==8 and Npcs.DROPS==3
    and Npcs.MESH_YAW==-90)
local LIST=Npcs.LIST
assert(#LIST>=1)
local seen,cultures={},0
for _,words in pairs(T) do if type(words)=='table' and words.xion then cultures=cultures+1 end end
assert(cultures==22,'The words in the 22 language files: '..cultures)
for _,n in ipairs(LIST) do
    assert(not seen[n.name],'A name once: '..n.name)
    seen[n.name]=true
    assert(n.room:find('^Xion_Rooms_D%d%d%d$') or n.room=='Under_P1_Streets' or n.room=='Under_P1_Shops',n.room)
    local a=math.rad(n.frame.yaw)
    assert((n.at.X-n.frame.X)*math.cos(a)+(n.at.Y-n.frame.Y)*math.sin(a)>0,n.name..' stands on its side of its frame')
    assert(Keep.path_ok(n.mesh) and #n.clips>=1,n.name)
    for _,c in ipairs(n.clips) do assert(Keep.path_ok(c),c) end
    for culture,words in pairs(T) do
        local x=type(words)=='table' and words.xion
        if x then
            assert(x[n.name] and x[n.name..'_hello'],culture..' lacks '..n.name)
            local line=string.format(x.says,x[n.name],x[n.name..'_hello'])
            assert(#line<=200,culture..': '..#line..' bytes')
        end
    end
end
local R=LIST[1]
assert(R.name=='repairer' and R.room=='Xion_Rooms_D011' and R.yaw==-70 and #R.clips==6)
-- D011's frame (its layout): the room origin plus the spot (132, -347.4) turned by the inward yaw of -70 degrees.
local a=math.rad(-70)
local x,y=-10650.4+132*math.cos(a)+347.4*math.sin(a),3388.3+132*math.sin(a)-347.4*math.cos(a)
assert(math.abs(R.at.X-x)<1 and math.abs(R.at.Y-y)<1 and math.abs(R.at.Z-413.97)<1,'The spot at the bench')
assert(R.frame.X==-10650.4 and R.frame.Y==3388.3 and R.frame.yaw==-70,'The room frame of the layout')
-- The plate's ten, in the layout's order, by the level of the floor each stands on and by its frame: the plate's edge
-- at grid v 35.5 (EDGE) or the door wall of its room.
local EDGE={X=-220.5,Y=4449.2,yaw=130}
local PLATE={
    plate_gate_guard={'Under_P1_Streets',-27.9,6333.9,-596.0,220,EDGE},
    plate_storyteller={'Under_P1_Streets',-1188.6,6534.8,-1107.0,310,EDGE},
    plate_porter={'Under_P1_Shops',-664.9,5381.7,-1103.0,220,{X=-766.9,Y=5161.6,yaw=43}},
    plate_welder={'Under_P1_Shops',-649.6,7666.0,-1103.0,143,EDGE},
    plate_stall_keeper_1={'Under_P1_Streets',-2437.0,5409.0,-1105.0,198,EDGE},
    plate_stall_keeper_2={'Under_P1_Streets',-584.6,6624.0,-1107.0,159,EDGE},
    plate_stall_keeper_3={'Under_P1_Shops',-1158.5,4445.4,-1104.0,47,{X=-932.7,Y=4242.1,yaw=137}},
    plate_resident_a={'Under_P1_Streets',-3281.4,5979.7,-1104.0,297,{X=-2906.6,Y=6163.8,yaw=207}},
    plate_mechanic={'Under_P1_Shops',-1984.4,4091.8,-1105.0,305,{X=-2180.3,Y=4369.8,yaw=305}},
    plate_resident_b={'Under_P1_Shops',-3733.0,6984.6,-1103.0,224,{X=-3505.1,Y=7274.9,yaw=224}}}
local D=require('world.maps.sboxion.data')
assert(#LIST==11 and LIST[2].name=='plate_gate_guard' and LIST[11].name=='plate_resident_b','The repairer, then the ten')
for i=2,11 do
    local n=LIST[i]
    local want=PLATE[n.name]
    assert(want and want[1]==n.room and n.at.X==want[2] and n.at.Y==want[3] and n.at.Z==want[4] and n.yaw==want[5]
        and n.frame.X==want[6].X and n.frame.Y==want[6].Y and n.frame.yaw==want[6].yaw,n.name..' in '..n.room)
    local b,a=D.UNDER,math.rad(D.UNDER.yaw)
    local u,v=(n.at.X*math.cos(a)+n.at.Y*math.sin(a))/100,(n.at.Y*math.cos(a)-n.at.X*math.sin(a))/100
    assert(u>b.u[1] and u<b.u[2] and v>b.v[1] and v<b.v[2] and n.at.Z>b.floor,n.name..' stands in the district\'s box')
end
local G=LIST[2]
assert(G.mesh=='/Game/Art/Character/NPC/CH_NPC_XionGuard/CH_NPC_XionGuard.CH_NPC_XionGuard'
    and G.clips[1]=='/Game/Art/Character/NPC/CH_NPC_XionGuard/Animation/N_XionGuard_KeepWatch1.N_XionGuard_KeepWatch1',
    'The gate guard at the foot of the arch stair')
-- The cook at the cantine: his own name and line in English, the name of the role he has there.
assert(T.en.xion.plate_stall_keeper_3=='Cook' and T.en.xion.plate_resident_a_hello:find('dartboard',1,true),
    'The lines of the cantine and of the house')
assert(LIST[8].mesh=='/Game/Art/Character/NPC/CH_NPC_CitizenMale_A/CH_NPC_CitizenMale_C.CH_NPC_CitizenMale_C',
    'The third stall keeper: mesh C in the folder of CitizenMale_A')

local logs,bodies,gone,said,saved,swept,level_reads
local level,body_error,clip_error,dropped,levels_error,pak
local world={
    levels=function()
        level_reads=level_reads+1
        if levels_error then error(levels_error,0) end
        return {{name='Xion_P',loaded=true,visible=true},level}
    end,
    body=function(at,yaw,mesh)
        if body_error then error(body_error,0) end
        local d={at=at,yaw=yaw,mesh=mesh,path='/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_'..(#bodies+1)}
        bodies[#bodies+1]=d
        return d
    end,
    body_clip=function(d,clip)
        if clip_error then error(clip_error,0) end
        d.clip=clip
    end,
    body_turn=function(d,at,yaw) d.at,d.yaw=at,yaw end,
    body_same=function(d) return not dropped and not d.gone end,
    body_gone=function(d) d.gone=true; gone[#gone+1]=d end,
    body_sweep=function(path,mesh) swept[#swept+1]={path=path,mesh=mesh}; return true end,
}
local stored=nil
local store={save=function(line) saved[#saved+1]=line; stored=line; return true end,load=function() return stored end}
local npcs
local function fresh(kept)
    logs,bodies,gone,said,saved,swept,level_reads={},{},{},{},{},{},0
    level={name=R.room,loaded=true,visible=true}
    body_error,clip_error,dropped,levels_error=nil,nil,false,nil
    stored=kept
    npcs=Npcs.new({log=function(m) logs[#logs+1]=m end,world=world,store=store,
        say=function(name) said[#said+1]=name end,gate=pak})
    npcs.arrive()
end
-- A place d cm from the repairer, further into the room (his spot is 132 cm inside the door wall). The limits are
-- tried 1 cm on each side, never on the number itself: a place worked out with a sine is not exact.
local IN=math.rad(R.frame.yaw)
local function at(d) return {X=R.at.X+d*math.cos(IN),Y=R.at.Y+d*math.sin(IN),Z=R.at.Z} end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end end
local function pass(d,n) for _=1,n or 1 do npcs.tick(at(d)) end end

-- Far: nothing, no read of the levels.
fresh()
pass(Npcs.NEAR+1,3)
assert(#bodies==0 and level_reads==0 and npcs.status()=='npcs 0 of '..#LIST..' shown')
-- Near with the level up: the body, turned, on the first clip, its path kept.
pass(Npcs.NEAR-1)
assert(#bodies==1 and bodies[1].mesh==R.mesh and bodies[1].yaw==R.yaw+Npcs.MESH_YAW and bodies[1].clip==R.clips[1]
    and bodies[1].at.X==R.at.X,'The body at its place')
assert(saved[#saved]=='repairer='..bodies[1].path and npcs.status()=='npcs 1 of '..#LIST..' shown')
assert(logs[#logs]=='npcs: repairer stands in Xion_Rooms_D011 at (-10932, 3145, 414), yaw -160, clip N_Engineer_Work1',
    logs[#logs])
pass(Npcs.NEAR-1,5)
assert(#bodies==1 and level_reads==1,'One body, the levels read once')
-- The talk: once within TALK, again only after she went past AGAIN.
pass(Npcs.TALK+1)
assert(#said==0)
pass(Npcs.TALK-1,3)
assert(#said==1 and said[1]=='repairer' and logged('npcs: repairer spoke, EVE 299 cm away'))
pass(Npcs.AGAIN-1)
pass(Npcs.TALK-1)
assert(#said==1,'Not again before she went past AGAIN')
pass(Npcs.AGAIN+1)
pass(Npcs.TALK-1)
assert(#said==2,'Again after she went away')
-- The street side of the door wall: 200 cm from him, yet nothing is said through the wall.
pass(Npcs.AGAIN+1)
pass(-200,3)
assert(#said==2,'Nothing through the wall')
pass(-100)
assert(#said==3,'Inside the room again')
-- Past FAR the body goes. Between NEAR and FAR nothing changes.
pass(Npcs.FAR-1)
assert(#gone==0)
pass(Npcs.FAR+1)
assert(#gone==1 and gone[1]==bodies[1] and saved[#saved]=='' and npcs.status()=='npcs 0 of '..#LIST..' shown')
pass(Npcs.NEAR+1,3)
assert(#bodies==1,'No body between NEAR and FAR once it went')
-- A body the engine dropped is removed through the engine's own check and made again, DROPS times a stay at most.
pass(Npcs.NEAR-1)
assert(#bodies==2)
dropped=true
pass(Npcs.NEAR-1)
assert(#bodies==3 and #gone==2 and gone[2]==bodies[2],'Removed and made again in the same pass')
pass(Npcs.NEAR-1,5)
assert(#bodies==1+Npcs.DROPS and logs[#logs]=='npcs: repairer lost its body 3 times: not made again in this stay',
    logs[#logs])
dropped=false
pass(Npcs.NEAR-1,5)
assert(#bodies==1+Npcs.DROPS,'No more in this stay')

-- The room's level is not there: no body, one line, asked again each WAIT passes.
fresh()
level.visible=false
pass(100,Npcs.WAIT*2)
assert(#bodies==0 and level_reads==2,'Asked once each WAIT passes: '..level_reads)
assert(#logs==1 and logs[1]=='npcs: repairer stays away: its level Xion_Rooms_D011 reads loaded true visible false',
    logs[1])
level.visible=true
pass(100,Npcs.WAIT)
assert(#bodies==1,'There once the level is')
fresh()
level={name='Xion_Rooms_D999',loaded=true,visible=true}
pass(100)
assert(#bodies==0 and logs[1]=='npcs: repairer stays away: its level Xion_Rooms_D011 is not on the streaming list')

-- A room the pak does not hold: one line an arrival, no body, no read of the levels. A gate that raises counts the
-- same.
for _,gate in ipairs({function() return nil,'no such room' end,function() error('boom',0) end}) do
    pak=gate
    fresh()
    assert(#logs==#LIST and logs[1]=='npcs: repairer stays away: this pak does not hold Xion_Rooms_D011'
        and logs[11]=='npcs: plate_resident_b stays away: this pak does not hold Under_P1_Shops',logs[1])
    pass(100,20)
    assert(#bodies==0 and level_reads==0 and #logs==#LIST)
end
local asked_for=nil
local asks={}
pak=function(umap) asked_for=asked_for or umap; asks[#asks+1]=umap; return true end
fresh()
pass(100)
assert(#bodies==1 and asked_for=='/Game/SBO_World/Rooms/Xion_Rooms_D011' and #asks==#LIST
    and asks[2]=='/Game/SBO_World/Rooms/Under_P1_Streets' and asks[11]=='/Game/SBO_World/Rooms/Under_P1_Shops',
    'The gate is asked for each NPC\'s level by its game path')
pak=nil
-- A body that cannot be made: one line, nothing left, no second try in the stay.
fresh()
body_error='CH_NPC_EngineerMale is missing on this PC'
pass(100,20)
assert(#bodies==0 and #logs==1
    and logs[1]=='npcs: repairer has no body: CH_NPC_EngineerMale is missing on this PC',logs[1])
body_error=nil
pass(100,20)
assert(#bodies==0,'No second try in this stay')
npcs.arrive()
pass(100)
assert(#bodies==1,'The next arrival tries again')
-- A clip that cannot play: the body made for it is removed.
fresh()
clip_error='N_Engineer_Work1 is missing on this PC'
pass(100)
assert(#bodies==1 and #gone==1 and npcs.status()=='npcs 0 of '..#LIST..' shown'
    and logs[1]=='npcs: repairer has no body: N_Engineer_Work1 is missing on this PC',logs[1])

-- coop xion npc.
fresh()
local ok,line=npcs.command()
assert(ok and line:find('repairer not shown, clip 1 N_Engineer_Work1, turned 0. Use: coop xion npc',1,true),line)
assert(line:find('6 N_Engineer_Idle',1,true),'The clips by number')
for _,bad in ipairs({{'7'},{'0'},{'x'},{'1.5'},{'2','3'},{'turn'},{'turn','181'},{'turn','x'}}) do
    ok,line=npcs.command(bad[1],bad[2])
    assert(not ok and line:find('^Use: coop xion npc'),tostring(bad[1]))
end
pass(100)
ok,line=npcs.command('4')
assert(ok and line=='repairer shown, clip 4 N_Engineer_Dusting, turned 0' and bodies[1].clip==R.clips[4],line)
ok,line=npcs.command('turn','90')
assert(ok and line=='repairer shown, clip 4 N_Engineer_Dusting, turned 90'
    and bodies[1].yaw==R.yaw+Npcs.MESH_YAW+90,line)
pass(Npcs.FAR+1)
pass(100)
assert(#bodies==2 and bodies[2].clip==R.clips[4] and bodies[2].yaw==R.yaw+Npcs.MESH_YAW+90,'The picks on the next body')
npcs.arrive()
pass(100)
assert(bodies[#bodies].clip==R.clips[4],'An arrival keeps the picks')
-- A pick lets a body that failed try again.
fresh()
body_error='no'
pass(100)
body_error=nil
assert(npcs.command('2'))
pass(100)
assert(#bodies==1 and bodies[1].clip==R.clips[2])
-- A pick whose call raises is refused with why.
clip_error='gone'
ok,line=npcs.command('3')
assert(not ok and line=='repairer: gone',line)

-- An arrival removes the bodies an earlier Lua load left.
fresh('repairer=/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_9 nobody=/Game/X.X:PersistentLevel.Actor_1')
assert(#swept==1 and swept[1].path=='/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_9' and swept[1].mesh==R.mesh
    and stored=='','The repairer\'s old body alone, then an empty store')
npcs.arrive()
assert(#swept==1,'The store is empty after it')
-- stop(): every body gone.
pass(100)
npcs.stop()
assert(#gone==1 and npcs.status()=='npcs 0 of '..#LIST..' shown')
-- An error in a pass: off with one line until the next arrival, the body removed.
fresh()
pass(100)
levels_error=nil
dropped=false
world.body_same=function() error('boom',0) end
pass(100)
assert(logs[#logs]=='npcs: off until the next arrival: error (boom)' and npcs.status()=='npcs off',logs[#logs])
assert(#gone==1 and gone[1]==bodies[1],'The body is removed when the part turns off')
world.body_same=function(d) return not dropped and not d.gone end
local lines=#logs
pass(100,5)
assert(#logs==lines,'Nothing while off')
npcs.arrive()
pass(100)
assert(npcs.status()=='npcs 1 of '..#LIST..' shown','On again at the next arrival')
-- No place of EVE: nothing.
npcs.tick(nil)

-- The district: a pak that holds the rooms only keeps the ten away. With the plate's levels in the pak and
-- Under_P1_Streets there, EVE beside the gate guard gets the four bodies of that level within NEAR: the guard, the
-- storyteller and the two stall keepers in the open. The guard talks to her, then the storyteller when she walks up to
-- him. There the resident of the house comes within NEAR. Those of Under_P1_Shops stay away while that level is not
-- there.
pak=function(umap) return umap:find('/Xion_Rooms_',1,true)~=nil end
fresh()
assert(#logs==10 and logs[1]=='npcs: plate_gate_guard stays away: this pak does not hold Under_P1_Streets',logs[1])
local guard={X=G.at.X+100*math.cos(math.rad(G.frame.yaw)),Y=G.at.Y+100*math.sin(math.rad(G.frame.yaw)),Z=G.at.Z+95}
npcs.tick(guard)
assert(#bodies==0 and level_reads==0,'No district NPC without the district in the pak')
pak=function() return true end
fresh()
level={name='Under_P1_Streets',loaded=true,visible=true}
npcs.tick(guard)
assert(#bodies==4 and bodies[1].mesh==G.mesh and bodies[1].yaw==G.yaw+Npcs.MESH_YAW and bodies[1].clip==G.clips[1],
    'The gate guard\'s body first: '..#bodies)
assert(#said==1 and said[1]=='plate_gate_guard'
    and logged('npcs: plate_gate_guard stands in Under_P1_Streets at (-28, 6334, -596), yaw 130, clip '
        ..'N_XionGuard_KeepWatch1')
    and logged('npcs: plate_porter stays away: its level Under_P1_Shops is not on the streaming list'),logs[#logs])
local T=LIST[3]
npcs.tick({X=T.at.X+100*math.cos(math.rad(T.frame.yaw)),Y=T.at.Y+100*math.sin(math.rad(T.frame.yaw)),Z=T.at.Z+95})
assert(T.name=='plate_storyteller' and #said==2 and said[2]=='plate_storyteller' and #bodies==5
    and logged('npcs: plate_resident_a stands in Under_P1_Streets'),'The storyteller on the placette')
-- The lower street over the guard, at G18's height: too far to talk, the bodies stay shown.
npcs.tick({X=guard.X,Y=guard.Y,Z=-228+95})
npcs.tick({X=guard.X,Y=guard.Y,Z=-228+95})
assert(#said==2 and #bodies==5 and #gone==0,'Nothing said from the street')
assert(npcs.status()=='npcs 5 of 11 shown',npcs.status())
pak=nil
print('sboxion_npcs_test ok')
