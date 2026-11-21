-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/partner/bench.lua's ghost bench over fake ghosts and files: coop bench ghosts' words (0 to 64 ghosts, the
-- tiers, ring 1 to 300 m, nocloth, noshadow, add; anything else refused with the usage); her ghost on first; the
-- ghosts on their ring with their tier's look on slots 101 on; their table from coop-bench-table.txt at the native
-- part's count; their displays in coop-bench.txt with offset and stride; their paths in coop-bench-ghosts.txt; one log
-- line a window, its format; add up to 64; off removes all; a map change; the next Lua load's sweep. Then the wiring:
-- the bench ticks with the members' ghosts and coop off ends it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local Bench=require('online.partner.bench')
local USAGE=Bench.USAGE

-- The words.
local function parsed(...) local o,why=Bench.parse(...); return o,why end
local o=parsed('0')
assert(o and o.n==0 and o.tier=='full' and o.ring==5 and not o.add and not o.nocloth and not o.noshadow,'0: the lines')
assert(parsed('64').n==64 and parsed('1').n==1)
for _,bad in ipairs({{'65'},{'-1'},{'x'},{},{'1.5'},{'16','huge'},{'16','ring'},{'16','ring','0'},{'16','ring','301'},
    {'16','ring','x'},{'16','full','mid'},{'16','add','add'},{'16','ring','5','ring','6'}}) do
    local none,why=parsed(table.unpack(bad))
    assert(none==nil and why==USAGE,'refused: '..table.concat(bad,' '))
end
o=parsed('16','mid','ring','40')
assert(o.n==16 and o.tier=='mid' and o.ring==40)
o=parsed('20','ring','120','far','add')
assert(o.tier=='far' and o.ring==120 and o.add)
o=parsed('16','full','nocloth','noshadow')
assert(o.nocloth and o.noshadow and o.ring==5)
assert(parsed('8','ring','1').ring==1 and parsed('8','ring','300').ring==300)
assert(parsed('8','far','nocloth').nocloth,'Any tier takes them')

-- The ring: ghost j at 2 pi j / n, in cm; the turn adds to each angle.
local r=Bench.ring(4,5)
local want={{500,0},{0,500},{-500,0},{0,-500}}
for j=1,4 do
    assert(math.abs(r[j][1]-want[j][1])<1e-9 and math.abs(r[j][2]-want[j][2])<1e-9,'ring '..j)
end
r=Bench.ring(2,1,math.pi/2)
assert(math.abs(r[1][1])<1e-9 and math.abs(r[1][2]-100)<1e-9 and math.abs(r[2][2]+100)<1e-9)
assert(#Bench.ring(0,5)==0)

-- The out line and the log line.
local w=Bench.parse_out('bench 7 ghosts 16 taken 15 frames 60 gap 16700 24100 tick 410 1200 written 960 refused 2 '
    ..'table 9 4\n')
assert(w.seq==7 and w.ghosts==16 and w.taken==15 and w.frames==60 and w.gap==16700 and w.gap_max==24100 and
    w.tick==410 and w.tick_max==1200 and w.written==960 and w.refused==2 and w.generation==9 and w.count==4)
assert(w.ws==nil and w.private==nil,'No memory on this line')
assert(Bench.line(w,{ghosts=16,groups='16 full at 5 m',drawn=16,rendered=11,ms=0.25})=='Bench: 16 ghosts (16 full at '
    ..'5 m), 15 of 16 taken, 16 drawn, 11 rendered; frame mean 16.7 ms, worst 24.1 ms (60 frames); native tick mean '
    ..'0.41 ms, max 1.20 ms; Lua ghosts 0.250 ms a frame; 960 written, 2 refused')
w=Bench.parse_out('bench 8 ghosts 0 taken 0 frames 0 gap 0 0 tick 0 0 written 0 refused 0 table 0 0 memory 9876 '
    ..'10234\n')
assert(w.ws==9876 and w.private==10234)
assert(Bench.line(w,{ghosts=0,groups='',drawn=0,rendered=0,ms=0})=='Bench: 0 ghosts, 0 of 0 taken, 0 drawn, 0 '
    ..'rendered; frame mean 0.0 ms, worst 0.0 ms (0 frames); native tick mean 0.00 ms, max 0.00 ms; Lua ghosts 0.000 '
    ..'ms a frame; 0 written, 0 refused; working set 9876 MB, private 10234 MB')
assert(Bench.parse_out(nil)==nil and Bench.parse_out('bench off\n')==nil and Bench.parse_out('bench 1 ghosts')==nil)

-- The fakes: files beside coop-settings.txt, ghosts made by make, her ghost on, the log.
local files,writes={},{}
local link={read_file=function(name) return files[name] end,
    write_file=function(name,text) files[name]=text; writes[#writes+1]=name; return true end,
    mod_assets=function() return {} end}
local made,logged,her_on={},{},true
local function make(f,slot,look,tag)
    local g={files=f,slot=slot,look=look,tag=tag,on=false,remotes={},ticks=0,places=0}
    function g.toggle() g.on=not g.on; return true,g.on and 'Ghost on.' or 'Ghost off.' end
    function g.active() return g.on end
    function g.remote(...) g.remotes[#g.remotes+1]=table.pack(...) end
    function g.tick() g.ticks=g.ticks+1; clock=clock+0.0001 end
    function g.place() g.places=g.places+1; clock=clock+0.0001 end
    function g.body() return g.shows end
    made[#made+1]=g
    return g
end
local function new_bench(own)
    made={}
    return Bench.new({link=own or link,make=make,
        look={cloth=true,dyes=true,effects=true,drone=true,sounds=true,faces=true},name_tag=true,log=function(line) logged[#logged+1]=line end,active=function() return her_on end})
end
local b=new_bench()
assert(#b.tick()==0 and next(writes)==nil,'No earlier bench: nothing written')
assert(b.status()=='Bench off.')
her_on=false
local ok,why=b.ghosts('8')
assert(ok==false and why=='turn the ghost on first: coop puppet' and #made==0)
her_on=true
ok,why=b.ghosts('65')
assert(ok==false and why==USAGE and #made==0)

-- 16 full ghosts, cloth and shadows off: slots 101 to 116, on, on a 5 m ring, with the name tag.
ok,why=b.ghosts('16','full','nocloth','noshadow')
assert(ok and why=='Bench on: 16 ghosts (16 full at 5 m nocloth noshadow); a line a second goes to UE4SS.log (coop '
    ..'bench off ends it).',why)
assert(#made==16 and made[1].slot==101 and made[16].slot==116)
for _,g in ipairs(made) do
    local l=g.look
    assert(g.on and g.tag==true and l.cloth==false and l.shadow==false and l.dyes==true and l.lod==nil,'full look')
    assert(l.effects==false and l.faces==false and l.sounds==false and l.drone==false,'none of their native calls')
end
local full={table.unpack(made)}
-- Her table reaches each ghost at the native part's count; the window's line.
files[Bench.OUT]='bench 1 ghosts 0 taken 0 frames 60 gap 16000 20000 tick 300 900 written 0 refused 0 table 7 3\n'
b.sync()
assert(#logged==1 and logged[1]:find('^Bench: 16 ghosts %(16 full at 5 m nocloth noshadow%), 0 of 0 taken, 0 drawn'),
    tostring(logged[1]))
assert(#full[1].remotes==1 and full[1].remotes[1][1]==7 and full[1].remotes[1][2]==3 and full[1].remotes[1][3]=='bench')
assert(files[Bench.FILE]=='bench 7\n','No display yet: the head alone')
files[Bench.TABLE]='SBT 9\ngeneration 7\n'
assert(full[1].files.remote_table()=='SBT 9\ngeneration 7\n','Her table: coop-bench-table.txt')

-- A new set (no add) replaces it: 16 mid ghosts on a 40 m ring, written every 2nd frame, no tag.
ok,why=b.ghosts('16','mid','ring','40')
assert(ok and why:find('^Bench on: 16 ghosts %(16 mid at 40 m%)'),why)
for _,g in ipairs(full) do assert(not g.on,'the full ghosts are gone') end
local mid={table.unpack(made,17,32)}
assert(#mid==16 and mid[1].slot==101 and mid[16].slot==116,'slots from 101 again')
for _,g in ipairs(mid) do
    assert(g.on and g.tag==false and g.look.lod==2 and g.look.shadow==false and g.look.cloth==false,'mid look')
    assert(g.look.basesuit==nil and g.look.dyes==true)
end
-- Each ghost built publishes its display and keeps its path: the bench file and the list follow.
for k,g in ipairs(mid) do
    g.files.display('display 7\nmailbox 0x'..k..' 0x5c0\n')
    g.files.store().save('/Game/Map.Map:PersistentLevel.Actor_'..k)
end
assert(mid[1].files.store().load()==nil,'The bench sweeps its list itself')
assert(select(2,(files[Bench.LIST] or ''):gsub('\n',''))==16,'Listed at once: a Lua reload before the next pass '
    ..'still finds them')
b.sync()
local text=files[Bench.FILE]
assert(text:find('^bench 7\nghost 4000 0 2\ndisplay 7\nmailbox 0x1 0x5c0\nghost 3696 1531 2\ndisplay 7\n'),text)
assert(text:find('\nghost 0 4000 2\ndisplay 7\nmailbox 0x5 0x5c0\n',1,true),'ghost 5 at 90 degrees')
assert(text:find('\nghost %-4000 0 2\n') and text:find('\nghost 0 %-4000 2\n'),text)
local blocks=0
for _ in text:gmatch('\nghost ') do blocks=blocks+1 end
assert(blocks==16)
local list=files[Bench.LIST]
assert(list:find('^/Game/Map.Map:PersistentLevel.Actor_1\n') and select(2,list:gsub('\n',''))==16,list)
local count=#writes
b.sync()
assert(#writes==count,'Unchanged: not written again')

-- One line a window: Lua's time a frame in its ghosts, drawn and rendered from their bodies.
for _,g in ipairs(mid) do
    g.shows={asked={}}
    function g.shows:WasRecentlyRendered(t) self.asked[#self.asked+1]=t; return g.slot%2==0 end
end
mid[16].shows=nil
for _=1,10 do b.tick(); b.place() end
files[Bench.OUT]='bench 2 ghosts 16 taken 16 frames 60 gap 16700 24100 tick 410 1200 written 480 refused 0 table 7 3\n'
b.sync()
assert(#logged==2,'a new window')
assert(logged[2]=='Bench: 16 ghosts (16 mid at 40 m), 16 of 16 taken, 15 drawn, 7 rendered; frame mean 16.7 ms, '
    ..'worst 24.1 ms (60 frames); native tick mean 0.41 ms, max 1.20 ms; Lua ghosts 3.200 ms a frame; 480 written, 0 '
    ..'refused',logged[2])
assert(mid[1].shows.asked[1]==0.2,'WasRecentlyRendered(0.2)')
assert(#mid[1].remotes==3 and mid[1].remotes[3][2]==3,'Fed at each pass: the ghost reads a new count only')
b.sync()
assert(#logged==2,'the same window: no line')
assert(b.status()=='Bench on: 16 ghosts (16 mid at 40 m), 15 drawn (coop bench off ends it).',b.status())

-- add: a group of far ghosts on a 120 m ring, up to 64 in all.
ok,why=b.ghosts('48','far','ring','120','add')
assert(ok and why:find('^Bench on: 64 ghosts %(16 mid at 40 m, 48 far at 120 m%)'),why)
local far={table.unpack(made,33,80)}
assert(#far==48 and far[1].slot==117 and far[48].slot==164)
for _,g in ipairs(mid) do assert(g.on,'add keeps the set') end
for _,g in ipairs(far) do
    local l=g.look
    assert(l.lod==99 and l.shadow==false and l.cloth==false and l.dyes==false and l.basesuit==true and l.bare==true
        and g.tag==false,'far look')
end
far[1].files.display('display 7\nmailbox 0xf1 0x5c0\n')
b.sync()
assert(files[Bench.FILE]:find('\nghost 11974 785 4\ndisplay 7\nmailbox 0xf1 0x5c0\n',1,true),
    'stride 4 at 120 m, the second group half a step on')
ok,why=b.ghosts('1','add')
assert(ok==false and why=='at most 64 bench ghosts in all: 64 now' and #made==80)
-- A second group of the same size turns by half a step: on another disk.
do
    local own={}
    local c=new_bench({read_file=function(name) return own[name] end,
        write_file=function(name,t) own[name]=t; return true end})
    c.ghosts('2','ring','1')
    c.ghosts('2','ring','1','add')
    made[3].files.display('d\n')
    made[4].files.display('d\n')
    c.sync()
    assert(own[Bench.FILE]=='bench 0\nghost 0 100 1\nd\nghost 0 -100 1\nd\n',own[Bench.FILE])
    c.off('test')
end

-- A map change: each ghost clears its display, then her new table comes at a new generation.
for _,g in ipairs(mid) do g.files.display(nil); g.files.store().clear() end
far[1].files.display(nil)
far[1].files.store().clear()
b.sync()
assert(files[Bench.FILE]=='bench 7\n' and files[Bench.LIST]=='',files[Bench.FILE])
files[Bench.OUT]='bench 3 ghosts 0 taken 0 frames 60 gap 1 1 tick 1 1 written 0 refused 0 table 8 4\n'
b.sync()
local function last(g) return g.remotes[#g.remotes] end
assert(last(mid[1])[1]==8 and last(mid[1])[2]==4 and last(mid[1])[3]=='bench' and last(far[9])[1]==8)
assert(files[Bench.FILE]=='bench 8\n')
-- Her capture withdrawn: no table, each ghost's goes.
files[Bench.OUT]='bench 4 ghosts 0 taken 0 frames 60 gap 1 1 tick 1 1 written 0 refused 0 table 0 0\n'
b.sync()
assert(last(mid[1]).n==0 and last(far[48]).n==0,'remote() with nothing: her table gone')

-- off removes every ghost and stops the native part.
mid[2].files.store().save('/Game/Map.Map:PersistentLevel.Actor_2')
b.sync()
ok,why=b.off('coop bench off')
assert(ok and why=='Bench off (coop bench off): 64 ghosts removed.',why)
for _,g in ipairs(mid) do assert(not g.on) end
for _,g in ipairs(far) do assert(not g.on) end
assert(files[Bench.FILE]=='bench off\n' and files[Bench.LIST]=='')
local places=mid[1].places
assert(#b.place()==0 and #b.sync()==0 and mid[1].places==places,'Off: nothing runs')
assert(b.status()=='Bench off.')
-- coop off ends it the same way (online/partner/wiring.lua's M.ghosts_off): bench 0 is the lines alone.
ok,why=b.ghosts('0')
assert(ok and why=='Bench on: 0 ghosts; a line a second goes to UE4SS.log (coop bench off ends it).',why)
files[Bench.OUT]=nil
b.sync()
assert(files[Bench.FILE]=='bench 0\n','The lines with no ghost (no table since the last window)')
ok,why=b.off('coop off')
assert(ok and why=='Bench off (coop off): 0 ghosts removed.' and files[Bench.FILE]=='bench off\n')
-- A window left from an earlier run is not logged; the next one is.
files[Bench.OUT]='bench 9 ghosts 0 taken 0 frames 60 gap 1 1 tick 1 1 written 0 refused 0 table 8 4\n'
local lines=#logged
b.ghosts('0')
b.sync()
assert(#logged==lines,'seq 9 was there before')
files[Bench.OUT]='bench 10 ghosts 0 taken 0 frames 60 gap 1 1 tick 1 1 written 0 refused 0 table 8 4\n'
b.sync()
assert(#logged==lines+1)
b.off('test')
-- A ghost that raises is said once, the others still run.
do
    local c=new_bench()
    c.ghosts('2')
    made[1].tick=function() error('broken',0) end
    local said=c.tick()
    assert(#said==1 and said[1][1]==false and said[1][2]:find('^bench 1: error') and made[2].ticks==1)
    assert(#c.tick()==0 and made[2].ticks==2,'once')
    c.off('test')
end

-- The next Lua load: its first tick destroys the actors the list names that are still ghosts, then bench off.
local Object={}
local function object(path,poseable)
    local a={path=path,destroyed=false}
    function a:type() return 'UObject' end
    function a:IsValid() return not self.destroyed end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent()
        return {type=function() return 'UObject' end,IsValid=function() return true end,
            IsA=function(_,class) return poseable and class==Object.poseable end}
    end
    return a
end
Object.poseable={type=function() return 'UObject' end,IsValid=function() return true end}
local world={['/Script/Engine.PoseableMeshComponent']=Object.poseable,['/Game/A.A:Actor_1']=object('a',true),
    ['/Game/A.A:Actor_2']=object('b',false)}
StaticFindObject=function(path) return world[path] end
files[Bench.LIST]='/Game/A.A:Actor_1\n/Game/A.A:Actor_2\n/Game/A.A:Gone\n'
files[Bench.FILE]='bench 8\nghost 500 0 1\ndisplay 8\n'
local reloaded=new_bench()
local said=reloaded.tick()
assert(world['/Game/A.A:Actor_1'].destroyed and not world['/Game/A.A:Actor_2'].destroyed,'ghosts only')
assert(#said==1 and said[1][1]==true and said[1][2]=='Bench: 1 ghost of an earlier Lua load removed.',tostring(said[1]))
assert(files[Bench.FILE]=='bench off\n' and files[Bench.LIST]=='')
count=#writes
reloaded.tick()
assert(#writes==count,'once a Lua load')
-- A lost bench off: under Wine the worker's open handle keeps a removed file's name, so the rename fails and no file
-- is left. The next pass writes it again. A new Lua load writes it when no file is there while the worker's window or
-- her table still is (the bench may still run); with none of them nothing is written.
do
    local own,lose={},false
    local disk={read_file=function(name) return own[name] end,
        write_file=function(name,t)
            if lose and name==Bench.FILE then own[name],lose=nil,false; return false end
            own[name]=t; return true
        end}
    local c=new_bench(disk)
    c.ghosts('2')
    c.sync()
    assert(own[Bench.FILE]=='bench 0\n')
    lose=true
    c.off('test')
    assert(own[Bench.FILE]==nil,'lost')
    c.sync()
    assert(own[Bench.FILE]=='bench off\n','written again at the next pass')
    for _,left in ipairs({Bench.OUT,Bench.TABLE}) do
        own[Bench.FILE],own[Bench.OUT],own[Bench.TABLE]=nil,nil,nil
        own[left]='left by the worker\n'
        new_bench(disk).tick()
        assert(own[Bench.FILE]=='bench off\n','a new load with '..left)
    end
    own[Bench.FILE],own[Bench.OUT],own[Bench.TABLE]=nil,nil,nil
    new_bench(disk).sync()
    assert(own[Bench.FILE]==nil,'never run: no file')
end

-- The wiring: with the native part, the bench's ghosts tick, place and sync with the members' ghosts; coop bench
-- reaches it; coop off ends it. A fake ghost and capture stand for the module's own files.
package.loaded.UEHelpers={}
local wired={}
package.loaded['online.partner.capture']={new=function()
    return {leave_out=function() end,pose_source=function() end}
end}
local slot0={on=true}
package.loaded['online.partner.puppet']={assets_off=function() end,new=function(f,_,_,tag,look,_,_,_,slot)
    if slot==nil then
        return {active=function() return slot0.on end,toggle=function() slot0.on=not slot0.on; return true,'x' end}
    end
    local g=make(f,slot,look,tag)
    wired[#wired+1]=g
    return g
end}
files={}
local M={link={read_file=link.read_file,write_file=link.write_file,mod_assets=link.mod_assets,
    members=function() return {} end,remote=function() end},native_tick=function() end,
    look={cloth=true},settings={name_tag=true},print=print,log=function(line) logged[#logged+1]=line end,
    say=function() end,words=function() end,VERSION='test',off_modules={},bike={},ask=function() end}
local words=dofile('mod/StellarCoop/Scripts/online/partner/wiring.lua').new(M)
assert(select(2,words.bench('size'))==USAGE and select(2,words.bench('off','now'))==USAGE)
assert(select(2,words.bench())=='Bench off.')
ok,why=words.bench('ghosts','2','far')
assert(ok and #wired==2 and wired[1].slot==101 and wired[1].look.bare==true and wired[1].look.cloth==false,why)
M.ghosts.tick()
M.ghosts.place()
assert(wired[1].ticks==1 and wired[2].places==1,'with the members\' ghosts')
wired[1].files.display('display 3\n')
files[Bench.OUT]='bench 1 ghosts 0 taken 0 frames 1 gap 1 1 tick 1 1 written 0 refused 0 table 3 1\n'
M.ghosts.sync()
assert(files[Bench.FILE]=='bench 3\nghost 500 0 4\ndisplay 3\n' and wired[1].remotes[1][1]==3,files[Bench.FILE])
lines=#logged
M.ghosts_off()
assert(not wired[1].on and not wired[2].on and files[Bench.FILE]=='bench off\n' and not slot0.on,'coop off')
assert(logged[lines+1]=='OK: Bench off (coop off): 2 ghosts removed.',tostring(logged[lines+1]))
-- Without the native tick: no bench.
M.native_tick=nil
words=dofile('mod/StellarCoop/Scripts/online/partner/wiring.lua').new(M)
assert(select(2,words.bench('ghosts','2'))=='the native tick is unavailable')
print('online.partner_bench_test ok')
