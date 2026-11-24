-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- fight/bosses/ui/viewer.lua: the seven cut models in order, each one's title in the player's words; Part and Skin
-- follow the model, with the console's own words; Model and Part ask nothing; Skin, Show, Free camera and Remove run
-- the right words through the console's path; Show's value is what is shown now, Free camera's the camera's state; a
-- refusal comes back; every shown value fits the menu's value column.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={}
local Leviathan=require('fight.bosses.leviathan')
local Viewer=require('fight.bosses.ui.viewer')
local T=require('ui.text')
local shown,skins,filming,refuse=nil,{},false,nil
local ran={}
local page=Viewer.new({run=function(name,...)
        ran[#ran+1]=table.concat({name,...},' ')
        if refuse then return false,refuse end
        local sub,a=...
        if sub=='skin' then skins[name]=a elseif sub=='show' then shown={name,a}
        elseif sub=='cam' then filming=not filming elseif sub=='off' then shown,filming=nil,false end
        return true,'ok'
    end,leviathan={shown=function() if shown then return shown[1],shown[2] end end,
        skin=function(name) return skins[name] or 'default' end,filming=function() return filming end}})
assert(page.title(T.en)=='Cut models')
for name in pairs(Leviathan.CREATURES) do
    local found=false
    for _,n in ipairs(Viewer.ORDER) do found=found or n==name end
    assert(found,name..': not on the page')
end
local function row(id) for _,r in ipairs(page.rows(T.en)) do if r.id==id then return r end end end
local function value(id) return row(id).value end
local ids={}
for i,r in ipairs(page.rows(T.en)) do ids[i]=r.id end
assert(table.concat(ids,' ')=='model part skin show cam remove')
-- The models in order; picking asks nothing.
local titles={}
for i=1,#Viewer.ORDER do titles[i]=value('model'); row('model').select() end
assert(table.concat(titles,'|')=='Leviathan|Gardener|Tendril|Mann|NieR machine|Orcal prototype|Enya prototype'
    and #ran==0)
assert(value('model')=='Leviathan','Wraps')
row('model').step(-1)
assert(value('model')=='Enya prototype' and value('part')=='mech' and value('skin')=='default')
row('model').step(1)
-- Part follows the model, its words in order; Skin its skins then default, asked of the viewer.
assert(value('part')=='body')
row('part').step(1); row('part').step(1)
assert(value('part')=='b' and #ran==0)
assert(row('skin').select()==true and ran[#ran]=='leviathan skin statue' and value('skin')=='statue')
row('skin').step(1); row('skin').step(1)
assert(ran[#ran]=='leviathan skin default' and value('skin')=='default')
-- Show: the picked part; its value what is shown.
assert(value('show')=='Nothing shown')
assert(row('show').select()==true and ran[#ran]=='leviathan show b' and value('show')=='Leviathan b')
-- Another model keeps its own part; Gardener has no skin to change.
row('model').step(1)
local n=#ran
assert(value('part')=='body' and row('skin').select()==true and #ran==n,'Gardener: default only, nothing asked')
-- Free camera and Remove.
assert(value('cam')=='Off' and row('cam').select() and ran[#ran]=='gardener cam' and value('cam')=='On')
assert(row('remove').select() and ran[#ran]=='gardener off' and value('show')=='Nothing shown' and value('cam')=='Off')
-- A refusal comes back.
refuse='coop gardener show runs only on a co-op save'
local ok,why=row('show').select()
assert(not ok and why==refuse and value('show')=='Nothing shown')
refuse=nil
-- Every value the page can show within the menu's 26 value columns (ui/text_test.lua's count: a wide character two),
-- in every language: each model, and each shown model with its longest part.
local function columns(s)
    local c=0
    for _,p in utf8.codes(s) do
        c=c+((p>=0x1100 and p<=0x115F or p>=0x2E80 and p<=0xA4CF or p>=0xAC00 and p<=0xD7A3 or p>=0xF900 and p<=0xFAFF
            or p>=0xFF00 and p<=0xFF60) and 2 or (p>=0xE31 and p<=0xE4E and p~=0xE32 and p~=0xE33) and 0 or 1)
    end
    return c
end
for lang,t in pairs(T) do if type(t)=='table' and t.tools then
    local v=t.tools.viewer
    for name,who in pairs(Leviathan.CREATURES) do
        local longest=''
        for _,m in ipairs(who.meshes) do if #m>#longest then longest=m end end
        local text=v[name]..' '..longest
        assert(columns(text)<=26,lang..': '..text)
    end
end end
print('fight_bosses_ui_viewer_test ok')
