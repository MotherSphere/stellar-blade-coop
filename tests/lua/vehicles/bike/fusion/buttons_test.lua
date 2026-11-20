-- vehicles/bike/fusion/buttons.lua with a fake button table (dev build): the default keys_bike.txt; RT / LT give
-- SBO's model a world stick ahead of or behind the nose, turned by the left stick; no trigger leaves the stick alone;
-- the profile takes the gameplay actions out, keeps menus and jump, moves LT / RT actions to LB / RB, and puts the
-- player's own table back at the dismount; a journal left by a crash is repaired at the next start.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local function obj(o)
    o=o or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function() return true end
    return o
end
local function entry(n,k) return {ActionName=FName(n),Key={KeyName=FName(k)},bShift=false,bCtrl=false,bAlt=false,
    bCmd=false,bCustomizeKey=true,bMainKey=true,bAZERTY=false,Priority=0,SortValue=0} end
local function axis(n,k) return {AxisName=FName(n),Key={KeyName=FName(k)},Scale=1,bCustomizeKey=true,bMainKey=true,
    bAZERTY=false} end
local function arr(t) return setmetatable({GetArrayNum=function() return #t end},{__index=function(_,i) return t[i] end}) end
local acts,axes={},{}
-- the player's table: 60 gameplay actions, menus, jump, aim on LT and shoot on RT; 25 axes
for i=1,60 do acts[#acts+1]=entry('AttackLight'..i,'Gamepad_FaceButton_Right') end
acts[#acts+1]=entry('UI_Confirm','Gamepad_FaceButton_Bottom')
acts[#acts+1]=entry('Jump','Gamepad_FaceButton_Bottom')
acts[#acts+1]=entry('TPSMode','Gamepad_LeftTrigger')
acts[#acts+1]=entry('TPSFire','Gamepad_RightTrigger')
acts[#acts+1]=entry('TPSMode','RightMouseButton')
for i=1,25 do axes[#axes+1]=axis('MoveForward'..i,'Gamepad_LeftY') end
local function same(m,r) return m.ActionName:ToString()==r.ActionName:ToString() and m.Key.KeyName:ToString()==r.Key.KeyName:ToString() end
local IS=obj({rebuilds=0})
IS.ActionMappings,IS.AxisMappings=arr(acts),arr(axes)
function IS:RemoveActionMapping(r) for i=#acts,1,-1 do if same(acts[i],r) then table.remove(acts,i) end end end
function IS:AddActionMapping(r) acts[#acts+1]=r end
function IS:RemoveAxisMapping() end
function IS:AddAxisMapping(r) axes[#axes+1]=r end
function IS:ForceRebuildKeymaps() self.rebuilds=self.rebuilds+1 end
StaticFindObject=function(p) if p=='/Script/Engine.Default__InputSettings' then return IS end return obj() end
FindAllOf=function() return nil end -- no game settings object: the engine's table is the player's
local dir=os.tmpname():gsub('[^\\/]+$','')
local log={}
local Buttons=require('vehicles.bike.fusion.buttons')
for _,f in ipairs({'keys_bike.txt','keys_restore.txt','keys_backup.txt'}) do os.remove(dir..f) end
local B=Buttons.new({log=function(l) log[#log+1]=l end,dir=dir})

-- 1. Defaults: RT / W throttle, LT / S brake, X / LeftShift handbrake; aim and shoot move to LB / RB.
local d=Buttons.parse(Buttons.DEFAULT)
assert(d.ctl.throttle[1]=='Gamepad_RightTriggerAxis' and d.ctl.brake[1]=='Gamepad_LeftTriggerAxis'
    and d.move.Gamepad_LeftTrigger=='Gamepad_LeftShoulder' and d.save==false and #d.bad==0)

-- 2. The profile on: gameplay out, menus and jump kept, LT / RT actions on LB / RB, keyboard aim kept.
local line=B.on(nil)
assert(line:find('bike profile on: 62 on%-foot entries off, 2 moved'),line)
local function has(n,k) for _,m in ipairs(acts) do if m.ActionName:ToString()==n and m.Key.KeyName:ToString()==k then return true end end end
assert(not has('AttackLight1','Gamepad_FaceButton_Right') and has('UI_Confirm','Gamepad_FaceButton_Bottom') and has('Jump','Gamepad_FaceButton_Bottom'))
assert(has('TPSMode','Gamepad_LeftShoulder') and has('TPSFire','Gamepad_RightShoulder') and not has('TPSMode','Gamepad_LeftTrigger'))
assert(has('TPSMode','RightMouseButton'),'keyboard aim stays')
local function exists(f) local h=io.open(dir..f,'r') if h then h:close() return true end return false end
assert(exists('keys_bike.txt') and exists('keys_restore.txt'),'keys file and journal written')

-- 3. Controls: RT ahead (turned by the left stick), LT behind, nothing held: nil; handbrake: drift.
local held={}
local pc=obj({})
function pc:GetInputAnalogKeyState(k) return held[k.KeyName:ToString()] or 0 end
function pc:IsInputKeyDown(k) return held[k.KeyName:ToString()]==1 end
local s,drift=B.controls(pc,0)
assert(s==nil and drift==false,'no trigger: the stick drives')
held.Gamepad_RightTriggerAxis=1
s=B.controls(pc,90)
assert(math.abs(s.x)<1e-9 and math.abs(s.y-1)<1e-9,'throttle: ahead of a nose at 90 degrees')
held.Gamepad_LeftX=1
s=B.controls(pc,0)
assert(math.abs(s.x-math.cos(math.rad(45)))<1e-9 and s.y>0,'steer right: 45 degrees off the nose')
held={Gamepad_LeftTriggerAxis=0.8,Gamepad_FaceButton_Left=1}
s,drift=B.controls(pc,0)
assert(math.abs(s.x+0.8)<1e-9 and drift==true,'brake: behind the nose; handbrake: drift')

-- 4. Off: her own table back, journal gone; off again: nothing.
assert(B.off(nil)=='buttons: on-foot buttons back' and has('AttackLight1','Gamepad_FaceButton_Right')
    and has('TPSMode','Gamepad_LeftTrigger') and not has('TPSMode','Gamepad_LeftShoulder'))
assert(not exists('keys_restore.txt') and B.off(nil)==nil and B.controls(pc,0)==nil)

-- 5. A crash while riding: the journal puts her table back at the next start.
B.on(nil)
local B2=Buttons.new({log=function() end,dir=dir})
assert(B2.repair(nil)=='buttons: button table repaired after an unclean exit' and has('AttackLight1','Gamepad_FaceButton_Right'))
assert(B2.repair(nil)==nil,'nothing left to repair')
for _,f in ipairs({'keys_bike.txt','keys_restore.txt','keys_backup.txt'}) do os.remove(dir..f) end
print('fusion buttons_test ok')
