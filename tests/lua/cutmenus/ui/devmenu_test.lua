-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- cutmenus/ui/devmenu.lua over cutmenus/devmenu.lua and cutmenus/commands.lua: every row of DevMenu.ROWS reachable
-- once (lockswitch as the lock-on's Off); a lasting switch On runs its row and reads On once the game took it; Off runs
-- clear, after which every lasting switch but the lock-on reads Off; enemyclear ends the enemies' switches; the
-- lock-on's Off runs lockswitch only; buttons say they ran; a refusal comes back with nothing read On; the panel steps
-- Off, Quests, Player info and back as the native part takes it; coop off ends every switch.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local pc={ServerRequest_Cheat=function() end}
package.loaded['core.player']={her=function() return {} end,controller=function() return pc end}
package.loaded['core.unreal']={find=function()
        return {FindRow=function() return {ID={get=function() return 9000001 end}} end}
    end,value_of=function(v) return type(v)=='table' and v.get and v.get() or v end,
    why=dofile('mod/StellarCoop/Scripts/core/unreal.lua').why}
local D=require('cutmenus.devmenu')
local Menus=require('cutmenus.commands')
local DM=require('cutmenus.ui.devmenu')
local T=require('ui.text')
local status_text='mod=v\nengine=on peers=0 warp=idle me=228\nslot=coop\n'
local dm=D.new({log=function() end,status=function() return status_text end})
local slot,devinfo_refused=true,nil
local panel='off'
local asked={}
local cmds=Menus.new({coop_slot=function(what) if slot then return true end return false,what..': not a co-op save' end,
    ask=function(line)
        return function() asked[#asked+1]=line; if devinfo_refused then return false,devinfo_refused end return true end
    end,devmenu=dm,panel=function(which) panel=which end})
local ran={}
local page=DM.new({run=function(name,a) ran[#ran+1]=name..' '..a; return cmds[name](a) end,devmenu=dm,
    panel=function() return panel end})
assert(page.title(T.en)=='Developer menu')
local function row(id) for _,r in ipairs(page.rows(T.en)) do if r.id==id then return r end end end
local function value(id) return row(id).value end
-- Every row of DevMenu.ROWS once, but lockswitch (the lock-on's Off); three headings; the panel last.
local rows,named=page.rows(T.en),{}
local heads={}
for _,r in ipairs(rows) do
    if r.head then heads[#heads+1]=r.label else assert(not named[r.id],r.id); named[r.id]=true end
    assert(r.head or (type(r.label)=='string' and r.select),r.id)
end
assert(table.concat(heads,'|')=='EVE|ENEMIES NEAR EVE|PANELS' and rows[#rows].id=='devinfo')
for _,r in ipairs(D.ROWS) do assert(named[r[1]] or r[1]=='lockswitch',r[1]) end
local n=0
for _ in pairs(named) do n=n+1 end
assert(n==20,'19 rows and the panel')
-- Switches: On runs the row; Off runs clear: every lasting switch but the lock-on reads Off.
for _,id in ipairs({'nodamage','speed200','nolockswitch','enemynoai'}) do
    assert(value(id)=='Off' and row(id).select()==true and value(id)=='On' and ran[#ran]=='devmenu '..id,id)
end
assert(row('speed200').step(1)==true and ran[#ran]=='devmenu clear')
assert(value('nodamage')=='Off' and value('speed200')=='Off' and value('enemynoai')=='Off'
    and value('nolockswitch')=='On')
assert(row('nolockswitch').select()==true and ran[#ran]=='devmenu lockswitch' and value('nolockswitch')=='Off')
row('enemyimmortal').select(); row('stealth').select()
assert(row('enemyclear').select()==true and value('enemyimmortal')=='Off' and value('stealth')=='On','enemyclear')
-- Buttons: no value, no step, they say they ran.
local ok,note=row('attack30').select()
assert(ok and note=='Asked of the game.' and value('attack30')=='' and not row('attack30').step
    and ran[#ran]=='devmenu attack30')
-- Off a co-op save: refused, nothing read On.
slot=false
ok,note=row('gauges').select()
assert(not ok and note=='coop devmenu gauges: not a co-op save' and value('gauges')=='Off')
ok,note=row('heal').select()
assert(not ok and note=='coop devmenu heal: not a co-op save')
slot=true
-- The panel: Off, Quests, Player info, Off; left goes back; a refusal keeps it.
assert(value('devinfo')=='Off' and row('devinfo').select()==true and asked[#asked]=='devinfo quest'
    and value('devinfo')=='Quests')
assert(row('devinfo').step(1) and value('devinfo')=='Player info')
assert(row('devinfo').step(1) and value('devinfo')=='Off')
assert(row('devinfo').step(-1) and asked[#asked]=='devinfo player' and value('devinfo')=='Player info')
devinfo_refused='not the pinned game build'
ok,note=row('devinfo').step(1)
assert(not ok and note=='not the pinned game build' and value('devinfo')=='Player info')
devinfo_refused=nil
-- coop off: every switch Off.
row('tachy').select()
dm.stop()
assert(value('tachy')=='Off' and value('stealth')=='Off')
print('cutmenus_ui_devmenu_test ok')
