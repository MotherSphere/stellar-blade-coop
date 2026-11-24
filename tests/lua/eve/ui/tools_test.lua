-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- eve/ui/tools.lua over eve/commands.lua: the page's title and its three switches in the player's words; Select, left
-- and right ask the other state through the console's path; a fly or slowmo the native part took shows On (switched),
-- a refused one does not. The refusal comes back for the menu's note. Glide shows eve/glide.lua's state.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Tools=require('eve.ui.tools')
local Eve=require('eve.commands')
local T=require('ui.text')
local switched,glide,slot,refuse={},false,true,nil
local asked={}
local commands=Eve.new({
    coop_slot=function(what) if slot then return true end return false,what..' runs only on a co-op save' end,
    ask=function(line)
        return function() asked[#asked+1]=line; if refuse then return false,refuse end return true,'asked' end
    end,
    switched=function(name,on) switched[name]=on end,flight={on=function() return 'keys' end,off=function() end},
    glide={command=function(sub) glide=sub=='on'; return true,'glide '..sub end}})
local ran={}
local page=Tools.new({run=function(name,word) ran[#ran+1]=name..' '..word; return commands[name](word) end,
    on=function(name) if name=='glide' then return glide end return switched[name]==true end})
assert(page.title(T.fr)==T.fr.modules.eve)
local function row(id) for _,r in ipairs(page.rows(T.en)) do if r.id==id then return r end end end
local rows=page.rows(T.en)
assert(#rows==3 and rows[1].label=='Debug flight' and rows[2].label=='Slow motion' and rows[3].label=='Glide')
for _,r in ipairs(rows) do assert(r.value=='Off' and r.select and r.step) end
assert(row('fly').select()==true and ran[1]=='fly on' and asked[1]=='fly on' and row('fly').value=='On')
assert(row('fly').step(1)==true and ran[2]=='fly off' and row('fly').value=='Off')
assert(row('glide').select()==true and ran[3]=='glide on' and row('glide').value=='On')
assert(row('glide').step(-1)==true and row('glide').value=='Off')
-- Refused: off a co-op save, or by the native part; the value stays, the refusal comes back.
slot=false
local ok,why=row('slowmo').select()
assert(not ok and why=='coop slowmo on runs only on a co-op save' and row('slowmo').value=='Off')
slot,refuse=true,'not the pinned game build'
ok,why=row('slowmo').select()
assert(not ok and why=='not the pinned game build' and row('slowmo').value=='Off' and asked[#asked]=='slowmo on')
refuse=nil
assert(row('slowmo').select() and row('slowmo').value=='On' and switched.slowmo==true)
print('eve_tools_test ok')
