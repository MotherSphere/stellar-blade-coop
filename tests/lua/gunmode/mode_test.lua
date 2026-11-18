-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- gunmode/mode.lua with lua5.4 alone, against a fake UE4SS and a fake EVE whose stance follows the rows fired: off
-- without its pak or with gun_mode=off; with it, G turns gun mode on (the on rows in order, standing at 0.7 s, TPS
-- mode 0 once settled, the shoulder camera, the NIKKE row on the drone frame), LMB fires full auto with each round
-- written at the crosshair point in EVE's frame, Y crouches (the cover row, the kneel animset, mode 2 again), Shift
-- rolls (the gun lifted, then the on rows again), G turns it off (the off rows, the camera and the bullet put back,
-- the off rows again 1.2 s later), and an error in the pose loop stays inside it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path

local T=0
os.clock=function() return T end
local hooks,game_loops,notify={},{},{}
local fired={}
local logs={}
local function FNameOf(s) return {s=s,ToString=function() return s end} end
FName=FNameOf
Key=setmetatable({},{__index=function(_,k) return k end})
ModifierKey={CONTROL='CONTROL'}
function RegisterHook(path,fn) hooks[path]=fn end
function NotifyOnNewObject(cls,fn) notify[cls]=fn end
function LoopInGameThreadWithDelay(ms,fn) game_loops[#game_loops+1]=fn end
-- Nothing may run Lua off the game thread: these must never be called.
function RegisterKeyBind() error('a key bind runs Lua off the game thread') end
function ExecuteWithDelay() error('ExecuteWithDelay runs Lua off the game thread') end
function LoopAsync() error('LoopAsync runs Lua off the game thread') end
function LoadAsset() return nil end
function FindAllOf() return {} end

local function obj(t) t.IsValid=function() return true end; return t end
local down={}
local pawn
local function stance(name,tps,mode) pawn._stance,pawn._tps,pawn.TPSModeType=name,tps,mode end
local lib=obj({CreateSBZoneEvent=function(_,kind,row)
    fired[#fired+1]=row.s
    if row.s=='NGM_AE_GunOn' then stance('P_Eve_GunNikkeHide',true,2)
    elseif row.s=='NGM_AE_GunOff' then stance('P_Eve_Default',false,pawn.TPSModeType) end
end})
local row=obj({DestTargetTransformType=1,DestTargetRelativeAxisType=1,DestTargetRelativeLocation={X=0,Y=0,Z=0}})
local drone=obj({DestTargetTransformType=0,DestTargetRelativeAxisType=2})
local tbl=obj({FindRow=function(_,name) return name:find('GunNikke') and row or drone end})
local stats=obj({IsGamePaused=function() return false end})
local objects={['/Script/SB.Default__SBBlueprintLibrary']=lib,['/Game/Local/Data/ProjectileTable.ProjectileTable']=tbl,
    ['/Script/Engine.Default__GameplayStatics']=stats}
function StaticFindObject(path) return objects[path] end
local custom={}
pawn=obj({_stance='P_Eve_Default',_tps=false,TPSModeType=0,CustomLookAtActive=false,
    CurrentBulletItemAlias=FNameOf('Bullet_Missile'),
    CameraBoom=obj({CustomOffset={X=0,Y=0,Z=0}}),
    GetCurrentStanceName=function(self) return FNameOf(self._stance) end,
    IsTPSMode=function(self) return self._tps end,
    GetTPSModeType=function(self) return self.TPSModeType end,
    K2_GetActorLocation=function() return {X=0,Y=0,Z=0} end,
    K2_GetActorRotation=function() return {Pitch=0,Yaw=90,Roll=0} end,
    GetTPSLookAtWorldLocation=function() return {X=0,Y=1000,Z=50} end,
    ActiveCustomMovingStanceData=function(_,d) custom[#custom+1]=d.OverrideStanceAnim.s end,
    DeactiveCustomMovingStanceData=function() custom[#custom+1]='off' end})
local pc=obj({Pawn=pawn,bShowMouseCursor=false,
    IsInputKeyDown=function(_,k) return down[k.KeyName.s]==true end})
function FindFirstOf(name) if name=='SBPlayerController' then return pc end end

local function run(to)
    while T<to do
        T=T+1/60
        for _,fn in ipairs(game_loops) do fn() end
    end
end
local function tap(key) down[key]=true; run(T+0.1); down[key]=nil; run(T+0.1) end
local function count(name) local n=0 for _,r in ipairs(fired) do if r==name then n=n+1 end end return n end
local function has(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end return false end

package.loaded['gunmode.mode']=nil
local M=require('gunmode.mode')
local FOLDER='C:\\G\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop'
local PAKS='C:\\G\\SB\\Content\\Paks\\~mods\\'
local files={}
for _,n in ipairs({'RoguelikeMode_P','zNikkeGunMode_P'}) do
    for _,e in ipairs({'.utoc','.ucas','.pak'}) do files[PAKS..n..e]=1 end
end
local settings=''
local function env()
    return {log=function(m) logs[#logs+1]=m end,folder=FOLDER,read=function(p) return files[p] and 'x' or nil end,
        read_all=function(p) return p==FOLDER..'\\coop-settings.txt' and settings or nil end}
end

-- 1. Off: gun_mode=off, or Survival Protocol's pak missing: no loop.
settings='gun_mode=off\n'
M.new(env()).start()
assert(#game_loops==0 and has('gun_mode=off'))
settings=''
local saved=files; files={}
for k in pairs(saved) do if not k:find('Roguelike',1,true) then files[k]=1 end end
M.new(env()).start()
assert(#game_loops==0 and has('pak is missing (no RoguelikeMode_P'))
files=saved

-- 2. On (the pose on too, gun_pose=on): one game-thread loop; no standing pak noted.
settings='gun_pose=on\n'
local gm=M.new(env())
gm.start()
assert(#game_loops==1 and has('NIKKE kneel only') and has('ready: G'))
run(T+4.5) -- Past the new-world pause a fresh controller would set.

-- 3. G: the on rows in order, then standing, TPS mode 0, the camera, the NIKKE row on the drone frame.
tap('G')
assert(table.concat(fired,' ',1,6)=='NGM_ItemA_Ammo NGM_AE_Reload NGM_AE_GunOn NGM_AE_Beta NGM_AE_Ammo NGM_AE_Peace')
assert(gm.state.on and pawn._stance=='P_Eve_GunNikkeHide')
run(T+1.0)
assert(count('NGM_AE_PosOff')==1 and custom[#custom]=='off')
run(T+2.5)
assert(pawn.TPSModeType==0 and row.DestTargetTransformType==0 and row.DestTargetRelativeAxisType==2)
assert(pawn.CameraBoom.CustomOffset.Y==60 and pawn.CurrentBulletItemAlias.s=='Bullet_Nikke' and pawn.CustomLookAtActive)

-- 4. LMB held: full auto at the shot's cool time; each round at the crosshair point in EVE's frame (facing +Y, the
-- point 1000 ahead and 50 up); released, it stops.
down.LeftMouseButton=true
run(T+1.0)
local shots=count('NGM_AE_Fire')
assert(shots>=6 and shots<=9,shots)
local v=row.DestTargetRelativeLocation
assert(math.abs(v.X-1000)<1e-6 and math.abs(v.Y)<1e-6 and v.Z==50)
down.LeftMouseButton=nil
run(T+0.5)
local after=count('NGM_AE_Fire')
run(T+0.5)
assert(count('NGM_AE_Fire')==after)

-- 5. Y: crouched (the centre cover, the kneel animset, mode 2 again); Y again: standing.
down.Y=true; run(T+0.1); down.Y=nil
run(T+0.6)
assert(gm.state.crouched and count('NGM_AE_Pos2')>=1 and custom[#custom]=='P_Eve_GunNikkeHide' and pawn.TPSModeType==2)
down.Y=true; run(T+0.1); down.Y=nil
run(T+2.0)
assert(not gm.state.crouched and pawn.TPSModeType==0)

-- 6. Shift: the gun lifted for the game's evade, then the on rows again after the roll.
local ons=count('NGM_AE_GunOn')
down.LeftShift=true; run(T+0.1); down.LeftShift=nil
run(T+0.3)
assert(count('NGM_AE_GunOff')==1 and gm.state.roll_back)
run(T+1.0)
assert(not gm.state.roll_back and count('NGM_AE_GunOn')>ons)

-- 7. The pose: its errors (no components in this fake) stay inside it and leave gun mode on.
assert(gm.state.on and gm.status():find('errors',1,true))

-- 8. G: the off rows, the camera and the bullet back, the off rows again 1.2 s later.
run(T+1.0)
local offs=count('NGM_AE_PeaceOff')
tap('G')
assert(not gm.state.on and count('NGM_AE_PeaceOff')==offs+1 and pawn.CameraBoom.CustomOffset.Y==0)
assert(pawn.CurrentBulletItemAlias.s=='Bullet_Missile' and not pawn.CustomLookAtActive and pawn.TPSModeType==2)
run(T+1.5)
assert(count('NGM_AE_PeaceOff')==offs+2)

-- 9. A tap of D-pad Right turns it on; a hold does not (the bike's).
down.Gamepad_DPad_Right=true; run(T+0.1); down.Gamepad_DPad_Right=nil; run(T+0.5)
assert(gm.state.on)
tap('G'); run(T+0.5)
down.Gamepad_DPad_Right=true; run(T+1.0); down.Gamepad_DPad_Right=nil; run(T+0.5)
assert(not gm.state.on)
assert(gm.status():find('gun mode off',1,true))
print('gunmode mode: ok')
