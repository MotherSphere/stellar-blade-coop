-- The co-op saves at the title (saves.lua) on a fake kit and a fake link: with auto_coop_save=ask the question shows
-- once a visit of the title, while the game uses your own saves (saves=main) and no copy pass runs, once the kit has
-- its whole look; Convert and play co-op (Play co-op once a co-op copy exists) asks for "saves coop" and shows the
-- pass until saves=coop, then closes with a notice; a pass that ends without the switch, or a request with no answer
-- in 2 s, shows why with only the solo choices left; a solo choice after a request asks "saves main"; Decide later and
-- Esc close it for this visit; Don't ask again rewrites only auto_coop_save's line, then plays co-op; the title left
-- closes it. With always, no question: the request at each visit, its result as a notice. With off, nothing. In a
-- session on your own save with shared enemies on, one notice a session. The game's input is the question's while it
-- is open and comes back 150 ms after it closes. English and French.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui_text')
local Saves=require('saves')
local clock=0
os.clock=function() return clock end
-- UE4SS refuses any call from a coroutine (main.lua's loops run on the game thread): none here either.
local function main_thread() local _,main=coroutine.running(); assert(main,'called from a coroutine') end

-- The kit, as chat_test fakes it: the group's view from a builder that keeps what each text and row was set to.
local calls,state,built={},{ready=true,whole=true,off=false,language=nil},{}
local holder,inputting=nil,false
local kit={}
function kit.add(name,place,build)
    local b={panel=function() end}
    function b.shade(x,y,w,h,color) built.shade={x=x,y=y,w=w,h=h,color=color} end
    function b.text(_,_,s)
        local t={s=s}
        t.set=function(v) t.s=v end
        return t
    end
    function b.row() local r={}; r.set=function(l,v,st) r.l,r.v,r.st=l,v,st end; return r end
    function b.hints(_,_,_,list) local out={}; for i,h in ipairs(list) do out[i]=b.text(0,0,h[2]) end; return out end
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
local said,logs={},{}
local env={LOCALAPPDATA='C:\\Users\\Ana\\AppData\\Local'}
local present,opened={},{} -- The files that exist; every path looked at.
local view
local function new()
    calls,built,holder,inputting,said,logs,asked,opened={},{},nil,false,{},{},{},{}
    return Saves.new({kit=kit,link=link,settings=settings,theme={shade='shade',text='white'},
        say=function(text) said[#said+1]=text end,log=function(line) logs[#logs+1]=line end,
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
for _,case in ipairs({at({saves='?'}),at({saves='off'}),{convert='idle'},at({convert='busy 1/6'})}) do
    info=case -- Not read yet, another build, no slot line (an older native part), a pass running.
    quarter(false,true)
    assert(#calls==0 and #asked==0 and not saves.is_open(),tostring(case.saves)..' '..tostring(case.convert))
end
info=at({saves='coop'}); quarter(false,true); assert(#calls==0 and #asked==0,'The co-op saves already: nothing to ask')
info=at()
state.whole=false; quarter(false,true); assert(#calls==0,'The kit still warms its look: it waits')
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
-- No co-op copy in this account's folder: each slot's looked at, by its full path.
assert(#opened==5 and opened[1]=='C:\\Users\\Ana\\AppData\\Local\\SB\\Saved\\SaveGames\\76561198000000001\\'
    ..'StellarBladeCoop00.sav' and opened[5]:find('StellarBladeCoop04.sav$'),opened[1])

-- Up and down wrap over the four choices; left and right do nothing.
saves.nav('up'); assert(screen():find("Don't ask again|Always co-op|focus",1,true) and calls[#calls]=='sound move')
saves.nav('down'); saves.nav('down'); assert(screen():find('Play solo normally||focus',1,true))
local n=#calls
saves.nav('left'); saves.nav('right'); assert(#calls==n and screen():find('Play solo normally||focus',1,true))

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
saves.nav('select')
assert(asked[1]=='saves coop' and saves.is_open() and logs[#logs]=='co-op saves: asked the native part: saves coop')
assert(screen()=='CO-OP SAVES\nSwitching to the co-op saves.',screen())
saves.nav('select'); saves.nav('down'); assert(#asked==1 and screen()=='CO-OP SAVES\nSwitching to the co-op saves.')
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
saves.nav('select'); assert(asked[1]=='saves coop')
info=at({convert="error:slot 3's save fails the game's own check, so it was not copied"})
quarter(false,true)
assert(screen()=='CO-OP SAVES\nThe co-op saves could not be switched on. Your own saves were not changed.\n'
    .."slot 3's save fails the game's own check, so it was not copied\n"
    ..'Play solo normally||focus\nDecide later||normal',screen())
assert(logs[#logs]=="co-op saves stay off: slot 3's save fails the game's own check, so it was not copied",logs[#logs])
saves.nav('down'); assert(screen():find('Decide later||focus',1,true))
saves.nav('down'); assert(screen():find('Play solo normally||focus',1,true),'Two choices, wrapping')
saves.nav('select')
assert(asked[2]=='saves main' and not saves.is_open() and #said==0,'Withdrawn, closed, nothing said')

-- The same pass result as before the request, for 2 s: refused (said in coop-link.log); Esc then withdraws too.
saves=new()
info=at({convert='done'})
quarter(false,true); saves.nav('select')
for _=1,7 do quarter(false,true) end
assert(screen()=='CO-OP SAVES\nSwitching to the co-op saves.','Under 2 s: still waiting')
quarter(false,true)
assert(screen()=='CO-OP SAVES\nThe co-op saves could not be switched on. Your own saves were not changed.\n'
    ..'coop-link.log says why.\nPlay solo normally||focus\nDecide later||normal',screen())
saves.nav('back'); assert(asked[2]=='saves main' and not saves.is_open())
-- A pass still running after 2 minutes counts as failed; a pass whose line changed without the switch at once.
saves=new()
info=at()
quarter(false,true); saves.nav('select')
info=at({convert='busy 1/6'})
for _=1,479 do quarter(false,true) end
assert(screen()=='CO-OP SAVES\nMaking the co-op copies: step 1 of 6.')
quarter(false,true); assert(screen():find('could not be switched on',1,true),'2 minutes')
saves=new()
info=at()
quarter(false,true); saves.nav('select')
info=at({convert='done'}); quarter(false,true)
assert(screen():find('coop-link.log says why.',1,true),'Done, yet still saves=main: the switch failed')
-- Esc while the pass runs: "saves main" withdraws the switch, the question closes for this visit.
saves=new()
info=at()
quarter(false,true); saves.nav('select')
info=at({convert='busy 1/6'}); quarter(false,true)
saves.nav('back')
assert(asked[1]=='saves coop' and asked[2]=='saves main' and not saves.is_open())
quarter(false,true); assert(not saves.is_open() and #asked==2,'The pass not followed any more')
-- A request that cannot be written: why, at once.
saves=new()
info=at()
quarter(false,true)
refuse='cannot write C:\\Mod\\coop-request.txt.tmp'
saves.nav('select')
assert(#asked==0 and screen():find('cannot write C:\\Mod\\coop-request.txt.tmp',1,true),screen())
refuse=nil
-- A reason the native part wrote with controls or bytes that are not UTF-8: cleaned, never raised.
saves=new()
info=at()
quarter(false,true); saves.nav('select')
info=at({convert='error:bad\0 \255name\27'}); quarter(false,true)
assert(screen():find('\nbad name\n',1,true),screen())

-- Don't ask again: auto_coop_save=always rewritten in its own line (every other byte kept), in effect at once, then co-op.
file='\239\187\191# mine\r\nmenu_key=F7\r\nauto_coop_save=ask\r\nchat=off\r\n'
saves=new()
info=at()
quarter(false,true)
saves.nav('up'); saves.nav('select')
assert(file=='\239\187\191# mine\r\nmenu_key=F7\r\nauto_coop_save=always\r\nchat=off\r\n',file)
assert(settings.auto_coop_save=='always' and asked[1]=='saves coop' and saves.is_open())
assert(logs[#logs-1]=='co-op saves: auto_coop_save=always saved in coop-settings.txt',logs[#logs-1])
info=at({saves='coop',convert='done'}); quarter(false,true); assert(not saves.is_open())
-- A file that cannot be read or written: said in the log, co-op all the same.
settings.auto_coop_save,file='ask',nil
saves=new()
info=at()
quarter(false,true); saves.nav('up'); saves.nav('select')
assert(settings.auto_coop_save=='ask' and asked[1]=='saves coop'
    and logs[#logs-1]=='co-op saves: auto_coop_save=always not saved: coop-settings.txt cannot be read',logs[#logs-1])

-- The title left while it asks: closed (Decide later), nothing asked; while a pass runs: followed, its result said.
saves=new()
info=at()
quarter(false,true)
quarter(false,false)
assert(not saves.is_open() and #asked==0 and calls[#calls]=='sound close')
saves=new()
info=at()
quarter(false,true); saves.nav('select')
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
saves.nav('select'); assert(#asked==0)
state.off=false

-- always: no question; "saves coop" once a visit at the title; its result said once the kit shows, at the title or
-- later in a world.
settings.auto_coop_save='always'
saves=new()
info=at()
state.ready=false
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

-- off: nothing at all.
settings.auto_coop_save='off'
saves=new()
info=at()
for _=1,3 do quarter(false,true) end
assert(#calls==0 and #asked==0 and #said==0 and #logs==0)
settings.auto_coop_save='ask'

-- In a session on your own save with shared enemies on: one notice a session, in a world; again in the next one. Not
-- with shared enemies off, not on a co-op save, not with auto_coop_save=off.
settings.shared_enemies=true
saves=new()
info=at({slot='main'})
mode='host'
quarter(true,false); quarter(true,false)
assert(#said==1 and said[1]=='You play your own save, and shared enemies run on co-op saves only. Quit to the title '
    ..'to switch; the ghost works now.',said[1])
mode='none'; quarter(true,false)
mode='guest'; quarter(true,false); assert(#said==2,'The next session')
mode=nil; quarter(true,false); mode='guest'; quarter(true,false); assert(#said==2,'An unread status ends nothing')
for _,case in ipairs({{shared=false,slot='main',auto='ask'},{shared=true,slot='coop',auto='ask'},
        {shared=true,slot='main',auto='off'},{shared=true,slot='none',auto='always'}}) do
    settings.shared_enemies,settings.auto_coop_save=case.shared,case.auto
    saves=new()
    info=at({slot=case.slot,saves=case.slot=='coop' and 'coop' or 'main'})
    quarter(true,false)
    assert(#said==0,case.slot..' '..case.auto)
end
settings.shared_enemies,settings.auto_coop_save,mode=false,'ask','none'

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
settings.ui_language='english'
quarter(true,false); quarter(false,true)
assert(screen():find('^CO%-OP SAVES\n'),'ui_language=english')
settings.ui_language='game'
state.language=nil
-- Both languages complete.
for k in pairs(T.en.saves) do assert(T.fr.saves[k],k) end
for k in pairs(T.fr.saves) do assert(T.en.saves[k],k) end

-- coop ui reset closes it as Decide later (a request out: withdrawn); coop off stops it with no kit call.
saves=new()
info=at()
quarter(false,true); saves.nav('select')
saves.close()
assert(not saves.is_open() and asked[2]=='saves main')
saves=new()
quarter(true,false); quarter(false,true)
n=#calls
saves.stop()
assert(not saves.is_open() and #calls==n)
saves.tick(clock+1); quarter(false,true); assert(#calls==n,'Stopped: the kit gave the input back itself')

print('saves_test ok')
