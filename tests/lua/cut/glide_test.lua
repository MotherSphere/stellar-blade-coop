-- cut/glide.lua over a fake EVE, movement component and player controller: the rule (Jump held 0.2 s of her world
-- time, a release starting it over, a hitch counted as 0.1 s, never while rising, on the ground or in the developer
-- flight); nothing read while off; bGlide set once a glide starts and put back when Jump is released, she lands, flies
-- or rises, her EVE changes, the save is not a co-op one (checked once a second) or the controller is gone; the pause
-- menu (her time standing still) never completes a hold; coop glide off and coop off put it back; a failing frame puts
-- it back and turns coop glide off with a line for the screen; the next Lua load's restore clears a bGlide left on,
-- once; and coop glide's words.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local SBC={type=function() return 'UObject' end,IsValid=function() return true end}
local PCC={type=function() return 'UObject' end,IsValid=function() return true end}
StaticFindObject=function(path)
    if path=='/Script/SB.SBCharacter' then return SBC end
    if path=='/Script/Engine.PlayerController' then return PCC end
end
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=function(self) return not self.gone end
    return o
end
-- EVE: her world time, velocity, movement (falling or not), the flight flag and every write of bGlide.
local function make_eve()
    local e=uobj({time=10,velocity={X=0,Y=0,Z=500},bFlyingAction=false,writes={},reads=0})
    local m=uobj({falling=false})
    function m:IsFalling() return self.falling end
    local glide=false
    setmetatable(e,{__index=function(_,k)
        if k=='bGlide' then return glide end
        if k=='CharacterMovement' then e.reads=e.reads+1; return m end
    end,__newindex=function(t,k,v)
        if k~='bGlide' then return rawset(t,k,v) end
        if t.locked then error('read only',0) end
        glide=v
        t.writes[#t.writes+1]=v
    end})
    function e:IsA(c) return c==SBC end
    function e:GetGameTimeSinceCreation() return self.time end
    function e:GetVelocity() return self.velocity end
    e.move=m
    return e
end
local eve=make_eve()
local down={}
local pc=uobj({IsInputKeyDown=function(_,key) return down[key.KeyName:ToString()]==true end,
    IsA=function(_,c) return c==PCC end})
local gets=0
package.loaded.UEHelpers={GetPlayer=function() gets=gets+1; return eve end,
    GetPlayerController=function() return pc end}
local Glide=require('cut.glide')
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local coop=true
local slots=0
local g=Glide.new({log=log,slot=function()
    slots=slots+1
    if coop then return true end
    return false,'coop glide runs only on a co-op save'
end})
-- One frame dt s of her world time later.
local function frame(dt)
    eve.time=eve.time+(dt or 0.0625) -- Steps a binary fraction holds exactly.
    return g.tick()
end

-- The rule alone.
local s={held=0}
assert(Glide.HOLD==0.2)
assert(not Glide.want(s,0.1,true,true,true,false) and math.abs(s.held-0.1)<1e-9,'0.1 s held: not yet')
assert(Glide.want(s,0.1,true,true,true,false),'0.2 s held, falling past the top: glide')
assert(not Glide.want(s,0.1,true,true,false,false),'Rising: no glide, the hold kept')
assert(Glide.want(s,0.1,true,true,true,false),'Past the top again: glide')
assert(not Glide.want(s,0.1,true,true,true,true),'Never in the developer flight')
assert(not Glide.want(s,0.1,true,false,true,false),'Never on the ground')
assert(not Glide.want(s,0.1,false,true,true,false) and s.held==0,'A release starts the hold over')
assert(not Glide.want(s,5,true,true,true,false) and s.held==0.1,'A hitch counts as 0.1 s')
assert(not Glide.want(s,-3,true,true,true,false) and s.held==0.1,'Time that went back counts as nothing')

-- coop glide's words.
for _,bad in ipairs({{},{'On'},{'on','x'},{'toggle'}}) do
    local ok,why=g.command(table.unpack(bad))
    assert(ok==false and why=='Use: coop glide on|off',why)
end
assert(select(2,g.command('off'))=='glide off already')

-- Off: nothing read.
gets=0
assert(frame()==nil and gets==0,'Nothing read while off')

-- On: on the ground, nothing set; her movement alone is read.
local ok,said=g.command('on')
assert(ok and said=='glide on: hold Jump (Space, or A/Cross) in the air, from the top of the jump' and g.active())
assert(last()=='glide on')
down.SpaceBar=true
frame(); frame(); frame(); frame(); frame()
assert(#eve.writes==0 and slots==1,'On the ground, nothing; the slot checked once a second')
-- The jump: rising with Jump held, then past the top.
eve.move.falling=true
frame(); frame(); frame(); frame(); frame()
assert(#eve.writes==0,'Rising: nothing, however long Jump is held')
eve.velocity.Z=-20
frame()
assert(eve.writes[1]==true and eve.bGlide==true and last()=='glide on EVE (velocity Z -20 cm/s)',last())
frame()
assert(#eve.writes==1,'Set once')
down.SpaceBar=nil
frame()
assert(eve.writes[2]==false and last()=='glide ended (Jump released) after 0.1 s',last())
-- Held again in the air: 0.2 s of her time, on the pad's key.
down.Gamepad_FaceButton_Bottom=true
frame(0.125)
assert(#eve.writes==2,'0.125 s: not yet')
frame(0.125)
assert(eve.writes[3]==true,'0.25 s: glide again')
-- The pause menu: her time stands still, the glide holds; released and pressed in it, the hold starts over.
down.Gamepad_FaceButton_Bottom=nil
frame(0)
assert(eve.writes[4]==false)
down.Gamepad_FaceButton_Bottom=true
for _=1,10 do frame(0) end
assert(#eve.writes==4,'A pause never completes a hold')
frame(0.125); frame(0.125)
assert(eve.writes[5]==true)
-- Landing.
eve.move.falling=false
frame()
assert(eve.writes[6]==false and last():find('^glide ended %(landed%) after 0%.%d s$'),last())
-- The developer flight, and rising again, end a glide.
eve.move.falling=true
frame(0.125); frame(0.125); frame()
assert(eve.writes[7]==true)
eve.bFlyingAction=true
frame()
assert(eve.writes[8]==false and last():find('^glide ended %(flight or rising%)'),last())
eve.bFlyingAction=false
frame()
assert(eve.writes[9]==true)
eve.velocity.Z=300
frame()
assert(eve.writes[10]==false,'A launch upwards ends it')
eve.velocity.Z=-20
frame()
assert(eve.writes[11]==true)
-- No controller this frame: Jump reads as released.
pc.gone=true
frame()
assert(eve.writes[12]==false and last():find('Jump released'),last())
pc.gone=false
frame(0.125); frame(0.125)
assert(eve.writes[13]==true)
-- Not a co-op save any more: put back at the next check, and nothing set until one again.
coop=false
frame()
assert(#eve.writes==13,'The slot is checked once a second')
clock=clock+1
frame()
assert(eve.writes[14]==false and last()=='glide ended (not a co-op save) after 0.1 s',last())
frame(); frame(0.125); frame(0.125)
assert(#eve.writes==14,'Nothing set off a co-op save')
coop=true
clock=clock+1
frame(); frame(0.125); frame(0.125)
assert(eve.writes[15]==true)
-- Her EVE changes (a map change): ours put back on the old one, the new one glides from her own hold.
local old=eve
eve=make_eve()
eve.move.falling,eve.velocity.Z=true,-20
frame()
assert(old.writes[16]==false and old.bGlide==false and last()=='glide ended (her EVE changed) after 0.0 s',last())
assert(#eve.writes==0,'No glide at her first frame: the hold starts over with her time')
frame(0.125); frame(0.125)
assert(eve.writes[1]==true)
-- coop glide off puts it back and reads nothing more.
ok,said=g.command('off')
assert(ok and said=='glide off' and eve.writes[2]==false and not g.active())
assert(last():find('^glide ended %(coop glide off%)'),last())
gets=0
frame()
assert(gets==0 and #eve.writes==2)
-- coop off likewise.
g.command('on'); frame(); frame(0.125); frame(0.125)
assert(eve.writes[3]==true)
g.stop()
assert(eve.writes[4]==false and not g.active() and last():find('^glide ended %(coop off%)'),last())
-- A failing frame: bGlide put back, coop glide off, a line for the screen.
g.command('on'); frame(); frame(0.125); frame(0.125)
assert(eve.writes[5]==true)
eve.GetVelocity=function() error('no velocity',0) end
local good,message=frame()
assert(good==false and message=='coop glide stopped: no velocity' and eve.writes[6]==false and not g.active())
assert(last()=='coop glide stopped: no velocity',last())
-- A failing put back says so.
eve.GetVelocity=function(self) return self.velocity end
g.command('on'); frame(); frame(0.125); frame(0.125)
assert(eve.writes[7]==true)
eve.locked=true
g.command('off')
assert(eve.bGlide==true and logs[#logs]:find('bGlide not put back %(read only%)'),logs[#logs])
-- The next Lua load's restore: a bGlide left on goes back to false, once; nothing to do when it reads false.
eve.locked=nil
local g2=Glide.new({log=log,slot=function() return true end})
g2.restore()
assert(eve.bGlide==false and last()=='glide restore: bGlide was left on, put back',last())
eve.bGlide=true
local n=#logs
g2.restore()
assert(eve.bGlide==true and #logs==n,'Once a load')
eve.bGlide=false
local g3=Glide.new({log=log,slot=function() return true end})
n=#eve.writes
local lines=#logs
g3.restore()
assert(#eve.writes==n and #logs==lines,'Nothing written when it reads false')
eve=nil
Glide.new({log=log,slot=function() return true end}).restore() -- No EVE (the title screen): nothing.
print('glide_test: ok')
