-- cut/mxboss.lua with fake UE4SS objects: outside world 2800 nothing; in it, a Lion body of the Large blueprint near
-- its spawn point is fixed once through coop lion's adopt, a Gardener body's mesh turned -90 degrees once, each with
-- one [MXBOSS] line; a body far from the point is not the row's; bodies are looked for only near a boss point; the
-- boss bar's <M_LionC> reads Lion while the fixed Lion lives; EVE in an arena with no body for 20 s gets one line
-- naming coop mxiii boss, and nothing is spawned by itself; coop mxiii boss spawns the nearest arena's boss by its own
-- command, and refuses outside Matrix XIII or away from any arena.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at,o=next_address,fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
FName=function(t) return t end
FText=function(t) return {text=t} end
local map='MXIII_P'
local world=object({GetFullName=function() return 'World /Game/Art/BG/WorldMap_DLC_01/Level_P/'..map..'.'..map end})
local here={X=0,Y=0,Z=0}
local eve=object({IsA=function() return true end,GetWorld=function() return world end,
    K2_GetActorLocation=function() return here end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return nil end}
local bodies,blocks,walks={},{},0
local function body(class,at)
    local mesh=object({K2_SetRelativeRotation=function(self,r) self.turned=(self.turned or 0)+1; self.yaw=r.Yaw end})
    local c=object({Mesh=mesh,GetFullName=function() return class..' /Game/x.'..class end,
        K2_GetActorLocation=function() return at end})
    bodies[#bodies+1]=c
    return c
end
StaticFindObject=function(path) return object({path=path}) end
FindAllOf=function(name)
    if name=='TextBlock' then return blocks end
    walks=walks+1
    return bodies
end
local Boss=require('cut.mxboss')
local lines,adopted,spawns={},{},{}
local lion={adopt=function(c) adopted[#adopted+1]=c; return 'leader: the Lion AnimBP runs on a hidden CH_M_NA_46' end,
    command=function() spawns[#spawns+1]='lion'; return true,'Lion asked' end}
local gardener={command=function() spawns[#spawns+1]='gardener'; return true,'Gardener asked' end}
local points={DLC02_40_E_CharS_051={at={10000,0,0},yaw=0},DLC02_20_E_CharS_904={at={-10000,0,0},yaw=0}}
local b=Boss.new({log=function(m) lines[#lines+1]=m end,lion=lion,gardener=gardener,points=points})

-- Away from both points: no body search at all.
clock=1; b.tick()
assert(walks==0 and #lines==0,'No search far from a boss')
-- Outside Matrix XIII: nothing, and coop mxiii boss refuses.
map='Matrix_XI'
here={X=10000,Y=0,Z=0}
clock=2; b.tick()
assert(walks==0)
local ok,why=b.command(); assert(ok==false and why=='coop mxiii boss works in Matrix XIII only',why)
map='MXIII_P'
-- Near the Lion's point: a Large body 50 m away is not its row's; one 10 m away is fixed once.
body('CH_M_NA_02_BluePrint_Large_C',{X=15000,Y=0,Z=0})
clock=3; b.tick()
assert(walks>0 and #adopted==0 and #lines==0,'Too far from its point')
local l1=body('CH_M_NA_02_BluePrint_Large_C',{X=11000,Y=0,Z=0})
clock=4; b.tick()
assert(#adopted==1 and adopted[1]==l1,'Adopted')
assert(lines[1]=='Lion DLC02_40_E_CharS_051 found near its point: leader: the Lion AnimBP runs on a hidden CH_M_NA_46',
    lines[1])
clock=5; b.tick(); assert(#adopted==1,'Once a body')
-- The boss bar: a live block reading <M_LionC> reads Lion; another block is left alone.
local shown='<M_LionC>'
local bar=object({GetFName=function() return 'TextBlock_BossName' end,
    GetFullName=function() return 'TextBlock /Engine/Transient.GameEngine.BossBar.TextBlock_BossName' end,
    GetText=function() return shown end,SetText=function(_,t) shown=t.text end})
blocks={bar}
clock=6; b.tick()
assert(shown=='<M_LionC>','The blocks looked for again 10 s after the last look')
clock=14; b.tick()
assert(shown=='Lion' and lines[#lines]=='boss name: <M_LionC> -> Lion',lines[#lines])
-- The Gardener: its mesh turned once.
here={X=-10000,Y=0,Z=0}
local g1=body('CH_M_NA_01_BluePrint_C',{X=-10500,Y=0,Z=0})
clock=15; b.tick()
assert(g1.Mesh.turned==1 and g1.Mesh.yaw==-90 and lines[#lines]=='Gardener DLC02_20_E_CharS_904 found near its point: '
    ..'mesh turned -90 degrees',lines[#lines])
clock=16; b.tick(); assert(g1.Mesh.turned==1)
-- No body in an arena for 20 s: one line, nothing spawned by itself; coop mxiii boss spawns that arena's boss.
bodies={}
lines={}
here={X=10500,Y=0,Z=0}
for t=17,36 do clock=t; b.tick() end
assert(#lines==0,'Not before 20 s')
clock=37; b.tick()
assert(lines[1]=='no Lion body within 30 m of DLC02_40_E_CharS_051 after 20 s: coop mxiii boss spawns one (key 0, no '
    ..'saved death)',lines[1])
for t=38,60 do clock=t; b.tick() end
assert(#lines==1 and #spawns==0,'Said once, never spawned by itself')
ok,why=b.command()
assert(ok and why=='Lion asked' and spawns[1]=='lion' and lines[2]=='fallback: Lion by its own command, key 0, no saved '
    ..'death',tostring(why))
here={X=-10200,Y=0,Z=0}
ok,why=b.command(); assert(ok and spawns[2]=='gardener',tostring(why))
here={X=0,Y=0,Z=0}
ok,why=b.command(); assert(ok==false and why=='coop mxiii boss: no Lion or Gardener spawn point within 25 m',why)
-- Leaving Matrix XIII forgets the fixed bodies: a new visit fixes again.
map='Matrix_XI'
clock=61; b.tick()
map='MXIII_P'
here={X=10000,Y=0,Z=0}
bodies={l1}
clock=62; b.tick()
assert(#adopted==2,'Fixed again after a map change')
-- The generated points: the three bosses of the mxspawn batch.
local Rows=require('cut.mxiii_rows')
for _,row in ipairs({'DLC02_20_E_CharS_904','DLC02_30_E_CharS_029','DLC02_40_E_CharS_051'}) do
    assert(Rows.BOSS[row] and #Rows.BOSS[row].at==3,row)
end
print('mxboss_test: ok')
