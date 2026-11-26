-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Tetrapod's door in SBO Xion (world/maps/sboxion/sboxion.lua ticks this part each 250 ms pass while EVE's map is
-- SBO Xion).
-- SB keeps the inside of the Tetrapod away from the ship of the hangar: one blueprint actor, BP_Env_TetraPod3_2 of
-- E04_Area05_B_LD, about 540 m from it, with its own lights and its own point, TeleportPoint_XionTetrapodInside. SB
-- sends the player there by a warp from the Wasteland (EventZoneWarpTable row WLA_40_E_ZoneWarp_001) and brings her
-- back to the hangar at Xion_Camp_10. Its zone events run in Zone_Xion_10 only, so in Zone_SBO_Xion nothing opens the
-- ship: the doorway of the hangar shows SB's entrance fog and leads nowhere.
-- This part is the way in and the way out. EVE standing STAY passes in a row in the doorway of the hangar (data.lua's
-- DOOR) is put inside (IN). Standing STAY passes in front of the ship's right door, inside (HATCH), she is put at SB's
-- point in front of the Tetrapod (OUT). Each move is the recovery's: SB's black first (world.black, the fade of SB's
-- own warps), then world.put (K2_TeleportTo, then StopMovementImmediately) LEAD passes later, LIFT cm over the point,
-- whatever the black's call did. After a move nothing is looked at for HOLD passes.
-- The floor: SB's blueprint gives the ship's 124 parts the profile NoCollision, so in the first game test (25
-- November 2026) EVE fell through it twice and the recovery brought her back. The way in now asks world.ship(true)
-- before the move: every part gets SB's profile BlockAll (engine.lua's ship says why the profile). The way out and
-- coop off ask world.ship(false): the ship as SB ships it.
-- E04_Area05_B_LD is streamed by volume as SB ships it (data.lua's VOLUMED), so the ship may come in after EVE. After
-- the way in she is watched until she walks: DROP cm under the point she is put on it again, the ship is asked again
-- on each pass while its last call wrote no part and a black that is up at once comes every AGAIN passes. After SETTLE
-- passes with no floor she is put back outside. A recovery that moved her out of the ship ends the watch.
-- No part written is not only a ship not found: after a respawn in the game test of 26 November 2026 the actor was in
-- memory and the call before the move wrote 0 parts. SB showed E04_Area05_B_LD only once she was inside.
-- The probe (coop xion tetrapod probe), a test tool to find what kills EVE in the ship: with the 124 parts made solid
-- as she arrived she was dead one pass later in the third game test (26 November 2026), 7 cm from the point. With no
-- part solid she fell and lived. The probe puts the ship back as SB ships it, then makes the same move under SB's
-- black. It puts her on the point again as the watch does. Once the ship's parts are in memory (world.parts, asked
-- each pass, SETTLE passes at most) it makes one more part solid each pass (world.part), in the engine's order, from
-- part n or part n alone. A part the engine names otherwise now is not written: the door goes off. Each write is one
-- log line with EVE's place, movement mode and life (the life= word of the status text's sboxionwarp line, the one
-- recover.lua reads). At the first life read of 3 to 5 (recover.lua's death rule) it names the last two parts written
-- and writes no more. The recovery handles the death. LIVE passes after the last part with her alive it says so and
-- ends. She is put back outside if she does not stand then. The way out and coop off put the ship back as SB ships it
-- too. A probe that holds her in falling mode for 10 s may see SB's own fall timer kill her (recover.lua): its death
-- line counts the passes she did not walk.
-- busy: the recovery waits (photo mode, a cutscene, a warp, another zone) or handles a fall or a death
-- (recover.lua's busy). Such a pass counts nothing and asks no move. A move already asked is still made. The watch
-- and the probe run on such passes too.
-- An error in a pass turns the door off with one log line until the next arrival.
-- tests/lua/world/maps/sboxion/tetrapod_test.lua covers it.
local U=require('core.unreal')
local D=require('world.maps.sboxion.data')
local T=D.TETRAPOD
local Tetrapod={}
local USE='Use: coop xion tetrapod [in|out|probe [<n>|only <n>]]'
local GROUND={[1]=true,[2]=true} -- EMovementMode: Walking, NavWalking.
local LIVE=8 -- Passes after the probe's last part before it says EVE lives: she died one pass after the parts.
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end
local function turn() local a=math.rad(T.SHIP.Yaw); return math.cos(a),math.sin(a) end
-- A point of the ship frame in the world.
function Tetrapod.world(p)
    local c,s=turn()
    return {X=T.SHIP.X+p.x*c-p.y*s,Y=T.SHIP.Y+p.x*s+p.y*c,Z=T.SHIP.Z+p.z}
end
-- A point of the world in the ship frame.
function Tetrapod.ship(at)
    local c,s=turn()
    local dx,dy=at.X-T.SHIP.X,at.Y-T.SHIP.Y
    return {x=dx*c+dy*s,y=-dx*s+dy*c,z=at.Z-T.SHIP.Z}
end
local function within(p,box,a,b,c)
    return p[a]>=box.lo[a] and p[a]<=box.hi[a] and p[b]>=box.lo[b] and p[b]<=box.hi[b] and p[c]>=box.lo[c]
        and p[c]<=box.hi[c]
end
-- The box EVE stands in: 'door' (the doorway of the hangar), 'hatch' (in front of the ship's right door), or nil.
local function box_of(at)
    if within(at,T.DOOR,'X','Y','Z') then return 'door' end
    if within(Tetrapod.ship(at),T.HATCH,'x','y','z') then return 'hatch' end
end
-- Where a move ends and the yaw EVE gets there, -180 to 180. The probe's move ends at the point inside too.
local function target(to)
    if to=='out' then return {X=T.OUT.X,Y=T.OUT.Y,Z=T.OUT.Z},T.OUT.Yaw end
    return Tetrapod.world(T.IN),(T.SHIP.Yaw+T.IN.yaw+180)%360-180
end
-- coop xion tetrapod probe [<n>|only <n>]: the first part to make solid and whether it is the only one, or nil for
-- other words or a part out of 1 to PARTS.
local function probe_words(a,b,c)
    local only=a=='only'
    if c~=nil or only and b==nil or not only and b~=nil then return nil end
    local word=only and b or a
    local n=word==nil and 1 or tonumber(tostring(word):match('^%d+$') or '')
    if n and n>=1 and n<=T.PARTS then return n,only end
end

-- o: log(m), status() the native status text (its sboxionwarp line's life= word, for the probe) and world, the
-- engine calls (world/maps/sboxion/engine.lua's move, put, black, ship, parts and part; a fake in the tests).
function Tetrapod.new(o)
    local log,world=o.log,o.world
    local box,seen=nil,0 -- The box EVE stands in and for how many passes in a row.
    -- A move that waits under SB's black: {left=<passes>, to='in', 'out' or 'probe', ask=<the probe's words>}.
    local lead=nil
    local hold=0 -- Passes left after a move on which nothing is looked at.
    local off=nil -- The error that turned the door off until the next arrival.
    local solid=false -- This stay asked the ship or one of its parts to be solid.
    local parts,unread=nil,false -- The parts the ship's last call wrote; its error was said.
    -- After the way in, until EVE walks in the ship: {passes=, again=<her fall was said>}.
    local settle=nil
    -- After the probe's move: {passes=, from=, only=, list=<world.parts()>, next=<the part to write next>, last=,
    -- before=<the last two written>, made=<parts written>, after=<passes since the last one>, still=<passes in a row
    -- she did not walk>, again=}.
    local probe=nil
    local self={}
    -- The ship made solid or put back as SB ships it: the parts written, or nil (not in memory, or the call raised).
    local function ship(on)
        local ok,n=pcall(world.ship,on)
        if not ok then
            if not unread then
                unread=true
                log('tetrapod: ship: unread ('..U.why(n)..')')
            end
            n=nil
        end
        if on then solid,parts=true,n else solid=false end
        return n
    end
    local function ship_text() return parts and parts..' parts solid' or 'ship not found' end
    local function back()
        local n=ship(false)
        log('tetrapod: ship as SB ships it again: '..(n and n..' parts' or 'not found'))
    end
    -- SB's black, asked once and never waited for. fade: the s it fades in over, 0 for a black that is up at once.
    local function black(fade)
        local ok,up=pcall(world.black,D.BLACK,fade,D.BLACK_OUT)
        return not ok and 'not shown: '..U.why(up) or up==false and 'not shown: SB made no loading screen'
            or up==nil and 'asked, its handle did not read' or fade>0 and string.format('up in %.1f s',fade)
            or 'up at once'
    end
    -- ask: the probe's words ({from=, only=}). The probe's move puts the ship back as SB ships it first, even when
    -- this door made nothing solid: after a Lua reload it does not know what an earlier one made solid.
    local function put(to,ask)
        local at,yaw=target(to)
        box,seen,hold,settle,probe=nil,0,T.HOLD,nil,nil
        if to=='in' then ship(true) elseif to=='probe' then back() end
        if world.put({X=at.X,Y=at.Y,Z=at.Z+D.LIFT},yaw)==false then
            log(string.format('tetrapod: %s: the move to %s was refused by K2_TeleportTo',to,place(at)))
            if to=='in' then back() end
            return
        end
        log(string.format('tetrapod: %s: EVE at %s, yaw %.1f',to,place(at),yaw))
        if to=='in' then settle={passes=0}
        elseif to=='probe' then probe={passes=0,from=ask.from,only=ask.only,made=0,after=0,still=0}
        else back() end
    end
    local function start(to,why,ask)
        log(string.format('tetrapod: %s asked (%s); black %s; EVE moves in %d passes',to,why,black(D.BLACK_IN),D.LEAD))
        lead,box,seen,settle,probe={left=D.LEAD,to=to,ask=ask},nil,0,nil,nil
    end
    -- EVE more than DROP cm under the point inside is put on it again, said once a move (w.again), with a black that
    -- is up at once every AGAIN passes. what: the move's word; state: the end of its line.
    local function again(m,w,what,state)
        local at=Tetrapod.world(T.IN)
        if m.at.Z>=at.Z-T.DROP then return end
        if not w.again then
            w.again=true
            log(string.format('tetrapod: %s: no floor yet under EVE at %s: on the point again (%s)',what,place(m.at),
                state))
        end
        world.put({X=at.X,Y=at.Y,Z=at.Z+D.LIFT},(T.SHIP.Yaw+T.IN.yaw+180)%360-180)
        if w.passes%T.AGAIN==0 then black(0) end
    end
    -- A pass of the watch after the way in.
    local function settling(m)
        settle.passes=settle.passes+1
        if not within(Tetrapod.ship(m.at),T.CABIN,'x','y','z') then
            settle=nil
            log('tetrapod: in: EVE is out of the ship at '..place(m.at)..' before she stood: the watch ends')
            return back()
        end
        local at=Tetrapod.world(T.IN)
        local low=m.at.Z<at.Z-T.DROP
        if GROUND[m.mode] and not low then
            log(string.format('tetrapod: in: EVE stands in the ship after %d passes, %s',settle.passes,ship_text()))
            settle=nil
            return
        end
        if not parts or parts==0 then
            ship(true)
            if parts and parts>0 then
                log(string.format('tetrapod: in: ship solid after %d passes: %d parts',settle.passes,parts))
            end
        end
        if settle.passes>=T.SETTLE then
            log(string.format('tetrapod: in: no floor under EVE after %d passes (%s): back outside',settle.passes,
                ship_text()))
            return put('out')
        end
        again(m,settle,'in',ship_text())
    end
    -- A part of the probe's list as its lines name it: its number of the count, its component and its mesh.
    local function named(list,i)
        return string.format('%d/%d %s (%s)',i,#list,list[i].component,list[i].mesh)
    end
    -- A pass of the probe: her life first, then the list or one more part, then the point again as the watch does.
    local function probing(m)
        local p=probe
        p.passes,p.still=p.passes+1,GROUND[m.mode] and 0 or p.still+1
        if not within(Tetrapod.ship(m.at),T.CABIN,'x','y','z') then
            probe=nil
            log('tetrapod: probe: EVE is out of the ship at '..place(m.at)..': the probe ends')
            if solid then back() end
            return
        end
        local life=tonumber(('\n'..(o.status() or '')):match('\nsboxionwarp=[^\r\n]- life=(%d+)'))
        if life and life>=3 and life<=5 then -- Dead, Despawn, Destroy: recover.lua's death rule.
            probe=nil
            local parts_said=not p.last and 'no part made solid' or 'last part made solid '..named(p.list,p.last)
                ..(p.before and ', the pass before '..named(p.list,p.before) or '')
            log(string.format('tetrapod: probe: EVE dead (life %d) at %s, mode %s, %d passes without walking; %s; '
                ..'no more part is written',life,place(m.at),tostring(m.mode),p.still,parts_said))
            return
        end
        if not p.list then
            local list=world.parts()
            if list and list[1] then
                p.list,p.next=list,p.from
                log(string.format('tetrapod: probe: ship found after %d passes: %d parts, %s',p.passes,#list,
                    p.only and 'part '..p.from..' alone made solid'
                    or 'one more made solid each pass from part '..p.from))
            elseif p.passes>=T.SETTLE then
                probe=nil
                log(string.format('tetrapod: probe: no ship parts after %d passes: back outside',p.passes))
                return put('out')
            end
        end
        if p.next then
            local i=p.next
            local q=assert(p.list[i],'no part '..i..': the ship has '..#p.list)
            local now=assert(world.part(i,true,q.component),'the ship is not in memory any more')
            solid,p.made,p.before,p.last=true,p.made+1,p.last,i
            p.next=not p.only and i<#p.list and i+1 or nil
            log(string.format('tetrapod: probe: part %s: %s, now %s; EVE at %s, mode %s, life %s',named(p.list,i),
                q.profile,now,place(m.at),tostring(m.mode),life or '?'))
        elseif p.list then
            p.after=p.after+1
            if p.after>=LIVE then
                probe=nil
                local standing=GROUND[m.mode]
                log(string.format('tetrapod: probe: EVE lives with %s solid, %d passes after the last one, at %s, '
                    ..'mode %s: the probe ends%s',p.only and 'part '..p.from..' alone'
                    or string.format('parts %d to %d',p.from,#p.list),LIVE,place(m.at),tostring(m.mode),
                    standing and '' or ', back outside with no floor'))
                if not standing then put('out') end -- Nothing else would hold her up: she would fall.
                return
            end
        end
        again(m,p,'probe',p.made..' parts solid')
    end
    local function tick(busy,read)
        local m=read or world.move()
        if not m then
            box,seen=nil,0
            return
        end
        if lead then
            lead.left=lead.left-1
            if lead.left<=0 then
                local to,ask=lead.to,lead.ask
                lead=nil
                put(to,ask)
            end
            return
        end
        if settle then
            settling(m)
            if settle then return end
        end
        if probe then
            probing(m)
            if probe then return end
        end
        if hold>0 then
            hold=hold-1
            return
        end
        local now=not busy and box_of(m.at) or nil
        if now~=box then box,seen=now,0 end
        if not now then return end
        seen=seen+1
        if seen>=T.STAY then
            start(now=='door' and 'in' or 'out',string.format('EVE stood %d passes at %s',seen,place(m.at)))
        end
    end
    -- Each 250 ms pass while EVE's map is SBO Xion. read: EVE as the recovery read her in this pass (world.move's
    -- table), so a pass reads her once; without it the door reads her itself.
    function self.tick(busy,read)
        if off then return end
        local ok,e=pcall(tick,busy,read)
        if ok then return end
        off,lead,settle,probe=U.why(e),nil,nil,nil
        log('tetrapod: door off until the next arrival: error ('..off..')')
    end
    -- Each arrival in SBO Xion: the door on, nothing kept of the stay before. The door is ticked in SBO Xion only, so
    -- a move that waited at a map change is dropped here. The world before is gone with its ship.
    function self.arrive()
        box,seen,lead,hold,off,settle,probe,solid,parts,unread=nil,0,nil,0,nil,nil,nil,false,nil,false
        log(string.format('tetrapod: door on: in at %s, out at %s',place(Tetrapod.world(T.IN)),place(T.OUT)))
    end
    -- coop off: the ship as SB ships it, when this stay made it or one of its parts solid.
    function self.stop()
        lead,settle,probe=nil,nil,nil
        if solid then back() end
    end
    -- coop xion tetrapod [in|out|probe [<n>|only <n>]]: the move asked at once, wherever EVE stands. With no word:
    -- where she is. The probe waits for an idle door: no move, no watch and no probe under way.
    function self.go(word,a,b,c)
        local from,only
        if word=='probe' then
            from,only=probe_words(a,b,c)
            if not from then return false,USE end
        elseif word~=nil and word~='in' and word~='out' or a~=nil then return false,USE end
        if off then return false,'coop xion tetrapod: the door is off until the next arrival: '..off end
        local ok,m=pcall(world.move)
        if not ok or not m then return false,'coop xion tetrapod: no EVE' end
        if word==nil then
            return true,'EVE is '..(within(Tetrapod.ship(m.at),T.CABIN,'x','y','z') and 'inside' or 'outside')
                ..' the Tetrapod, door on'
        end
        if lead or from and (settle or probe) then return false,'coop xion tetrapod: a move is under way' end
        hold=0
        start(word,'coop xion tetrapod '..table.concat({word,a,b},' '),from and {from=from,only=only})
        return true,word..': the move is asked'
    end
    return self
end
return Tetrapod
