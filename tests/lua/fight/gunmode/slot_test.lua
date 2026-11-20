-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's D-pad rifle slot (fight/gunmode/ui/slot.lua) over a fake kit, then through gun mode over fake.lua: the
-- slot shows at the rifle out with the rifle icon set and the counts written, follows the rounds, hides when the rifle
-- goes away, at a pause, in the photo mode, after a new controller and at stop. A part left behind by a root rebuild is made again. When
-- kit.part refuses, the kit's image (given the icon before it shows) and text stand in. Without the icon the counts
-- show alone, with one log line. No frame looks the icon up. The keep holds the icon: no look-up across rebuilds. A
-- refusal of kit.part does not stop the next build's try. The leaf's class is warmed.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local Slot=require('fight.gunmode.ui.slot')
local clock=100
os.clock=function() return clock end
FText=function(s) return s end

-- A kit as ui/kit/kit.lua's API gives it: one group, built again by rebuild() (its parts left behind), a part made
-- unless k.refuse, the pause as k.is_paused (its reads counted), the classes warmed in k.warmed.
local function fake_kit()
    local k={shown={},builds=0,parts={},reads=0,up=true,warmed={}}
    function k.warm_part(path) k.warmed[#k.warmed+1]=path end
    local function widget()
        local w={calls={},text=nil}
        local function rec(name) return function(_,...) w.calls[#w.calls+1]={name,...} end end
        w.Set,w.UpdateItemCount=rec('Set'),rec('UpdateItemCount')
        w.SetRenderScale,w.SetRenderTransformPivot=rec('SetRenderScale'),rec('SetRenderTransformPivot')
        w.TextBlock_Item_Count={SetText=function(_,t) w.text=t end,SetColorAndOpacity=function(_,c) w.color=c end}
        return w
    end
    function k.add(name,place,build) k.name,k.place,k.build=name,place,build end
    function k.rebuild()
        k.builds=k.builds+1
        local order={}
        local b={}
        function b.image()
            local i={on=nil}
            i.show=function(on) i.on=on; order[#order+1]='icon '..tostring(on) end
            i.texture=function(t) i.tex=t; order[#order+1]='texture'; return true end
            return i
        end
        function b.text(_,_,str,style)
            local t={str=str,style=style}
            t.set=function(s) t.str=s end
            t.color=function(c) t.col=c end
            t.show=function(on) t.on=on end
            return t
        end
        k.v=k.build(b)
        k.v.order=order
    end
    function k.view(name) return k.up and name==k.name and k.v or nil end
    function k.show(name,on) k.shown[name]=on end
    function k.paused() k.reads=k.reads+1; return k.is_paused==true end
    function k.part(group,class,x,y,w,h,fill)
        assert(group==Slot.GROUP and class==Slot.CLASS and w==nil and h==nil)
        if k.refuse then return nil,'part WB_MainHUD_ItemSlotGeneral_C: Create failed: no widget' end
        local wd=widget()
        fill(wd)
        local rec={w=wd,build=k.builds}
        k.parts[#k.parts+1]=rec
        return rec
    end
    function k.alive(rec) return rec and rec.build==k.builds and not rec.w.dead and rec.w or nil end
    function k.drop(rec) rec.w.dead=true end
    return k
end
local THEME={white={R=1,G=1,B=1,A=1},text={R=1,G=1,B=1,A=1}}
local ICON={IsValid=function() return true end}
-- StaticFindObject and LoadAsset with the rifle icon there (unless gone), each look-up of it counted.
local looks=0
local gone=false
local function engine(fallback)
    StaticFindObject=function(path)
        if path==Slot.ICON then looks=looks+1; return not gone and ICON or nil end
        return fallback and fallback(path)
    end
    local load=fallback and LoadAsset
    LoadAsset=function(path)
        if path==Slot.ICON then return not gone and ICON or nil end
        return load and load(path)
    end
end
local function called(w,name)
    local out={}
    for _,c in ipairs(w.calls) do if c[1]==name then out[#out+1]=c end end
    return out
end
local GREEN={0.35,0.85,1.0}

-- 1. The part: made at the first show with render scale 0.6, the icon set, the counts written; one icon look-up for
--    many frames, the pause read every 0.25 s; only changed numbers written. Hidden by the kit's pause.
do
    engine(); looks=0
    local k=fake_kit()
    local logs={}
    local s=Slot.new({kit=k,theme=THEME,log=function(m) logs[#logs+1]=m end,x=620,y=1820})
    assert(k.name==Slot.GROUP and k.place.x==620 and k.place.y==1820 and k.place.fixed==true)
    k.rebuild()
    assert(k.v.icon.on==false and k.v.count.on==false,'the stand-ins start hidden')
    s.show('60 | 5',GREEN,60)
    assert(#k.parts==1 and k.shown[Slot.GROUP]==true,'part made, group shown')
    local w=k.parts[1].w
    local sc=called(w,'SetRenderScale')[1]
    assert(sc and sc[2].X==0.6 and sc[2].Y==0.6,'render scale 0.6')
    assert(called(w,'Set')[1][2]==ICON,'Set with the rifle icon')
    local u=called(w,'UpdateItemCount')[1]
    assert(u[2]==60 and u[3]==false,'UpdateItemCount(60, false)')
    assert(w.text=='60 | 5','"rounds | magazines": '..tostring(w.text))
    for i=1,600 do
        clock=clock+1/60
        s.show(i<300 and '60 | 5' or '59 | 5',GREEN,i<300 and 60 or 59)
    end
    assert(looks==1,'the icon looked up once, not per frame: '..looks)
    assert(k.reads<=41 and k.reads>=37,'the pause read every 0.25 s: '..k.reads)
    assert(#called(w,'UpdateItemCount')==2 and w.text=='59 | 5','only changed numbers written')
    assert(#k.parts==1,'no part made again while it lives')
    k.is_paused=true; clock=clock+1
    s.show('59 | 5',GREEN,59)
    assert(k.shown[Slot.GROUP]==false,'hidden while the kit says paused')
    k.is_paused=false; clock=clock+1
    s.show('59 | 5',GREEN,59)
    assert(k.shown[Slot.GROUP]==true,'back after the pause')
    assert(#logs==0,table.concat(logs,'; '))
end

-- 2. A root rebuild leaves the part behind: it is made again at the next show. While shown it is made again when the
--    view changes.
do
    engine()
    local k=fake_kit()
    local s=Slot.new({kit=k,theme=THEME,log=function() end,x=0,y=0})
    k.rebuild()
    s.show('60 | 5',GREEN,60)
    s.hide()
    assert(k.shown[Slot.GROUP]==false)
    k.parts[1].w.dead=true -- Freed with no new view (the kit's alive gives nil).
    clock=clock+1
    s.show('60 | 5',GREEN,60)
    assert(#k.parts==2 and k.parts[2].w.text=='60 | 5','made again at the next show, counts written')
    k.rebuild() -- A map change while shown.
    clock=clock+1
    s.show('58 | 5',GREEN,58)
    assert(#k.parts==3 and k.parts[3].w.text=='58 | 5' and called(k.parts[3].w,'Set')[1][2]==ICON,'made again')
end

-- 3. kit.part refused: the kit image is given the icon before it shows, the num text shows the counts; said once.
do
    engine()
    local k=fake_kit()
    k.refuse=true
    local logs={}
    local s=Slot.new({kit=k,theme=THEME,log=function(m) logs[#logs+1]=m end,x=0,y=0})
    k.rebuild()
    s.show('60 | 5',GREEN,60)
    assert(k.v.icon.tex==ICON and k.v.icon.on==true,'the stand-in image has the icon')
    local o=k.v.order
    assert(o[#o-1]=='texture' and o[#o]=='icon true','texture set before it shows: '..table.concat(o,', '))
    assert(k.v.count.on==true and k.v.count.str=='60 | 5' and k.v.count.style=='num','the num text has the counts')
    assert(k.shown[Slot.GROUP]==true)
    k.rebuild(); clock=clock+1
    s.show('50 | 4',GREEN,50)
    assert(k.v.count.str=='50 | 4' and #logs==1,'one line: '..table.concat(logs,'; '))
    k.refuse=false -- The refusal passes: the next build makes the part.
    k.rebuild(); clock=clock+1
    s.show('50 | 4',GREEN,50)
    assert(#k.parts==1 and k.parts[1].w.text=='50 | 4','kit.part tried again at a new build')
    assert(#logs==1,'still one line: '..table.concat(logs,'; '))
end

-- 3b. The keep serves the icon: no look-up by path at any build, the icon wanted when the slot is made. The leaf's
--     class is warmed through the kit.
do
    engine(); looks=0
    local Keep=require('core.keep')
    local want,serves,get=Keep.want,Keep.serves,Keep.get
    local wanted,gets={},0
    Keep.want=function(paths) for _,p in ipairs(paths) do wanted[p]=true end end
    Keep.serves=function(p) return p==Slot.ICON end
    Keep.get=function(p) gets=gets+1; return p==Slot.ICON and ICON or nil end
    local k=fake_kit()
    local s=Slot.new({kit=k,theme=THEME,log=function() end,x=0,y=0})
    assert(wanted[Slot.ICON],'the keep wants the icon')
    assert(k.warmed[1]==Slot.CLASS:sub(1,-3) and #k.warmed==1,'the leaf class warmed: '..tostring(k.warmed[1]))
    for i=1,3 do
        k.rebuild(); clock=clock+1
        s.show('60 | 5',GREEN,60)
        assert(#k.parts==i and called(k.parts[i].w,'Set')[1][2]==ICON,'made again with the kept icon')
    end
    assert(looks==0 and gets==3,'no look-up by path across rebuilds: '..looks..' looks, '..gets..' gets')
    Keep.want,Keep.serves,Keep.get=want,serves,get
end

-- 4. No icon: no part, no image, the counts alone, one log line, no error; again after a rebuild.
do
    engine(); gone=true
    local k=fake_kit()
    local logs={}
    local s=Slot.new({kit=k,theme=THEME,log=function(m) logs[#logs+1]=m end,x=0,y=0})
    k.rebuild()
    s.show('60 | 5',GREEN,60)
    assert(#k.parts==0 and k.v.icon.on==false and k.v.icon.tex==nil,'no icon drawn')
    assert(k.v.count.on==true and k.v.count.str=='60 | 5','the counts alone')
    k.rebuild(); clock=clock+1
    s.show('60 | 5',GREEN,60)
    assert(#logs==1 and logs[1]:find('no rifle icon',1,true),table.concat(logs,'; '))
    gone=false
end

-- 5. Through gun mode over fake.lua: shown at the rifle out with the counts, the rounds followed while firing, hidden
--    at a pause (shown again after), when the rifle goes away, in the photo mode, after a new controller and at stop. No
--    icon look-up a frame.
do
    local w=Fake.new(); w.install()
    engine(w.find); looks=0
    local photo='0'
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,photo=function() return photo end})
    local k=fake_kit()
    gun.hud({kit=k,theme=THEME})
    k.rebuild()
    local function frames(n) for _=1,n do clock=clock+1/60; gun.tick() end end
    local function toggle(on)
        clock=clock+1
        gun.toggle_now()
        assert(gun.state.on==on,on and 'the rifle is out' or 'the rifle is away')
    end
    assert(k.shown[Slot.GROUP]==nil,'nothing shown before the rifle')
    toggle(true)
    frames(2)
    assert(k.shown[Slot.GROUP]==true and #k.parts==1,'shown at the rifle out')
    local p=k.parts[1].w
    assert(p.text=='60 | 5' and called(p,'Set')[1][2]==ICON,'icon and counts: '..tostring(p.text))
    w.down.RightMouseButton,w.down.LeftMouseButton=true,true
    w.pawn.bTPSMode=true
    frames(30)
    w.down.LeftMouseButton=nil
    frames(2)
    local left=p.text
    assert(left~='60 | 5' and left:match('^%d+ | 5$'),'the rounds followed: '..tostring(left))
    local u=called(p,'UpdateItemCount')
    assert(tostring(u[#u][2])==left:match('^%d+'),'UpdateItemCount has the magazine\'s rounds')
    w.paused=true; frames(1)
    assert(k.shown[Slot.GROUP]==false,'hidden at a pause')
    w.paused=false; frames(1)
    assert(k.shown[Slot.GROUP]==true,'shown after it')
    w.down.RightMouseButton=nil; w.pawn.bTPSMode=false
    toggle(false)
    assert(k.shown[Slot.GROUP]==false,'hidden when the rifle goes away')
    toggle(true); frames(2)
    assert(k.shown[Slot.GROUP]==true)
    photo='1'; frames(20)
    assert(not gun.state.on and k.shown[Slot.GROUP]==false,'hidden in the photo mode')
    photo='0'
    toggle(true); frames(2)
    assert(k.shown[Slot.GROUP]==true)
    gun.new_controller(w.pc) -- A death or a camp warp: the rifle away, hidden at the next frame.
    frames(1)
    assert(k.shown[Slot.GROUP]==false,'hidden after a new controller')
    clock=clock+5; frames(1)
    toggle(true); frames(2)
    assert(k.shown[Slot.GROUP]==true)
    frames(600)
    assert(looks==1,'one icon look-up for the part, none a frame: '..looks)
    gun.stop('coop off')
    assert(k.shown[Slot.GROUP]==false,'hidden at stop')
end

-- 6. gun_mode=off: no group.
do
    local w=Fake.new(); w.install()
    local gun=GunMode.new({log=function() end,settings=require('core.link').parse_settings('gun_mode=off\n')})
    local k=fake_kit()
    gun.hud({kit=k,theme=THEME})
    assert(k.name==nil,'no group with gun_mode=off')
end
print('gunmode slot: ok')
