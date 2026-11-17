-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online tab (ui/kit/pause_tab.lua) over fakes. Covered: nothing before the game is ready; the class
-- loaded, the keeper made and the Construct hook registered once; a Construct adds one button after SB's 8 with the
-- word, SB's last button's style, RefreshDesign and HitTestInvisible; a second Construct adds none; a row rebuilt to
-- SB's 8 gets it again at the next slow while paused; a click over the button closes the pause menu once through the
-- native part's close (SB's own, never the widget's CloseSelf), one elsewhere or with no pause menu does nothing; RB
-- closes it, the co-op menu opens at the first tick after the unpause, or after 2 s still paused a give-up line and
-- notice; a close refused for now logs one line and waits for nothing, one that can never work stops the tab with one
-- STOP line and asks pausetab off; pause_tab off makes nothing and asks pausetab off; the asks:
-- once a change, a refused one again at the next slow and logged once; a pause menu of another shape stops the tab
-- with one STOP line and asks pausetab off; coop off stops it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local MASTER='/Game/Art/UI/Widget/GameMenu/WB_GameMenu_Master.WB_GameMenu_Master'
local MASTER_KEEPER=MASTER..'.StellarCoop_PauseTabKeeper'
local addresses=0
local function object(fields)
    fields=fields or {}
    addresses=addresses+8
    local address=addresses
    fields.type=function() return 'UObject' end
    fields.IsValid=function() return true end
    fields.GetAddress=function() return address end
    return fields
end
local missing=setmetatable({},{__index=function(_,k)
    if k=='type' then return function() return 'UObject' end end
    if k=='IsValid' then return function() return false end end
end})
local logs,hooks,objects,loaded,constructed
local mouse,under,ask_refusal
local function reset()
    logs,hooks,objects,loaded,constructed={},{},{},{},{}
    mouse,under,ask_refusal={X=10,Y=20},false,nil
end
reset()
StaticFindObject=function(path) return objects[path] or missing end
LoadAsset=function(path)
    loaded[#loaded+1]=path
    objects[path..'_C']=object({GetOuter=function() return object() end})
end
StaticConstructObject=function(class,outer,name,flags,internal)
    constructed[#constructed+1]={class=class,outer=outer,name=name,flags=flags,internal=internal}
    objects[MASTER_KEEPER]=object()
    return objects[MASTER_KEEPER]
end
FName=function(s) return s end
FText=function(s) return s end
RegisterHook=function(path,f) hooks[#hooks+1]={path=path,f=f} end
local function libraries()
    objects['/Script/UMG.Default__WidgetLayoutLibrary']=object({GetMousePositionOnPlatform=function() return mouse end})
    objects['/Script/UMG.Default__SlateBlueprintLibrary']=object({IsUnderLocation=function(_,geometry,at)
        assert(geometry.cached and at==mouse)
        return under
    end})
end
local Tab=require('ui.kit.pause_tab')

-- A pause menu whose tab row holds SB's 8 buttons, each with the five style fields.
local function menu(no_tap_set)
    local buttons,class={},object()
    local function button(i)
        return object({TextWidthValue=200+i,MinTextMargin=10+i,TextColor='color'..i,TextFont='font'..i,
            TextShadowColor='shadow'..i})
    end
    for i=1,8 do buttons[i]=button(i) end
    local row=object({
        GetChildrenCount=function() return #buttons end,
        GetChildAt=function(_,i) return buttons[i+1] end,
        RemoveChild=function(_,c)
            for i,x in ipairs(buttons) do if x==c then table.remove(buttons,i); return true end end
        end,
    })
    local tabs=object({TabButtonClass=class,TabButtonContainer=row,
        CreateDynamicChildUserWidget=function(_,c,panel)
            assert(c==class and panel==row)
            local made=object({refreshed=0,
                TextBlock=object({SetText=function(self,t) self.text=t end}),
                RefreshDesign=function(self) self.refreshed=self.refreshed+1 end,
                SetVisibility=function(self,v) self.visibility=v end,
                GetCachedGeometry=function() return {cached=true} end})
            buttons[#buttons+1]=made
            return made
        end})
    -- CloseSelf counted: it skips SB's own close (its menu-close save, the shown tab's deactivate), so never called.
    local m=object({closes=0,CloseSelf=function(self) self.closes=self.closes+1 end})
    if not no_tap_set then m.WB_Tap_Set=object({WB_Common_Tabs=tabs}) end
    return m,buttons
end

local function new(t)
    t=t or {}
    -- closes: the native closes asked; answer: what the next ones return (closed by default).
    local s={opens=0,notices=0,asks={},paused=true,enabled=true,ready=true,closes=0,answer={true}}
    s.tab=Tab.new({log=function(line) logs[#logs+1]=line end,ready=function() return s.ready end,
        enabled=function() return s.enabled end,word=function() return 'Online' end,
        paused=function() return s.paused end,open=function() s.opens=s.opens+1 end,
        notice=function() s.notices=s.notices+1 end,
        ask=function(line)
            s.asks[#s.asks+1]=line
            if ask_refusal then return false,ask_refusal end
            return true,'asked the native part: '..line
        end,
        close=function() s.closes=s.closes+1; return table.unpack(s.answer) end})
    return s
end
local function construct(m) for _,h in ipairs(hooks) do if h.path==MASTER..'_C:Construct' then h.f(m) end end end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end end

-- Not ready: no hook, no keeper, no load. Ready: the class loaded, one keeper, the Construct hook, once.
reset()
local s=new()
s.ready=false
s.tab.tick(0)
assert(#hooks==0 and #constructed==0 and #loaded==0,'Not ready: nothing')
s.ready=true
s.tab.tick(0); s.tab.tick(0)
assert(#loaded==1 and loaded[1]==MASTER and #constructed==1 and constructed[1].internal==0x40000000
    and constructed[1].name=='StellarCoop_PauseTabKeeper','The class loaded and kept once')
assert(#hooks==1 and hooks[1].path==MASTER..'_C:Construct' and #logs==1 and logs[1]:find('hook on',1,true),
    'One Construct hook')

-- A Construct: our button after SB's 8, with the word, SB's last button's style, refreshed and HitTestInvisible.
local m,buttons=menu()
construct(m)
local ours=buttons[9]
assert(#buttons==9 and ours.TextValue=='Online' and ours.TextBlock.text=='Online','Our button after SB\'s 8')
for _,k in ipairs({'TextWidthValue','MinTextMargin','TextColor','TextFont','TextShadowColor'}) do
    assert(ours[k]==buttons[8][k],'Style copied from SB\'s last button: '..k)
end
assert(ours.refreshed==1 and ours.visibility==3,'RefreshDesign once, HitTestInvisible')
construct(m)
assert(#buttons==9,'A second Construct of that pause menu adds none')
-- The asks: pausetab on at the first slow, none while nothing changes.
s.tab.slow(); s.tab.slow()
assert(#s.asks==1 and s.asks[1]=='pausetab on','Asked on once')
-- A row rebuilt to SB's 8 gets ours again as the 9th at the next slow while paused.
table.remove(buttons)
s.paused=false; s.tab.slow()
assert(#buttons==8,'Not paused: the row is left alone')
s.paused=true; s.tab.slow()
assert(#buttons==9 and buttons[9]~=ours and buttons[9].TextValue=='Online','Added again')

-- A click: over the button closes the pause menu once; elsewhere nothing.
libraries()
assert(s.tab.armed(),'Armed while a pause menu has our button')
s.tab.click(1); assert(s.closes==0,'A click elsewhere: nothing')
under=true
s.tab.click(1); s.tab.click(1.1)
assert(s.closes==1 and m.closes==0 and not s.tab.armed(),
    'A click over the button: closed once by SB\'s own close, then no pause menu')
s.tab.tick(1.5); assert(s.opens==0,'Still paused: not yet')
s.paused=false
s.tab.tick(1.6); s.tab.tick(1.7)
assert(s.opens==1,'The first tick after the unpause opens the co-op menu once')

-- RB on Settings: closed once; the co-op menu waits for the unpause; still paused 2 s on: the give-up.
s.paused=true
local m2=menu(); construct(m2)
s.tab.event(10); s.tab.event(10.1)
assert(s.closes==2 and m2.closes==0 and not logged('nothing opened'),'RB: closed once by SB\'s own close')
s.tab.tick(11); s.tab.tick(12.1); s.tab.tick(13)
assert(s.opens==1 and s.notices==1
    and logged("pause tab: the game stayed paused for 2 s; the pause menu is the player's"),
    'Still paused after 2 s: one line, one notice, no open')
-- With no pause menu seen: nothing closed, one line.
s.tab.event(20); assert(logged('nothing opened'))
-- A close refused for now (SB has no pause menu open): one line, no wait, the tab still works at the next pause menu.
s.answer={false,'the game has no pause menu open'}
local m7=menu(); construct(m7)
local before=#logs
s.tab.event(30); s.tab.tick(30.1); s.paused=false; s.tab.tick(30.2)
assert(s.closes==3 and #logs==before+1 and logs[#logs]=='pause tab: nothing closed: the game has no pause menu open'
    and s.opens==1 and s.notices==1,'Refused for now: one line, nothing opened')
s.paused=true; s.answer={true}
local m8=menu(); construct(m8)
s.tab.event(40); s.paused=false; s.tab.tick(40.1)
assert(s.closes==4 and s.opens==2,'The next pause menu closes and opens the co-op menu')
-- A close that can never work (no export in the native part, or it is off): one STOP line, pausetab off at the next
-- slow, no more buttons.
s.paused=true; s.answer={false,'the native part has no coop_pause_close (not exported)',true}
local m9,b9=menu(); construct(m9)
s.tab.event(50)
assert(logs[#logs]=='STOP: the native part has no coop_pause_close (not exported); the pause menu keeps its 8 tabs '
    ..'until the mod reloads' and not s.tab.armed(),logs[#logs])
s.tab.slow(); assert(s.asks[#s.asks]=='pausetab off','Stopped: off asked')
local m10,b10=menu(); construct(m10)
assert(#b9==9 and #b10==8 and m9.closes==0,'Stopped: no more buttons')

-- pause_tab off: no button, RB and a click do nothing, pausetab off asked at the next slow.
reset(); libraries()
s=new(); s.tab.tick(0)
s.enabled=false
local m3,b3=menu(); construct(m3)
s.tab.event(1); under=true; s.tab.click(1)
assert(#b3==8 and s.closes==0 and m3.closes==0 and not s.tab.armed() and #logs==1,'Off: nothing')
s.tab.slow(); assert(s.asks[1]=='pausetab off','Off asked')
-- A refused ask: asked again at the next slow, logged once.
s.enabled=true; ask_refusal='coop-request.txt cannot be written'
s.tab.slow(); s.tab.slow()
assert(#s.asks==3 and s.asks[3]=='pausetab on' and #logs==2
    and logs[2]=='pause tab: pausetab on not asked: coop-request.txt cannot be written','Refused: again, one line')
ask_refusal=nil
s.tab.slow(); s.tab.slow(); assert(#s.asks==4,'Asked once more, then nothing')

-- A pause menu with no WB_Tap_Set: one STOP line, pausetab off at the next slow, RB does nothing.
reset()
s=new(); s.tab.tick(0); s.tab.slow()
local m4=menu(true); construct(m4); construct(m4)
assert(#logs==2 and logs[2]:find('^STOP: ') and logs[2]:find('the pause menu has no WB_Tap_Set; the pause menu keeps '
    ..'its 8 tabs until the mod reloads$'),logs[2])
s.tab.slow(); assert(s.asks[#s.asks]=='pausetab off','Failed: off asked')
s.tab.event(1); assert(s.closes==0 and m4.closes==0 and #logs==2,'Failed: RB does nothing')

-- coop off: no more buttons, not armed.
reset()
s=new(); s.tab.tick(0)
local m5,b5=menu(); construct(m5)
assert(s.tab.armed())
s.tab.stop()
assert(not s.tab.armed())
local m6,b6=menu(); construct(m6)
assert(#b5==9 and #b6==8,'Stopped: no more buttons')
print('pause_tab_test ok')
