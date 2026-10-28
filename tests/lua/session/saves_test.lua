-- The co-op saves at the title (session/saves.lua) on a fake kit and a fake link: with auto_coop_save=ask the question
-- shows once a visit of the title, while the game uses your own saves (saves=main), the Steam ID is known and no copy
-- pass runs, once the kit has its whole look; Convert and play co-op (Play co-op once a co-op copy exists) asks for
-- "saves coop" and shows the pass until saves=coop, then closes with a notice; a pass that ends without the switch, or
-- a request with no answer in 2 s, shows why with only the solo choices left (an unread status is no answer; a pass
-- said failed that switches after all is said on); a solo choice after a request asks "saves main"; Decide later, Esc
-- and 60 s with no key close it for this visit; Enter and a click take a choice only from 1 s after it shows; a left
-- click takes the choice under the mouse; Don't ask again rewrites only auto_coop_save's line, then plays co-op; the
-- title left closes it. With always, no question: the request at each visit, its result as a notice. With off, nothing.
-- The game's input is the question's while it is open and comes back 150 ms after it closes. While the game uses the
-- co-op copies, a badge at the top right of the title. English and French.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local Saves=require('session.saves')
local clock=0
os.clock=function() return clock end
-- UE4SS refuses any call from a coroutine (main.lua's loops run on the game thread): none here either.
local function main_thread() local _,main=coroutine.running(); assert(main,'called from a coroutine') end

-- The kit, as chat_test fakes it: the group's view from a builder that keeps what each text and row was set to.
local calls,state,built={},{ready=true,whole=true,off=false,language=nil},{}
local holder,inputting=nil,false
local kit={}
function kit.add(name,place,build)
    local b={}
    function b.panel(_,y,_,h) b.bottom=y+h end
    function b.shade(x,y,w,h,color) built.shade={x=x,y=y,w=w,h=h,color=color} end
    function b.text(_,_,s)
        local t={s=s}
        t.set=function(v) t.s=v end
        return t
    end
    function b.row()
        local r={}
        r.set=function(l,v,st) r.l,r.v,r.st=l,v,st end
        r.hovered=function() return r.hover==true end
        return r
    end
    -- Its labels; keys: the icons asked, in order ('move enter escape'); y: the row's top; bottom: the panel's.
    function b.hints(_,y,_,list)
        local out,keys={},{}
        for i,h in ipairs(list) do out[i],keys[i]=b.text(0,0,h[2]),h[1] end
        out.keys,out.y,out.bottom=table.concat(keys,' '),y,b.bottom
        return out
    end
    built[name]={place=place,view=build(b)}
end
function kit.ready() main_thread(); return state.ready and not state.off end
function kit.whole() return kit.ready() and state.whole end
function kit.view(name) return kit.ready() and built[name].view or nil end
function kit.off() return state.off end
function kit.language() return state.language end
function kit.show(name,on,now) calls[#calls+1]='show '..name..' '..tostring(on)..(now and ' tween' or '') end
function kit.sound(name) calls[#calls+1]='sound '..name end
function kit.input(on,who) -- As the kit: each once, and off only from the one who holds it (and a player controller).
    if on then
        if inputting and holder==who then return end
        holder,inputting=who,true
        calls[#calls+1]='input true '..tostring(who)
    elseif inputting and holder==who and not state.no_pc then
        inputting=false
        calls[#calls+1]='input false '..tostring(who)
    end
end
-- The link: the slot line's saves= and verdict, the convert= line and the Steam ID as of its last changes(); the
-- requests written; coop-settings.txt.
local info,asked,mode,file,refuse={},{},'none',nil,nil
local link={
    saves=function() return info end,
    request=function(line)
        if refuse then return false,refuse end
        asked[#asked+1]=line
        return true,'asked the native part: '..line
    end,
    mode=function() return mode end,
    settings_text=function() return file end,
    write_settings=function(text) if refuse then return false,refuse end file=text; return true end,
}
local settings={auto_coop_save='ask',ui_language='game',shared_enemies=false}
local said,said_en,logs={},{},{} -- said_en: the English given with each.
local env={LOCALAPPDATA='C:\\Users\\Ana\\AppData\\Local'}
local present,opened={},{} -- The files that exist; every path looked at.
local view
local function new()
    calls,built,holder,inputting,said,said_en,logs,asked,opened={},{},nil,false,{},{},{},{},{}
    return Saves.new({kit=kit,link=link,settings=settings,theme={shade='shade',text='white'},
        say=function(text,en) said[#said+1]=text; said_en[#said]=en end,log=function(line) logs[#logs+1]=line end,
        env=function(name) return env[name] end,
        exists=function(path) opened[#opened+1]=path; return present[path]==true end})
end
local saves=new()
local function screen() -- The question as drawn: title, body rows, then the choices 'label|value|state'.
    local v=built.saves.view
    local out={v.title.s}
    for _,t in ipairs(v.body) do if t.s~='' then out[#out+1]=t.s end end
    for _,r in ipairs(v.rows) do if r.l~='' then out[#out+1]=r.l..'|'..r.v..'|'..r.st end end
    return table.concat(out,'\n')
end
local function since(n) return table.concat(calls,'|',n+1) end
local function quarter(world,title) clock=clock+0.25; return saves.slow(world,title) end
-- Enter or a click, 1 s on: the question takes no choice sooner after it shows.
local function pick(what) clock=clock+1; return saves.nav(what) end
local MAIN={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
local function at(t) local c={}; for k,v in pairs(MAIN) do c[k]=v end; for k,v in pairs(t or {}) do c[k]=v end; return c end

-- The group: over the whole screen (scaled from its centre, the shade larger than any screen at ui_scale 75), it takes
-- the mouse, hidden until the question shows.
local place=built.saves.place
assert(place.hit and not place.shown and place.pivot.X==0.5 and place.pivot.Y==0.5,'Hidden, and it takes the mouse')
assert(built.shade.x<=-1920 and built.shade.y<=-1080 and built.shade.x+built.shade.w>=3840+1920
    and built.shade.y+built.shade.h>=2160+1080 and built.shade.color=='shade','A shade under it all: no click goes through')

-- Not before every condition holds: the title (a pawn on its map, no save loaded), saves=main, no pass running, the
-- kit's whole look. Nothing to the native part, no input taken.
info=at()
for _,case in ipairs({{false,false,'no title'},{true,true,'a save loaded'},{false,false,'loading'}}) do
    quarter(case[1],case[2])
    assert(#calls==0 and #asked==0 and not saves.is_open(),case[3])
end
for _,case in ipairs({at({saves='?'}),at({saves='off'}),{convert='idle'},at({convert='busy 1/6'}),
        {saves='main',convert='idle',slot='none'}}) do
    info=case -- Not read yet, another build, no slot line (an older native part), a pass running, no Steam ID yet.
    quarter(false,true)
    assert(#calls==0 and #asked==0 and not saves.is_open(),tostring(case.saves)..' '..tostring(case.convert))
end
-- The co-op saves already: nothing to ask, the badge at the top right instead (hidden in a world).
info=at({saves='coop'}); quarter(false,true)
assert(since(0)=='show badge true' and #asked==0 and built.badge.view.text.s=='CO-OP SAVES',since(0))
assert(built.badge.place.pivot.X==1 and not built.badge.place.shown and not built.badge.place.hit,'Top right, hidden')
quarter(true,false); assert(since(1)=='show badge false','Not in a world')
quarter(false,true); assert(since(2)=='show badge true')
info=at()
state.whole=false; quarter(false,true); assert(since(3)=='show badge false','The kit still warms its look: it waits')
calls={}
state.whole=true
assert(quarter(false,true)==nil and saves.is_open(),'Then it shows')
assert(since(0)=='show saves true tween|input true saves|sound open',since(0))
assert(screen()=='CO-OP SAVES\nPlay co-op on copies of your saves?\n'
    ..'StellarCoop copies your saves to separate co-op files, and Continue and Load\n'
    ..'Game then use those copies. Your own saves are not changed.\n'
    ..'Convert and play co-op||focus\nPlay solo normally||normal\nDecide later||normal\n'
    ..'Don\'t ask again|Always co-op|normal',screen())
local v=built.saves.view
assert(v.hints[1].s=='Move' and v.hints[2].s=='Select' and v.hints[3].s=='Decide later','Esc decides later')
assert(v.hints.keys=='move enter escape','It moves on W, A, S, D (Z, Q on AZERTY) and the arrows, as the menu')
assert(v.hints.y+66<=v.hints.bottom,'The key icons (66 units high) stay inside the panel')
-- No co-op copy in this account's folder: each slot's looked at, by its full path.
assert(#opened==5 and opened[1]=='C:\\Users\\Ana\\AppData\\Local\\SB\\Saved\\SaveGames\\76561198000000001\\'
    ..'StellarBladeCoop00.sav' and opened[5]:find('StellarBladeCoop04.sav$'),opened[1])

-- Up and down wrap over the four choices; left and right do nothing.
saves.nav('up'); assert(screen():find("Don't ask again|Always co-op|focus",1,true) and calls[#calls]=='sound move')
saves.nav('down'); saves.nav('down'); assert(screen():find('Play solo normally||focus',1,true))
local n=#calls
saves.nav('left'); saves.nav('right'); assert(#calls==n and screen():find('Play solo normally||focus',1,true))

-- Enter and a click take a choice only from 1 s after the question showed, so a press meant for the title screen does
-- not answer it; the arrows and Esc act at once.
built.saves.view.rows[3].hover=true
saves.nav('select'); saves.nav('click'); clock=clock+0.75; saves.nav('select'); saves.nav('click')
assert(saves.is_open() and #calls==n and #asked==0 and screen():find('Play solo normally||focus',1,true),since(n))
built.saves.view.rows[3].hover=nil
clock=clock+0.25

-- Play solo normally: closed, nothing asked, the game's input back 150 ms later (not before), once this visit.
saves.nav('select')
assert(not saves.is_open() and #asked==0 and since(n)=='sound select|show saves false tween|sound close',since(n))
assert(logs[#logs]=='co-op saves: Play solo normally: your own saves',logs[#logs])
saves.tick(clock+0.1); assert(calls[#calls]=='sound close','Not yet')
saves.tick(clock+0.15); assert(calls[#calls]=='input false saves')
n=#calls
for _=1,4 do quarter(false,true) end
assert(#calls==n and not saves.is_open(),'Not again in this visit')
-- The title left (a save loaded) and shown again: a new visit asks again.
quarter(true,false); quarter(false,false); quarter(false,true)
assert(saves.is_open() and screen():find('Convert and play co-op||focus',1,true),'Back at the title: asked again')

-- Esc: Decide later, the same way out.
n=#calls
saves.nav('back')
assert(not saves.is_open() and #asked==0 and since(n)=='sound back|show saves false tween|sound close',since(n))
assert(logs[#logs]=='co-op saves: Decide later: your own saves')
quarter(false,true); assert(not saves.is_open())
-- The input still due is asked back at each slow until given (a map change has no player controller).
state.no_pc=true
saves.tick(clock+1); assert(calls[#calls]=='sound close' and inputting,'No player controller: still due')
state.no_pc=false
quarter(false,true); assert(calls[#calls]=='input false saves','Asked again at the next slow')

-- A co-op copy exists (made in an earlier run): Play co-op, and the text for copies.
quarter(true,false)
present['C:\\Users\\Ana\\AppData\\Local\\SB\\Saved\\SaveGames\\76561198000000001\\StellarBladeCoop02.sav']=true
quarter(false,true)
assert(screen()=='CO-OP SAVES\nPlay co-op on your co-op saves?\n'
    ..'Continue and Load Game then use your co-op copies. Your own saves are not\nchanged.\n'
    ..'Play co-op||focus\nPlay solo normally||normal\nDecide later||normal\nDon\'t ask again|Always co-op|normal',
    screen())

-- Play co-op: "saves coop", the question stays with the pass's steps (no choice left; Esc cancels), until saves=coop.
n=#calls
pick('select')
assert(asked[1]=='saves coop' and saves.is_open() and logs[#logs]=='co-op saves: asked the native part: saves coop')
assert(screen()=='CO-OP SAVES\nSwitching to the co-op saves.',screen())
pick('select'); saves.nav('down'); assert(#asked==1 and screen()=='CO-OP SAVES\nSwitching to the co-op saves.')
info=at({convert='busy 2/6'}); quarter(false,true)
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 2 of 6.',screen())
info=at({convert='busy 5/6'}); quarter(false,true)
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 5 of 6.')
info=at({convert='done',saves='coop'}); quarter(false,true)
assert(not saves.is_open() and since(n):find('show saves false tween|sound close$'),since(n))
assert(said[1]=='Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.',said[1])
assert(logs[#logs]=='co-op saves on' and #asked==1,'Nothing more asked')
saves.tick(clock+0.2); assert(calls[#calls]=='input false saves')
quarter(false,true); assert(not saves.is_open() and #said==1,'Once')

-- A pass that ends without the switch: why, with the solo choices only; Play solo normally then asks "saves main",
-- which withdraws a switch still to come.
present={}
saves=new()
info=at({convert='done'}) -- An earlier pass.
quarter(false,true)
pick('select'); assert(asked[1]=='saves coop')
info=at({convert="error:slot 3's save fails the game's own check, so it was not copied"})
quarter(false,true)
assert(screen()=='CO-OP SAVES\nThe co-op saves could not be switched on. Your own saves were not changed.\n'
    .."slot 3's save fails the game's own check, so it was not copied\n"
    ..'Play solo normally||focus\nDecide later||normal',screen())
assert(logs[#logs]=="co-op saves stay off: slot 3's save fails the game's own check, so it was not copied",logs[#logs])
saves.nav('down'); assert(screen():find('Decide later||focus',1,true))
saves.nav('down'); assert(screen():find('Play solo normally||focus',1,true),'Two choices, wrapping')
pick('select')
assert(asked[2]=='saves main' and not saves.is_open() and #said==0,'Withdrawn, closed, nothing said')

-- The same pass result as before the request, for 2 s: refused (said in coop-link.log); Esc then withdraws too.
saves=new()
info=at({convert='done'})
quarter(false,true); pick('select')
for _=1,7 do quarter(false,true) end
assert(screen()=='CO-OP SAVES\nSwitching to the co-op saves.','Under 2 s: still waiting')
quarter(false,true)
assert(screen()=='CO-OP SAVES\nThe co-op saves could not be switched on. Your own saves were not changed.\n'
    ..'coop-link.log says why.\nPlay solo normally||focus\nDecide later||normal',screen())
saves.nav('back'); assert(asked[2]=='saves main' and not saves.is_open())
-- A pass still running after 2 minutes counts as failed; a pass whose line changed without the switch at once.
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='busy 1/6'})
for _=1,479 do quarter(false,true) end
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 1 of 6.')
quarter(false,true); assert(screen():find('could not be switched on',1,true),'2 minutes')
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='done'}); quarter(false,true)
assert(screen():find('coop-link.log says why.',1,true),'Done, yet still saves=main: the switch failed')
-- Esc while the pass runs: "saves main" withdraws the switch, the question closes for this visit.
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='busy 1/6'}); quarter(false,true)
saves.nav('back')
assert(asked[1]=='saves coop' and asked[2]=='saves main' and not saves.is_open())
quarter(false,true); assert(not saves.is_open() and #asked==2,'The pass not followed any more')
-- A request that cannot be written: why, at once.
saves=new()
info=at()
quarter(false,true)
refuse='cannot write C:\\Mod\\coop-request.txt.tmp'
pick('select')
assert(#asked==0 and screen():find('cannot write C:\\Mod\\coop-request.txt.tmp',1,true),screen())
refuse=nil
-- A reason the native part wrote with controls or bytes that are not UTF-8: cleaned, never raised.
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='error:bad\0 \255name\27'}); quarter(false,true)
assert(screen():find('\nbad name\n',1,true),screen())
-- An unread status (link.changes() keeps no line then) during a pass is no news: the pass goes on to the switch.
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='busy 1/6'}); quarter(false,true)
info={}; quarter(false,true)
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 1 of 6.',screen())
info=at({convert='busy 2/6'}); quarter(false,true)
info=at({convert='done',saves='coop'}); quarter(false,true)
assert(not saves.is_open() and said[1]:find('^Co%-op saves on') and #asked==1,'Switched')
-- Unread at the request: the next line read is no failure, and 2 s with no step is.
saves=new()
info=at()
quarter(false,true)
info={}; pick('select')
info=at(); quarter(false,true)
assert(asked[1]=='saves coop' and screen()=='CO-OP SAVES\nSwitching to the co-op saves.',screen())
info={}
for _=1,6 do quarter(false,true) end
assert(screen()=='CO-OP SAVES\nSwitching to the co-op saves.')
quarter(false,true); assert(screen():find('could not be switched on',1,true),'2 s of unread status: no answer')
-- A pass said failed (here no answer in 2 s) that switches after all: the question closes, the copies said on.
info=at({convert='done',saves='coop'}); quarter(false,true)
assert(not saves.is_open() and said[1]:find('^Co%-op saves on') and #asked==1,tostring(said[1]))

-- Don't ask again: auto_coop_save=always rewritten in its own line (every other byte kept), in effect at once, then co-op.
file='\239\187\191# mine\r\nmenu_key=F7\r\nauto_coop_save=ask\r\nchat=off\r\n'
saves=new()
info=at()
quarter(false,true)
saves.nav('up'); pick('select')
assert(file=='\239\187\191# mine\r\nmenu_key=F7\r\nauto_coop_save=always\r\nchat=off\r\n',file)
assert(settings.auto_coop_save=='always' and asked[1]=='saves coop' and saves.is_open())
assert(logs[#logs-1]=='co-op saves: auto_coop_save=always saved in coop-settings.txt',logs[#logs-1])
info=at({saves='coop',convert='done'}); quarter(false,true); assert(not saves.is_open())
-- A file that cannot be read or written: said in the log, co-op all the same.
settings.auto_coop_save,file='ask',nil
saves=new()
info=at()
quarter(false,true); saves.nav('up'); pick('select')
assert(settings.auto_coop_save=='ask' and asked[1]=='saves coop'
    and logs[#logs-1]=='co-op saves: auto_coop_save=always not saved: coop-settings.txt cannot be read',logs[#logs-1])

-- A left click: the choice under the mouse; over none, nothing.
saves=new()
info=at()
quarter(false,true)
n=#calls
pick('click'); assert(saves.is_open() and #calls==n,'Over no choice')
built.saves.view.rows[2].hover=true
pick('click')
assert(not saves.is_open() and #asked==0 and calls[n+1]=='sound select'
    and logs[#logs]=='co-op saves: Play solo normally: your own saves',logs[#logs])

-- 60 s with no key (a controller alone cannot answer it): Decide later. A key starts the 60 s again; none while a pass
-- runs; the error screen has its own 60 s, then withdraws the switch. Each slow draws it again (the kit sets only what
-- changed), so a root the kit built again shows it whole.
saves=new()
info=at()
quarter(false,true)
for _=1,200 do quarter(false,true) end
saves.nav('down')
built.saves.view.title.s=''
for _=1,239 do quarter(false,true) end
assert(saves.is_open() and built.saves.view.title.s=='CO-OP SAVES','A key restarted the 60 s; drawn again')
quarter(false,true)
assert(not saves.is_open() and #asked==0 and logs[#logs-1]=='co-op saves: no key in 60 s'
    and logs[#logs]=='co-op saves: Decide later: your own saves',logs[#logs])
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='busy 1/6'})
for _=1,300 do quarter(false,true) end
assert(saves.is_open() and screen():find('step 1 of 6',1,true),'Not while the pass runs')
info=at({convert='error:the backup folder could not be made'}); quarter(false,true) -- Its first quarter.
for _=1,238 do quarter(false,true) end
assert(saves.is_open() and screen():find('the backup folder',1,true))
quarter(false,true); assert(not saves.is_open() and asked[2]=='saves main','60 s on the error screen')

-- The title left while it asks: closed (Decide later), nothing asked; while a pass runs: followed, its result said.
saves=new()
info=at()
quarter(false,true)
quarter(false,false)
assert(not saves.is_open() and #asked==0 and calls[#calls]=='sound close')
saves=new()
info=at()
quarter(false,true); pick('select')
quarter(true,false)
assert(not saves.is_open() and #asked==1)
info=at({convert='error:Continue or Load Game was chosen at the title (load mode 2)',slot='main'})
quarter(true,false)
assert(said[1]=='Co-op saves off for this load: Continue or Load Game was chosen at the title (load mode 2). You '
    ..'play your own saves.',said[1])

-- The UI off (an engine error): no question; one log line a visit; your own saves.
saves=new()
info=at()
state.off=true
quarter(false,true); quarter(false,true)
assert(#calls==0 and not saves.is_open() and #logs==1
    and logs[1]=='co-op saves: the question cannot show (the co-op UI is off): your own saves',logs[1])
pick('select'); assert(#asked==0)
state.off=false

-- always: no question; "saves coop" once a visit at the title; its result said once the kit shows, at the title or
-- later in a world.
settings.auto_coop_save='always'
saves=new()
info=at({slot='unknown'}) -- At a game start Lua sees the title before the native part read coop-state.txt.
state.ready=false
quarter(false,true)
assert(#asked==0 and not saves.is_open(),'Not before the native part judged the title: it would refuse for the run')
info=at()
quarter(false,true)
assert(asked[1]=='saves coop' and #calls==0 and not saves.is_open(),'No question, no kit needed')
quarter(false,true); assert(#asked==1,'Once a visit')
info=at({saves='coop',convert='done'}); quarter(false,true)
assert(#said==0,'Not while the kit is down at the title: the line above EVE drops it there')
quarter(false,false); assert(#said==0)
quarter(true,false); assert(said[1]=='Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.')
state.ready=true
quarter(true,false); assert(#said==1)
-- Its failure, said at once with the kit up; and asked again at the next visit only.
saves=new()
info=at()
quarter(false,true)
info=at({convert='error:the backup folder could not be made'})
quarter(false,true)
assert(said[1]=='Co-op saves off for this load: the backup folder could not be made. You play your own saves.',said[1])
quarter(false,true); assert(#asked==1)
quarter(true,false); info=at(); quarter(false,true); assert(#asked==2 and asked[2]=='saves coop','A new visit')
-- A switch with no answer at all (the native part refused it before any pass, as it does when it has not judged the
-- title yet at a game start): asked again in the same visit, 3 times, then said off.
saves=new()
said,said_en={},{}
asked={}
info=at()
quarter(false,true)
assert(#asked==1)
for try=1,3 do
    for _=1,8 do quarter(false,true) end -- WAIT quarters with no pass: no answer, then asked again in that slow.
    assert(logs[#logs-1]=='co-op saves: no answer to the switch; asked again ('..try..' of 3)',logs[#logs-1])
    assert(#asked==try+1 and asked[#asked]=='saves coop' and #said==0,'Asked again at once, no notice meanwhile')
end
for _=1,8 do quarter(false,true) end
assert(logs[#logs]=='co-op saves stay off: no switch (coop-link.log says why)' and #asked==4,logs[#logs])
quarter(false,true); assert(#asked==4,'Not past 3 tries in a visit')
quarter(true,false); info=at(); quarter(false,true); assert(#asked==5,'A new visit asks again')
-- In Japanese the line comes with its English: the line above EVE shows that one (its font has Latin-1 only).
state.language='ja-JP'
saves=new()
info=at()
quarter(false,true)
info=at({convert='error:the backup folder could not be made'})
quarter(false,true)
assert(#said==1 and said[1]~=said_en[1] and said[1]:find('the backup folder could not be made',1,true)
    and said_en[1]=='Co-op saves off for this load: the backup folder could not be made. You play your own saves.',
    tostring(said_en[1]))
state.language=nil

-- off: nothing at all.
settings.auto_coop_save='off'
saves=new()
info=at()
for _=1,3 do quarter(false,true) end
assert(#calls==0 and #asked==0 and #said==0 and #logs==0)
settings.auto_coop_save='ask'

-- A friend's invite held at the title (link.saves()'s held, joined from the title): the question's first line says so.
-- Answered without co-op in this visit, it asks once more when an invite is held, on its first choice; once a visit.
settings.auto_coop_save='ask'
saves=new()
info=at({held=true})
quarter(false,true)
assert(screen()=="CO-OP SAVES\nYour friend's invite waits until your save loads.\nPlay co-op on copies of your saves?\n"
    ..'StellarCoop copies your saves to separate co-op files, and Continue and Load\n'
    ..'Game then use those copies. Your own saves are not changed.\n'
    ..'Convert and play co-op||focus\nPlay solo normally||normal\nDecide later||normal\n'
    ..'Don\'t ask again|Always co-op|normal',screen())
saves.nav('back')
quarter(false,true); assert(not saves.is_open(),'Asked with the invite already: not again')
saves=new()
info=at()
quarter(false,true); saves.nav('down'); pick('select')
quarter(false,true); assert(not saves.is_open() and not screen():find('invite',1,true))
info=at({held=true}); quarter(false,true)
assert(saves.is_open() and screen():find("^CO%-OP SAVES\nYour friend's invite waits until your save loads%.\n")
    and screen():find('Convert and play co-op||focus',1,true),screen())
saves.nav('back'); quarter(false,true); assert(not saves.is_open(),'Once a visit')
quarter(true,false); quarter(false,true); assert(saves.is_open(),'A new visit')
saves.nav('back')
-- An invite that comes while the question is open adds its line there: answered without co-op, not asked again.
saves=new()
info=at()
quarter(false,true); info=at({held=true}); quarter(false,true)
assert(saves.is_open() and screen():find("^CO%-OP SAVES\nYour friend's invite waits until your save loads%.\n"),
    screen())
saves.nav('down'); pick('select')
quarter(false,true); quarter(false,true); assert(not saves.is_open(),'The invite line seen: no second ask')
-- The kit not whole on the tick the invite comes: the second ask waits for it.
saves=new()
info=at()
quarter(false,true); saves.nav('back')
info=at({held=true}); state.whole=false; quarter(false,true); assert(not saves.is_open())
state.whole=true; quarter(false,true); assert(saves.is_open(),'Asked once the kit is whole')
saves.nav('back')
-- Co-op chosen: nothing more (the game then uses the copies). always: no question at all.
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({held=true,convert='busy 1/6'}); quarter(false,true)
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 1 of 6.',screen())
settings.auto_coop_save='always'
saves=new()
info=at({held=true})
quarter(false,true); quarter(false,true)
assert(not saves.is_open() and #asked==1,'always: the switch, no question')
settings.auto_coop_save='ask'
state.language='fr-FR'
saves=new()
info=at({held=true})
quarter(false,true)
assert(screen()=="SAUVEGARDES CO-OP\nL'invitation de votre partenaire attend le chargement de votre sauvegarde.\n"
    ..'Jouer en co-op sur des copies de vos sauvegardes ?\n'
    ..'StellarCoop copie vos sauvegardes dans des fichiers co-op séparés, et la\n'
    ..'partie que vous chargez ensuite est une de ces copies. Vos propres sauvegardes\nne changent pas.\n'
    ..'Convertir et jouer en co-op||focus\nJouer en solo normalement||normal\nDécider plus tard||normal\n'
    ..'Ne plus demander|Toujours co-op|normal',screen())
saves.nav('back')
state.language=nil

-- A manual co-op slot (link.saves()'s marker: StellarCoopSlot.txt names slot 4) once the game uses the co-op copies:
-- said once a Lua load, at the title or in a world, with what is no longer needed, and in English too. Not while the
-- game uses your own saves, where the manual slot is still the co-op save.
saves=new()
info=at({marker='4'})
quarter(false,true); saves.nav('back')
quarter(true,false); assert(#said==0,'Own saves: the manual slot is the co-op save')
info=at({saves='coop',marker='4'})
quarter(true,false)
assert(#said==1 and said[1]=='Co-op now plays StellarBladeCoop04.sav. With the game closed, you can move '
    ..'StellarCoopSlot.txt out of the save folder, and StellarBladeSave04.sav unless you played it after that copy was '
    ..'made.',said[1])
quarter(false,true); quarter(true,false); assert(#said==1,'Once a Lua load')
state.language='fr-FR'
saves=new()
info=at({saves='coop',marker='2'})
quarter(true,false)
assert(said[1]=='Le co-op utilise désormais StellarBladeCoop02.sav. Jeu fermé, vous pouvez sortir StellarCoopSlot.txt '
    ..'du dossier, et StellarBladeSave02.sav sauf si vous y avez joué après cette copie.',said[1])
assert(said_en[1]=='Co-op now plays StellarBladeCoop02.sav. With the game closed, you can move StellarCoopSlot.txt '
    ..'out of the save folder, and StellarBladeSave02.sav unless you played it after that copy was made.',
    tostring(said_en[1])) -- The English for the line above EVE.
state.language=nil

-- Another game build (a game update: link.saves()'s build): the co-op saves are off; with ask or always, said once a Lua
-- load at the title, nothing asked; with off, nothing. saves=off for another reason (coop off) says nothing.
for _,want in ipairs({'ask','always'}) do
    settings.auto_coop_save=want
    saves=new()
    info=at({saves='off',build=true})
    quarter(true,false); assert(#said==0,'Not in a world')
    quarter(false,true)
    assert(#said==1 and said[1]=='Co-op saves are off: StellarCoop does not support this version of the game. You play '
        ..'your own saves until StellarCoop is updated.' and #asked==0 and #calls==0 and not saves.is_open(),said[1])
    assert(logs[1]=='co-op saves: off on this game build (coop-link.log: engine off): your own saves',logs[1])
    quarter(true,false); quarter(false,true); assert(#said==1,'Once a Lua load')
end
saves=new()
info=at({saves='off'})
quarter(false,true); assert(#said==0 and #logs==0,'Not another build')
settings.auto_coop_save='off'
saves=new()
info=at({saves='off',build=true})
quarter(false,true); assert(#said==0 and #logs==0,'off: nothing')
settings.auto_coop_save='ask'
state.language='fr-FR'
saves=new()
info=at({saves='off',build=true})
quarter(false,true)
assert(said[1]=="Sauvegardes co-op coupées : StellarCoop ne prend pas en charge cette version du jeu. Vous jouez sur "
    .."vos propres sauvegardes jusqu'à une mise à jour de StellarCoop.",said[1])
state.language=nil

-- In a session on your own save with shared enemies on, nothing from here: main.lua's shared enemies notice says how to
-- switch, once.
settings.shared_enemies=true
saves=new()
info=at({slot='main'})
mode='host'
quarter(true,false); quarter(true,false)
assert(#said==0,said[1])
settings.shared_enemies,mode=false,'none'

-- French: the game's culture, unless ui_language=english.
state.language='fr-FR'
saves=new()
info=at()
quarter(false,true)
assert(screen()=='SAUVEGARDES CO-OP\nJouer en co-op sur des copies de vos sauvegardes ?\n'
    ..'StellarCoop copie vos sauvegardes dans des fichiers co-op séparés, et la\n'
    ..'partie que vous chargez ensuite est une de ces copies. Vos propres sauvegardes\nne changent pas.\n'
    ..'Convertir et jouer en co-op||focus\nJouer en solo normalement||normal\nDécider plus tard||normal\n'
    ..'Ne plus demander|Toujours co-op|normal',screen())
saves.nav('back')
info=at({saves='coop'}); quarter(false,true); assert(built.badge.view.text.s=='SAUVEGARDES CO-OP')
info=at()
settings.ui_language='english'
quarter(true,false); quarter(false,true)
assert(screen():find('^CO%-OP SAVES\n'),'ui_language=english')
settings.ui_language='game'
-- Japanese: the line under the failure ends with 。, as the failure's own line does.
state.language='ja-JP'
saves=new()
info=at()
quarter(false,true); pick('select')
info=at({convert='done'}); quarter(false,true)
assert(screen():find('\n理由：coop-link.log。\n',1,true),screen())
saves.nav('back')
state.language=nil
-- Both languages complete.
for k in pairs(T.en.saves) do assert(T.fr.saves[k],k) end
for k in pairs(T.fr.saves) do assert(T.en.saves[k],k) end

-- coop ui reset closes it as Decide later (a request out: withdrawn); coop off stops it with no kit call.
saves=new()
info=at()
quarter(false,true); pick('select')
saves.close()
assert(not saves.is_open() and asked[2]=='saves main')
-- The focus watchdog (close(true)): the same while it asks, but a pass under way is followed on, its result said.
saves=new()
info=at()
quarter(false,true)
saves.close(true)
assert(not saves.is_open() and #asked==0 and calls[#calls]=='sound close','Asking: Decide later')
saves=new()
info=at()
quarter(false,true); pick('select')
saves.close(true)
assert(not saves.is_open() and #asked==1 and calls[#calls]=='sound close','The pass kept')
info=at({saves='coop',convert='done'}); quarter(false,true)
assert(said[1]=='Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.',said[1])
saves=new()
quarter(true,false); quarter(false,true)
n=#calls
saves.stop()
assert(not saves.is_open() and #calls==n)
saves.tick(clock+1); quarter(false,true); assert(#calls==n,'Stopped: the kit gave the input back itself')

print('saves_test ok')
