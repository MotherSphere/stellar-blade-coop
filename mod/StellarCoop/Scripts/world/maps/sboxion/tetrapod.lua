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
-- E04_Area05_B_LD is streamed by volume as SB ships it (data.lua's VOLUMED). Whether the ship shows at once when EVE
-- arrives was not seen in game.
-- busy: the recovery waits (photo mode, a cutscene, a warp, another zone) or handles a fall or a death
-- (recover.lua's busy). Such a pass counts nothing and asks no move. A move already asked is still made.
-- An error in a pass turns the door off with one log line until the next arrival.
-- tests/lua/world/maps/sboxion/tetrapod_test.lua covers it.
local U=require('core.unreal')
local D=require('world.maps.sboxion.data')
local T=D.TETRAPOD
local Tetrapod={}
local USE='Use: coop xion tetrapod [in|out]'
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
-- Where a move ends and the yaw EVE gets there, -180 to 180.
local function target(to)
    if to=='out' then return {X=T.OUT.X,Y=T.OUT.Y,Z=T.OUT.Z},T.OUT.Yaw end
    return Tetrapod.world(T.IN),(T.SHIP.Yaw+T.IN.yaw+180)%360-180
end

-- o: log(m) and world, the engine calls (world/maps/sboxion/engine.lua's move, put and black; a fake in the tests).
function Tetrapod.new(o)
    local log,world=o.log,o.world
    local box,seen=nil,0 -- The box EVE stands in and for how many passes in a row.
    local lead=nil -- A move that waits under SB's black: {left=<passes>, to='in' or 'out'}.
    local hold=0 -- Passes left after a move on which nothing is looked at.
    local off=nil -- The error that turned the door off until the next arrival.
    local self={}
    local function put(to)
        local at,yaw=target(to)
        box,seen,hold=nil,0,T.HOLD
        if world.put({X=at.X,Y=at.Y,Z=at.Z+D.LIFT},yaw)==false then
            log(string.format('tetrapod: %s: the move to %s was refused by K2_TeleportTo',to,place(at)))
        else
            log(string.format('tetrapod: %s: EVE at %s, yaw %.1f',to,place(at),yaw))
        end
    end
    -- SB's black, asked once and never waited for, then the move LEAD passes later.
    local function start(to,why)
        local ok,up=pcall(world.black,D.BLACK,D.BLACK_IN,D.BLACK_OUT)
        log(string.format('tetrapod: %s asked (%s); black %s; EVE moves in %d passes',to,why,
            not ok and 'not shown: '..U.why(up) or up==false and 'not shown: SB made no loading screen'
                or up==nil and 'asked, its handle did not read' or string.format('up in %.1f s',D.BLACK_IN),D.LEAD))
        lead,box,seen={left=D.LEAD,to=to},nil,0
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
                local to=lead.to
                lead=nil
                put(to)
            end
            return
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
        off,lead=U.why(e),nil
        log('tetrapod: door off until the next arrival: error ('..off..')')
    end
    -- Each arrival in SBO Xion: the door on, nothing kept of the stay before. The door is ticked in SBO Xion only, so
    -- a move that waited at a map change is dropped here.
    function self.arrive()
        box,seen,lead,hold,off=nil,0,nil,0,nil
        log(string.format('tetrapod: door on: in at %s, out at %s',place(Tetrapod.world(T.IN)),place(T.OUT)))
    end
    -- coop xion tetrapod [in|out]: the move asked at once, wherever EVE stands. With no word: where she is.
    function self.go(word)
        if word~=nil and word~='in' and word~='out' then return false,USE end
        if off then return false,'coop xion tetrapod: the door is off until the next arrival: '..off end
        local ok,m=pcall(world.move)
        if not ok or not m then return false,'coop xion tetrapod: no EVE' end
        if word==nil then
            return true,'EVE is '..(within(Tetrapod.ship(m.at),T.CABIN,'x','y','z') and 'inside' or 'outside')
                ..' the Tetrapod, door on'
        end
        if lead then return false,'coop xion tetrapod: a move is under way' end
        hold=0
        start(word,'coop xion tetrapod '..word)
        return true,word..': the move is asked'
    end
    return self
end
return Tetrapod
