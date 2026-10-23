-- The first-launch guide (ui/guide_text.lua's nine pages) on the Uplink kit (ui/kit.lua): the Mother Sphere art on the
-- left, the page's title and body on the right, Page n of 9, and four rows: Next, Back, Don't show again and Close.
-- It opens by itself once a Lua load on the title screen while coop-guide.txt is missing beside coop-settings.txt
-- (the mod's first run), before the co-op saves' question, which waits while waiting() says so; and at any time from
-- the co-op menu's Guide row and with coop guide, on the title screen or in the game world (there not while the game
-- is paused or shows a menu). Don't show again, or a close on the last page, writes coop-guide.txt (one line, through
-- the link), and from then on it no longer opens by itself. While it is open the game ignores its keys (the kit's
-- input, with the mouse cursor shown), and main.lua hands it the co-op saves' question's keys through front(): up and
-- down move between the rows (past one that cannot run: Back on the first page, Next on the last), left and right
-- turn the page, Enter, Space or A runs the row (from 1 s after it shows, as the question), Esc or B closes; the row
-- the mouse moves onto takes the focus, and a left click runs the row under it. The game's input comes back 150 ms
-- after a close. It closes by itself when the place it opened in goes (the title left, a map change), the kit's root
-- hides or turns off, the game pauses in the world, or after 3 minutes with no key (a pad that is not XInput cannot
-- answer); the host's question (session/join.lua) closes it as it opens, as it does the menu. The art, by timediffer24
-- and given to this project (not covered by the GPL), is Assets\MotherSphere.png in the mod folder, imported once
-- with the engine's ImportFileAsTexture2D (again only once the engine freed it: a root built again drops the old
-- image); an import that fails is logged once and the guide shows without it. That import is its only engine call:
-- the kit makes the others.
local U=require('core.unreal')
local G=require('ui.guide_text')
local T=require('ui.text')
local Chat=require('session.chat')
local Guide={}
local FILE,LINE='coop-guide.txt','The co-op guide opens by itself on the title screen while this file is missing.\n'
local ART,RENDER='\\Assets\\MotherSphere.png','/Script/Engine.Default__KismetRenderingLibrary'
-- Seconds before the game's input comes back; seconds after it shows before it runs a row; 250 ms ticks with no key
-- (3 minutes); seconds between two looks at the row under the mouse.
local BACK,ARM,IDLE,HOVER=0.15,1,720,0.1
-- Layout units of the kit's 3840 by 2160, scaled from the screen's centre, at most 125 % (Guide.MOST): at any
-- ui_scale the panel stays on a 16:10 screen and under the co-op saves' badge. The art, 821 by 1200 pixels, keeps its
-- ratio; the text column right of it: body rows of WIDE columns (Mideum 34, 18 units a column, as the co-op saves'
-- question), the title's TITLE columns (Bold 56, about 32 units a column), a row label's LABEL (Bold 40, about 23).
Guide.PANEL={x=770,y=430,w=2300,h=1300}
Guide.ART={x=818,y=478,w=824,h=1204}
Guide.MOST=1.25
local P,A=Guide.PANEL,Guide.ART
local TX=A.x+A.w+48 -- The text column's left; it ends 48 units inside the panel.
Guide.WIDE,Guide.BODY,Guide.TITLE,Guide.LABEL=74,14,41,57
local WIDE,BODY=Guide.WIDE,Guide.BODY
local ROWS={'next','back','never','close'}
local COUNT=#G.en.pages
-- A page's body as drawn: each line of it (\n) broken into rows of WIDE columns.
function Guide.rows(body)
    local rows={}
    for line in (body..'\n'):gmatch('(.-)\n') do
        for _,row in ipairs(Chat.wrap(line,WIDE)) do rows[#rows+1]=row end
    end
    return rows
end
-- o: {kit=ui.kit's, link= (read_file, write_file), settings= (main.lua's: ui_language), theme=ui.THEME,
-- log=function(line), folder= the mod folder (main.lua's)}.
function Guide.new(o)
    local kit,link,settings,log=o.kit,o.link,o.settings,o.log
    local self={}
    local open,page,cursor,back_at,ready_at,idle=false,1,1,nil,0,0
    local place,here=nil,nil -- Where it opened, where the last slow was: 'title', 'world' or nil (loading).
    local hover,hover_at=false,0 -- The row under the mouse at the last look (false: none since it opened).
    local tried,seen,stopped=false,nil,false -- Opened by itself this load; coop-guide.txt there (nil: unread).
    local words,hint=G.en,T.en.hint
    local art,painted=nil,nil -- The texture ({o=, full=}, false once an import failed); the view whose image has it.
    kit.add('guide',{x=0,y=0,w=3840,h=2160,hit=true,pivot={X=0.5,Y=0.5},most=Guide.MOST},function(b)
        b.shade(-1920,-1080,7680,4320,o.theme.shade) -- Takes the mouse: no click reaches the title menu under it.
        b.panel(P.x,P.y,P.w,P.h)
        local v={art=b.image(A.x,A.y,A.w,A.h,nil,o.theme.white),title=b.text(TX,P.y+40,'','title'),body={},rows={}}
        v.art.show(false) -- Until its texture is in.
        for i=1,BODY do v.body[i]=b.text(TX,P.y+124+(i-1)*46,'','body') end
        v.page=b.text(TX,P.y+788,'','status',o.theme.grey)
        for i=1,#ROWS do v.rows[i]=b.row(TX-24,P.y+860+(i-1)*76,P.x+P.w-24-(TX-24)) end
        v.hints=b.hints(TX,P.y+1192,400,{{'move',''},{'enter',''},{'escape',''}})
        return v
    end)
    local function known()
        if seen==nil then seen=link.read_file(FILE)~=nil end
        return seen
    end
    -- The first run's guide still to show by itself.
    local function due() return not (tried or stopped) and not known() end
    local function usable(id) return (id~='next' or page<COUNT) and (id~='back' or page>1) end
    -- The art's texture: the one imported while the engine still holds it, else imported now; false once an import
    -- failed (said once); nil with no player controller (a map loads: tried again at the next draw).
    local function texture()
        if art==false then return false end
        local ok,got,full=pcall(function()
            local t=art and U.valid(art.o)
            if t and U.text(t:GetFullName())==art.full then return t,art.full end
            local pc=U.controller()
            if not pc then return nil end
            local x=U.valid(U.find(RENDER):ImportFileAsTexture2D(pc,o.folder..ART))
            if not x then error('no texture from '..o.folder..ART,0) end
            return x,U.text(x:GetFullName())
        end)
        if ok and not got then return nil end
        art=ok and {o=got,full=full} or false
        if not ok then log('guide: the art did not load ('..tostring(got)..'): the guide shows without it') end
        return ok and got
    end
    -- The art into this build's image: true once there, or given up.
    local function paint(v)
        local t=texture()
        if t==nil then return false end
        local shown=t and v.art.texture(t)
        if t and not shown then
            art=false
            log('guide: the art was refused: the guide shows without it')
        end
        v.art.show(shown==true)
        return true
    end
    local function draw()
        local v=open and kit.view('guide')
        if not v then return end
        if v~=painted and paint(v) then painted=v end
        local p=words.pages[page]
        v.title.set(p.title)
        local lines=Guide.rows(p.body)
        for i,t in ipairs(v.body) do t.set(lines[i] or '') end
        v.page.set(words.page:format(page,COUNT))
        for i,r in ipairs(v.rows) do
            r.set(words[ROWS[i]],'',not usable(ROWS[i]) and 'disabled' or i==cursor and 'focus' or 'normal')
        end
        v.hints[1].set(hint.move)
        v.hints[2].set(hint.select)
        v.hints[3].set(words.close)
    end
    -- coop-guide.txt, once: the guide no longer opens by itself.
    local function remember()
        if known() then return end
        seen=true
        local ok,why=link.write_file(FILE,LINE)
        log(ok and 'guide: coop-guide.txt written: the guide no longer opens by itself'
            or 'guide: coop-guide.txt not written ('..tostring(why)..'): the guide opens by itself at the next start')
    end
    local function close(why)
        if not open then return end
        if page==COUNT then remember() end
        open=false
        kit.show('guide',false,os.clock())
        kit.sound('close')
        back_at=os.clock()+BACK
        log('guide: closed on page '..page..' ('..why..')')
    end
    local function show(why)
        local culture=kit.language()
        words,hint=G.pick(culture,settings.ui_language),T.pick(culture,settings.ui_language).hint
        open,place,page,cursor,back_at,idle,hover,ready_at=true,here,1,1,nil,0,false,os.clock()+ARM
        kit.show('guide',true,os.clock())
        kit.input(true,'guide',true)
        if kit.off() then -- The kit turned off as it took the game's input: it would be open unseen.
            open=false
            return false,'the guide needs the co-op UI, which stopped (see the log)'
        end
        kit.sound('open')
        log('guide: open ('..why..')')
        draw()
        return true,'guide open'
    end
    -- Another page (dir -1 or 1), if there is one: the cursor off a row that can no longer run (Next on the last
    -- page goes to Close, Back on the first to Next).
    local function turn(dir)
        local was=page
        page=math.max(1,math.min(COUNT,page+dir))
        if not usable(ROWS[cursor]) then cursor=ROWS[cursor]=='next' and 4 or 1 end
        return page~=was
    end
    local function run(id)
        if id=='next' or id=='back' then turn(id=='next' and 1 or -1); return draw() end
        if id=='never' then remember() end
        close(id=='never' and "Don't show again" or 'Close')
    end
    -- The row under the mouse: its number, or nil.
    local function under()
        local v=kit.view('guide')
        for i,r in ipairs(v and v.rows or {}) do if r.hovered() then return i end end
    end
    function self.is_open() return open end
    -- The first run's guide open or still to open: the co-op saves' question waits meanwhile.
    function self.waiting() return open or due() end
    -- The co-op menu's Guide row and coop guide: open on its first page, on the title screen or in the game world with
    -- the kit's root up; true, or false and why.
    function self.open()
        if open then return true,'the guide is open' end
        if stopped then return false,'coop off is active until the game restarts' end
        if kit.off() then return false,'the guide needs the co-op UI, which is off (see the log)' end
        if not (here and kit.ready()) then return false,'the guide opens on the title screen or in the game world' end
        if here=='world' and kit.paused() then
            return false,'the guide does not open while the game is paused or shows a menu'
        end
        return show('asked')
    end
    -- Each 250 ms: whether a save is loaded (world) and whether the title screen shows (title), as the co-op saves'
    -- question takes them.
    function self.slow(world,title)
        if stopped then return end
        here=world and 'world' or title and 'title' or nil
        if open then
            if kit.off() or not kit.ready() then close('the co-op UI hid')
            elseif here~=place then close('left the '..place)
            elseif here=='world' and kit.paused() then close('the game paused')
            else
                idle=idle+1
                if idle>=IDLE then close('no key in 3 minutes') end
            end
        end
        if not (open or back_at) then kit.input(false,'guide') end -- Still due (no player controller at the close).
        if here=='title' and not open and due() then
            if kit.off() then
                tried=true
                log('guide: it cannot show (the co-op UI is off)')
            elseif kit.whole() then
                tried=true
                show('first run: no coop-guide.txt')
            end
        end
        draw() -- The kit may have built its root again meanwhile: on change only.
    end
    -- A navigation key while open: 'up', 'down', 'left', 'right', 'select', 'back' (Esc: Close) or 'click' (the left
    -- mouse button: the row under the mouse, if it can run). select and click from ARM after it showed.
    function self.nav(what)
        if not open or kit.off() then return end -- Unseen: the next slow closes it.
        if (what=='select' or what=='click') and os.clock()<ready_at then return end
        idle=0
        if what=='click' then
            local i=under()
            if i and usable(ROWS[i]) then
                cursor=i
                kit.sound('select')
                run(ROWS[i])
            end
        elseif what=='up' or what=='down' then
            repeat cursor=(cursor-1+(what=='up' and -1 or 1))%#ROWS+1 until usable(ROWS[cursor])
            kit.sound('move')
            draw()
        elseif what=='left' or what=='right' then
            if turn(what=='left' and -1 or 1) then kit.sound('change') end
            draw()
        elseif what=='select' then
            kit.sound('select')
            run(ROWS[cursor])
        elseif what=='back' then
            kit.sound('back')
            close('Esc')
        end
    end
    -- Each frame: the game's input back, once due. While open, every 100 ms: the row the mouse moved onto (another
    -- than at the last look) takes the focus, so a resting mouse never takes it back from the keys, nor the row under
    -- the mouse as it opens.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'guide')
        end
        if open and now>=hover_at then
            hover_at=now+HOVER
            local slot=under()
            local moved=hover~=false and slot~=hover
            hover=slot
            if moved then idle=0 end
            if moved and slot and usable(ROWS[slot]) and slot~=cursor then
                cursor=slot
                kit.sound('move')
                draw()
            end
        end
    end
    -- coop ui reset and the focus watchdog; why: who else closed it (the host's question as it opens).
    function self.close(why) close(why or 'coop ui reset') end
    -- coop off: nothing more (kit.stop gives the game its input back).
    function self.stop() stopped,open,back_at=true,false,nil end
    -- The guide in front of the co-op saves' question (session/saves.lua), for main.lua, which routes that question's
    -- keys, pad events, left clicks, ticks, slows, closes and stops to the pair: a key to the guide while it is open,
    -- else to the question; each slow the guide's first, so the question sees it open or still to open.
    function self.front(saves)
        return {is_open=function() return open or saves.is_open() end,
            nav=function(what) if open then return self.nav(what) end return saves.nav(what) end,
            tick=function(now) self.tick(now); saves.tick(now) end,
            slow=function(world,title) self.slow(world,title); saves.slow(world,title) end,
            close=function(keep) self.close(); saves.close(keep) end,
            stop=function() self.stop(); saves.stop() end}
    end
    return self
end
return Guide
