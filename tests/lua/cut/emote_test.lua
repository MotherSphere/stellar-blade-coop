-- cut/emote.lua over a fake EVE, animation instance and asset store: the 31 poses under the menu's six categories and
-- their list; the end rule (movement input past 0.1, in the air, a skill); coop emote's words; no start without EVE, in
-- the air, during a skill, without her animation instance, with a clip missing or with no montage made; a start plays
-- the clip in DefaultSlot as a looped dynamic montage, the clip loaded once (LoadAsset at the first command, never in a
-- frame); nothing read in a frame while none plays; each frame's reads end it at movement input, in the air, at a
-- skill, when the montage no longer plays and on another EVE, with a 0.25 s blend; another emote, coop emote off and
-- coop off end it; a failing frame stops it with a line for the screen; the next Lua load's restore stops a dynamic
-- montage an earlier load left, once, and never one of the game's. GetPlayer gives a new wrapper at each call, as UE4SS
-- does, so EVE is told by address.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=function(self) return not self.gone end
    return o
end
local classes={}
local function class(path)
    classes[path]=classes[path] or uobj({path=path})
    return classes[path]
end
-- Clips by object path, in memory or only on disk (loadable): LoadAsset brings one into memory.
local memory,disk,loads,finds={},{},{},0
local function clip(path)
    return uobj({path=path,GetFullName=function() return 'AnimSequence '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.AnimSequence' or c.path=='/Script/Engine.AnimationAsset' end})
end
StaticFindObject=function(path)
    if path:find('^/Script/') then return class(path) end
    finds=finds+1
    return memory[path]
end
LoadAsset=function(path)
    loads[#loads+1]=path
    memory[path]=memory[path] or disk[path]
    return memory[path]
end
local DIR='/Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/'
local function on_disk(name) disk[DIR..name..'.'..name]=clip(DIR..name..'.'..name) end
on_disk('Clap'); on_disk('HandHeart'); on_disk('Natarajasana')
-- EVE: her address, movement input, movement (falling or not), skill, mesh and animation instance; the instance
-- records each montage call.
local addresses,montages=0,0
local function make_eve()
    addresses=addresses+1
    local address=addresses
    local a=uobj({plays={},stops={},playing={}})
    function a:PlaySlotAnimationAsDynamicMontage(asset,slot,bin,bout,rate,loops,trigger,at)
        self.plays[#self.plays+1]={asset=asset,slot=slot:ToString(),bin=bin,bout=bout,rate=rate,loops=loops,
            trigger=trigger,at=at}
        if self.refuse then return nil end
        montages=montages+1
        local m=uobj({n=montages})
        m.GetFullName=function() return 'AnimMontage /Engine/Transient.AnimMontage_'..m.n end
        self.playing[m]=true
        self.active=m
        return m
    end
    function a:Montage_IsPlaying(m) return self.playing[m]==true end
    function a:Montage_Stop(blend,m)
        if self.locked then error('read only',0) end
        self.stops[#self.stops+1]={blend=blend,m=m}
        self.playing[m]=nil
    end
    function a:GetCurrentActiveMontage() return self.active end
    local mesh=uobj({GetAnimInstance=function() return a end})
    local move=uobj({falling=false})
    function move:IsFalling() return self.falling end
    local e=uobj({stick={X=0,Y=0,Z=0},skill=false,Mesh=mesh,CharacterMovement=move,reads=0,
        GetAddress=function() return address end})
    function e:IsA(c) return c.path=='/Script/SB.SBCharacter' end
    function e:GetLastMovementInputVector() self.reads=self.reads+1; return self.stick end
    function e:IsRunningSkill() return self.skill end
    e.anim,e.move=a,move
    return e
end
local eve=make_eve()
local gets=0
local function wrapper(o) return o and setmetatable({},{__index=o,__newindex=o}) end
package.loaded.UEHelpers={GetPlayer=function() gets=gets+1; return wrapper(eve) end}
local Emote=require('cut.emote')
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local em=Emote.new({log=log})

-- The poses: 31, each name once, lowercase, each clip under PhotoMode; the list names them by category.
local n=0
for name,pose in pairs(Emote.POSES) do
    n=n+1
    assert(name:match('^[a-z0-9]+$'),name)
    assert(pose.path==DIR..pose.clip..'.'..pose.clip,pose.path)
    assert(not pose.clip:find('Selfie',1,true),'No selfie clip: '..pose.clip)
end
assert(n==31,n)
local categories={}
for _,c in ipairs(Emote.CATEGORIES) do categories[#categories+1]=c[1] end
assert(table.concat(categories,' ')=='Greetings Expression Orders Emotion Pose Dance',table.concat(categories,' '))
local list=Emote.list()
assert(list:find('^Greetings: salute, kungfu, toast%. Expression: clap, heart, thumbsup, victory, kiss%. Orders: '),
    list)
assert(list:find(' Dance: flow, nataraja, somersault%. coop emote <name> plays one; move, jump, dodge or attack to '
    ..'stop it%.$'),list)
for name in pairs(Emote.POSES) do assert(list:find(' '..name..'[,.]'),name) end

-- The rule alone.
assert(Emote.ends(0,false,false)==nil,'Standing still: it holds')
assert(Emote.ends(0.1,false,false)==nil,'A stick at rest (0.1): it holds')
assert(Emote.ends(0.5,false,false)=='movement input')
assert(Emote.ends(0,true,false)=='in the air')
assert(Emote.ends(0,false,true)=='a skill runs')

-- coop emote's words.
for _,bad in ipairs({{'clap','x'},{'list','x'},{'off','now'}}) do
    local ok,why=em.command(table.unpack(bad))
    assert(ok==false and why=='Use: coop emote [list|<name>|off]',why)
end
local ok,said=em.command()
assert(ok and said==list)
ok,said=em.command('list')
assert(ok and said==list)
ok,said=em.command('Clap')
assert(ok==false and said=="no emote 'Clap': coop emote list names them",said)
ok,said=em.command('off')
assert(ok and said=='no emote plays' and #logs==0,said)

-- Nothing read in a frame while none plays.
gets=0
assert(em.tick()==nil and gets==0)

-- No start: no EVE, in the air, during a skill, no animation instance, a clip missing.
local saved=eve
eve=nil
ok,said=em.command('clap')
assert(ok==false and said=='no EVE in the world',said)
eve=saved
eve.move.falling=true
ok,said=em.command('clap')
assert(ok==false and said=='EVE is in the air: try again on the ground',said)
eve.move.falling=false
eve.skill=true
ok,said=em.command('clap')
assert(ok==false and said=='EVE is busy (a skill runs): try again once she stands',said)
eve.skill=false
eve.Mesh.gone=true
ok,said=em.command('clap')
assert(ok==false and said=='EVE has no animation instance',said)
eve.Mesh.gone=false
assert(#loads==0,'Nothing loaded for a refused start')
ok,said=em.command('salute')
assert(ok==false and said=='Salute is missing on this PC' and loads[1]==DIR..'Salute.Salute',said)
assert(#eve.anim.plays==0 and not em.active())

-- A start: the clip loaded once, played in DefaultSlot as a looped dynamic montage blended over 0.25 s.
ok,said=em.command('clap')
assert(ok and said=='emote clap: move, jump, dodge or attack to stop it' and em.active(),said)
assert(loads[2]==DIR..'Clap.Clap' and #loads==2)
local p=eve.anim.plays[1]
assert(p.asset==memory[DIR..'Clap.Clap'] and p.slot=='DefaultSlot' and p.bin==0.25 and p.bout==0.25 and p.rate==1.0
    and p.loops==1048576 and p.trigger==-1.0 and p.at==0.0)
assert(last()=='emote clap: Clap in DefaultSlot, montage AnimMontage /Engine/Transient.AnimMontage_1, playing yes',
    last())
-- Frames: it holds while she stands; a stick at rest does not end it.
eve.stick={X=0.05,Y=0.05,Z=0}
clock=clock+1.5
assert(em.tick()==nil and em.active() and #eve.anim.stops==0)
-- Movement input ends it with a 0.25 s blend.
eve.stick={X=0.6,Y=0,Z=0}
assert(em.tick()==nil and not em.active())
assert(eve.anim.stops[1].blend==0.25 and eve.anim.stops[1].m.n==1)
assert(last()=='emote clap ended (movement input) after 1.5 s',last())
-- Along Y alone too: the length counts every axis.
em.command('clap')
eve.stick={X=0,Y=0.6,Z=0}
assert(em.tick()==nil and not em.active() and last()=='emote clap ended (movement input) after 0.0 s',last())
eve.stick={X=0,Y=0,Z=0}
-- Played again: from the cache, no load and no lookup.
finds=0
em.command('clap')
assert(#loads==2 and finds==0 and eve.anim.plays[#eve.anim.plays].asset==memory[DIR..'Clap.Clap'],'Cached: '..finds)
-- A jump, a skill, and a montage that no longer plays end it.
eve.move.falling=true
em.tick()
assert(not em.active() and last()=='emote clap ended (in the air) after 0.0 s',last())
eve.move.falling=false
em.command('clap')
eve.skill=true
em.tick()
assert(not em.active() and last()=='emote clap ended (a skill runs) after 0.0 s',last())
eve.skill=false
em.command('clap')
eve.anim.playing[eve.anim.active]=nil
em.tick()
assert(not em.active() and last()=='emote clap ended (the montage no longer plays) after 0.0 s',last())
-- Another emote ends the first one, then plays.
em.command('clap')
local first=eve.anim.active
ok,said=em.command('heart')
assert(ok and said=='emote heart: move, jump, dodge or attack to stop it')
assert(logs[#logs-1]=='emote clap ended (another emote) after 0.0 s',logs[#logs-1])
assert(eve.anim.stops[#eve.anim.stops].m==first and eve.anim.active~=first)
assert(eve.anim.plays[#eve.anim.plays].asset==memory[DIR..'HandHeart.HandHeart'])
-- coop emote off.
ok,said=em.command('off')
assert(ok and said=='emote off' and not em.active() and last()=='emote heart ended (coop emote off) after 0.0 s')
-- Another EVE (a map change): ended, the old one's montage stopped while it lives.
em.command('nataraja')
local old=eve
eve=make_eve()
em.tick()
assert(not em.active() and last()=='emote nataraja ended (her EVE changed) after 0.0 s',last())
assert(old.anim.stops[#old.anim.stops].m==old.anim.active)
-- coop off.
em.command('clap')
em.stop()
assert(not em.active() and last()=='emote clap ended (coop off) after 0.0 s',last())
-- No montage made: refused, nothing kept.
eve.anim.refuse=true
ok,said=em.command('clap')
assert(ok==false and said=='the game made no montage for Clap' and not em.active(),said)
assert(last()=='emote clap: no montage made for Clap',last())
eve.anim.refuse=nil
-- A failing frame: stopped, a line for the screen.
em.command('clap')
eve.GetLastMovementInputVector=function() error('no input',0) end
local good,message=em.tick()
assert(good==false and message=='coop emote stopped: no input' and not em.active(),message)
assert(logs[#logs-1]=='emote clap ended (error) after 0.0 s' and last()=='coop emote stopped: no input',last())
eve.GetLastMovementInputVector=nil
-- A stop that fails says so.
em.command('clap')
eve.anim.locked=true
em.command('off')
assert(last()=='emote clap ended (coop emote off) after 0.0 s: not stopped (read only)',last())
eve.anim.locked=nil

-- The next Lua load's restore: a dynamic montage left playing is stopped, once; one of the game's is left.
eve.anim.active=nil
em.command('clap')
local left=eve.anim.active
local stops=#eve.anim.stops
local em2=Emote.new({log=log})
em2.restore()
assert(#eve.anim.stops==stops+1 and eve.anim.stops[stops+1].m==left and eve.anim.stops[stops+1].blend==0.25)
assert(last()=="emote restore: an earlier load's montage stopped",last())
em2.restore()
assert(#eve.anim.stops==stops+1,'Once a load')
eve.anim.active=uobj({GetFullName=function() return 'AnimMontage /Game/Art/Some_Montage.Some_Montage' end})
local lines=#logs
Emote.new({log=log}).restore()
assert(#eve.anim.stops==stops+1 and #logs==lines,'The game\'s own montage is left')
eve=nil
Emote.new({log=log}).restore() -- No EVE (the title screen): nothing.
assert(#logs==lines)
print('emote_test: ok')
