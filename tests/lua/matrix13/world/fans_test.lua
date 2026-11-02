-- matrix13/world/fans.lua with fake UE4SS objects: outside world 2800 and away from the room nothing is looked at; in
-- the room each rotor is held still until its own lever reads On, then runs, one line a change; the objects are walked
-- for once while held, and again once one goes stale (a level streamed back in), at most every FIND s; an error or no
-- rotor gives one STOP line. The Lion's death enables the levers: the rows say so, and a row-side check holds it here.
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
local function rotor(name)
    local owner=object({GetFName=function() return name end})
    return object({active=true,GetOwner=function() return owner end,IsActive=function(self) return self.active end,
        SetActive=function(self,on,reset)
            assert(reset==false)
            self.active,self.sets=on,(self.sets or 0)+1
        end})
end
local function lever(name)
    return object({EnvActorName=name,state='Off',GetStateTagname=function(self) return self.state end})
end
local F={rotor('Z4_Z4R10_S_Fan1_Rotor'),rotor('Z4_Z4R10_S_Fan2_Rotor'),rotor('Z4_Z4R10_S_Fan3_Rotor'),rotor('Other')}
local L={lever('DLC02_40_EnvS_023'),lever('DLC02_40_EnvS_024'),lever('DLC02_40_EnvS_025'),lever('DLC02_40_EnvS_001')}
local walks,raise=0,nil
FindAllOf=function(name)
    if raise then error(raise) end
    if name=='RotatingMovementComponent' then
        walks=walks+1
        return F
    end
    return {}
end
local eve_at={X=0,Y=0,Z=0}
local eve=object({K2_GetActorLocation=function() return eve_at end})
StaticFindObject=function(path) return object({path=path,GetAllActorsOfClass=function(_,_,_,out)
    for i,x in ipairs(L) do out[i]=x end
end}) end
-- U.actors_of proves the class hash through FindAllOf('PlayerController'): with none it walks by name, so give levers.
local real=FindAllOf
FindAllOf=function(name)
    if name=='SBZoneEnvActor' then return L end
    return real(name)
end
local Fans=require('matrix13.world.fans')
local lines,there={},false
local f=Fans.new({log=function(m) lines[#lines+1]=m end,here=function() return there and eve or nil end})
local function step() clock=clock+Fans.EVERY; f.tick() end

-- Outside Matrix XIII: no walk, and a rotor is left alone.
step()
assert(walks==0 and F[1].active and #lines==0)
-- In the world, far from the room: no walk.
there=true; step()
assert(walks==0 and F[1].active and #lines==0,'no walk away from the room')
-- In the room: all three held still, one line each; another rotor untouched.
eve_at=Fans.CENTER
step()
assert(walks==1 and not F[1].active and not F[2].active and not F[3].active and F[4].active and F[4].sets==nil)
assert(#lines==3 and lines[1]:find('Fan1_Rotor held still',1,true),lines[1])
-- Nothing changes, nothing is called or walked again.
step(); step()
assert(walks==1 and F[1].sets==1 and #lines==3)
-- Lever 023 On: fan 1 runs, the others stay still.
L[1].state='On'; step()
assert(F[1].active and not F[2].active and not F[3].active and #lines==4 and lines[4]:find('Fan1_Rotor runs',1,true))
-- A rotor streamed back in: a fresh object, found at the next walk, held still again; no walk before FIND s.
F[2].destroyed=true
F[2]=rotor('Z4_Z4R10_S_Fan2_Rotor')
local at=clock
clock=clock+Fans.FIND
step()
assert(walks==2 and not F[2].active,'the new object is held still')
assert(clock>at)
-- Another object at a held rotor's address (a reload), still valid: not used, and looked for again.
local old=F[1]
old.active=true
old.GetOwner=function() return object({GetFName=function() return 'SomethingElse' end}) end
local old_sets=old.sets
F[1]=rotor('Z4_Z4R10_S_Fan1_Rotor')
clock=clock+Fans.FIND
step()
assert(old.sets==old_sets,'Nothing is called on the other object')
assert(F[1].active==true and walks==3,'The real rotor found again; its lever reads On')
-- A walk that raises: one STOP line, the tick survives.
F[3].destroyed=true
raise='boom'
clock=clock+Fans.FIND
step(); step()
local stops=0
for _,l in ipairs(lines) do if l:find('^STOP') then stops=stops+1 end end
assert(stops==1,'one STOP line')
raise=nil
-- No rotor at all: one STOP line naming it, and leaving the world forgets what it held.
F={}
for _,x in ipairs({'Fan1','Fan2','Fan3'}) do lines[#lines+1]=x end
there=false; step()
there=true; clock=clock+Fans.FIND; step()
assert(lines[#lines]:find('no fan rotor found',1,true),lines[#lines])

-- The rows: the levers start disabled, and the Lion's death enables each one.
local Rows=require('matrix13.world.rows')
local function row(batch,name,tbl)
    for _,r in ipairs(batch) do
        if r[2]==name and r[1]==tbl then return r end
    end
end
local function field(r,name)
    for _,c in ipairs(r[4]) do if c[1]==name then return c[3] end end
end
local dead=field(row(Rows.MXSPAWN,'DLC02_40_E_CharS_051','EventSpawnTable'),'EventOnDead')
for i,env in ipairs({'023','024','025'}) do
    local name='DLC02_40_EnvS_'..env
    assert(field(row(Rows.MXLOWER,name,'ZoneEnvSpawnTable'),'InitActivate')==2,name)
    local event='DLC02_40_E_EnvC_'..(630+i)
    local envc=row(Rows.MXLOWER,event,'EventEnvControlTable')
    assert(field(envc,'EnvSpawnAlias')==name and field(envc,'Activate')==1,event)
    assert(dead:find(event,1,true),event..' on the Lion')
end
print('fans_test passed')
