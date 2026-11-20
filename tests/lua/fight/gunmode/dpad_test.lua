-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's HUD entry (fight/gunmode/ui/dpad.lua). Its glyph: the Right twin of the pad glyph the game shows, or the
-- gun mode key's keyboard icon. Through gun mode over fake.lua, with a stub entry: ticked ten times a second with the
-- configured key (F4 unless set; nil for none), the rounds as "rounds | magazines" while the rifle is out and no text
-- while it is away, the hip-fire crosshair off while the rifle is away; taken off the HUD at coop off. None with
-- gun_mode=off or hud_entry=false. The rifle icon is the game's own texture, wanted from the keep.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('fight.gunmode.ui.dpad')
local P='/Game/Art/UI/Texture/Interaction/'
assert(D.glyph_path(P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up','F4')
    ==P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Up.KeyIcon_DualShock4_Gamepad_DPad_Up','F4')
    ==P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Right.KeyIcon_DualShock4_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q','F4')==P..'PC/KeyIcon_KeyBoard_F4.KeyIcon_KeyBoard_F4')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q',nil)==nil)
assert(D.glyph_path(P..'PC/Something.Something','F4')==nil and D.glyph_path(nil,'F4')==nil)
assert(D.ICON:match('^/Game/.+/([%w_]+)%.([%w_]+)$'),'the icon is a game texture path, no file')
do
    local Keep=require('core.keep')
    local want=Keep.want
    local wanted={}
    Keep.want=function(paths) for _,p in ipairs(paths) do wanted[p]=true end end
    D.new({log=function() end,valid=function() return false end,try=function() end})
    assert(wanted[D.ICON],'the keep wants the rifle icon')
    Keep.want=want
end

-- Through gun mode: a stub entry records each tick.
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local made,ticks,cross,hidden={},{},{},0
package.loaded['fight.gunmode.ui.dpad']={new=function()
    local e={}
    function e.tick(key,text,c) ticks[#ticks+1]={key=key,text=text,c=c} end
    function e.crosshair(on) cross[#cross+1]=on end
    function e.hide() hidden=hidden+1 end
    made[#made+1]=e
    return e
end}
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
package.loaded['fight.gunmode.mode']=nil
local GunMode=require('fight.gunmode.mode')
local Link=require('core.link')
local clock=100
os.clock=function() return clock end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end

do
    local w=Fake.new(); w.install()
    local gun=GunMode.new({log=function() end})
    frames(gun,60)
    assert(#made==1,'one entry')
    assert(#ticks>=9 and #ticks<=11,#ticks..' ticks in 1 s')
    assert(ticks[#ticks].key=='F4' and ticks[#ticks].text==nil,'the key, no rounds while the rifle is away')
    assert(cross[#cross]==false,'no crosshair while the rifle is away')
    clock=clock+1; gun.toggle_now()
    assert(gun.state.on)
    frames(gun,30)
    assert(ticks[#ticks].text=='60 | 5','the rounds while the rifle is out: '..tostring(ticks[#ticks].text))
    gun.stop('coop off')
    assert(hidden==1,'taken off the HUD at coop off')
    local n=#ticks
    frames(gun,60)
    assert(#ticks==n,'no tick after coop off')
end
do
    local w=Fake.new(); w.install()
    ticks={}
    local gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_key=F2\n')})
    frames(gun,10)
    assert(ticks[#ticks].key=='F2','the configured key: '..tostring(ticks[#ticks].key))
    ticks={}
    gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_key=none\n')})
    frames(gun,10)
    assert(#ticks>0 and ticks[#ticks].key==nil,'no key with gun_key=none')
    ticks={}
    gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_mode=off\n')})
    frames(gun,60)
    assert(#ticks==0,'no entry with gun_mode=off')
    local Config=require('fight.gunmode.config')
    Config.DEFAULTS.hud_entry=false
    gun=GunMode.new({log=function() end})
    frames(gun,60)
    assert(#ticks==0,'no entry with hud_entry=false')
    Config.DEFAULTS.hud_entry=true
end
print('gunmode dpad_test ok')
