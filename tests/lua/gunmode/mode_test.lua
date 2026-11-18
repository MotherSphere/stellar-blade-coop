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
    -- Recorded by gun mode's logical name (GM_AE_GunOn, ...): the SB row it fired, looked up in data.lua's lists.
    local D=require('gunmode.data')
    local name=row.s
    for k,e in pairs(D.OWN) do if e[1]==row.s then name='GM_AE_'..k end end
    for k,e in pairs(D.BORROWED) do if e[1]==row.s then name='GM_AE_'..k end end
    row={s=name}
    fired[#fired+1]=row.s
    if row.s=='GM_AE_GunOn' then stance('P_Eve_GunNikkeHide',true,2)
    elseif row.s=='GM_AE_GunOff' then stance('P_Eve_Default',false,pawn.TPSModeType) end
end})
-- UE4SS's UDataTable over plain tables: FindRow gives the live row; AddRow must not be used (it crashed SB).
local function datatable(rows)
    return obj({rows=rows,FindRow=function(self,name) return self.rows[name] end,
        AddRow=function() error('AddRow crashed the game') end,
        ForEachRow=function(self,fn) for k,v in pairs(self.rows) do fn(FNameOf(k),v) end end})
end
-- SB's rows, as data.lua expects them; one borrowed row missing (a spare NIKKE row stands in).
local eae_rows={Nikke_99_E_ActorEff_001={ID=1,ActorEffectAlias=FNameOf('P_Eve_Spare')}}
do
    local D=require('gunmode.data')
    for _,e in pairs(D.OWN) do eae_rows[e[1]]={ID=1,ActorEffectAlias=FNameOf(e[2])} end
    for k,e in pairs(D.BORROWED) do
        if k~='Peace' then eae_rows[e[1]]={ID=1,ActorEffectAlias=FNameOf('Nikke_Mission_'..k)} end
    end
end
local tables={
    EffectTable=datatable({M_Scarlet_CounterLinkStart={ID=5961071,ActionValue1=FNameOf('M_Scarlet_GroggyCounter')}}),
    EventActorEffectTable=datatable(eae_rows),
    SkillCommandTable=datatable({P_Eve_GunNikke_ShootSlug1_1={CommandActionType=2},P_Eve_GunNikke_ShootSlug1_2={CommandActionType=2},
        P_Eve_GunNikke_ShootSlug2_1={CommandActionType=5}}),
    SkillActiveStepTable=datatable({P_Eve_GunNikke_ShootSlug1_1_Hit1={StepType=3},P_Eve_GunNikke_ShootSlug1_1_Cast1={StepType=1}}),
}
local row=obj({DestTargetTransformType=1,DestTargetRelativeAxisType=1,DestTargetRelativeLocation={X=0,Y=0,Z=0}})
local drone=obj({DestTargetTransformType=0,DestTargetRelativeAxisType=2})
local tbl=obj({FindRow=function(_,name) return name:find('GunNikke') and row or drone end})
local stats=obj({IsGamePaused=function() return false end})
local objects={['/Script/SB.Default__SBBlueprintLibrary']=lib,['/Game/Local/Data/ProjectileTable.ProjectileTable']=tbl,
    ['/Script/Engine.Default__GameplayStatics']=stats}
for name,t in pairs(tables) do objects['/Game/Local/Data/'..name..'.'..name]=t end
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

-- 1. Off: gun_mode=off: no loop.
settings='gun_mode=off\n'
M.new(env()).start()
assert(#game_loops==0 and has('gun_mode=off'))

-- 2. On (the pose on too, gun_pose=on): one game-thread loop; no standing pak noted.
settings='gun_pose=on\ngun_fire_effect=on\n'
local gm=M.new(env())
gm.start()
assert(#game_loops==1 and has('NIKKE kneel only') and has('ready: G'))
run(T+4.5) -- Past the new-world pause a fresh controller would set.

-- 3. G: SB's rows taken (the borrowed ones on gun mode's effects, the missing one replaced by a spare, the counter
-- link effect on the shot, the fire commands on the burst shot's type, the shot step on its cast's), then the on rows
-- in order, standing, TPS mode 0, the camera, the NIKKE row on the drone frame.
tap('G')
local D=require('gunmode.data')
local eff,eae=tables.EffectTable.rows,tables.EventActorEffectTable.rows
assert(eff.M_Scarlet_CounterLinkStart.ActionValue1.s=='P_Eve_GunNikke_ShootSlug1_1')
assert(eae[D.row('GunOn')].ActorEffectAlias.s=='P_Eve_GunNikke' and eae[D.row('Fire')].ActorEffectAlias.s==D.FIRE_EFFECT)
assert(D.row('Peace')=='Nikke_99_E_ActorEff_001' and eae[D.row('GunOff')].ActorEffectAlias.s=='P_Eve_GunNikke_Dispel')
assert(tables.SkillCommandTable.rows.P_Eve_GunNikke_ShootSlug1_2.CommandActionType==5)
assert(tables.SkillActiveStepTable.rows.P_Eve_GunNikke_ShootSlug1_1_Hit1.StepType==1)
assert(table.concat(fired,' ',1,5)=='GM_AE_Reload GM_AE_GunOn GM_AE_Beta GM_AE_Ammo GM_AE_Peace',table.concat(fired,' '))
assert(gm.state.on and pawn._stance=='P_Eve_GunNikkeHide')
run(T+1.0)
assert(count('GM_AE_PosOff')==1 and custom[#custom]=='off')
run(T+2.5)
assert(pawn.TPSModeType==0 and row.DestTargetTransformType==0 and row.DestTargetRelativeAxisType==2)
assert(pawn.CameraBoom.CustomOffset.Y==60 and pawn.CurrentBulletItemAlias.s=='Bullet_Nikke' and pawn.CustomLookAtActive)

-- 4. LMB held: full auto at the shot's cool time; each round at the crosshair point in EVE's frame (facing +Y, the
-- point 1000 ahead and 50 up); released, it stops.
down.LeftMouseButton=true
run(T+1.0)
local shots=count('GM_AE_Fire')
assert(shots>=6 and shots<=9,shots)
local v=row.DestTargetRelativeLocation
assert(math.abs(v.X-1000)<1e-6 and math.abs(v.Y)<1e-6 and v.Z==50)
down.LeftMouseButton=nil
run(T+0.5)
local after=count('GM_AE_Fire')
run(T+0.5)
assert(count('GM_AE_Fire')==after)

-- 5. Y: crouched (the centre cover, the kneel animset, mode 2 again); Y again: standing.
down.Y=true; run(T+0.1); down.Y=nil
run(T+0.6)
assert(gm.state.crouched and count('GM_AE_Pos2')>=1 and custom[#custom]=='P_Eve_GunNikkeHide' and pawn.TPSModeType==2)
down.Y=true; run(T+0.1); down.Y=nil
run(T+2.0)
assert(not gm.state.crouched and pawn.TPSModeType==0)

-- 6. Shift: the gun lifted for the game's evade, then the on rows again after the roll.
local ons=count('GM_AE_GunOn')
down.LeftShift=true; run(T+0.1); down.LeftShift=nil
run(T+0.3)
assert(count('GM_AE_GunOff')==1 and gm.state.roll_back)
run(T+1.0)
assert(not gm.state.roll_back and count('GM_AE_GunOn')>ons)

-- 7. The pose: its errors (no components in this fake) stay inside it and leave gun mode on.
assert(gm.state.on and gm.status():find('errors',1,true))

-- 8. G: the off rows, the camera and the bullet back, the off rows again 1.2 s later.
run(T+1.0)
local offs=count('GM_AE_PeaceOff')
tap('G')
assert(not gm.state.on and count('GM_AE_PeaceOff')==offs+1 and pawn.CameraBoom.CustomOffset.Y==0)
assert(pawn.CurrentBulletItemAlias.s=='Bullet_Missile' and not pawn.CustomLookAtActive and pawn.TPSModeType==2)
run(T+1.5)
assert(count('GM_AE_PeaceOff')==offs+2)

-- 9. A tap of D-pad Right turns it on; a hold does not (the bike's).
down.Gamepad_DPad_Right=true; run(T+0.1); down.Gamepad_DPad_Right=nil; run(T+0.5)
assert(gm.state.on)
tap('G'); run(T+0.5)
down.Gamepad_DPad_Right=true; run(T+1.0); down.Gamepad_DPad_Right=nil; run(T+0.5)
assert(not gm.state.on)
assert(gm.status():find('gun mode off',1,true))
print('gunmode mode: ok')
