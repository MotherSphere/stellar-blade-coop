-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/maps/matrix13/words.lua: every game culture but English and French has its generated file with exactly the ids
-- the code reads (derived here from the hand-written sources), each a line; each talk line carries its id; line() picks
-- French and English as given (the Gardener's French is SB's La guivre).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={} -- world/maps/matrix13/level/boss.lua's requires read it at load.
FName=function(t) return t end
FText=function(t) return {text=t} end
local W=require('world.maps.matrix13.words')
local CULTURES=require('ui.text.culture').CULTURES
local want,n,speakers={},0,{}
local function need(id) assert(not want[id],'id twice: '..id); want[id]=true; n=n+1 end
for k in pairs(require('world.maps.matrix13.quest.text').en) do need('quest.'..k) end
local function talk(prefix,lines)
    for k,l in ipairs(lines) do
        need(('%s.%02d'):format(prefix,k))
        assert(l.id==('%s.%02d'):format(prefix,k),prefix..' '..k..': id '..tostring(l.id))
        if l[1]~='' and not l[1]:find('^Seq_Actor_') then speakers[l[1]]=true end
    end
end
for _,name in ipairs({'prologue','arrival','finale'}) do
    talk('talk.'..name,require('world.maps.matrix13.talks.'..name))
end
for z=1,4 do
    for scene,lines in pairs(require('world.maps.matrix13.talks.zone'..z)) do talk('talk.zone.'..scene,lines) end
end
for s in pairs(speakers) do need('speaker.'..s) end
for _,b in ipairs(require('world.maps.matrix13.level.boss').LIST) do if b.shown then need('boss.'..b.name) end end
assert(n==236,n..' ids, not 236')
local cultures=0
for c in pairs(CULTURES) do
    if c=='en' or c=='fr' then
        assert(W.TEXT[c]==nil,c..': hand-written, no generated file')
    else
        cultures=cultures+1
        local t=assert(W.TEXT[c],c..': no world/maps/matrix13/text/'..c..'.lua')
        for id in pairs(want) do assert(type(t[id])=='string' and t[id]~='',c..': no '..id) end
        for id in pairs(t) do assert(want[id],c..': '..id..' is no id of the code') end
    end
end
assert(cultures==21,cultures..' cultures, not 21')
for c in pairs(W.TEXT) do assert(CULTURES[c],c..': no game culture') end
assert(W.line('fr','quest.T','On Time',"À l'heure")=="À l'heure" and W.line('en','quest.T','On Time','x')=='On Time')
assert(W.line('ja','quest.T','On Time','x')==W.TEXT.ja['quest.T'] and W.TEXT.ja['quest.T']~='On Time')
assert(W.line('ja','no.such','On Time','x')=='On Time' and W.line('xx','quest.T','On Time','x')=='On Time')
assert(W.line('fr','boss.Lion','Lion',nil)=='Lion')
assert(W.line('fr','boss.Gardener','Gardener',require('world.maps.matrix13.level.boss').LIST[2].fr)=='La guivre')
print('world/maps/matrix13/words_test: ok')
