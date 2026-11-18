-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shared enemies' console commands (Phase 11, experimental): coop fight with its pilot and spawn probe; coop pvp,
-- the PvP test (a test tool). fight/wiring.lua builds them with new(o) at each Lua load and main/loader.lua merges them
-- into the command table; main/pass.lua runs coop fight on by itself for shared_enemies=on (fight/wiring.lua's
-- fight_asks). o: link, settings, native_tick, ask (a line for the native part), coop_slot and fight_auto_off() (coop
-- fight off cancels that ask).
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
-- coop pvp (the PvP test, a test tool with no menu row, out of the usage line): on (needs pvp_spike=on and
-- shared_enemies=off, as both run in the shared fight's job; the native part waits for a friend and a co-op save),
-- off and status (the fight= line), which check nothing.
local PVP_USE='Use: coop pvp on | off | status'
local PVP_WORDS={on=true,off=true,status=true}
function Fight.new(o)
    local link,settings,native_tick,ask,coop_slot=o.link,o.settings,o.native_tick,o.ask,o.coop_slot
    local self={}
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
    function self.pvp(sub,extra)
        if extra~=nil or not PVP_WORDS[sub or ''] then return false,PVP_USE end
        if sub=='on' then
            if not native_tick then return false,'the native tick is unavailable' end
            if not settings.pvp_spike then return false,'the PvP test is off in coop-settings.txt (pvp_spike=off)' end
            if settings.shared_enemies then
                return false,'the PvP test needs shared_enemies=off in coop-settings.txt: both use the same fight job'
            end
            local others=link and link.others() or 0
            if others>1 then return false,'the PvP test is for 2 players at most; this session has '..(others+1) end
            return ask('fight pvp')()
        end
        if sub=='off' then return ask('fight pvp off')() end
        local ok,why=ask('fight status')()
        if not ok then return ok,why end
        return true,link.fight() or 'no PvP status yet'
    end
    return self
end
return Fight
