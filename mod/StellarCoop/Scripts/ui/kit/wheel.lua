-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wheel: a ring of slots around the screen's centre, held open by a key or a pad button and played on its release,
-- drawn with Stellar Blade's own item wheel (WB_MainHUD_ItemEquip's slot pieces for 3, 4, 5 and 6 slots, its lit look,
-- its centre's soft disc, dotted circle and pointer arc, its open and focus sounds) at 80 % of the game's size, over a
-- shade, in one kit group (ui/kit/kit.lua). A module opens it with its pages (open), one ring a page; the mouse (its
-- direction from the screen's centre, past DEAD units, once it moved) or the right stick (the native part's sector)
-- points at a slot, and the slot stays lit until another one is pointed at; the release of the key or the button
-- that opened it, a left click or A plays the slot pointed at; Q and E (A and E on an AZERTY keyboard), a right click,
-- LB and RB change the page; Esc and B cancel. It takes the game's input as the co-op menu does, with no mouse cursor:
-- the camera stays still and the game runs on. The game's input comes back BACK s after any close, so the key that
-- closed it never reaches the game. It closes with nothing played when the module's guard gives a reason (each
-- frame), when the game's window is no longer in front, when our HUD hides or the game pauses (each 250 ms), at coop
-- ui reset and at coop off. The module's closed(why, id, page) hears every close, with the slot's id when one plays.
-- Its key hints: the kit's own key icons for the keyboard, SB's hint widget (the player's last device's icons) for the
-- pad and the page tabs. No engine call here: the kit makes them.
local Parts=require('ui.kit.parts')
local Wheel={}
Wheel.K=0.8 -- Of the game's item wheel's size.
Wheel.MOST=6 -- Slots a page at most: the game has wheel art for 3, 4, 5 and 6.
-- The group's box, the ring's centre in it (the box's, so ui_scale scales around it), its radii and the slot names'.
local W,H=2000,1640
local CX,CY=W//2,H//2
Wheel.INNER,Wheel.OUTER,Wheel.LABEL=293,632,462
Wheel.DEAD=60 -- Units from the centre the mouse must be past to point.
Wheel.MOVE=4 -- Units the mouse must move between two frames to point (a resting mouse never takes the stick's slot).
Wheel.BACK=0.15 -- Seconds from a close to the game's input back.
local TAB_Y,HINT_Y,CELL=96,1500,420 -- The page tabs' line, the hints' top and a hint's cell.
local ICON,GAP=66,12 -- A hint's icon, as the kit's own hints draw it.
-- The game's pieces (WB_MainHUD_ItemEquip's brushes, read in its export): width, height and the pivot's height in the
-- piece, the ring's centre: their bottom's middle, 80 units under it for the 3-slot pieces (1420x710: 790/710).
local GAME={[6]={790,790,1},[5]={980,791,1},[4]={1582,791,1},[3]={1420,710,790/710}}
local WRAP={[6]=370,[5]=434,[4]=520,[3]=520} -- A slot name's wrap width: its slot's chord at the label's radius.
-- The direction from the centre in degrees, clockwise from up (screen units: y down).
function Wheel.angle(dx,dy) return (math.deg(math.atan(dx,-dy))+360)%360 end
-- The middle of the native part's 5 degree stick sector s (1 to 72), in degrees clockwise from up.
function Wheel.sector_angle(s) return (s-1)*5+2.5 end
-- The slot (1 to n) at a direction, slot 1 at 12 o'clock and the next ones clockwise.
function Wheel.slot(n,angle) return math.floor((angle+180/n)/(360/n))%n+1 end
-- Slot i of an n-slot ring: the piece's place and size in the group's units, its pivot (the ring's centre) and its
-- turn, and the middle of its name.
function Wheel.place(n,i)
    local g=GAME[n]
    local w,h=math.floor(g[1]*Wheel.K+0.5),math.floor(g[2]*Wheel.K+0.5)
    local a=(i-1)*360/n
    local r=math.rad(a)
    return {x=CX-w/2,y=CY-g[3]*h,w=w,h=h,pivot={X=0.5,Y=g[3]},angle=a,lx=CX+Wheel.LABEL*math.sin(r),
        ly=CY-Wheel.LABEL*math.cos(r)}
end
-- Pages from groups ({title=, slots={...}}): a group of more than MOST slots split into the fewest pages, of sizes
-- that differ by one at most (11: 6 and 5), titled '<title> 1', '<title> 2'...
function Wheel.pages(groups)
    local out={}
    for _,g in ipairs(groups) do
        local k=math.max(1,math.ceil(#g.slots/Wheel.MOST))
        local base,extra,at=#g.slots//k,#g.slots%k,0
        for j=1,k do
            local n=base+(j<=extra and 1 or 0)
            local slots={}
            for i=1,n do slots[i]=g.slots[at+i] end
            at=at+n
            out[#out+1]={title=k>1 and g.title..' '..j or g.title,slots=slots}
        end
    end
    return out
end
-- o: {kit=ui/kit/kit.lua's, theme=its THEME, words=function() -> the player's words (ui/text.lua's), reads=the native
-- part's {stick=, held=, fkey=} (main/boot.lua's) or nil: an older DLL}.
function Wheel.new(o)
    local kit,theme=o.kit,o.theme
    local self={}
    local open,back_at,spec,page,pointed,mouse=false,nil,nil,1,nil,nil
    local parts,shown_parts=Parts.new(kit,function() end,'wheel'),{}
    kit.warm_part(Parts.ASSET.hint)
    kit.add('wheel',{x=(3840-W)/2,y=(2160-H)/2,w=W,h=H,pivot={X=0.5,Y=0.5},most=1.3},function(b)
        local v={sets={},fkeys={},icons={},labels={}}
        b.shade(CX-4000,CY-2400,8000,4800,theme.shade) -- The whole screen at any size, ui_scale 75 % too.
        v.blur=b.image(CX-288,CY-288,576,576,'wheel_blur',{R=0,G=0,B=0,A=0.5})
        for n=3,Wheel.MOST do
            local set={bg={},focus={},names={}}
            for i=1,n do
                local p=Wheel.place(n,i)
                set.bg[i]=b.image(p.x,p.y,p.w,p.h,'wheel'..n,nil,p.pivot)
                set.focus[i]=b.image(p.x,p.y,p.w,p.h,'wheel'..n..'_focus',nil,p.pivot)
                set.bg[i].turn(p.angle)
                set.focus[i].turn(p.angle)
                set.bg[i].show(false)
                set.focus[i].show(false)
                set.names[i]=b.text(p.lx,p.ly,'','name',theme.grey,{X=0.5,Y=0.5},{wrap=WRAP[n]})
                set.names[i].show(false)
            end
            v.sets[n]=set
        end
        v.dots=b.image(CX-284,CY-284,568,568,'wheel_dots')
        v.pointer=b.image(CX-284,CY-284,568,568,'wheel_pointer',nil,{X=0.5,Y=0.5})
        v.pointer.show(false)
        v.name=b.text(CX,CY-24,'','item',theme.white,{X=0.5,Y=0.5},{wrap=480})
        v.page=b.text(CX,CY+40,'','body',theme.beta,{X=0.5,Y=0.5})
        v.tabs={b.text(CX-420,TAB_Y,'','hint',theme.dim,{X=0.5,Y=0.5}),b.text(CX,TAB_Y,'','hint',theme.white,
            {X=0.5,Y=0.5}),b.text(CX+420,TAB_Y,'','hint',theme.dim,{X=0.5,Y=0.5})}
        b.image(CX-60,TAB_Y+28,120,6,nil,theme.beta) -- The current page's bar.
        local left=CX-2*CELL
        for k=1,12 do
            if k~=10 then v.fkeys[k]=b.image(left,HINT_Y,ICON,ICON,'key_f'..k); v.fkeys[k].show(false) end
        end
        for i,key in ipairs({false,'key_mouse','key_mouse_right','key_escape'}) do
            if key then v.icons[i]=b.image(left+(i-1)*CELL,HINT_Y,ICON,ICON,key) end
            v.labels[i]=b.text(left+(i-1)*CELL+ICON+GAP,HINT_Y+9,'','hint')
        end
        return v
    end)
    -- SB's hint widgets: the pad's three hints in the cells the keyboard's use (play, point, cancel), then the tabs'
    -- LB and RB (Q and E on the keyboard).
    local function hints(w)
        local left=CX-2*CELL
        local pad=spec.device=='pad'
        return {pad and Parts.hint(left,HINT_Y,w.wheel.release,'UI_DPad_Left') or false,
            pad and Parts.hint(left+CELL,HINT_Y,w.wheel.point,'UI_RightThumbstick') or false,false,
            pad and Parts.hint(left+3*CELL,HINT_Y,w.hint.back,'Negative') or false,
            #spec.pages>1 and Parts.hint(CX-700,TAB_Y-33,'','UI_LeftShoulder') or false,
            #spec.pages>1 and Parts.hint(CX+634,TAB_Y-33,'','UI_RightShoulder') or false}
    end
    local function ring() return math.max(3,#spec.pages[page].slots) end
    local function draw()
        local v=open and kit.view('wheel')
        if not v then return end
        local w=o.words()
        local pg=spec.pages[page]
        local n=ring()
        for m,set in pairs(v.sets) do
            for i=1,m do
                local slot=m==n and pg.slots[i]
                set.bg[i].show(m==n)
                set.focus[i].show(slot and pointed==i or false)
                set.names[i].show(slot and true or false)
                if slot then
                    set.names[i].set(slot.label)
                    set.names[i].color(pointed==i and theme.white or theme.grey)
                end
            end
        end
        local cur=pointed and pg.slots[pointed]
        v.name.set(cur and cur.label or spec.title or '')
        v.page.set(pg.title)
        v.pointer.show(cur and true or false)
        if cur then v.pointer.turn(180+(pointed-1)*360/n) end -- The game turns it 180 degrees to point up.
        local count=#spec.pages
        v.tabs[1].set(count>1 and spec.pages[(page-2)%count+1].title or '')
        v.tabs[2].set(pg.title)
        v.tabs[3].set(count>2 and spec.pages[page%count+1].title or '')
        local specs=hints(w)
        parts.sync(shown_parts,'wheel',specs,#specs)
        local pad=spec.device=='pad'
        for k,icon in pairs(v.fkeys) do icon.show(not pad and k==spec.key) end
        for i,word in ipairs({w.wheel.release,w.wheel.point,w.wheel.next,w.hint.back}) do
            if v.icons[i] then v.icons[i].show(not pad) end
            local game=pad and kit.alive(shown_parts[i])
            v.labels[i].set((pad and (i==3 or game)) and '' or word)
        end
    end
    local function close(why,slot)
        if not open then return end
        open=false
        kit.show('wheel',false)
        back_at=os.clock()+Wheel.BACK
        kit.sound(slot and 'select' or 'back')
        local s=spec
        if s.closed then s.closed(why,slot and slot.id,page) end
    end
    local function play(how)
        local slot=pointed and spec.pages[page].slots[pointed]
        close(slot and how or 'released with nothing pointed at',slot)
    end
    function self.is_open() return open end
    -- spec: {pages={{title=, slots={{id=, label=}, ...}}, ...} (3 to MOST slots a page; fewer leave slots empty),
    -- page=the first shown, title=the centre's word while nothing is pointed at, device='key' (key: the F-key's
    -- number, 1 to 12, whose release plays) or 'pad' (D-pad Left's), guard=function() -> why it must close or nil,
    -- closed=function(why, id, page)}. true; or false, a word of T.wheel for the screen ('off', 'world', 'native')
    -- and why in English.
    function self.open(s)
        if open then return false,'world','the wheel is open already' end
        if kit.off() then return false,'off','the UI stopped' end
        if not kit.ready() then return false,'world','our UI is not up (no world, or the title)' end
        if kit.paused() then return false,'world','the game is paused or shows one of its screens' end
        if kit.holding() then return false,'world','one of our screens holds the input' end
        if not o.reads then return false,'native','the native part has no coop_stick, coop_held or coop_fkey' end
        if not (s.pages and s.pages[1]) then return false,'world','no page' end
        spec,page,pointed,mouse,back_at=s,math.max(1,math.min(s.page or 1,#s.pages)),nil,nil,nil
        local v=kit.screen()
        if v then kit.move('wheel',v.w/2-CX,v.h/2-CY) end
        open=true
        kit.show('wheel',true)
        kit.input(true,'wheel',false)
        if kit.off() then open=false; return false,'off','the UI stopped as it took the input' end
        kit.centre_pointer()
        kit.sound('wheel_open')
        draw()
        return true
    end
    -- A navigation word while open: 'tab_left', 'tab_right' (the page; pointing starts over), 'select' (plays the slot
    -- pointed at; nothing when none), 'back' (cancels). true when the wheel took it.
    function self.nav(word)
        if not open then return false end
        if word=='tab_left' or word=='tab_right' then
            if #spec.pages>1 then
                page=(page-1+(word=='tab_left' and -1 or 1))%#spec.pages+1
                pointed=nil
                kit.sound('change')
                draw()
            end
        elseif word=='select' then
            if pointed then play('select') end
        elseif word=='back' then close('cancelled') end
        return true
    end
    -- Each frame: the game's input back once due; while open, the guard, the window, the release, then the stick or
    -- the mouse.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'wheel')
        end
        if not open then return end
        if kit.off() then return close('the UI stopped') end
        local why=spec.guard and spec.guard()
        if why then return close(why) end
        local r=o.reads
        local held
        if spec.device=='pad' then
            local h=r.held()
            if h==2 then return close('the game window is not in front') end
            held=h==1
        else
            local f=r.fkey()
            if f==13 then return close('the game window is not in front') end
            held=f==spec.key
        end
        local sector=r.stick()
        if sector==73 then return close('the game window is not in front') end
        if not held then return play('release') end
        local n,at=ring(),nil
        if sector>0 then at=Wheel.slot(n,Wheel.sector_angle(sector))
        else
            local x,y=kit.pointer()
            local v=kit.screen()
            if x and v then
                local dx,dy=x-v.w/2,y-v.h/2
                if mouse and math.abs(x-mouse[1])+math.abs(y-mouse[2])>Wheel.MOVE and dx*dx+dy*dy>Wheel.DEAD^2 then
                    at=Wheel.slot(n,Wheel.angle(dx,dy))
                end
                mouse={x,y}
            end
        end
        if at and at~=pointed and spec.pages[page].slots[at] then
            pointed=at
            kit.sound('wheel_move')
            draw()
        end
    end
    -- Each 250 ms: closed when our HUD may not show or the game pauses; the game's input given back again while
    -- still due.
    function self.slow(shown)
        if open and (not shown or kit.paused()) then close(shown and 'the game paused' or 'our HUD is hidden') end
        if not (open or back_at) then kit.input(false,'wheel') end
        draw()
    end
    -- coop ui reset and the focus watchdog: closed, nothing played (the kit gives the input back).
    function self.close(why) close(why or 'closed') end
    -- coop off: closed with nothing played and no call (kit.stop gives the input back).
    function self.stop()
        open,back_at=false,nil
        kit.show('wheel',false)
    end
    return self
end
return Wheel
