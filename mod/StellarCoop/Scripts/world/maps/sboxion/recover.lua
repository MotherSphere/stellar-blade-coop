-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's copy of the in-place respawn of online/modes/scoreattack/run.lua and of the ground read of
-- online/group/travel.lua: sboxion owns it; a fix here does not reach theirs.
-- Falls and deaths in SBO Xion (world/maps/sboxion/sboxion.lua ticks this part each 250 ms pass while EVE's map is SBO
-- Xion).
-- The paks of 2026-11-23 and of the rooms load none of SB's level-design sublevels, so SB's fall volumes are missing
-- and nothing of SB catches a fall out of the city. SB's logic update 0x141ba1810 (build 26123051) then counts the time
-- EVE stays in falling mode at logic +0x344 and applies the effect of its constant Falling_Effect_Dead once the count
-- reaches the threshold at logic +0x340 (Falling_Time_Dead, compiled default 10.0 s at 0x1425f3d98). The same function
-- writes 0 to the count on the first frame she does not fall (0x141ba1b7c), so putting her on the ground is enough:
-- nothing of SB is written.
-- The full test pak loads those sublevels as SB ships them. The rows of the city's 19 fall volumes name Zone_Xion_10
-- as the zone they act in, so in Zone_SBO_Xion the recovery runs the same with each pak. Whether SB's volumes act
-- there was not seen in game.
-- The ground point: each pass, world.move() gives EVE's place, yaw and movement mode from one read. A pass on which
-- she walks (mode 1 or 2) at or above data.lua's FLOOR joins a streak. The oldest of STREAK passes in a row is the
-- ground point: a place she walked on, at most 1 s old. A jump, a fall, a guard that waits or a step of more than
-- JUMP cm between two passes starts the streak again and keeps the point. An arrival drops it.
-- The fall: with EVE under FLOOR the part asks SB's black (world.black), the fade SB's own fall warp shows: to black
-- over BLACK_IN s, black for BLACK s, back to the picture over BLACK_OUT s. LEAD passes later it calls world.put
-- (K2_TeleportTo, then StopMovementImmediately) to the ground point plus LIFT cm, facing the point's yaw, so the move
-- is made under the black. The move never waits for the black: it is made at that pass whatever the black's call did. A
-- call that raised, no loading screen and a handle that did not read each give one log line. With no ground point, or
-- after a failure, the target is the arrival point of the stay. After a failure the move is made in the pass that reads
-- her under FLOOR. A black that is up at once is asked after it, only when the game took the teleport. SB ends each
-- black by itself, so the part keeps nothing of it and has nothing to lift. The first walking read within CHECK s of
-- the world's time is the success. A refused teleport or CHECK s without that read is a failure. A success and a full
-- streak set the failures to 0. Two failures with neither between them stop the recovery until the next arrival or coop
-- xion recover on. An error in a pass counts as a failure, so an error on every pass is logged twice.
-- The guards: no EVE, photo mode and a theater= word of the status text's engine line other than none. When that line
-- has a warp= word: a warp under way, another zone or another zone type than SBO Xion's. Two words are no guard, since
-- each can stay for the whole game run. theater=fault: the native theater read faulted and is off
-- (native/src/glue/tick/status.inc). zonetype=0 beside SBO Xion's area: the native zone row read faulted, has not run
-- yet or found no row (native/src/online/group/warp_game.inc). SBO Xion has no cutscene and area= names the zone. A
-- pass that waits moves nothing and empties the streak. A put-back being checked keeps its time. Passes on which the
-- world's time did not move are skipped, so a world that stands still uses up no CHECK. A move that waits under the
-- black counts neither kind of pass, so it can come after the black is over. Without a warp= word (online/group's
-- native read is off) falls are still caught.
-- The death: SB's own death screen cannot bring EVE back here. In a standalone game its respawn 0x141e47070 calls the
-- camp respawn 0x141cdb440, which compares the world of the save's camp zone with the world of the current zone. For
-- another world it takes 0x141cdfbd0 to the zone warp 0x141cdfe70, which returns 0 when the current zone's row is of
-- type 5 (0x141cf7630). SB's respawn job has no such test, so the part asks it in place: ServerRequest_ActorRespawn
-- (GUID, false) queues FSBActorRespawn, whose Simulate 0x141b10b30 refills her recovery items (0x141bb84f0) and hands
-- the game thread 0x141bacf40. That sends the message SBPresentation::FSBActorRespawn::Execute 0x141b1b100 handles
-- with 0x141a6a820(actor, 0): FSBActor::SetLifeState 0x141a85f10(actor, 1), then the thunk 0x14b963e00's case 2,
-- which sets her HP (FSBActor +0x11c) to its maximum (+0x120).
-- The death rule starts while the sboxionwarp line of the status text reads life=3, 4 or 5 (ESBActorLifeState Dead,
-- Despawn, Destroy; native/src/world/maps/sboxion/warp_worker.inc writes the word while EVE is inside SBO Xion). It
-- starts on the value, not on its change: a death read while a guard waited, one left from the mode off and one found
-- after a Lua reload are handled too. Then score attack's block, with one change. For TRY s at most it waits for life
-- 3 to 5, warp=idle with me=<GUID> and no nightop=rule on the engine line, an SB player controller, a standalone
-- game, EVE and the death screen playing, each reason logged once, then makes the one call. The change: after SCREEN
-- s without a playing death screen the call is made without one. AFTER s later it logs the result. With life 1 or 6
-- a death screen that still plays is hidden until the next death, a stop or the recovery stopping after two failures.
-- If EVE is then not walking or is under FLOOR, the fall's put-back runs, in the mode death too. Life still 3 to 5,
-- or no call in TRY s, is a failure: the next pass starts the death again unless the recovery stopped. TRY, AFTER and
-- SCREEN count passes, so they run in real time whatever the world's time does. Without a warp= word the call is
-- never made: it needs the GUID.
-- tests/lua/world/maps/sboxion/recover_test.lua covers it.
local U=require('core.unreal')
local D=require('world.maps.sboxion.data')
local Recover={}
local GROUND={[1]=true,[2]=true} -- EMovementMode: Walking, NavWalking.
local MOST=2 -- Failures in a row that stop the recovery.
local TICK=0.25 -- s between two passes (main/pass.lua's loop).
local MODES={on='falls are caught, deaths are',death='falls are not caught, deaths are',
    off='falls are not caught, deaths are not'}
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end

-- o: log(m), status() the native status text, photo() main/base.lua's photo_state ('0' out of photo mode; optional)
-- and world, the engine calls (world/maps/sboxion/engine.lua's move, put, black, controller, standalone, respawn,
-- screen and hide; a fake in the tests).
function Recover.new(o)
    local log,world=o.log,o.world
    local mode,stopped,fails,arrival='on',false,0,'city'
    local ring,point,first={},nil,false -- The streak, the ground point ({at=, yaw=, time=}) and whether it was said.
    local last,prev=nil,nil -- The world's time and EVE's place at the pass before.
    local waiting,bare=nil,false -- Why the passes wait; the missing warp= word was said.
    local check=nil -- A put-back being checked: {spent=<s of the world's time since it>}.
    local lead=nil -- A first put-back that waits under SB's black: {left=<passes>, said=<its line's start>}.
    -- A death being handled, until the respawn's result line: {ticks=, said=, call=<the pass of the call>, before=}.
    local dead=nil
    local hidden=nil -- The call that shows the death screen this part hid.
    local passes,look_at=0,0 -- Every pass; the death screen's widget is looked for again at most every 10 s.
    local here=nil -- EVE as the last pass read her, for the Tetrapod's door; nil when the pass read nothing.
    local self={}
    -- The death screen we hid comes back as it was.
    local function show(reason)
        local back=hidden
        hidden=nil
        back()
        log('respawn: death screen shown again ('..reason..')')
    end
    local function fail(what)
        fails=fails+1
        log(string.format('%s: failure %d of %d',what,fails,MOST))
        if fails<MOST then return end
        stopped,check,dead,lead=true,nil,nil,nil
        log('recovery stopped after '..MOST..' failures in a row; coop xion recover on starts it again; way out: coop '
            ..'xion leave')
        if hidden then show('the recovery stopped') end -- No pass reads a new death from here on.
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
    -- SB's black for a put-back (world.black), asked once and never waited for: SB ends it by itself. fade: the s it
    -- fades in over, 0 for a black that is up at once. tail: the end of its line.
    local function black(fade,tail)
        local ok,up=pcall(world.black,D.BLACK,fade,D.BLACK_OUT)
        log('black: '..(not ok and 'not shown: '..U.why(up) or up==false and 'not shown: SB made no loading screen'
            or up==nil and 'asked, its handle did not read' or fade>0 and string.format('up in %.1f s',fade)
            or 'up at once')..tail)
    end
    -- A put-back is due. With no failure counted: SB's order, its black first and the move LEAD passes later, under
    -- it, whatever the black did. After a failure: the move in this pass, then a black that is up at once.
    local function due(m,said)
        if fails>0 then
            put(m,said)
            if check then black(0,'') end -- check is set: the game took the teleport.
            return
        end
        black(D.BLACK_IN,string.format('; EVE at %s moves in %d passes',place(m.at),D.LEAD))
        lead={left=D.LEAD,said=said}
    end
    -- Why this pass waits, or nil. line: the status text's engine line.
    local function guard(m,line)
        if not m then return 'no EVE' end
        if o.photo and o.photo()~='0' then return 'photo mode' end
        local theater=line:match(' theater=(%S+)')
        if theater and theater~='none' and theater~='fault' then return 'cutscene '..theater end
        local warp=line:match(' warp=(%a+)')
        if not warp then return nil end
        if warp~='idle' then return 'a warp is under way' end
        local area,kind=line:match(' area=(%S+)'),line:match(' zonetype=(%d+)')
        if area~=D.ZONE or kind~='5' and kind~='0' then return 'zone '..tostring(area)..' type '..tostring(kind) end
    end
    -- Whether the death screen plays: true, false, or nil with no widget.
    local function playing()
        local look=passes>=look_at
        local up=world.screen(look)
        if up==nil and look then look_at=passes+40 end
        return up
    end
    local function screen_word(up) return up==nil and 'gone' or up and 'up' or 'off' end
    -- Why the respawn waits, or nil with our EVE's GUID, the controller and whether the death screen plays: score
    -- attack's checks (life 3 to 5, no respawn or warp in flight, no probe rule, a standalone game, EVE, the death
    -- screen playing), the last one only for SCREEN s.
    local function blocker(m,line,life)
        if not life then return 'no life read' end
        if life<3 or life>5 then return 'life '..life end
        local warp,me=line:match(' warp=(%a+) me=(%d+)')
        if not warp then return 'no warp read' end
        if warp~='idle' then return 'a respawn or a warp is under way' end
        if line:find(' nightop=rule',1,true) then return 'a coop no probe rule is set in this game run' end
        local pc=world.controller()
        if not pc then return 'no SB player controller' end
        if not world.standalone(pc) then return 'the game is not standalone' end
        if not m then return 'no EVE' end
        local up=playing()
        if not up and dead.ticks*TICK<D.SCREEN then return 'no death screen' end
        return nil,tonumber(me),pc,up
    end
    -- A death being handled, each pass: SB's in-place respawn of our EVE, once, as soon as every check holds, tried
    -- for TRY s. AFTER s after the call, the result. waits: a guard waits on this pass.
    local function respawn(m,line,life,waits)
        dead.ticks=dead.ticks+1
        if not dead.call then
            if life==1 or life==6 then
                dead=nil
                log('death: over before the respawn was asked (life '..life..')')
                return
            end
            local why,me,pc,up=blocker(m,line,life)
            if why then
                if why~=dead.said then
                    dead.said=why
                    log('respawn waits: '..why)
                end
                if dead.ticks*TICK>=D.TRY then
                    dead=nil
                    fail(string.format('respawn not asked in %d s: %s',D.TRY,why))
                end
                return
            end
            dead.call,dead.before=dead.ticks,{life=life,screen=screen_word(up),pawn=m.pawn}
            log(string.format('respawn: ServerRequest_ActorRespawn(%d, false) asked (life %d, %s)',me,life,
                up and 'death screen up' or 'no death screen in '..D.SCREEN..' s'))
            world.respawn(pc,me)
            return
        end
        if (dead.ticks-dead.call)*TICK<D.AFTER then return end
        local b,up=dead.before,playing()
        local screen=screen_word(up)
        local alive=life==1 or life==6
        if alive and up then
            hidden=world.hide()
            screen=hidden and 'hidden' or screen
        end
        local said=string.format('respawn result: life %d/%s, death screen %s/%s, EVE pawn %s, mode %s',b.life,
            life or '?',b.screen,screen,not m and 'gone' or m.pawn==b.pawn and 'same' or 'new',
            m and tostring(m.mode) or '?')
        dead=nil
        if life and life>=3 and life<=5 then return fail(said) end
        log(said)
        if not alive or not m then return end
        if GROUND[m.mode] and m.at.Z>=D.FLOOR then fails=0
        elseif not waits then due(m,'death: EVE at '..place(m.at)..' not on the ground') end
    end
    local function tick()
        passes=passes+1
        local text='\n'..(o.status() or '')
        local line=text:match('\nengine=([^\r\n]*)') or ''
        local life=tonumber(text:match('\nsboxionwarp=[^\r\n]- life=(%d+)'))
        local m=world.move()
        here=m
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
        local down=life~=nil and life>=3 and life<=5
        if hidden and down then show('a new death') end
        if down and not dead and not reason and mode~='off' then
            dead,check,lead={ticks=0},nil,nil
            log(string.format('death: life %d, EVE at %s',life,place(m.at)))
        end
        if dead then return respawn(m,line,life,reason~=nil) end
        if reason or not moving then return end
        local walks=GROUND[m.mode] and m.at.Z>=D.FLOOR
        if not walks or prev and U.metres(prev,m.at)*100>D.JUMP then ring={} end
        prev=m.at
        if walks then
            ring[#ring+1]={at=m.at,yaw=m.yaw,time=m.time}
            if #ring>D.STREAK then table.remove(ring,1) end
            if #ring==D.STREAK then
                point,fails=ring[1],0 -- She walked for a full streak: an older failure no longer counts.
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
        if lead then -- Counted like a check: not on a pass that waits, not while the world's time stands still.
            lead.left=lead.left-1
            if lead.left<=0 then
                local said=lead.said
                lead=nil
                put(m,said)
            end
            return
        end
        if mode=='on' and m.at.Z<D.FLOOR then -- Her life is not 3 to 5 here: in the mode on that returned above.
            due(m,string.format('fall: EVE at %s under the floor, mode %s, life %s',place(m.at),tostring(m.mode),
                life or '?'))
        end
    end
    -- Each 250 ms pass while EVE's map is SBO Xion.
    function self.tick()
        here=nil
        if stopped then return end
        local ok,e=pcall(tick)
        if not ok then
            check,dead,lead=nil,nil,nil
            fail('recovery: error ('..U.why(e)..')')
        end
    end
    -- Each arrival in SBO Xion at the point of name (data.lua's ARRIVALS): the mode on, nothing kept of the stay
    -- before.
    function self.arrive(name)
        mode,stopped,fails,arrival='on',false,0,D.ARRIVALS[name] and name or 'city'
        ring,point,first,last,prev,waiting,bare,check,dead,lead={},nil,false,nil,nil,nil,false,nil,nil,nil
        log(string.format('recovery on: floor Z %d, arrival point %s %s',D.FLOOR,arrival,place(D.ARRIVALS[arrival])))
    end
    -- A map change or coop off (reason): a put-back that waits under the black, one being checked and a respawn not
    -- asked yet are dropped and a death screen this part hid is shown again.
    function self.stop(reason)
        check,dead,lead=nil,nil,nil
        if hidden then show(reason) end
    end
    -- For the Tetrapod's door (tetrapod.lua): a guard waits, or a put-back or a death is being handled, as of the last
    -- pass. Then EVE as that pass read her (world.move's table), or nil when it read nothing (a stopped recovery, an
    -- error before the read).
    function self.busy() return waiting~=nil or check~=nil or lead~=nil or dead~=nil,here end
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
        if word=='off' then check,dead,lead=nil,nil,nil else stopped,fails=false,0 end
        local line='recovery mode '..word..': '..MODES[word]
        log(line)
        return true,line
    end
    return self
end
return Recover
