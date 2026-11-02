-- matrix13/world/mila.lua over a fake Doro: she appears once at the place asked, with Kara's mesh, the sitting clip looped
-- and the marker's yaw turned to the mesh's forward; asking again does nothing; another place moves her; no place removes
-- her; a body gone with its world comes back; a failure logs one STOP and never retries; the next Lua load sweeps the
-- path kept in her file; coop mxiii mila changes her pose (a held clip at its second) and scale, at once or at her next
-- spawn, and refuses what is not a pose, a second or a scale.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local object=function(t)
    t=t or {}
    t.type=function() return 'UObject' end
    t.IsValid=t.IsValid or function(self) return not self.gone end
    return t
end
package.loaded['core.unreal']={valid=function(x) return x and x:IsValid() and x or nil end}
local spawns,removed,swept,fail={},0,{},nil
local function mesh()
    return {PlayAnimation=function(self,clip,loop) self.clip,self.loop,self.at=clip,loop,nil end,
        SetPlayRate=function(self,r) self.rate=r end,SetPosition=function(self,t,notify) self.at,self.notify=t,notify end,
        SetRelativeScale3D=function(self,v) self.scale=v end}
end
package.loaded['race.doro']={
    resolve=function(path) if fail=='clip' then return nil end; return {path=path} end,
    spawn=function(world,at,rot,look)
        if fail=='spawn' then error('no mesh') end
        local d={actor=object(),path='/x/Actor_'..(#spawns+1),mesh=mesh()}
        spawns[#spawns+1]={world=world,at=at,rot=rot,look=look,d=d}
        return d
    end,
    remove=function(d) removed=removed+1; d.actor.gone=true end,
    same=function(a,path) return a:IsValid() and (a.moved or path)==path and a or nil end,
    sweep=function(path,mesh) swept[#swept+1]={path,mesh}; return true end,
}
local Mila=require('matrix13.world.mila')
local world={}
local eve={GetWorld=function() return world end}
local lines,files={},{}
local function new() return Mila.new({log=function(m) lines[#lines+1]=m end,read=function(n) return files[n] end,
    write=function(n,t) files[n]=t; return true end}) end
local m=new()
-- Nowhere: nothing spawned, and no file to sweep.
m.set(nil,eve)
assert(#spawns==0 and #swept==0)
-- The shelf.
m.set('shelf',eve)
local s=spawns[1]
assert(#spawns==1 and s.world==world and s.look.path:find('CH_NPC_Kara.CH_NPC_Kara',1,true))
assert(s.at==Mila.PLACES.shelf.at and s.rot.Yaw==-185 and s.rot.Pitch==0)
assert(s.d.mesh.clip.path==Mila.CLIP and s.d.mesh.loop==true and Mila.CLIP:find('CH_NPC_ScavengerFemale_A',1,true))
assert(s.d.mesh.rate==1 and s.d.mesh.at==nil and s.d.mesh.scale.X==0.9 and s.d.mesh.scale.Z==0.9,'Corpse sit, 0.9')
assert(files['coop-mxiii-mila.txt']=='/x/Actor_1' and #lines==1 and lines[1]=='Mila sits at shelf')
-- Asked again: nothing more.
m.set('shelf',eve)
assert(#spawns==1 and removed==0)
-- The drive room: the shelf's body goes, a new one sits.
m.set('floor',eve)
assert(#spawns==2 and removed==1 and spawns[2].at==Mila.PLACES.floor.at and spawns[2].rot.Yaw==-5)
-- The world went: her actor gone, she comes back while wanted.
spawns[2].d.actor.gone=true
m.set('floor',eve)
assert(#spawns==3)
-- No place: removed.
m.set(nil,eve)
assert(removed==3 and spawns[3].d.actor.gone)
-- A failure: one STOP, no retry, no error, on either kind.
local failing=new()
fail='spawn'
failing.set('shelf',eve); failing.set('shelf',eve)
local stops=0
for _,l in ipairs(lines) do if l:find('^STOP: Mila has no body') then stops=stops+1 end end
assert(stops==1 and #spawns==3)
fail='clip'
local noclip=new()
noclip.set('floor',eve)
assert(lines[#lines]:find('the corpse sit clip is missing',1,true) and #spawns==3)
fail=nil
-- A new Lua load removes the body the last one left, once.
files['coop-mxiii-mila.txt']='/x/Old'
swept={}
local again=new()
again.set(nil,eve); again.set(nil,eve)
assert(#swept==1 and swept[1][1]=='/x/Old' and swept[1][2]==Mila.MESH)
-- Another object at her actor's address: valid, not her. She comes back and that object is left alone.
do
    local at=new()
    at.set('shelf',eve)
    local n,d=#spawns,spawns[#spawns].d
    d.actor.moved='/x/SomethingElse'
    at.set('shelf',eve)
    assert(#spawns==n+1,'A reused address is no body')
end
-- coop mxiii mila: a held clip at once on her body, at its second, without notifies; a loop again plays at rate 1.
do
    local pm=new()
    local ok,text=pm.command()
    assert(ok and text:find('pose 1, corpse sit, scale 0.90',1,true) and text:find('4 standing idle',1,true),text)
    ok,text=pm.command('2','12.5')
    assert(ok and text:find('held at 12.5 s',1,true) and text:find('she shows in zone 4',1,true),text)
    pm.set('shelf',eve)
    local d=spawns[#spawns].d
    assert(d.mesh.clip.path==Mila.POSES[2].path and d.mesh.loop==false and d.mesh.rate==0 and d.mesh.at==12.5
        and d.mesh.notify==false,'Held at its next spawn')
    ok,text=pm.command('scale','1.1')
    assert(ok and d.mesh.scale.Y==1.1 and d.mesh.at==12.5 and lines[#lines]==text,text)
    ok=pm.command('4')
    assert(ok and d.mesh.clip.path:find('N_Scavenger_Idle1.N_Scavenger_Idle1',1,true) and d.mesh.loop==true
        and d.mesh.rate==1 and d.mesh.at==nil and d.mesh.scale.X==1.1,'A loop at once, the scale kept')
    assert(Mila.POSES[3].path:find('MV_Seq_Quest_Sub_026_02_Scavenger_C_01.MV_Seq_Quest_Sub_026_02_Scavenger_C_01',1,true))
    for _,bad in ipairs({{'0'},{'5'},{'1.5'},{'x'},{'2','-1'},{'2','x'},{'1','3'},{'scale'},{'scale','0.4'},
        {'scale','1.6'}}) do
        ok,text=pm.command(bad[1],bad[2])
        assert(not ok and text:find('^Use: coop mxiii mila'),table.concat(bad,' '))
    end
    assert(d.mesh.loop==true and d.mesh.scale.X==1.1,'A refusal changes nothing')
    -- A body that failed stays away until a new choice.
    fail='spawn'
    local retry=new()
    retry.set('floor',eve)
    fail=nil
    local n=#spawns
    retry.set('floor',eve)
    assert(#spawns==n,'No retry')
    retry.command('1')
    retry.set('floor',eve)
    assert(#spawns==n+1,'A new choice tries again')
end
-- The markers are the cooked map's, on their floors (plan z to world: z*100-939).
assert(math.abs(Mila.PLACES.shelf.at.Z-(-144.94*100-939))<1 and math.abs(Mila.PLACES.floor.at.Z-(-156.29*100-939))<1)
print('mila_test passed')
