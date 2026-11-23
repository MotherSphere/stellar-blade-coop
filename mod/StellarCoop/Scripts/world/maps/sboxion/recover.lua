-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's copy of the ground read of online/group/travel.lua: sboxion owns it; a fix here does not reach theirs.
-- Falls in SBO Xion (world/maps/sboxion/sboxion.lua ticks this part each 250 ms pass while EVE's map is SBO Xion).
-- SBO Xion loads none of SB's level-design sublevels, so SB's fall volumes are missing and nothing of SB catches a
-- fall out of the city. SB's logic update 0x141ba1810 (build 26123051) then counts the time EVE stays in falling mode
-- at logic +0x344 and applies the effect of its constant Falling_Effect_Dead once the count reaches the threshold at
-- logic +0x340 (Falling_Time_Dead, compiled default 10.0 s at 0x1425f3d98). The same function writes 0 to the count
-- on the first frame she does not fall (0x141ba1b7c), so putting her on the ground is enough: nothing of SB is
-- written.
-- The ground point: each pass, world.move() gives EVE's place, yaw and movement mode from one read. A pass on which
-- she walks (mode 1 or 2) at or above data.lua's FLOOR joins a streak. The oldest of STREAK passes in a row is the
-- ground point: a place she walked on, at most 1 s old. A jump, a fall, a guard that waits or a step of more than
-- JUMP cm between two passes starts the streak again and keeps the point. An arrival drops it.
-- The fall: with EVE under FLOOR the part calls world.put (K2_TeleportTo, then StopMovementImmediately) to the ground
-- point plus LIFT cm, facing the point's yaw. With no ground point, or after a failure, the target is the arrival
-- point of the stay. The first walking read within CHECK s of the world's time is the success. A refused teleport
-- or CHECK s without that read is a failure. Two failures in a row stop the recovery until the next arrival or
-- coop xion recover on. An error in a pass counts as a failure, so it is logged twice at most.
-- The guards: no EVE, photo mode, a theater= word of the status text's engine line other than none, and, when that
-- line has a warp= word, a warp under way or another zone or zone type than SBO Xion's. A pass that waits moves
-- nothing and empties the streak. A put-back being checked keeps its time. Passes on which the world's time did
-- not move (a pause) are skipped. Without a warp= word (online/group's native read is off) falls are still caught.
-- tests/lua/world/maps/sboxion/recover_test.lua covers it.
local U=require('core.unreal')
local D=require('world.maps.sboxion.data')
local Recover={}
local GROUND={[1]=true,[2]=true} -- EMovementMode: Walking, NavWalking.
local MOST=2 -- Failures in a row that stop the recovery.
local MODES={on='falls are caught, deaths are',death='falls are not caught, deaths are',
    off='falls are not caught, deaths are not'}
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end

-- o: log(m), status() the native status text, photo() main/base.lua's photo_state ('0' out of photo mode; optional)
-- and world, the engine calls (world/maps/sboxion/engine.lua's move and put; a fake in the tests).
function Recover.new(o)
    local log,world=o.log,o.world
    local mode,stopped,fails,arrival='on',false,0,'city'
    local ring,point,first={},nil,false -- The streak, the ground point ({at=, yaw=, time=}) and whether it was said.
    local last,prev=nil,nil -- The world's time and EVE's place at the pass before.
    local waiting,bare=nil,false -- Why the passes wait; the missing warp= word was said.
    local check=nil -- A put-back being checked: {spent=<s of the world's time since it>}.
    local self={}
    local function fail(what)
        fails=fails+1
        log(string.format('%s: failure %d of %d',what,fails,MOST))
        if fails<MOST then return end
        stopped,check=true,nil
        log('recovery stopped after '..MOST..' failures in a row; coop xion recover on starts it again; way out: coop '
            ..'xion leave')
    end
    -- EVE to the ground point, or to the stay's arrival point with none or after a failure. said: the line's start.
    local function put(m,said)
        local to,why=point,nil
        if point and fails==0 then
            why=string.format('the ground point %s read %.1f s ago',place(point.at),m.time-point.time)
        else
            local a=D.ARRIVALS[arrival]
            to={at=a,yaw=a.Yaw}
            why=string.format('the arrival point %s %s, %s',arrival,place(a),
                fails>0 and 'after a failure' or 'no ground point')
        end
        log(said..': to '..why)
        ring,prev={},nil
        if world.put({X=to.at.X,Y=to.at.Y,Z=to.at.Z+D.LIFT},to.yaw)==false then
            fail('put back refused by K2_TeleportTo')
        else check={spent=0} end
    end
    -- Why this pass waits, or nil. line: the status text's engine line.
    local function guard(m,line)
        if not m then return 'no EVE' end
        if o.photo and o.photo()~='0' then return 'photo mode' end
        local theater=line:match(' theater=(%S+)')
        if theater and theater~='none' then return 'cutscene '..theater end
        local warp=line:match(' warp=(%a+)')
        if not warp then return nil end
        if warp~='idle' then return 'a warp is under way' end
        local area,kind=line:match(' area=(%S+)'),line:match(' zonetype=(%d+)')
        if area~=D.ZONE or kind~='5' then return 'zone '..tostring(area)..' type '..tostring(kind) end
    end
    local function tick()
        local text='\n'..(o.status() or '')
        local line=text:match('\nengine=([^\r\n]*)') or ''
        local life=tonumber(text:match('\nsboxionwarp=[^\r\n]- life=(%d+)'))
        local m=world.move()
        local moving=m~=nil and m.time~=last
        local dt=m and last and m.time>last and m.time-last or 0
        last=m and m.time or nil
        local reason=guard(m,line)
        if reason~=waiting then
            waiting=reason
            log(reason and 'recovery waits: '..reason or 'recovery waits no more')
        end
        if m and not bare and not line:find(' warp=',1,true) then
            bare=true
            log('recovery: the engine line has no warp= word: falls are caught, deaths are not')
        end
        if reason then ring,prev={},nil end
        if reason or not moving then return end
        local walks=GROUND[m.mode] and m.at.Z>=D.FLOOR
        if not walks or prev and U.metres(prev,m.at)*100>D.JUMP then ring={} end
        prev=m.at
        if walks then
            ring[#ring+1]={at=m.at,yaw=m.yaw,time=m.time}
            if #ring>D.STREAK then table.remove(ring,1) end
            if #ring==D.STREAK then
                point=ring[1]
                if not first then
                    first=true
                    log('ground: first point '..place(point.at))
                end
            end
        end
        if check then
            check.spent=check.spent+dt
            if walks then
                log(string.format('put back: EVE walks at %s, %.1f s after the move',place(m.at),check.spent))
                check,fails=nil,0
            elseif check.spent>=D.CHECK then
                check=nil
                fail(string.format('put back failed: EVE at %s, mode %s, %d s after the move',place(m.at),
                    tostring(m.mode),D.CHECK))
            end
            return
        end
        if mode=='on' and not stopped and m.at.Z<D.FLOOR and not (life and life>=3 and life<=5) then
            put(m,string.format('fall: EVE at %s under the floor, mode %s, life %s',place(m.at),tostring(m.mode),
                life or '?'))
        end
    end
    -- Each 250 ms pass while EVE's map is SBO Xion.
    function self.tick()
        if stopped then return end
        local ok,e=pcall(tick)
        if not ok then
            check=nil
            fail('recovery: error ('..U.why(e)..')')
        end
    end
    -- Each arrival in SBO Xion at the point of name (data.lua's ARRIVALS): the mode on, nothing kept of the stay before.
    function self.arrive(name)
        mode,stopped,fails,arrival='on',false,0,D.ARRIVALS[name] and name or 'city'
        ring,point,first,last,prev,waiting,bare,check={},nil,false,nil,nil,nil,false,nil
        log(string.format('recovery on: floor Z %d, arrival point %s %s',D.FLOOR,arrival,place(D.ARRIVALS[arrival])))
    end
    -- A map change or coop off: a put-back being checked is dropped.
    function self.stop() check=nil end
    -- One part of coop xion status.
    function self.status()
        return string.format('recovery %s, %s, failures %d',stopped and 'stopped' or mode,
            point and string.format('ground %s %.1f s old',place(point.at),(last or point.time)-point.time)
                or 'no ground point',fails)
    end
    -- coop xion recover [on|death|off]: the mode, kept until the next arrival. on and death set the failures to 0 and
    -- end a stop. With no word: the status part.
    function self.mode(word)
        if word==nil then return true,self.status() end
        if not MODES[word] then return false,'Use: coop xion recover [on|death|off]' end
        mode=word
        if word=='off' then check=nil else stopped,fails=false,0 end
        local line='recovery mode '..word..': '..MODES[word]
        log(line)
        return true,line
    end
    return self
end
return Recover
