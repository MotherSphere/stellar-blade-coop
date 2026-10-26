-- The first-launch guide (ui/guide.lua and ui/guide_text.lua) on a fake kit, a fake link and fake engine objects, as
-- saves_test fakes them: every page and label in English, the other languages present and complete with English's
-- commands, keys, names and placeholders (English for what one lacks), every page within its rows and columns in every
-- language; the panel on screen at every ui_scale; the key hints and a dot a page, the current one lit; at the title
-- once a Lua load while coop-guide.txt is missing, once the kit has its whole look (waiting() meanwhile, which the
-- co-op saves' question reads), never in a world by itself; the keys (rows, pages, select from 1 s, Esc), the mouse
-- (hover every 100 ms, a click on the row under it) and the game's input given back 150 ms after a close; Don't show
-- again and a close on the last page writing coop-guide.txt; open() from the menu and coop guide and its refusals; its
-- own closes (the place left, the kit hidden or off, the game paused, 3 minutes with no key); the art imported once
-- with ImportFileAsTexture2D, set again on a new root, imported again once freed, a failure logged once with the guide
-- shown without it; coop off; and front(), the pair main.lua routes the co-op saves' question's keys and loops through.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local G=require('ui.guide_text')
local T=require('ui.text')
local R=require('nightop.recruiter_text')
local Chat=require('session.chat')
local Guide=require('ui.guide')
local clock=0
os.clock=function() return clock end
local function main_thread() local _,main=coroutine.running(); assert(main,'called from a coroutine') end

-- 1. The words. Nine pages in English, each a title and a body; the rows, the page line and the menu row.
assert(#G.en.pages==9,'Nine pages')
for i,p in ipairs(G.en.pages) do
    assert(type(p.title)=='string' and p.title~='' and type(p.body)=='string' and #p.body>100,'Page '..i)
end
assert(G.en.next=='Next' and G.en.back=='Back' and G.en.close=='Close' and G.en.never=="Don't show again"
    and G.en.page:format(3,9)=='Page 3 of 9' and G.en.row=='Guide')
assert(G.en.pages[1].title=='Welcome to Stellar Blade Online' and G.en.pages[9].title=='Help')
assert(G.en.pages[9].body:find('discord.gg/tvFApEEVfj',1,true) and G.en.pages[9].body:find('coop-report.txt',1,true)
    and G.en.pages[9].body:find('\nMother Sphere art by timediffer24.$'),'The last page credits the art')
assert(G.en.pages[5].body:find('coop nightop buy <n>',1,true) and G.en.pages[8].body:find('coop-settings.txt',1,true))
assert(G.en.pages[5].body:find('\ncoop nightop shop: open the shop screen\ncoop nightop buy: list the items\n',1,true),
    'shop opens the screen; buy alone lists')
-- A table for each language ui/text.lua has, and no other; each with G.en's keys at every level and its placeholders.
local function specs(s)
    local list={}
    for p in s:gmatch('%%.') do if p~='%%' then list[#list+1]=p end end
    return table.concat(list,' ')
end
local function same(t,en,at)
    for k,v in pairs(en) do
        local mine=rawget(t,k)
        assert(type(mine)==type(v),at..tostring(k)..': '..(mine==nil and 'missing' or 'a '..type(mine)))
        if type(v)=='table' then same(mine,v,at..tostring(k)..'.')
        else assert(specs(mine)==specs(v),at..tostring(k)..': "'..specs(mine)..'", not "'..specs(v)..'"') end
    end
    for k in pairs(t) do assert(en[k]~=nil,at..tostring(k)..': not in G.en') end
end
local codes={}
for name,t in pairs(T) do if type(t)=='table' then codes[#codes+1]=name end end
for _,name in ipairs(codes) do assert(type(G[name])=='table','G.'..name..': missing') end
local count=0
for name,t in pairs(G) do
    if type(t)=='table' then
        count=count+1
        assert(type(T[name])=='table','G.'..name..': not a language of ui/text.lua')
        if name~='en' then same(t,G.en,name..'.') end
    end
end
assert(count==#codes and count==22,count)
-- Each translated string keeps what its English holds of the console commands, file names, keys, the Discord address
-- and the names (KEEP, as written), and the keys B, C, E, Space, Ctrl, Shift and Enter as whole words, or under the
-- name OWN gives one in that language (its keyboard's, as ui/text.lua writes Strg, Maiusc, Invio, Maj or Intro).
local KEEP={'coop nightop start','coop nightop shop','coop nightop buy <n>','coop challenge','coop race record <name>',
    'coop race save','coop race start <name>','coop leviathan show','coop leviathan off','coop-settings.txt',
    'coop-report.txt','coop-link.log','UE4SS.log','discord.gg/tvFApEEVfj','F5','F6','F8','F9','F10','~','R2','View',
    'W A S D','Z Q S D','Stellar Blade Online','Steam','Discord','EVE','Leviathan','Naytiba','Shift Up','Mother Sphere',
    'timediffer24'}
local KEYS={'B','C','E','Space','Ctrl','Shift','Enter'}
local OWN={de={Space='Leertaste',Ctrl='Strg'},it={Space='Spazio',Shift='Maiusc',Enter='Invio'},no={Space='Mellomrom'},
    ru={Space='Пробел'},['zh-Hans']={Space='空格键'},fr={Shift='Maj',Enter='Entrée'},es={Shift='Mayús',Enter='Intro'},
    sv={Shift='Skift'}}
local function kept(t,en,at,own)
    for k,v in pairs(en) do
        local mine=t[k]
        if type(v)=='table' then kept(mine,v,at..k..'.',own)
        else
            for _,s in ipairs(KEEP) do assert(not v:find(s,1,true) or mine:find(s,1,true),at..k..': '..s) end
            for _,key in ipairs(KEYS) do
                local word='%f[%w]'..key..'%f[%W]'
                assert(not v:find(word) or mine:find(word) or own[key] and mine:find(own[key],1,true),at..k..': '..key)
            end
        end
    end
end
for name,t in pairs(G) do if type(t)=='table' and name~='en' then kept(t,G.en,name..'.',OWN[name] or {}) end end
assert(not pcall(kept,{pages={{body='F9: E'}}},{pages={{body='F10: E'}}},'',{}),'A lost key fails')
-- Where ui/text.lua names Shift, Ctrl or Enter its own way (its keys line, its chat hint), that language's guide never
-- uses the English name (Shift Up, the studio, aside).
local function all(t,out)
    for _,v in pairs(t) do if type(v)=='table' then all(v,out) else out[#out+1]=v end end
    return out
end
for name,t in pairs(G) do
    if type(t)=='table' and name~='en' then
        local text=table.concat(all(t,{}),'\n'):gsub('Shift Up','')
        for key,where in pairs({Shift=T[name].keys,Ctrl=T[name].keys,Enter=T[name].chat.hint}) do
            local word='%f[%w]'..key..'%f[%W]'
            assert(where:find(word) or not text:find(word),name..': '..key..', which ui/text.lua names its own way')
        end
    end
end
-- The pick: the game's culture, English with ui_language=english, for a culture with no table and for a word a table
-- lacks (a page, or a page's body).
assert(G.pick('fr-FR')==G.fr and G.pick('fr-FR','english')==G.en and G.pick(nil)==G.en and G.pick('xx-YY')==G.en)
local had=G.it
G.it={}
assert(G.pick('it-IT').pages[4].title==G.en.pages[4].title and G.pick('it-IT').next=='Next','Empty: English')
G.it={pages={{title='Benvenuto'}},next='Avanti'}
local it=G.pick('it-IT')
assert(it.pages[1].title=='Benvenuto' and it.pages[1].body==G.en.pages[1].body and it.pages[2]==G.en.pages[2]
    and it.next=='Avanti' and it.back=='Back','A word it lacks reads English')
G.it=had
-- In every language (English where a table lacks a word): each body within BODY rows of WIDE columns, each title
-- within TITLE columns, each row label within LABEL, the page line, and Close as the Esc hint within its 400-unit
-- cell after the icon's 78 units (Bold 30, about 17 units a column).
local function fits(at,text,most) assert(Chat.columns(text)<=most,at..': '..Chat.columns(text)..' > '..most) end
for name in pairs(R.TEXT) do
    local w=G.pick(name)
    for i=1,#G.en.pages do
        local p=w.pages[i]
        local rows=Guide.rows(p.body)
        assert(#rows<=Guide.BODY,name..' page '..i..': '..#rows..' rows')
        for _,row in ipairs(rows) do fits(name..' page '..i,row,Guide.WIDE) end
        fits(name..' title '..i,p.title,Guide.TITLE)
    end
    for _,id in ipairs({'next','back','never','close','row'}) do fits(name..'.'..id,w[id],Guide.LABEL) end
    fits(name..'.page',w.page:format(9,9),Guide.LABEL)
    fits(name..'.close (hint)',w.close,18)
end
-- Wrapping loses nothing: the rows, joined, are the body; a new line starts a row.
for i,p in ipairs(G.en.pages) do
    local rows=Guide.rows(p.body)
    assert(table.concat(rows,' ')==p.body:gsub('\n',' '),'Page '..i)
end
local last=Guide.rows(G.en.pages[9].body)
assert(last[#last]=='Mother Sphere art by timediffer24.')

-- The engine: UEHelpers' player controller, the rendering library's ImportFileAsTexture2D (each call's world and path;
-- import.raise: it raises; import.none: it gives nothing), textures that the engine may free (alive=false).
local function uobject(t)
    t.type=function() return 'UObject' end
    t.IsValid=function(s) main_thread(); return s.alive~=false end
    t.GetFullName=function(s) return s.full end
    return t
end
local pc_class=uobject({full='Class /Script/Engine.PlayerController'})
local pc=uobject({full='PlayerController /Game/Map.PC',IsA=function(_,class) return class==pc_class end})
local the_pc=pc
package.loaded.UEHelpers={GetPlayerController=function() return the_pc end}
local import={calls={},n=0}
local function texture()
    import.n=import.n+1
    return uobject({full='Texture2D /Engine/Transient.Texture2D_'..import.n})
end
local library=uobject({full='KismetRenderingLibrary /Script/Engine.Default__KismetRenderingLibrary',
    ImportFileAsTexture2D=function(_,world,path)
        main_thread()
        import.calls[#import.calls+1]={world=world,path=path}
        if import.raise then error(import.raise,0) end
        if import.none then return nil end
        import.last=texture()
        return import.last
    end})
StaticFindObject=function(path)
    if path=='/Script/Engine.PlayerController' then return pc_class end
    if path=='/Script/Engine.Default__KismetRenderingLibrary' then return library end
    error('unexpected path '..path)
end

-- The kit, as saves_test fakes it, its image keeping its texture and whether it shows (texture() false: refused);
-- rebuild() builds the group's view again (a new root).
local calls,state,built={},{ready=true,whole=true,off=false,paused=false,language=nil,refuse=false},{}
local holder,inputting,mousing=nil,false,false
local kit={}
local function builder()
    local b={}
    function b.panel(x,y,w,h) b.box={x=x,y=y,w=w,h=h} end
    function b.shade(x,y,w,h,color) b.shade_box={x=x,y=y,w=w,h=h,color=color} end
    function b.image(x,y,w,h,tex,tint)
        local i={x=x,y=y,w=w,h=h,tex=tex,c=tint,on=true}
        i.show=function(on) i.on=on end
        i.tint=function(c) i.c=c end
        i.texture=function(t) if state.refuse then return false end i.t=t; return true end
        return i
    end
    function b.text(x,y,s,style)
        local t={x=x,y=y,s=s,style=style}
        t.set=function(v) t.s=v end
        return t
    end
    function b.row(x,y,w)
        local r={x=x,y=y,w=w}
        r.set=function(l,v,st) r.l,r.v,r.st=l,v,st end
        r.hovered=function() return r.hover==true end
        return r
    end
    function b.hints(x,y,cell,list)
        local out,keys={},{}
        for i,h in ipairs(list) do out[i],keys[i]=b.text(x+(i-1)*cell,y,h[2],'hint'),h[1] end
        out.keys,out.x,out.y,out.cell=table.concat(keys,' '),x,y,cell
        return out
    end
    return b
end
function kit.add(name,place,build)
    local b=builder()
    built[name]={place=place,build=build,b=b,view=build(b)}
end
local function rebuild(name) local g=built[name]; g.b=builder(); g.view=g.build(g.b) end
function kit.ready() main_thread(); return state.ready and not state.off end
function kit.whole() return kit.ready() and state.whole end
function kit.view(name) return kit.ready() and built[name].view or nil end
function kit.off() return state.off end
function kit.paused() return state.paused end
function kit.language() return state.language end
function kit.show(name,on,now) calls[#calls+1]='show '..name..' '..tostring(on)..(now and ' tween' or '') end
function kit.sound(name) calls[#calls+1]='sound '..name end
function kit.input(on,who,mouse)
    if on then
        if inputting and holder==who then return end
        holder,inputting,mousing=who,true,mouse==true
        calls[#calls+1]='input true '..tostring(who)..(mouse and ' mouse' or '')
    elseif inputting and holder==who and not state.no_pc then -- As the kit: with a player controller only.
        inputting=false
        calls[#calls+1]='input false '..tostring(who)
    end
end
-- The link's own files beside coop-settings.txt: files (name to text), refuse: why a write fails.
local files,refuse,reads={},nil,0
local link={
    read_file=function(name) reads=reads+1; return files[name] end,
    write_file=function(name,text) if refuse then return false,refuse end files[name]=text; return true end,
}
local settings={ui_language='game'}
local logs={}
local FOLDER='C:\\Games\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop'
local guide
local function new() -- A new Lua load: a new guide, nothing imported yet.
    calls,built,holder,inputting,mousing,logs,import.calls={},{},nil,false,false,{},{}
    guide=Guide.new({kit=kit,link=link,settings=settings,
        theme={shade='shade',white='white',grey='grey',beta='beta',dim='dim'},
        log=function(line) logs[#logs+1]=line end,folder=FOLDER})
    return guide
end
local function view() return built.guide.view end
local function screen() -- Title, body rows, the page line, then the rows 'label|state'.
    local v=view()
    local out={v.title.s}
    for _,t in ipairs(v.body) do if t.s~='' then out[#out+1]=t.s end end
    out[#out+1]=v.page.s
    for _,r in ipairs(v.rows) do out[#out+1]=r.l..'|'..r.st end
    return table.concat(out,'\n')
end
local function rows() local out={}; for _,r in ipairs(view().rows) do out[#out+1]=r.l..'|'..r.st end
    return table.concat(out,' ') end
local function focus() for _,r in ipairs(view().rows) do if r.st=='focus' then return r.l end end end
local function lit() -- The page dots lit in Beta blue, the others dim.
    local out={}
    for i,d in ipairs(view().dots) do
        assert(d.c=='beta' or d.c=='dim',d.c)
        if d.c=='beta' then out[#out+1]=i end
    end
    return table.concat(out,' ')
end
local function since(n) return table.concat(calls,'|',n+1) end
local function quarter(world,title) clock=clock+0.25; return guide.slow(world,title) end
local function title() return quarter(false,true) end
local function key(what) return guide.nav(what) end
local function armed() clock=clock+1 end -- Select and click run 1 s after it shows.
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end end

-- 2. The group: over the whole screen, scaled from its centre up to 125 %, hidden until it shows, taking the mouse; the
-- shade larger than any screen at ui_scale 75; the art at its own ratio, the text column right of it, the rows and the
-- key hints inside the panel; nine page dots in a row at the right end of the page line, dim, after the longest page
-- line (Mideum 30, about 16 units a column); at every ui_scale the panel on a 16:10 screen (3456 by 2160) 48 units from
-- its edges, and under the co-op saves' badge (96 units high from y=96, scaled from its top: uncapped, 240 at 150 %).
new()
local place,b=built.guide.place,built.guide.b
assert(place.hit and not place.shown and place.pivot.X==0.5 and place.pivot.Y==0.5 and place.w==3840
    and place.h==2160 and place.most==1.25,'Hidden, centred, it takes the mouse')
local s=b.shade_box
assert(s.x<=-1920 and s.y<=-1080 and s.x+s.w>=3840+1920 and s.y+s.h>=2160+1080 and s.color=='shade')
local v,P=view(),b.box
assert(P.x==Guide.PANEL.x and P.w==Guide.PANEL.w)
local art=v.art
assert(math.abs(art.w/art.h-821/1200)<0.002 and art.x>=P.x+24 and art.y>=P.y+24 and art.y+art.h<=P.y+P.h-24)
assert(art.tex==nil and art.on==false and art.c=='white','Flat white, hidden until its texture is in')
local right=P.x+P.w-24
assert(v.title.x>art.x+art.w and v.body[1].x==v.title.x and #v.body==Guide.BODY and v.title.style=='title'
    and v.body[1].style=='body')
assert(v.body[#v.body].y+46<=v.page.y and v.page.y+40<=v.rows[1].y,'Body, page line, then the rows')
for _,r in ipairs(v.rows) do assert(r.x>art.x+art.w and r.x+r.w==right and r.w-36-24>=Guide.LABEL*23) end
assert(v.rows[#v.rows].y+76<=v.hints.y and v.hints.y+66<=P.y+P.h-22,'The key hints inside the panel')
assert(v.hints.keys=='move enter escape' and v.hints.x+3*v.hints.cell<=right)
assert(#v.dots==#G.en.pages and lit()=='','A dim dot a page')
for i,d in ipairs(v.dots) do
    assert(d.tex=='small' and d.w==d.h and d.y==v.dots[1].y and (i==1 or d.x>v.dots[i-1].x+d.w),'Dot '..i)
    assert(d.y>=v.page.y and d.y+d.h<=v.page.y+40,'Dot '..i..' by the page line')
end
assert(v.dots[#v.dots].x+v.dots[1].w<=right-24,'The dots inside the text column')
for name in pairs(R.TEXT) do
    assert(v.page.x+Chat.columns(G.pick(name).page:format(9,9))*16+24<=v.dots[1].x,name..'.page: over the dots')
end
assert(Guide.WIDE*18<=right+24-48-v.title.x and Guide.TITLE*32<=right+24-48-v.title.x,'The columns fit')
for pct=75,150,5 do
    local k=math.min(pct/100,place.most)
    local function at(x,c) return c+(x-c)*k end
    local x0,x1,y0,y1=at(P.x,1920),at(P.x+P.w,1920),at(P.y,1080),at(P.y+P.h,1080)
    assert(x0>=48 and x1<=3456-48 and y0>=96+96*pct/100 and y1<=2160-48,'ui_scale '..pct)
end

-- 3. The first run: at the title only, once the kit has its whole look; waiting() until then (the co-op saves'
-- question waits). Its input with the mouse cursor, page 1 with Next focused and Back unusable, the art imported from
-- the mod folder through the player controller and set on its image.
files={}
assert(guide.waiting() and reads==1,'Still to open: the question waits')
quarter(true,false); quarter(false,false)
assert(#calls==0 and not guide.is_open() and guide.waiting(),'Not in a world, not while loading')
state.whole=false; title()
assert(#calls==0 and not guide.is_open() and guide.waiting(),'The kit still warms its look: it waits')
state.whole=true; title()
assert(guide.is_open() and guide.waiting() and reads==1,'Then it shows; the file read once')
assert(since(0)=='show guide true tween|input true guide mouse|sound open',since(0))
assert(logged('guide: open (first run: no coop-guide.txt)'))
local page1=Guide.rows(G.en.pages[1].body)
assert(screen()==table.concat({G.en.pages[1].title,table.concat(page1,'\n'),'Page 1 of 9','Next|focus',
    'Back|disabled',"Don't show again|normal",'Close|normal'},'\n'),screen())
assert(v.hints[1].s=='Move' and v.hints[2].s=='Select' and v.hints[3].s=='Close' and lit()=='1')
assert(#import.calls==1 and import.calls[1].world==pc and import.calls[1].path==FOLDER..'\\Assets\\MotherSphere.png',
    'Imported from the mod folder')
assert(art.t==import.last and art.on==true,'The art shown')

-- 4. The keys: right and left turn the page (not past either end); up and down move between the rows past one that
-- cannot run; select from 1 s after it shows.
local n=#calls
key('left'); assert(v.page.s=='Page 1 of 9' and #calls==n and lit()=='1','No page before the first')
key('right'); assert(v.page.s=='Page 2 of 9' and v.title.s=='Play together' and calls[#calls]=='sound change')
assert(lit()=='2','The second dot lit')
assert(rows()=="Next|focus Back|normal Don't show again|normal Close|normal")
key('left'); assert(v.page.s=='Page 1 of 9' and rows()=="Next|focus Back|disabled Don't show again|normal Close|normal")
key('down'); assert(focus()=="Don't show again" and calls[#calls]=='sound move','Past Back on page 1')
key('up'); assert(focus()=='Next')
key('up'); assert(focus()=='Close','Up wraps')
key('down'); assert(focus()=='Next')
n=#calls
key('select'); assert(v.page.s=='Page 1 of 9' and #calls==n,'Not in its first second')
armed()
key('select'); assert(v.page.s=='Page 2 of 9' and calls[#calls]=='sound select')
key('down'); key('select'); assert(v.page.s=='Page 1 of 9' and focus()=='Next','Back on page 2: page 1, Next focused')

-- 5. The mouse: every 100 ms, the row it moved onto takes the focus (not the row under it as the guide opened, nor a
-- row that cannot run); a click runs the row under it, nothing off the rows or on a row that cannot run.
local r=v.rows
r[3].hover=true; guide.tick(clock)
assert(focus()=='Next','Under the mouse at the first look: not taken')
r[3].hover=nil; r[4].hover=true
guide.tick(clock+0.05); assert(focus()=='Next','Every 100 ms only')
clock=clock+0.1; guide.tick(clock); assert(focus()=='Close' and calls[#calls]=='sound move','Moved onto Close')
r[4].hover=nil; r[2].hover=true
clock=clock+0.1; guide.tick(clock); assert(focus()=='Close','Back cannot run on page 1')
n=#calls
key('click'); assert(guide.is_open() and #calls==n,'A click on Back on page 1: nothing')
r[2].hover=nil
key('click'); assert(guide.is_open() and #calls==n,'A click on no row: nothing')
r[1].hover=true
key('click'); assert(v.page.s=='Page 2 of 9' and focus()=='Next' and calls[#calls]=='sound select','Next clicked')
r[1].hover=nil
clock=clock+0.1; guide.tick(clock)

-- 6. To the last page: Next cannot run there and the focus goes to Close; Close writes coop-guide.txt (one line)
-- and closes; the game's input back 150 ms later, once.
for _=2,8 do key('select') end
assert(v.page.s=='Page 9 of 9' and v.title.s=='Help' and rows()=="Next|disabled Back|normal Don't show again|normal "
    ..'Close|focus',rows())
assert(lit()=='9','The last dot lit')
assert(v.body[#Guide.rows(G.en.pages[9].body)].s=='Mother Sphere art by timediffer24.','The credit on its own row')
key('select')
assert(not guide.is_open() and calls[#calls-1]=='show guide false tween' and calls[#calls]=='sound close')
assert(files['coop-guide.txt']:match('^[^\n]+\n$') and logged('coop-guide.txt written'),'One line written')
assert(logged('guide: closed on page 9 (Close)'))
assert(not guide.waiting(),'The question no longer waits')
n=#calls
guide.tick(clock+0.1); assert(#calls==n,'Not before 150 ms')
guide.tick(clock+0.15); assert(calls[#calls]=='input false guide')
guide.tick(clock+1); title(); assert(#calls==n+1,'Once, and not again by itself')
quarter(true,false); title(); assert(not guide.is_open(),'Once a Lua load')
-- A new Lua load with the file there: never by itself, nothing to wait for.
new(); title(); title()
assert(not guide.is_open() and not guide.waiting() and #calls==0,'coop-guide.txt there: not by itself')

-- 7. Don't show again writes it at once, on any page; Esc (or Close) before the last page writes nothing, so it opens
-- by itself again at the next load.
files={}
new(); title(); assert(guide.is_open())
armed(); key('down'); key('select')
assert(not guide.is_open() and files['coop-guide.txt'] and logged("closed on page 1 (Don't show again)"))
files={}
new(); title(); key('right'); key('right'); key('back')
assert(not guide.is_open() and calls[#calls-2]=='sound back' and not files['coop-guide.txt'] and logged('(Esc)'))
new(); title(); assert(guide.is_open(),'Opens again at the next load')
-- A write that fails is logged; the guide still does not open by itself again in this load.
refuse='cannot write coop-guide.txt.tmp'
armed(); key('down'); key('select')
assert(not files['coop-guide.txt'] and logged('coop-guide.txt not written (cannot write coop-guide.txt.tmp)'))
quarter(true,false); title(); assert(not guide.is_open() and not guide.waiting())
refuse=nil

-- 8. open() (the menu's Guide row, coop guide): on page 1 in the world or at the title with the root up; refused
-- while loading, with the root hidden or the kit off, and in the world while the game is paused or shows a menu.
files={['coop-guide.txt']='x\n'}
new()
assert(select(2,guide.open())=='the guide opens on the title screen or in the game world','No slow yet: no place')
quarter(true,false)
state.paused=true
assert(select(2,guide.open())=='the guide does not open while the game is paused or shows a menu')
state.paused=false
state.ready=false
assert(select(2,guide.open())=='the guide opens on the title screen or in the game world','Root hidden')
state.ready,state.off=true,true
assert(select(2,guide.open())=='the guide needs the co-op UI, which is off (see the log)')
state.off=false
assert(guide.open()==true and guide.is_open() and v~=view() and view().page.s=='Page 1 of 9')
assert(logged('guide: open (asked)') and select(2,guide.open())=='the guide is open')
v,art=view(),view().art
assert(art.t==import.last and art.on==true and #import.calls==1)
guide.close(); guide.open(); assert(#import.calls==1,'Opened again: not imported again')
quarter(true,false); assert(guide.is_open(),'Stays open in the world')

-- 9. Its own closes: the place it opened in left, the root hidden, the kit off, the game paused in the world, 3
-- minutes with no key (a key or a mouse move starts them over); the game's input still given back once due.
for _,case in ipairs({{'left the world',function() quarter(false,false) end},
        {'the co-op UI hid',function() state.ready=false; quarter(true,false); state.ready=true end},
        {'the co-op UI hid',function() state.off=true; quarter(true,false); state.off=false end},
        {'the game paused',function() state.paused=true; quarter(true,false); state.paused=false end}}) do
    quarter(true,false)
    assert(guide.open()==true)
    case[2]()
    assert(not guide.is_open() and logged('guide: closed on page 1 ('..case[1]..')'),case[1])
end
title(); assert(guide.open()==true)
for _=1,700 do title() end
key('right'); key('left')
for _=1,719 do title() end
assert(guide.is_open(),'A key starts the 3 minutes over')
title(); assert(not guide.is_open() and logged('(no key in 3 minutes)'))
state.paused=true; title(); assert(guide.open()==true,'At the title the game shows its cursor: no pause')
state.paused=false
-- No player controller at the close (a map loads): the input given back once there is one, at a slow.
quarter(false,false); assert(not guide.is_open())
state.no_pc=true; guide.tick(clock+1); quarter(false,false); assert(inputting,'No player controller: still due')
state.no_pc=false; quarter(false,false); assert(calls[#calls]=='input false guide','Given back at the next slow')

-- 10. The art: set again on a new root without an import while the engine holds the texture, imported again once it
-- freed it, and no player controller is no failure (tried again at the next draw).
files={['coop-guide.txt']='x\n'}
new(); quarter(true,false); guide.open()
local first=import.last
assert(view().art.t==first and #import.calls==1)
rebuild('guide'); quarter(true,false)
assert(view().art.t==first and view().art.on==true and #import.calls==1,'A new root: the same texture, set again')
first.alive=false; rebuild('guide'); the_pc=nil; quarter(true,false)
assert(view().art.on==false and view().art.t==nil and #import.calls==1,'Freed, no player controller: not yet')
the_pc=pc; quarter(true,false)
assert(#import.calls==2 and view().art.t==import.last and view().art.on==true,'Imported again')
-- An import that fails (it raises or gives nothing): logged once, the guide shown without it, never tried again in
-- this load; a texture the image refuses likewise.
for _,case in ipairs({{'raise','file not found'},{'none',true}}) do
    import[case[1]]=case[2]
    new(); quarter(true,false); guide.open()
    local calls_now=#import.calls
    assert(guide.is_open() and view().art.on==false and view().title.s==G.en.pages[1].title)
    rebuild('guide'); quarter(true,false); guide.close(); guide.open()
    assert(#import.calls==calls_now,'Never tried again')
    local said=0
    for _,l in ipairs(logs) do if l:find('^guide: the art did not load') then said=said+1 end end
    assert(said==1,'Said once')
    import[case[1]]=nil
end
assert(logged('guide: the art did not load (no texture from '..FOLDER..'\\Assets\\MotherSphere.png)'))
state.refuse=true
new(); quarter(true,false); guide.open()
assert(view().art.on==false and logged('guide: the art was refused: the guide shows without it'))
state.refuse=false

-- 11. The game's language picks the words, English with ui_language=english or for what a table lacks; the menu
-- hints are ui/text.lua's.
local fr=G.fr
G.fr={pages={{title='Bienvenue dans Stellar Blade Online'}},next='Suivant'}
state.language='fr-FR'
new(); quarter(true,false); guide.open()
assert(view().title.s=='Bienvenue dans Stellar Blade Online' and view().rows[1].l=='Suivant'
    and view().rows[4].l=='Close' and view().hints[1].s==T.fr.hint.move)
guide.close()
settings.ui_language='english'; guide.open()
assert(view().title.s==G.en.pages[1].title and view().rows[1].l=='Next')
settings.ui_language,state.language,G.fr='game',nil,fr

-- 12. coop ui reset closes it (logged as such); coop off stops it: nothing more, its keys do nothing.
guide.close(); guide.open(); guide.close()
assert(not guide.is_open() and logged('(coop ui reset)'))
guide.open(); guide.stop()
n=#calls
assert(not guide.is_open() and not guide.waiting())
key('right'); title(); quarter(true,false); guide.tick(clock+1)
assert(#calls==n and select(2,guide.open())=='coop off is active until the game restarts')

-- 13. front(): main.lua's pair for the co-op saves' question. A key to the guide while it is open, else to the
-- question; open while either is; each slow and tick the guide's first (the question sees it open or still to open);
-- a close and a stop reach both, the question's keep passed on.
files={}
new()
local seen={}
local saves={is_open=function() return seen.open==true end,
    nav=function(what) seen[#seen+1]='saves nav '..what end,
    tick=function() seen[#seen+1]='saves tick '..tostring(guide.is_open()) end,
    slow=function() seen[#seen+1]='saves slow '..tostring(guide.waiting()) end,
    close=function(keep) seen[#seen+1]='saves close '..tostring(keep) end,
    stop=function() seen[#seen+1]='saves stop' end}
local pair=guide.front(saves)
assert(not pair.is_open())
clock=clock+0.25; pair.slow(false,true)
assert(pair.is_open() and guide.is_open() and seen[#seen]=='saves slow true','The guide first: the question waits')
pair.nav('right'); assert(view().page.s=='Page 2 of 9' and #seen==1,'Its keys: the guide')
pair.tick(clock); assert(seen[#seen]=='saves tick true')
pair.nav('back'); assert(not guide.is_open() and not pair.is_open())
pair.nav('down'); assert(seen[#seen]=='saves nav down','Closed: the question')
seen.open=true; assert(pair.is_open())
clock=clock+0.25; pair.slow(false,true); assert(seen[#seen]=='saves slow false','Done: the question no longer waits')
pair.close(true); assert(seen[#seen]=='saves close true')
pair.stop(); assert(seen[#seen]=='saves stop' and not guide.waiting())
io.stdout:write('guide_test ok\n')
