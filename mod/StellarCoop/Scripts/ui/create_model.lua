-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Create a session screen's model (Host a session), no engine call: its rows from the settings' values, what Left,
-- Right and Select on a row ask for and the cursor. Its setting rows are Options' own (ui/model.lua's OPTIONS: their
-- values, ranges and defaults) and change the same coop-settings.txt keys; a key OPTIONS does not define has no row.
-- ui/create.lua gives the ids their words.
local Options=require('ui.model')
local M={}
local ROW={} -- Options' rows by setting.
for _,row in ipairs(Options.OPTIONS) do if row.key then ROW[row.key]=row end end
-- The rows in order: headers, settings, then Start and Back. under: shown while that setting is on. Options' own show
-- holds too: Friends join without asking under Public and Invitation only. Players: max_players, 2 to 4.
local E='shared_enemies'
local LAYOUT={{head='session'},{key='who_can_join'},{key='friends_ask'},{key='max_players'},{head='rules'},{key=E},
    {key='same_place',under=E},{key='same_spawns',under=E},{key='enemy_extra',under=E},{key='bosses',under=E},
    {key='enemy_hp_scale',under=E},{key='boss_hp_scale',under=E},{key='aggro',under=E},{key='shared_world'},
    {key='shared_story'},{key='shared_quests'},{key='revive'},{id='start'},{id='back'}}
-- o: {values= (ui/model.lua's values: the settings in effect), readable= (coop-settings.txt can be read)}. Returns the
-- rows shown: headers {head='session'|'rules'}, settings {id=, key=, row= (Options'), value=, locked=, why=} and the
-- actions {id='start'|'back', action=true}. Every setting is locked while the file cannot be read (why 'unreadable'):
-- a change could not be written.
function M.rows(o)
    local values,out=o.values,{}
    for _,r in ipairs(LAYOUT) do
        local row=r.key and ROW[r.key]
        if r.head then out[#out+1]={head=r.head}
        elseif r.id then out[#out+1]={id=r.id,action=true}
        elseif row and (not r.under or values[r.under]=='on') and (not row.show or row.show({values=values})) then
            out[#out+1]={id=r.key,key=r.key,row=row,value=values[r.key],locked=not o.readable,
                why=not o.readable and 'unreadable' or nil}
        end
    end
    return out
end
-- What Left (dir -1) or Right (+1) on a setting asks: {set=key, value=} its next value; nil on a header, an action, a
-- locked row or a range at its end.
function M.change(item,dir)
    if not (item and item.row) or item.locked then return nil end
    local new=Options.step(item.row,item.value,dir)
    return new and {set=item.key,value=new} or nil
end
-- What Select on item asks: {host=who_can_join's value} on Start, {back=true} on Back, a setting's next value as
-- Right; nil as change() gives it.
function M.select(o,item)
    if item and item.id=='start' then return {host=o.values.who_can_join} end
    if item and item.id=='back' then return {back=true} end
    return M.change(item,1)
end
-- The row after at (step +1 or -1), headers skipped, wrapping; locked rows are visited, so their reason shows.
function M.move(items,at,step)
    for _=1,#items do
        at=(at-1+step)%#items+1
        if not items[at].head then return at end
    end
    return at
end
return M
