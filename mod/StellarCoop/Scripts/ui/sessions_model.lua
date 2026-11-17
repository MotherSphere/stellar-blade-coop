-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Sessions screen's model (Find a session), no engine call: a tab's rows from the native part's list, the status
-- line's key, what Refresh and Select ask for, the cursor and the StringTable_UI keys a row's region and camp read.
-- One search at a time, M.GAP s apart at least, none while a match search runs; Refresh while our own search runs stops
-- it. The native part refuses the same (link/core.h's ask_list); asking here first keeps its notices out of the feed.
-- ui/sessions.lua gives the keys and ids their words.
local Join=require('session.join')
local Link=require('core.link')
local M={}
M.TABS={'public','friends'}
M.GAP=5 -- Seconds between two searches (link/core.h's kListEveryMs).
-- A row's region: its zone word (the host's map, the last part of its path) to the StringTable_UI keys tried in order,
-- the region's own name first (UI_RegionAlias_<segment>, the open worlds' UI_Map_Region_<world> next). A zone with no
-- key here shows as it is.
-- shortcut: the story maps whose segment names its key only, plus three named alike; DEDA (f01) and the DLC maps
-- (ard_p, met_p) show their raw word until a key for them is read in Ghidra.
local REGION={b07={'UI_RegionAlias_B07'},c05={'UI_RegionAlias_C05'},f02={'UI_RegionAlias_F02'},
    e03_wasteland_p={'UI_RegionAlias_E03','UI_Map_Region_WasteLand'},e04={'UI_RegionAlias_E04','UI_Map_Region_Xion'},
    e05_greatdesert_p={'UI_RegionAlias_E05','UI_Map_Region_GreatDesert'},abysslab_p={'UI_RegionAlias_AbyssLaboa'},
    alteslab_p={'UI_RegionAlias_AltesLaboa'},matrix_xi={'UI_RegionAlias_Matrix11'}}
-- The session rules a row's rules word holds, in its order (core/link.lua's Link.rules), as ui/model.lua's setting ids.
local RULES={'shared_enemies','bosses','shared_world','shared_story','shared_quests','revive'}
-- o: {tab='public'|'friends', search=, rows= (link.list()'s two), match=link.match(), asked=when we last asked for a
-- search (os.clock, nil: never), now=}. Returns {tab, rows (the tab's, as the native part ordered them: {lobby=, name=
-- (cleaned, nil when empty), players=, ping=, pal=, zone=, camp=, rules=}), status={key=, args=} or nil while rows show,
-- busy (a search runs: ours, or a match search), ours (that search is a list search), wait (seconds before Refresh asks
-- again, 0 when it can)}. Status keys: searching, failed, empty, wait, idle (no list of this tab yet).
function M.view(o)
    local s,tab=o.search,o.tab
    local ours=s~=nil and s.state=='searching'
    local busy=ours or (o.match~=nil and o.match.state=='searching')
    local wait=o.asked and math.max(0,math.ceil(M.GAP-(o.now-o.asked))) or 0
    local rows={}
    if s and s.tab==tab then
        for _,r in ipairs(o.rows or {}) do
            rows[#rows+1]={lobby=r.lobby,name=Join.name(r.name),players=r.players,ping=r.ping,pal=r.pal,zone=r.zone,
                camp=r.camp,rules=r.rules}
        end
    end
    local status
    if busy then status={key='searching'}
    elseif s and s.tab==tab and s.state=='failed' then status={key='failed'}
    elseif s and s.tab==tab then status=#rows==0 and {key='empty'} or nil
    elseif wait>0 then status={key='wait',args={wait}}
    else status={key='idle'} end
    return {tab=tab,rows=rows,status=status,busy=busy,ours=ours,wait=wait}
end
-- What Refresh asks the native part: list stop while our own search runs, list <tab> when it may search; nil while a
-- match search runs or under M.GAP s since the last ask.
function M.refresh(view)
    if view.ours then return 'list stop' end
    if view.busy or view.wait>0 then return nil end
    return 'list '..view.tab
end
-- What Select on row i asks: join its lobby; nil for no row.
function M.select(view,i)
    local r=view.rows[i]
    return r and 'join '..r.lobby or nil
end
-- The row after at, step +1 or -1, wrapping; 0 with no row.
function M.move(n,at,step)
    if n==0 then return 0 end
    return (at-1+step)%n+1
end
-- The other tab.
function M.other(tab) return tab==M.TABS[1] and M.TABS[2] or M.TABS[1] end
-- A zone word's region keys (nil: none known); a camp alias's key.
function M.region(zone) return zone and REGION[zone:lower()] end
function M.camp(alias) return alias and 'UI_CampAlias_'..alias end
-- A rules word read back (Link.read_rules: any SBO client writes it): the rule ids on, in order, with boss (the boss HP
-- scale in percent) while shared bosses are on; nil for a word of another shape.
function M.rules(word)
    local r=word and Link.read_rules(word)
    if not r then return nil end
    local out={}
    for _,id in ipairs(RULES) do if r[id] then out[#out+1]=id end end
    if r.bosses then out.boss=math.floor(r.boss_hp_scale*100+0.5) end
    return out
end
return M
