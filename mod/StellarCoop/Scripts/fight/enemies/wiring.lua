-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shared enemies' wiring (fight/enemies/): the reload kill switches, the notices, the menu rows' asks and spectate.
return {
uses={'online.partner'},
exports={'fight_notices','pilot_notices','fight_asks','spectate'},
new=function(M)
local print,log=M.print,M.log
-- shared_enemies=on: coop fight on asked once a load, as soon as the native part judged the slot (coop, main, or none
-- at the title: its build is pinned then); it then waits there for a friend, a co-op save and a loaded save. coop
-- fight off before then cancels the ask. The co-op menu's row changes shared_enemies while the mod runs: on asks again
-- the same way, off asks coop fight off at once when coop fight on waits or runs (fight_wanted: the value last acted
-- on); a probe, record or replay goes on, as at a reload below.
local fight_auto=M.settings~=nil and M.settings.shared_enemies
local fight_wanted=fight_auto
-- The co-op menu's same_place row while a mode that pairs (on, record, replay) waits or runs: off asks coop fight
-- pilot off at once, on coop fight pilot on (place_wanted: the value last acted on). With none asked, the next coop
-- fight on carries the setting.
local place_wanted=M.settings~=nil and M.settings.same_place
-- The co-op menu's hit_reactions and stagger_resist rows the same way: a change of either asks coop fight stagger with
-- both (stagger_wanted: the values last acted on).
local stagger_wanted={M.settings~=nil and M.settings.hit_reactions,M.settings~=nil and M.settings.stagger_resist}
-- spectate: the native part starts with it on. Once a load, as soon as the native part judged the slot, the loop asks
-- spectate on or off only where the engine line's spectate= word disagrees with the setting (no word reads as on).
-- coop spectate on or off before then cancels that ask. The co-op menu's row asks spectate on or off at once;
-- spectate_wanted: the value last acted on.
local spectate_auto=M.settings~=nil
local spectate_wanted=M.settings~=nil and M.settings.spectate
-- shared_enemies=off is a kill switch at a reload too (Ctrl+R): the native part outlives Lua, so a coop fight on that an
-- earlier load started ends here, waiting or running (its fight= line, from the start of its own line). A probe, record
-- or replay goes on: shared_enemies does not gate them.
if M.settings and not M.settings.shared_enemies and not M.off
    and ('\n'..(M.link.status() or '')):find('\nfight=%a+ mode=on ') then
    local ok,why=M.ask('fight off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_enemies=off: '..tostring(why))
end
-- pvp_spike=off is the PvP test's kill switch at a reload the same way: coop pvp on from an earlier load ends here,
-- waiting or running.
if M.settings and not M.settings.pvp_spike and not M.off
    and ('\n'..(M.link.status() or '')):find('\nfight=%a+ mode=pvp ') then
    local ok,why=M.ask('fight pvp off')()
    log((ok and 'OK: ' or 'STOP: ')..'pvp_spike=off: '..tostring(why))
end
-- same_place=off too, on the side that hosts: a same place an earlier load asked for ends here, running or waiting
-- (coop fight pilot off, until the next coop fight on). Only there: a guest's own value decides nothing at a start,
-- so a reload never stops what the host's game shows her.
if M.settings and not M.settings.same_place and not M.off then
    local raw='\n'..(M.link.status() or '')
    if raw:find('\nfight=%a+ mode=record ') or (raw:find('\nfight=%a+ mode=on ') and raw:find('\nlink=host ')) then
        local ok,why=M.ask('fight pilot off')()
        log((ok and 'OK: ' or 'STOP: ')..'same_place=off: '..tostring(why))
    end
end
if M.link then
    -- Spectate (fight/enemies/spectate.lua), logging [SP] lines: the camera and the respawn while our EVE is down in a
    -- shared boss fight. It reads partner's ghosts late (M.ghost_of and the puppet view); partner off: no ghost anchor,
    -- so the camera stays over our own EVE. Its tick runs first in fight_notices, after coop off too, so the view
    -- comes back on our EVE.
    M.spectate=require('fight.enemies.spectate').new({link=M.link,settings=M.settings,
        log=function(m) print('[StellarCoop][SP] '..tostring(m)..'\n') end,tell=M.tell,name=M.her_name,
        puppet=require('main.loader').view(M,'puppet'),ghost=function(k) return M.ghost_of(k) end,
        actors=require('core.actors'),player=require('core.player'),unreal=require('core.unreal')})
    -- The shared enemies' notices, from the fight= line (an unread status changes nothing), in the menu's language
    -- (read only to say one): on with the count when its enemies go from none to some, and the host's scaling unless it
    -- is 100 % and 100 % (the line's scale=, which the guest has from the host); off, or stopped for the run, once it
    -- ran or waited, in any mode, unless our own player ended it (coop fight off, the menu's row, coop off);
    -- and while coop fight on waits or runs, one notice for what keeps it from sharing, said again only when that
    -- changes, and FIGHT_HOLD seconds after the last at the soonest (her lines set her state, so a friend flipping it
    -- cannot flood them): your save or hers not a co-op one, her shared enemies off or stopped for the run, or the two
    -- of you on different maps. Waits that end by themselves (no friend yet, a load, photo mode) say nothing. Sharing
    -- with her on the same map, or the session's end, forgets what was said. Sharing as the guest, two more: once
    -- until it stops or the friend leaves, when the host has enemies we cannot pair for their MaxHP (the line's
    -- maxhp=: another difficulty or New Game+); and each time the host goes down (her vitals, as the partner card reads
    -- them) while enemies are linked: its respawn resets its enemies, and ours heal back to them.
    local P=require('ui.kit.hud_parts')
    local FIGHT_HOLD=5
    local fight_was,fight_count,fight_told,fight_hold=nil,0,nil,0
    local fight_maxhp,host_down=false,false
    -- Same spawns' notices (stage 4), from the same line while coop fight on runs: on once a session when its spawns=
    -- first reads on (the host's words or the guest's), stopped once when it reads stopped (the same-place error that
    -- stops same spawns too), and as guest once a session when its spawns_differ= first counts an enemy. Forgotten
    -- with fight_maxhp.
    local spawns_on,spawns_stopped,spawns_differ=false,false,false
    -- Camp rests in a shared area, as the guest, from the same line's epoch=<zone>/<n>/<resets>: in a shared area only
    -- the host's rest brings its enemies back for both. Said when the host's epoch n moves in the same zone while their
    -- vitals read alive and they were not down in the last REST_CALM seconds (a respawn of theirs has host_down), and
    -- when our own resets move while spawns= reads on and our life= read alive for the REST_CALM seconds before (our
    -- own respawn says nothing). Only with shared_world=off: with it on, the group module's rested notice says it. rest:
    -- the line's last zone, n and resets, when the host last read down, and since when ours reads alive. Forgotten with
    -- fight_maxhp.
    local REST_CALM,rest=10,{}
    -- The boss finisher (phase 3), from the line's fin= (the member whose finisher ends a boss) and mem= (ours): named
    -- once a winner, never when the winner is us. fin_was: the last fin= read, nil for none.
    -- shortcut: any member but us is named as her (M.her_name), right for the pair only; 7b2 maps members to names.
    local fin_was
    -- The boss QTE (phase 3), from the line's qte=<member>:<try> (its owner and try, live) and mem=: told at each
    -- change. Ours at try 0: for us; ours at a later try: the previous owner missed, named unless that was us; another
    -- member's: for her. qte_was: the last qte= read, nil for none. The same shortcut as fin_was names her.
    local qte_was
    function M.fight_notices()
        M.guarded('spectate',M.spectate.tick,M.chat_clock)
        if M.link.mode()=='none' then fight_told=nil end
        local line=M.link.fight()
        if not line then return end
        local fin=line:match(' fin=(%d+)')
        if fin and fin~=fin_was and fin~=line:match(' mem=(%d+)') then
            M.tell(function(w) return w.fight.finisher:format(M.her_name(w)) end)
        end
        fin_was=fin
        local qte=line:match(' qte=(%d+:%d+)')
        if qte and qte~=qte_was then
            local owner,try,mem=qte:match('^(%d+)'),qte:match(':(%d+)$'),line:match(' mem=(%d+)')
            local missed=try~='0' and (qte_was and qte_was:match('^(%d+)'))~=mem
            M.tell(function(w)
                if owner~=mem then return w.fight.qte_other:format(M.her_name(w)) end
                return missed and w.fight.qte_missed:format(M.her_name(w)) or w.fight.qte_you
            end)
        end
        qte_was=qte
        local state,mode,her=line:match('^fight=(%a+)'),line:match(' mode=(%a+)'),line:match(' her=(%S+)')
        local why=line:match(' why=(.*)$')
        local now=state=='on' and 'on '..tostring(mode) or state
        if now=='on on' then
            local count=tonumber(line:match(' enemies=(%d+)') or line:match(' pairs=(%d+)')) or 0
            if fight_count==0 and count>0 then
                local hp,balance=line:match(' scale=(%d+)/(%d+)')
                if hp=='100' and balance=='100' then hp=nil end
                M.tell(function(w)
                    local text=count==1 and w.fight.one or w.fight.on:format(count)
                    return hp and text..' '..w.fight.scale:format(tonumber(hp),tonumber(balance)) or text
                end)
            end
            fight_count=count
            if not fight_maxhp and (tonumber(line:match(' maxhp=(%d+)')) or 0)>0 then
                fight_maxhp=true
                M.tell(function(w) return w.fight.maxhp:format(M.her_name(w)) end)
            end
            local guest=line:find(' role=guest ')~=nil
            local m=guest and M.link.mate()
            local down=m and (m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0) or false
            if down and not host_down and count>0 then
                M.tell(function(w) return w.fight.host_down:format(M.her_name(w)) end)
            end
            host_down=down
            if down then rest.down_at=M.chat_clock end
            local life=M.link.life()
            local alive=life and (life.state==1 or life.state==6) and life.hp>0
            rest.alive_since=alive and (rest.alive_since or M.chat_clock) or nil
            local zone,n,resets=line:match(' epoch=(%d+)/(%d+)/(%d+)')
            if zone and guest then
                local say=not M.settings.shared_world
                if say and rest.zone==zone and rest.n~=n and m and (m.life==1 or m.life==6) and not down
                    and (not rest.down_at or M.chat_clock-rest.down_at>=REST_CALM) then
                    M.tell(function(w) return w.group.rest:format(M.her_name(w)) end)
                end
                if say and rest.resets and resets~=rest.resets and line:find(' spawns=on ') and rest.alive_since
                    and M.chat_clock-rest.alive_since>=REST_CALM then
                    M.tell(function(w) return w.group.rest_guest:format(M.her_name(w)) end)
                end
                rest.zone,rest.n,rest.resets=zone,n,resets
            end
            local spawns=line:match(' spawns=(%a+)')
            if spawns=='on' and not spawns_on then
                spawns_on=true
                local host=line:find(' role=host ')
                M.tell(function(w) return (host and w.spawns.host or w.spawns.guest):format(M.her_name(w)) end)
            elseif spawns=='stopped' and not spawns_stopped then
                spawns_stopped=true
                M.tell(function(w) return w.spawns.stopped end)
            end
            if not spawns_differ and (tonumber(line:match(' spawns_differ=(%d+)')) or 0)>0 then
                spawns_differ=true
                M.tell(function(w) return w.spawns.differ:format(M.her_name(w)) end)
            end
        elseif state=='off' or state=='stopped' then
            if fight_was and (fight_was:find('^on ') or fight_was=='waiting') and why~='coop fight off'
                and why~='coop off' then
                M.tell(function(w) return w.fight[state] end)
            end
            fight_count,fight_maxhp,host_down=0,false,false
            spawns_on,spawns_stopped,spawns_differ,rest=false,false,false,{}
        elseif why=='no friend linked' then -- The friend left: the next one hears about MaxHP again.
            fight_maxhp,host_down=false,false
            spawns_on,spawns_stopped,spawns_differ,rest=false,false,false,{}
        end
        fight_was=now
        if mode~='on' or (state~='on' and state~='waiting') then return end
        local missing
        if state=='waiting' and (why or ''):find('^not on a co%-op save') then missing='you'
        elseif her=='own-save' then missing='her_save'
        elseif her=='off' then missing='her_off'
        elseif her=='stopped' then missing='her_stopped'
        elseif state=='on' and her=='on' then
            local mine=M.puppet.me()
            local where=P.where(mine and mine.map,M.puppet.her_map())
            if where=='elsewhere' then missing='map' elseif where=='same' then fight_told=nil end
        end
        if not missing or missing==fight_told or M.chat_clock<fight_hold then return end
        fight_told,fight_hold=missing,M.chat_clock+FIGHT_HOLD
        if missing=='you' then -- How to switch, or the manual slot when the co-op copies are off.
            local info=M.link.saves() or {}
            local manual=M.settings.auto_coop_save=='off' or info.saves~='main'
            M.tell(function(w) return manual and w.fight.you_manual or w.fight.you end)
        else
            M.tell(function(w) return w.fight[missing]:format(M.her_name(w)) end)
        end
    end
    -- Same place's notices (stage 3a), from the pilot= line, in the menu's language (read only to say one): how many
    -- enemies it moves when they go from none to some, and why it went off once it was on (the host's game turned it
    -- off, or an error stopped it); never for our own coop fight pilot off or the row (why=asked), the host's own
    -- setting (why=setting) or the shared fight not running (why=fight: its own notices say so).
    local pilot_was,pilot_count=nil,0
    function M.pilot_notices()
        local line=M.link.pilot()
        if not line then return end
        local state=line:match('^pilot=(%a+)')
        if state=='on' then
            local count=tonumber(line:match(' piloted=(%d+)')) or 0
            if pilot_count==0 and count>0 then
                M.tell(function(w) return count==1 and w.pilot.one or w.pilot.on:format(count) end)
            end
            pilot_count=count
        else
            pilot_count=0
            local why=line:match(' why=(%a+)')
            if pilot_was=='on' and (why=='host' or state=='stopped') then
                M.tell(function(w)
                    local p=w.pilot
                    return p.off:format(state=='stopped' and p.stopped or p.host:format(M.her_name(w)))
                end)
            end
        end
        pilot_was=state
    end
    -- The co-op menu's shared_enemies, same_place, hit_reactions, stagger_resist and spectate rows, then coop fight on
    -- and the spectate ask once a load (main/pass.lua calls this).
    function M.fight_asks()
        if M.settings.shared_enemies~=fight_wanted and not M.off then -- The co-op menu's row.
            fight_wanted=M.settings.shared_enemies
            fight_auto=fight_wanted
            if not fight_wanted and (M.link.fight() or ''):find('^fight=%a+ mode=on ') then
                local ok,message=M.ask('fight off')()
                M.report(ok,'shared_enemies=off: '..tostring(message))
            end
        end
        if M.settings.same_place~=place_wanted and not M.off then -- The co-op menu's row.
            place_wanted=M.settings.same_place
            local mode=(M.link.fight() or ''):match('^fight=%a+ mode=(%a+)')
            if mode and mode~='probe' then
                local ok,message=M.ask(place_wanted and 'fight pilot on' or 'fight pilot off')()
                M.report(ok,'same_place='..(place_wanted and 'on' or 'off')..': '..tostring(message))
            end
        end
        local reactions,resist=M.settings.hit_reactions,M.settings.stagger_resist
        if (reactions~=stagger_wanted[1] or resist~=stagger_wanted[2]) and not M.off then -- The co-op menu's rows.
            stagger_wanted={reactions,resist}
            local mode=(M.link.fight() or ''):match('^fight=%a+ mode=(%a+)')
            if mode and mode~='probe' then
                local ok,message=M.ask(string.format('fight stagger %d %d',reactions and 1 or 0,resist and 1 or 0))()
                M.report(ok,'stagger: '..tostring(message))
            end
        end
        if M.settings.spectate~=spectate_wanted and not M.off then -- The co-op menu's row.
            spectate_wanted=M.settings.spectate
            local word=spectate_wanted and 'on' or 'off'
            local ok,message=M.ask('spectate '..word)()
            M.report(ok,'spectate='..word..': '..tostring(message))
        end
        if spectate_auto and not M.off then
            local verdict=(M.slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                spectate_auto=false
                local engine=('\n'..(M.link.status() or '')):match('\nengine=([^\r\n]*)') or ''
                local now=engine:match(' spectate=(%a+)') or 'on' -- faulted: no ask changes it.
                local word=M.settings.spectate and 'on' or 'off'
                if (now=='on' or now=='off') and now~=word then
                    local ok,message=M.ask('spectate '..word)()
                    M.report(ok,'spectate='..word..': '..tostring(message))
                end
            end
        end
        if fight_auto and not M.off then
            local verdict=(M.slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                fight_auto=false
                local ok,message=M.commands.fight('on')
                M.report(ok,'shared_enemies=on: '..tostring(message))
            end
        end
    end
end
return require('fight.enemies.commands').new({ask=M.ask,coop_slot=M.coop_slot,
    fight_auto_off=function() fight_auto=false end,spectate_auto_off=function() spectate_auto=false end,
    spectate=function() return M.spectate end,
    link=M.link,native_tick=M.native_tick,settings=M.settings})
end,
}
