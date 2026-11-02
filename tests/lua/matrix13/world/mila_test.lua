-- matrix13/world/mila.lua over a fake Doro: she appears once at the place asked, with Kara's mesh, the sitting clip looped
-- and the marker's yaw turned to the mesh's forward; asking again does nothing; another place moves her; no place removes
-- her; a body gone with its world comes back; a failure logs one STOP and never retries; the next Lua load sweeps the
-- path kept in her file.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local object=function(t)
    t=t or {}
    t.type=function() return 'UObject' end
    t.IsValid=t.IsValid or function(self) return not self.gone end
    return t
end
package.loaded['core.unreal']={valid=function(x) return x and x:IsValid() and x or nil end}
local spawns,removed,swept,fail={},0,{},nil
package.loaded['race.doro']={
    resolve=function(path) if fail=='clip' then return nil end; return {path=path} end,
    spawn=function(world,at,rot,look)
        if fail=='spawn' then error('no mesh') end
        local d={actor=object(),path='/x/Actor_'..(#spawns+1),mesh={PlayAnimation=function(self,clip,loop) self.clip,self.loop=clip,loop end}}
        spawns[#spawns+1]={world=world,at=at,rot=rot,look=look,d=d}
        return d
    end,
    remove=function(d) removed=removed+1; d.actor.gone=true end,
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
assert(lines[#lines]:find('the sitting clip is missing',1,true) and #spawns==3)
fail=nil
-- A new Lua load removes the body the last one left, once.
files['coop-mxiii-mila.txt']='/x/Old'
swept={}
local again=new()
again.set(nil,eve); again.set(nil,eve)
assert(#swept==1 and swept[1][1]=='/x/Old' and swept[1][2]==Mila.MESH)
-- The markers are the cooked map's, on their floors (plan z to world: z*100-939).
assert(math.abs(Mila.PLACES.shelf.at.Z-(-144.94*100-939))<1 and math.abs(Mila.PLACES.floor.at.Z-(-156.29*100-939))<1)
print('mila_test passed')
