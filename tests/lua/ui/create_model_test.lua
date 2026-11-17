-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- ui/create_model.lua, pure: the rows for each Who can join value (Friends join without asking under Public and
-- Invitation only), Shared enemies' sub-rows only while it is on, a setting Options does not define left out, a change's
-- next value written through settings_file.set and read back, Start and Back, the cursor over headers and every
-- setting locked with its reason while coop-settings.txt cannot be read.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Options=require('ui.model')
local SF=require('core.settings_file')
local M=require('ui.create_model')

local function ids(rows)
    local out={}
    for i,r in ipairs(rows) do out[i]=r.head and '#'..r.head or r.id end
    return table.concat(out,' ')
end
local values=Options.read('')
local rows=M.rows({values=values,readable=true})
-- The defaults: Public, so Friends join without asking; Shared enemies on, so its seven sub-rows; Shared story between
-- Shared world and Shared quests.
local ALL='#session who_can_join friends_ask #rules shared_enemies same_place same_spawns enemy_extra bosses '
    ..'enemy_hp_scale boss_hp_scale aggro shared_world shared_story shared_quests revive start back'
assert(ids(rows)==ALL,ids(rows))
assert(rows[2].value=='public' and rows[3].value=='off' and rows[2].row.values[4]=='closed' and not rows[2].locked)
for _,r in ipairs(rows) do assert(not r.locked and not r.why,r.id) end
-- Friends join without asking: under Public and Invitation only.
for who,shows in pairs({public=true,friends=false,invitation=true,closed=false}) do
    values.who_can_join=who
    local got=ids(M.rows({values=values,readable=true}))
    assert((got:find(' friends_ask ',1,true)~=nil)==shows,who)
end
values.who_can_join='public'
-- Shared enemies off: its sub-rows go; the other rules stay.
values.shared_enemies='off'
assert(ids(M.rows({values=values,readable=true}))=='#session who_can_join friends_ask #rules shared_enemies '
    ..'shared_world shared_story shared_quests revive start back')
values.shared_enemies='on'

-- A change: the next value, Left and Right, a choice wrapping, a range held at its ends; none on a header or an action.
local function at(key) for _,r in ipairs(M.rows({values=values,readable=true})) do if r.key==key then return r end end end
local a=M.change(at('who_can_join'),1)
assert(a.set=='who_can_join' and a.value=='friends' and M.change(at('who_can_join'),-1).value=='closed')
assert(M.change(at('friends_ask'),1).value=='on' and M.change(at('aggro'),1).value=='host')
assert(M.change(at('boss_hp_scale'),1).value=='2.05' and M.change(at('enemy_hp_scale'),-1).value=='1.3')
values.enemy_extra='3'
assert(M.change(at('enemy_extra'),1)==nil and M.change(at('enemy_extra'),-1).value=='2','A range held at its end')
values.enemy_extra='0'
assert(M.change(rows[1],1)==nil and M.change(rows[#rows],1)==nil and M.change(nil,1)==nil)
-- Written through settings_file.set as Options writes: the file's own line rewritten, read back as the new value.
local file='# mine\nwho_can_join=public\nshared_enemies=on\n'
a=M.change(at('who_can_join'),1)
file=SF.set(file,a.set,a.value)
assert(file=='# mine\nwho_can_join=friends\nshared_enemies=on\n',file)
values=Options.read(file)
assert(at('who_can_join').value=='friends' and not at('friends_ask'),'Friends only: the sub-row goes')
a=M.change(at('shared_enemies'),1)
values=Options.read(SF.set(file,a.set,a.value))
assert(values.shared_enemies=='off' and not at('same_place') and not at('aggro'))
values=Options.read('')

-- Select: Start hosts with Who can join's value shown; Back closes; on a setting, its next value as Right.
local o={values=values,readable=true}
rows=M.rows(o)
assert(M.select(o,rows[#rows-1]).host=='public' and M.select(o,rows[#rows]).back==true)
values.who_can_join='closed'
assert(M.select(o,rows[#rows-1]).host=='closed','The value now, not the one when the rows were made')
values.who_can_join='public'
assert(M.select(o,rows[2]).value=='friends' and M.select(o,rows[1])==nil)
-- The cursor: headers skipped, wrapping both ways.
assert(M.move(rows,2,-1)==#rows and M.move(rows,#rows,1)==2 and M.move(rows,3,1)==5 and M.move(rows,0,1)==2)

-- coop-settings.txt cannot be read: every setting locked with its reason (a locked row changes nothing and its value
-- still shows); Start and Back still run.
o.readable=false
rows=M.rows(o)
assert(ids(rows)==ALL)
for _,r in ipairs(rows) do
    if r.key then assert(r.locked and r.why=='unreadable' and r.value~=nil and M.change(r,1)==nil,r.key) end
end
assert(M.select(o,rows[2])==nil and M.select(o,rows[#rows-1]).host=='public' and M.select(o,rows[#rows]).back)
assert(M.move(rows,2,1)==3,'A locked row takes the cursor, so its reason shows')

-- A setting Options does not define has no row: Shared story gone with its Options row.
for i,r in ipairs(Options.OPTIONS) do if r.key=='shared_story' then table.remove(Options.OPTIONS,i) break end end
package.loaded['ui.create_model']=nil
local M2=require('ui.create_model')
local got=ids(M2.rows({values=values,readable=true}))
assert(not got:find('shared_story',1,true) and got:find('shared_world shared_quests',1,true),got)
print('create_model_test ok')
