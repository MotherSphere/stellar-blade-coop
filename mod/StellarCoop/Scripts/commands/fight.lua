-- The shared enemies' and the shared quests' console commands (Phases 11 and 12, experimental): coop fight, with its
-- pilot and spawn probe, and coop quests. main.lua builds them with new(o) at each Lua load and merges them into its
-- command table; its 250 ms loop runs coop fight on and coop quests on by itself for shared_enemies=on and
-- shared_quests=on. o: main.lua's link, settings, native_tick, ask (a line for the native part) and coop_slot, and
-- fight_auto_off() and quests_auto_off(): coop fight off and coop quests off cancel those asks.
local Fight={}
-- coop fight (Phase 11, experimental): its line for the native part, or nil when the arguments are off. A change is
-- whole units, signed or not, never 0, at most 10000000 (the native part's cap).
local FIGHT_USE='Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | record | replay | '
    ..'pilot status|probe|on|off | pilot test freeze|cmc|drive|replay|target|exec | '
    ..'pilot test bstart|phase|finish|summon | spawn probe'
local FIGHT_ALONE={on=true,off=true,status=true,probe=true,record=true,replay=true}
local function fight_line(sub,a,b,extra)
    if extra~=nil then return nil end
    if FIGHT_ALONE[sub] and a==nil then return 'fight '..sub end
    if sub~='test' then return nil end
    if a=='kill' and b==nil then return 'fight test kill' end
    local n=(a=='hp' or a=='sh' or a=='st') and type(b)=='string' and b:match('^[+-]?%d+$') and tonumber(b)
    if n and n~=0 and n>=-10000000 and n<=10000000 then return string.format('fight test %s %d',a,n) end
end
-- coop fight pilot's arguments (pilot below): one alone, or test and one of the probes.
local PILOT_ALONE={status=true,probe=true,on=true,off=true}
local PILOT_TESTS={freeze=true,cmc=true,drive=true,replay=true,target=true,exec=true,bstart=true,phase=true,
    finish=true,summon=true}
-- coop quests (Phase 12, experimental): on (needs shared_quests=on; the native part waits for a friend and a co-op
-- save), off, status (the quests= line, while the native part's whole answer follows in the log as quests_status
-- lines), probe, record and replay (the solo tools, on a co-op save only), and force <number>: the step that quest
-- holds for your own kill, or for a place the host's game could not read, made where you stand, once typed twice for
-- the same quest within 10 s (it can unlock that quest's trophies). on, probe and record carry quest_deny.
local QUESTS_USE='Use: coop quests on | off | status | probe | record | replay | force <quest number>'
local QUESTS_ALONE={on=true,off=true,status=true,probe=true,record=true,replay=true}
function Fight.new(o)
    local link,settings,native_tick,ask,coop_slot=o.link,o.settings,o.native_tick,o.ask,o.coop_slot
    local self={}
    local force_asked=nil -- coop quests force: the number typed and when ({id=, at=}), until typed again.
    -- coop fight pilot (same-place enemies, stages 3a to 3c): status (the pilot= line, after asking the native part,
    -- which then logs its stats lines), probe, on (needs same_place=on), off (a kill switch: no other check), or test
    -- and how far the drawn side goes, test target (the game's force target once, on an enemy this side owns), test
    -- exec (T11d-solo's takedown probe: the first frozen copy this side draws loses its balance) or test bstart, phase,
    -- finish and summon (stage 5's solo probes on the frozen boss copy of a replay; the native part answers why not
    -- otherwise).
    local function pilot(a,b,extra)
        if extra~=nil or not (PILOT_ALONE[a] and b==nil or a=='test' and PILOT_TESTS[b]) then
            return false,FIGHT_USE
        end
        if a~='off' and a~='status' and not native_tick then return false,'the native tick is unavailable' end
        if a=='on' and not settings.same_place then
            return false,'same place is off in coop-settings.txt (same_place=off)'
        end
        local ok,why=ask(b and 'fight pilot test '..b or 'fight pilot '..a)()
        if not ok or a~='status' then return ok,why end
        return true,link.pilot() or 'no same-place status yet'
    end
    -- on needs shared_enemies=on, on any save: the native part waits for a co-op save. probe, test, record and replay
    -- are the solo T11a tools, on a co-op save only (the native part checks again, and says in the log why it
    -- refuses). All but test carry fight_chars, none for auto (the native part's rule: every common enemy). Before
    -- them, in this order: guest_kills=confirmed and kill_credit=fought as one word each with on and replay (the modes
    -- that kill on the other side's word), and the host's scaling as "scale" and two whole percents with on and record
    -- (the modes that can host), and same_place=on as "place", aggro=host as "aggro-host" and bosses=on as "bosses" and
    -- boss_hp_scale in whole percents after them, then with on only same_spawns=on as "spawns", and with it an
    -- enemy_extra above 0 as "extra" and its number, then with on and spawn probe the guest's own spawn_filter=on as
    -- "filter". status answers
    -- with the fight= line; pilot is same-place enemies' own (pilot above). spawn probe is the probe with "spawns"
    -- before the ids: same spawns' reads alone (stage 4), whatever same_spawns says; its state is the fight= line's
    -- spawns=.
    function self.fight(sub,a,b,extra)
        if sub=='pilot' then return pilot(a,b,extra) end
        local spawn_probe=sub=='spawn'
        if spawn_probe then
            if a~='probe' or b~=nil or extra~=nil then return false,FIGHT_USE end
            sub,a=a,nil
        end
        local line=fight_line(sub,a,b,extra)
        if not line then return false,FIGHT_USE end
        if sub=='off' then o.fight_auto_off() end
        if sub~='off' and sub~='status' then
            if not native_tick then return false,'the native tick is unavailable' end
            if sub=='on' and not settings.shared_enemies then
                return false,'shared enemies are off in coop-settings.txt (shared_enemies=off)'
            end
            if sub~='on' then
                local ok,why=coop_slot('coop fight')
                if not ok then return false,why end
            end
            if (sub=='on' or sub=='replay') and settings.guest_kills=='confirmed' then line=line..' confirmed' end
            if (sub=='on' or sub=='replay') and settings.kill_credit=='fought' then line=line..' fought' end
            if sub=='on' or sub=='record' then
                line=line..string.format(' scale %d %d',math.floor(settings.enemy_hp_scale*100+0.5),
                    math.floor(settings.enemy_balance_scale*100+0.5))..(settings.same_place and ' place' or '')
                    ..(settings.aggro=='host' and ' aggro-host' or '')
                    ..(settings.bosses and string.format(' bosses %d',math.floor(settings.boss_hp_scale*100+0.5)) or '')
                    ..(sub=='on' and settings.same_spawns and ' spawns' or '')
                    ..(sub=='on' and settings.same_spawns and settings.enemy_extra>0
                        and ' extra '..settings.enemy_extra or '')
            end
            if spawn_probe then line=line..' spawns' end
            if (sub=='on' or spawn_probe) and settings.spawn_filter then line=line..' filter' end
            local chars=settings.fight_chars
            if sub~='test' and #chars>0 then line=line..' '..table.concat(chars,' ') end
        end
        local ok,why=ask(line)()
        if not ok or sub~='status' then return ok,why end
        return true,link.fight() or 'no shared fight status yet'
    end
    function self.quests(sub,a,extra)
        if extra~=nil or not (QUESTS_ALONE[sub or ''] and a==nil or sub=='force' and a~=nil) then
            return false,QUESTS_USE
        end
        if sub=='force' then
            local id=a:match('^%d+$') and tonumber(a)
            if not id or id<1 or id>65535 then return false,QUESTS_USE end
            local now=os.clock()
            if not (force_asked and force_asked.id==id and now-force_asked.at<=10) then
                force_asked={id=id,at=now}
                return false,'coop quests force '..id..' makes the step that quest '..id..' holds for your own kill, '
                    ..'or for a place the host\'s game could not read, where you stand now; the game may then unlock '
                    ..'that quest\'s trophies: type it again within 10 s to go on'
            end
            force_asked=nil
            return ask('quests force '..id)()
        end
        if sub=='off' then o.quests_auto_off() end
        if sub~='off' and sub~='status' then
            if not native_tick then return false,'the native tick is unavailable' end
            if sub=='on' and not settings.shared_quests then
                return false,'shared quests are off in coop-settings.txt (shared_quests=off)'
            end
            if sub~='on' then
                local ok,why=coop_slot('coop quests')
                if not ok then return false,why end
            end
        end
        local line='quests '..sub
        if (sub=='on' or sub=='probe' or sub=='record') and settings.quest_deny~='' then
            line=line..' deny '..settings.quest_deny
        end
        local ok,why=ask(line)()
        if not ok or sub~='status' then return ok,why end
        return true,(link.quests() or 'no shared quests status yet')
            ..' (the whole status follows in this log as quests_status lines)'
    end
    return self
end
return Fight
