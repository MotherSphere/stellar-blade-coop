-- coop leviathan: the cut Naytiba 10, the Leviathan (/Game/Art/Character/Monster/CH_M_NA_10/, found in pakchunk0's
-- index, not seen in game), shown with race/doro.lua's display parts: a plain actor with one mesh component, collision
-- off, the engine's single-node instance playing its clips. No SB character, no table row, no AI, nothing that can
-- die, so nothing of it reaches a quest, an achievement or a save; its Blueprint classes are looked up, never spawned.
-- list only reads: which assets resolve, each mesh's and clip's skeleton, each class's super class, and the
-- CharacterTable rows that name it. show puts one mesh ahead of EVE, facing her (by default at 1.6 times its bounding
-- sphere radius, 6 m at least, and lifted so its lowest point is 5 m above her feet), and plays each clip of its
-- skeleton twice in turn; play holds one; move places it again from where EVE stands; skin sets every material slot to
-- one material. off removes it, and so do coop off, a map change, its first error and the next Lua load
-- (coop-leviathan.txt, read at the first tick).
-- The free camera, for filming it: show and play turn it on, cam toggles it. A plain actor with one CameraComponent is
-- the view target, placed where the game's camera was, and flies from the keys each frame (none read while the co-op
-- menu or one of its boxes is open); the player controller ignores move and look input meanwhile, so EVE stays where
-- she is. Off (cam, off, coop off, a map change, its first error, the next Lua load): the view back on what it showed
-- before (EVE, or a camera of the game's) unless the game took it meanwhile, both ignore flags back as they were, the
-- actor gone.
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('race.doro')
local valid,value_of,text,find=U.valid,U.value_of,U.text,U.find
local Leviathan={}
local DIR='/Game/Art/Character/Monster/CH_M_NA_10/'
local OBJECT,ANIM='/Script/CoreUObject.Object','/Script/Engine.AnimationAsset'
local TABLE='/Game/Local/Data/CharacterTable.CharacterTable'
-- SBCharacterTableProperty's fields that hold names (its export: M_Hydra's Type M_Hydra, DespawnShow
-- Despawn/M_Hydra_Despawn, RefAppearance M_Hydra), read beside the row's own name.
local FIELDS={'Type','Flag','DeadAlias','DespawnShow','DefaultStanceAlias','BehaviorTreeRes','DefaultDetectAIAlias',
    'NarrowDetectAIAlias','RefAppearance'}
local AHEAD=600 -- cm in front of EVE: the least of the automatic distance, and all of it when the bounds are unread.
local AUTO=1.6 -- The automatic distance in bounding sphere radii.
-- cm: the automatic height puts the mesh's lowest point this far above EVE's feet (its root, when the bounds are
-- unread). A starting value, tuned in game.
local LIFT=500
local FAR=5000 -- m: the farthest distance and height show and move take.
local BLEND=0.3 -- s: the view's blend into and out of the free camera.
local SPEED,FAST=1000,4 -- cm/s: the free camera's speed (coop leviathan cam <m/s> sets it), times FAST with Shift.
-- Degrees a second of an arrow key: a starting value, tuned in game.
local TURN=90
local MAX_DT=0.1 -- s: a longer frame (a hitch) moves the camera this much.
local PC,MATERIAL='/Script/Engine.PlayerController','/Script/Engine.MaterialInterface'
-- The free camera's keys, Unreal key names (QWERTY and AZERTY both), read with IsInputKeyDown.
local KEYS={forward={'W','Z'},back={'S'},left={'A','Q'},right={'D'},up={'SpaceBar','E'},down={'LeftControl','C'},
    fast={'LeftShift'},turn_left={'Left'},turn_right={'Right'},look_up={'Up'},look_down={'Down'}}
local USE='Use: coop leviathan [list] | show [body|a|b|tentacle|statue] [<distance m>|auto] [<height m>|auto] '
    ..'[<scale>] | move <distance m>|auto [<height m>|auto] | skin statue|hydra|default | cam [<m/s>] | '
    ..'play [<clip>] | off'
-- What list reads, in order: {kind, object path}. A class's path is its Blueprint's with _C.
Leviathan.LIST={}
local function add(kind,dir,names)
    for name in names:gmatch('%S+') do
        Leviathan.LIST[#Leviathan.LIST+1]={kind=kind,path=dir..name..'.'..name..(kind=='class' and '_C' or '')}
    end
end
add('mesh',DIR,'CH_M_NA_10 Leviathan_A Leviathan_B M_LeviathanTentacleA')
add('mesh','/Game/Art/BG/Actor/SecretRoom/','C_Reviathan') -- The secret room's statue, a StaticMesh.
add('skeleton',DIR,'CH_M_NA_10_Skeleton Leviathan_A_Skeleton Leviathan_B_Skeleton M_LeviathanTentacleA_Skeleton')
add('clip',DIR..'Animation/','M_Leviathan_BashLeft1_1 M_Leviathan_BashRight1_1 M_Leviathan_BattleIdle01 '
    ..'M_Leviathan_BattleIdle02 M_Leviathan_Catch_1 M_Leviathan_LightningBall1_1 M_Leviathan_SmashLeft1_1 '
    ..'M_Leviathan_SmashRight1_1 M_LeviathanTentacleA_BashLeft M_LeviathanTentacleA_BashLeft_1 '
    ..'M_LeviathanTentacleA_BashRight M_LeviathanTentacleA_BashRight_1 M_LeviathanTentacleA_Battleidle01 '
    ..'M_LeviathanTentacleA_Smash M_LeviathanTentacleA_Smash_1 M_LeviathanTentacleA_SwingLeft_1 '
    ..'M_LeviathanTentacleA_SwingRight_1 M_LeviathanTentacleB_Catch M_LeviathanTentacleB_CatchHit '
    ..'M_LeviathanTentacleB_Swing')
add('clip',DIR..'Animation/BlendSpace/','IdleRun_BS_Battle TentacleA_IdleRun_BS_Peaceful')
add('clip',DIR,'CH_M_NA_10_Anim')
add('clip','/Game/Art/Character/PC/CH_P_EVE_01/Animation/','Hit_Leviathan_GrabSuccess') -- EVE's own.
add('class',DIR..'Blueprints/','CH_M_NA_10_Blueprint CH_M_NA_10_AnimBP CH_M_NA_10_TentacleA_Blueprint '
    ..'CH_M_NA_10_TentacleA_AnimBP CH_M_NA_10_TentacleB_Blueprint CH_M_NA_10_TentacleB_AnimBP '
    ..'CH_M_NA_10_Tentacle_AnimBP')
add('class','/Game/GameDesign/Level/BluePrintActor/Matrix_XI/','ME_Area04_SecretRoom_Leviathan')
add('asset','/Game/Art/Show/Despawn/','M_Leviathan_Despawn')
add('asset',DIR,'Default')
-- show's meshes: LIST's first five.
Leviathan.MESHES={body=1,a=2,b=3,tentacle=4,statue=5}
-- skin's materials: the secret room statue's, the Hydra's tentacles' (its folder also has MI_M_NA_09_V03_Upper);
-- default is the mesh's own.
Leviathan.SKINS={statue='/Game/Art/BG/Actor/SecretRoom/C_Reviathan_MI.C_Reviathan_MI',
    hydra='/Game/Art/Character/Monster/CH_M_NA_09/Materials/MI_M_NA_09_V03_Tentacle.MI_M_NA_09_V03_Tentacle',
    default=false}

local function name_of(path) return path:match('[^.]+$') end
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
-- A console word as a number within lo..hi, else nil.
local function num(x,lo,hi)
    x=tonumber(x)
    return x and x>=lo and x<=hi and x or nil
end
-- cm as m for a message: '6', '72.5'.
local function m(cm) return (string.format('%.1f',cm/100):gsub('%.0$','')) end
-- Where a display goes: dist cm ahead of EVE's feet along her facing and up cm above them, turned to face her.
local function spot(eve,dist,up)
    local body=valid(eve.Mesh)
    local at,yaw=value_of(body:K2_GetComponentLocation()),math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
    return {X=at.X+math.cos(yaw)*dist,Y=at.Y+math.sin(yaw)*dist,Z=at.Z+up},
        {Pitch=0,Yaw=value_of(body:K2_GetComponentRotation()).Yaw+180,Roll=0}
end
-- The controller as before the free camera. Its view target again, unless the game took the view from the camera
-- (camera: its actor's path) meanwhile, for a cutscene or a camera volume: left to the game then. EVE's pawn when that
-- target is gone or there was none. Move and look input ignored once less, and not at all when they were not before
-- (the game reset the stacked flag meanwhile), even when the view could not be set. was: {move=, look=, view=<the
-- view target's path, '' for none>}. Returns the flags read after, for the log.
local function give_back(pc,was,camera)
    local viewed,why=pcall(function()
        local view=valid(pc:GetViewTarget())
        if view and path_of(view)~=camera then return end
        local to=was.view~='' and valid(StaticFindObject(was.view)) or valid(pc:K2_GetPawn())
        if to then pc:SetViewTargetWithBlend(to,BLEND,0,0,false) end
    end)
    pc:SetIgnoreMoveInput(false)
    if not was.move and pc:IsMoveInputIgnored()==true then pc:ResetIgnoreMoveInput() end
    return string.format('move ignored %d, look ignored %d%s',pc:IsMoveInputIgnored()==true and 1 or 0,
        pc:IsLookInputIgnored()==true and 1 or 0,viewed and '' or '; view not set: '..tostring(why))
end
-- An entry's object (Doro.resolve: in memory, else LoadAsset); a class not found by itself is looked up again once its
-- Blueprint's package is loaded.
local function resolve(e)
    local o=Doro.resolve(e.path,OBJECT)
    if o or e.kind~='class' then return o end
    pcall(LoadAsset,e.path:sub(1,-3))
    return Doro.resolve(e.path,OBJECT)
end
-- The full name of o's skeleton (a skeletal mesh's or a clip's); nil when it has none.
local function skeleton_of(o)
    local ok,s=pcall(function() return text(valid(o.Skeleton):GetFullName()) end)
    return ok and s or nil
end
-- A clip's length in s, 3 when it has none (a blend space).
local function length_of(a)
    local ok,t=pcall(function() return tonumber(value_of(a.SequenceLength)) end)
    return ok and t and t>0 and t or 3
end
-- The clips of LIST on the skeleton of mesh (an entry of LIST), in order: {path, name, seconds}; and that skeleton.
local function clips_of(mesh)
    local skeleton,out=skeleton_of(resolve(mesh)),{}
    if not skeleton then return out end
    for _,e in ipairs(Leviathan.LIST) do
        local a=e.kind=='clip' and resolve(e)
        if a and a:IsA(find(ANIM)) and skeleton_of(a)==skeleton then
            out[#out+1]={path=e.path,name=name_of(e.path),seconds=length_of(a)}
        end
    end
    return out,skeleton
end
-- A mesh's bounds at a scale, from its asset's ExtendedBounds, in the mesh's own space (a component's Bounds is not
-- reflected in this build), in cm: {r=<sphere radius>, z=<centre above its root>, low=<lowest point above its root>}.
-- Raises when they cannot be read.
local function bounds_of(e,scale)
    local b=value_of(assert(resolve(e),'no mesh').ExtendedBounds)
    local o,x=value_of(b.Origin),value_of(b.BoxExtent)
    local r=assert(tonumber(value_of(b.SphereRadius)),'no SphereRadius')
    return {r=r*scale,z=o.Z*scale,low=(o.Z-x.Z)*scale}
end

-- o: log (the [LV] lines), store (coop-leviathan.txt through link.store; nil without the native part: no sweep at the
-- next Lua load), blocked (true while the co-op menu or one of its boxes takes the keys: the free camera reads none).
-- coop-leviathan.txt: the display (its actor's path, its mesh's) and the free camera (its actor's path, the
-- controller's, whether move and look input were ignored before it, 1 or 0, and the view target's path before it),
-- tab-separated; a part that is off is empty, and the file goes once both are.
function Leviathan.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local blocked=o.blocked or function() return false end
    local self={}
    local shown -- {d=<Doro.spawn's>, name=, map=, clips=, k=<cycle step>, next=<os.clock of the next>, held=<clip>,
    -- radius=, low=<bounds_of's r and low, nil when unread>, own=<its slots' materials before the first skin>}
    local cam -- {d=<Doro.spawn's>, pc=, pc_path=, map=, was={move=, look=, view=}, at=, yaw=, pitch=, t=, since=,
    -- said=}
    local skin='default' -- The last skin set: a new show keeps it.
    local speed=SPEED
    local restored,look_failed=false,false
    local fkeys={}
    local function fields()
        local f={}
        for x in ((store.load() or '')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=x end
        for k=1,7 do f[k]=f[k] or '' end
        return f
    end
    -- The file's fields from first on set to the values given ('' for none), the others kept. Returns the store's
    -- answer: false and why when the line could not be written.
    local function keep(first,...)
        local f=fields()
        for k=1,select('#',...) do f[first+k-1]=select(k,...) end
        local line=table.concat(f,'\t',1,7):gsub('\t+$','')
        if line=='' then return store.clear() end
        return store.save(line)
    end
    -- The free camera a file names: its controller given back (while the view is still on it), then its actor swept.
    -- Raises on a failing call.
    local function undo(f)
        local pc=f[4]~='' and valid(StaticFindObject(f[4]))
        local back='its controller is gone'
        if pc and pc:IsA(find(PC)) then back=give_back(pc,{move=f[5]=='1',look=f[6]=='1',view=f[7]},f[3]) end
        if f[3]~='' then Doro.sweep(f[3],'camera') end
        return back
    end
    -- What an earlier Lua load left (its display, its free camera), then the file cleared. Once, on the game thread
    -- (the first tick, show or cam).
    function self.restore()
        if restored then return end
        restored=true
        local f=fields()
        if f[1]=='' and f[3]=='' and f[4]=='' then return end
        local said={}
        if f[1]~='' then
            local ok,gone=pcall(Doro.sweep,f[1],f[2])
            said[#said+1]=not ok and tostring(gone) or gone and 'the display of an earlier Lua load destroyed'
                or 'nothing left'
        end
        if f[3]~='' or f[4]~='' then
            local _,back=pcall(undo,f)
            said[#said+1]='the free camera of an earlier Lua load off: '..tostring(back)
        end
        store.clear()
        log('restore: '..table.concat(said,'; '))
    end
    local function remove(why)
        local s=shown
        shown=nil
        local ok,e=pcall(Doro.remove,s.d)
        if ok then keep(1,'','') end -- Else the next Lua load tries again.
        log('removed ('..why..')'..(ok and '' or ': '..tostring(e)))
    end
    -- The free camera off: the controller given back (while it is the one met: after a map change it is not), then its
    -- actor gone. Each step its own pcall; the file keeps the camera when one fails. Returns ok, message.
    local function cam_off(why)
        local c=cam
        if not c then return true,'The free camera is off already.' end
        cam=nil
        local back_ok,back=pcall(function()
            local pc=Doro.same(c.pc,c.pc_path)
            return pc and give_back(pc,c.was,c.d.path) or 'its controller is gone'
        end)
        -- ponytail: the actor goes at once, so the engine may cut to EVE's view instead of blending; remove it 0.3 s
        -- later if the cut shows in a video.
        local gone_ok,gone=pcall(Doro.remove,c.d)
        local ok=back_ok and gone_ok
        if ok then keep(3,'','','','','') end
        local line=string.format('cam off (%s): %s%s',why,tostring(back),gone_ok and '' or '; '..tostring(gone))
        log(line)
        return ok,ok and "Free camera off: the game's camera is back." or 'Free camera off with an error: '..line
    end
    -- The free camera on where the game's camera is now, as the view target; move and look input ignored. True, or
    -- false and why.
    local function cam_on()
        self.restore()
        if cam then return true end
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local pc=U.controller()
        if not pc then return false,'no player controller' end
        local manager=valid(pc.PlayerCameraManager)
        if not manager then return false,'no camera manager' end
        local at,r=value_of(manager:GetCameraLocation()),value_of(manager:GetCameraRotation())
        -- A camera this Lua load could not give back holds the flags and the view from before it: never replaced by
        -- its own.
        local f,pc_path=fields(),path_of(pc)
        if f[3]~='' then pcall(Doro.sweep,f[3],'camera') end
        local view=valid(pc:GetViewTarget())
        local was=f[4]==pc_path and {move=f[5]=='1',look=f[6]=='1',view=f[7]}
            or {move=pc:IsMoveInputIgnored()==true,look=pc:IsLookInputIgnored()==true,view=view and path_of(view) or ''}
        local d=Doro.spawn(eve:GetWorld(),{X=at.X,Y=at.Y,Z=at.Z},{Pitch=r.Pitch,Yaw=r.Yaw,Roll=0},{camera=true})
        -- The file before the controller changes: a camera the next Lua load could not give back never turns on.
        local saved,save_why=keep(3,d.path,pc_path,was.move and '1' or '0',was.look and '1' or '0',was.view)
        if saved==false then
            pcall(Doro.remove,d)
            return false,'coop-leviathan.txt not written ('..tostring(save_why)..')'
        end
        local now=os.clock()
        cam={d=d,pc=pc,pc_path=pc_path,map=U.map_of(eve),was=was,at={X=at.X,Y=at.Y,Z=at.Z},yaw=r.Yaw,pitch=r.Pitch,
            t=now,since=now,said=false}
        pcall(function() d.mesh:SetFieldOfView(value_of(manager:GetFOVAngle())) end) -- The same framing.
        local ok,why=pcall(function()
            pc:SetViewTargetWithBlend(d.actor,BLEND,0,0,false)
            pc:SetIgnoreMoveInput(true) -- Look input stays on: the game turns the controller from the mouse (fly()).
        end)
        if not ok then
            local _,message=cam_off('error')
            return false,tostring(why)..'; '..message
        end
        log(string.format('cam on at %.0f %.0f %.0f yaw %.1f pitch %.1f, %s m/s; before: move ignored %d, look '
            ..'ignored %d, view %s',at.X,at.Y,at.Z,r.Yaw,r.Pitch,m(speed),was.move and 1 or 0,was.look and 1 or 0,
            was.view~='' and was.view or 'none'))
        return true
    end
    -- Any of the keys held.
    local function held(pc,names)
        for _,name in ipairs(names) do
            fkeys[name]=fkeys[name] or {KeyName=FName(name)}
            if pc:IsInputKeyDown(fkeys[name])==true then return true end
        end
        return false
    end
    -- The controller's rotation, which the game turns from the mouse or a controller's stick as it does for EVE's own
    -- camera (look input stays on). In this game GetInputMouseDelta and the MouseX and MouseY axis values read 0
    -- (2026-10-22). nil once it cannot be read, said once: the arrow keys alone turn the camera then.
    local function control(pc)
        if look_failed then return nil end
        local ok,r=pcall(function() return value_of(pc:GetControlRotation()) end)
        if ok and type(r)=='table' and tonumber(r.Yaw) and tonumber(r.Pitch) then return r end
        look_failed=true
        log('cam: the view cannot follow the mouse ('..tostring(ok and 'no rotation' or r)
            ..'); the arrow keys turn the camera')
        return nil
    end
    -- The pitch the mouse gives, from three places: the controller's rotation, EVE's own camera component and the view
    -- rotation it wants (DesiredViewRotFromLegacy). In this game the mouse turns the controller's yaw but not its
    -- pitch (2026-10-22), so the camera's pitch follows whichever source moved most since the camera turned on.
    -- Each source's pitch, -180 to 180, or nil when it cannot be read.
    local function pitches(c,pawn,r)
        local function norm(p) p=tonumber(p); if not p then return nil end p=p%360; return p>180 and p-360 or p end
        if c.lens==nil then
            local ok,lens=pcall(function()
                return valid(pawn:GetComponentByClass(find('/Script/SB.SBCameraComponent')))
            end)
            c.lens=ok and lens or false
        end
        local out={control=r and norm(r.Pitch)}
        if c.lens then
            local ok,v=pcall(function() return norm(value_of(c.lens:K2_GetComponentRotation()).Pitch) end)
            out.camera=ok and v or nil
            ok,v=pcall(function() return norm(value_of(c.lens.DesiredViewRotFromLegacy).Pitch) end)
            out.desired=ok and v or nil
        end
        return out
    end
    local SOURCES={'control','camera','desired'}
    -- Each frame while the free camera is on: EVE on another map, another controller or its actor gone ends it, with no
    -- call on it. Else the mouse and the arrows turn it and the keys move it along its view. Once, 1 s in, the view
    -- target is logged.
    local function fly(c,now)
        local dt=math.min(math.max(now-c.t,0),MAX_DT)
        c.t=now
        local pawn,pc=valid(UE.GetPlayer()),Doro.same(c.pc,c.pc_path)
        if not pawn or not pc or U.map_of(pawn)~=c.map then return 'map change' end
        if not Doro.same(c.d.actor,c.d.path) then return 'its actor is gone' end
        if not c.said and now>=c.since+1 then
            c.said=true
            local target=valid(pc:GetViewTarget())
            log('cam view target '..(target and text(target:GetFullName()) or 'none'))
        end
        if blocked() then return end
        local function axis(plus,minus) return (held(pc,plus) and 1 or 0)-(held(pc,minus) and 1 or 0) end
        -- The arrows add their turn to the controller's, or turn the camera alone when it cannot be read.
        local turn_yaw=axis(KEYS.turn_right,KEYS.turn_left)*TURN*dt
        local turn_pitch=axis(KEYS.look_up,KEYS.look_down)*TURN*dt
        local r=control(pc)
        local now_p=pitches(c,pawn,r)
        if not c.base then c.base,c.pitch0,c.probes=now_p,c.pitch,0 end
        -- The source that moved most since the camera turned on gives the pitch's change.
        local best,used=0,'none'
        for _,k in ipairs(SOURCES) do
            local v,b=now_p[k],c.base[k]
            if v and b then
                local d=(v-b+180)%360-180
                if math.abs(d)>math.abs(best)+0.01 then best,used=d,k end
            end
        end
        if c.probes<6 and now>=c.since+c.probes+1 then
            c.probes=c.probes+1
            local function f(k) return now_p[k] and string.format('%.1f',now_p[k]) or '-' end
            log(string.format('cam pitch probe %d: control %s, camera %s, desired %s; used %s %.1f',c.probes,
                f('control'),f('camera'),f('desired'),used,best))
        end
        if r then
            c.add_yaw,c.add_pitch=(c.add_yaw or 0)+turn_yaw,(c.add_pitch or 0)+turn_pitch
            c.yaw=(tonumber(r.Yaw)+c.add_yaw)%360
            c.pitch=math.max(-89,math.min(89,c.pitch0+best+c.add_pitch))
        else
            c.yaw=(c.yaw+turn_yaw)%360
            c.pitch=math.max(-89,math.min(89,c.pitch+turn_pitch))
        end
        local f,r,u=axis(KEYS.forward,KEYS.back),axis(KEYS.right,KEYS.left),axis(KEYS.up,KEYS.down)
        local v=speed*(held(pc,KEYS.fast) and FAST or 1)*dt
        local y,p,at=math.rad(c.yaw),math.rad(c.pitch),c.at
        at.X=at.X+v*(f*math.cos(p)*math.cos(y)-r*math.sin(y))
        at.Y=at.Y+v*(f*math.cos(p)*math.sin(y)+r*math.cos(y))
        at.Z=at.Z+v*(f*math.sin(p)+u)
        c.d.mesh:K2_SetWorldLocationAndRotation({X=at.X,Y=at.Y,Z=at.Z},{Pitch=c.pitch,Yaw=c.yaw,Roll=0},false,{},false)
    end
    -- show's and play's word on the free camera: ', free camera on' or why not; '' when it was on already. A camera
    -- that fails never fails the show or the play.
    local function with_cam()
        if cam then return '' end
        local ran,ok,why=pcall(cam_on)
        if ran and ok then return ', free camera on' end
        return ', no free camera ('..tostring(ran and why or ok)..')'
    end
    -- One line per entry of LIST, then the CharacterTable rows whose name or name fields hold NA_10 or eviathan
    -- (Leviathan, and the statue's Reviathan), with their ID and MeshScale, and a count.
    local function list()
        local found=0
        for _,e in ipairs(Leviathan.LIST) do
            local x=resolve(e)
            local line='list '..e.kind..' '..name_of(e.path)..': '
            if not x then line=line..'missing'
            else
                found=found+1
                line=line..text(x:GetFullName()):match('^%S+')
                if e.kind=='class' then
                    local ok,super=pcall(function() return text(valid(x:GetSuperStruct()):GetFName()) end)
                    line=line..' super='..(ok and super or '-')
                elseif e.kind=='mesh' or e.kind=='clip' then
                    line=line..' skeleton='..name_of(skeleton_of(x) or '-')
                end
            end
            log(line)
        end
        local rows,named=0,0
        local function read(row,field)
            local ok,v=pcall(function() local x=value_of(row[field]); return type(x)=='number' and x or text(x) end)
            return ok and tostring(v) or '?'
        end
        local ok,why=pcall(function()
            local dt=Doro.resolve(TABLE,'/Script/Engine.DataTable')
            if not dt then error('not found',0) end
            dt:ForEachRow(function(key,row)
                rows,row=rows+1,value_of(row)
                local words={'list row '..text(key)}
                for _,f in ipairs(FIELDS) do words[#words+1]=f..'='..read(row,f) end
                local line=table.concat(words,' ')
                if line:lower():find('na_10',1,true) or line:lower():find('eviathan',1,true) then
                    named=named+1
                    log(line..' ID='..read(row,'ID')..' MeshScale='..read(row,'MeshScale'))
                end
            end)
        end)
        log(ok and string.format('list CharacterTable rows=%d named=%d',rows,named)
            or 'list CharacterTable not read: '..tostring(why))
        return true,string.format('Leviathan list: %d of %d assets found, %s; [LV] lines in this log.',found,
            #Leviathan.LIST,ok and named..' CharacterTable rows name it' or 'CharacterTable not read')
    end
    -- Every material slot of the shown mesh to the skin's material, or back to the mesh's own (read before the first
    -- skin). Returns the slot count; raises when the material is missing.
    local function paint(s,name)
        local mesh=s.d.mesh
        local n=math.floor(tonumber(value_of(mesh:GetNumMaterials())) or 0)
        local material=name~='default' and assert(Doro.resolve(Leviathan.SKINS[name],MATERIAL),
            name_of(Leviathan.SKINS[name])..' is missing on this PC')
        if material and not s.own then
            s.own={}
            for i=0,n-1 do s.own[i]=mesh:GetMaterial(i) end
        end
        if s.own then
            for i=0,n-1 do mesh:SetMaterial(i,material or s.own[i]) end
        end
        log(string.format('skin %s: %d slots, %s',name,n,material and name_of(Leviathan.SKINS[name]) or 'its own'))
        return n
    end
    -- s placed dist m ahead of where EVE stands and up m above her feet, facing her; each 'auto' for its default.
    -- Returns both in cm.
    local function place(s,eve,dist,up)
        local cm=dist=='auto' and (s.radius and math.max(AHEAD,AUTO*s.radius) or AHEAD) or dist*100
        local up_cm=up=='auto' and LIFT-(s.low or 0) or up*100
        local at,rot=spot(eve,cm,up_cm)
        s.d.mesh:K2_SetWorldLocationAndRotation(at,rot,false,{},true)
        return cm,up_cm
    end
    -- The shown display while its actor is still the one spawned; else none, removed as a tick would, with no call on
    -- it.
    local function current()
        if shown and not Doro.same(shown.d.actor,shown.d.path) then remove('its actor is gone') end
        return shown
    end
    -- A second show replaces the first. dist: m, or 'auto'; up: m, or 'auto'. The last skin set and the free camera on.
    local function show(which,dist,up,scale)
        self.restore()
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        if shown then remove('replaced') end
        -- A display whose removal failed is still in the file: it goes first, else no new one, so the file never loses
        -- it and the next Lua load can still sweep it.
        local f=fields()
        if f[1]~='' then
            local ok,why=pcall(Doro.sweep,f[1],f[2])
            if not ok then return false,'the Leviathan shown before could not be removed: '..tostring(why) end
            keep(1,'','')
        end
        local e=Leviathan.LIST[Leviathan.MESHES[which]]
        local at,rot=spot(eve,AHEAD,0)
        local d=Doro.spawn(eve:GetWorld(),at,rot,{path=e.path,static=which=='statue'})
        local s={d=d,name=which,map=U.map_of(eve),clips={},k=0,next=0}
        shown=s
        keep(1,d.path,e.path)
        d.mesh:SetRelativeScale3D({X=scale,Y=scale,Z=scale})
        -- Its bounds at its scale: the automatic distance and height.
        local read,b=pcall(bounds_of,e,scale)
        if read and b.r>0 then
            s.radius,s.low=b.r,b.low
            log(string.format('show %s: bounding sphere radius %s m, centre %s m and lowest point %s m above its root',
                which,m(b.r),m(b.z),m(b.low)))
        else
            log(string.format('show %s: bounds unread (%s), %s m ahead, its root %s m up',which,
                read and 'radius 0' or tostring(b),m(AHEAD),m(LIFT)))
        end
        local cm,up_cm=place(s,eve,dist,up)
        if skin~='default' then
            local ok,why=pcall(paint,s,skin)
            if not ok then log('skin '..skin..' not set: '..tostring(why)) end
        end
        local clips,skeleton=clips_of(e)
        s.clips=clips
        log(string.format('show %s: %s, %d clips on skeleton %s, %s m ahead, %s m up, scale %g',which,name_of(e.path),
            #clips,name_of(skeleton or '-'),m(cm),m(up_cm),scale))
        return true,string.format('Leviathan %s shown %s m ahead, %s m up, scale %g, %d clips in turn%s; [LV] lines in '
            ..'this log.',which,m(cm),m(up_cm),scale,#clips,with_cam())
    end
    -- The shown display placed again from where EVE stands now: dist m (or 'auto') ahead, up m (or 'auto') up.
    local function move(dist,up)
        local s=current()
        if not s then return false,'no Leviathan is shown: coop leviathan show first' end
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local cm,up_cm=place(s,eve,dist,up)
        log(string.format('move %s: %s m ahead, %s m up',s.name,m(cm),m(up_cm)))
        return true,string.format('Leviathan %s moved %s m ahead of EVE, %s m up.',s.name,m(cm),m(up_cm))
    end
    local function set_skin(name)
        local s=current()
        if not s then
            skin=name
            return true,'Leviathan skin '..name..' for the next show.'
        end
        local n=paint(s,name)
        skin=name
        return true,string.format('Leviathan %s skin %s on its %d material slots.',s.name,name,n)
    end
    -- The clip whose name ends with want, else holds it (any case), held looping; none: the cycle again. The free
    -- camera on.
    local function play(want)
        local s=shown
        if not s then return false,'no Leviathan is shown: coop leviathan show first' end
        if not want then
            s.held,s.next=nil,0
            return true,'Leviathan '..s.name..' back to its cycle'..with_cam()..'.'
        end
        want=want:lower()
        local pick=nil
        for _,c in ipairs(s.clips) do if not pick and c.name:lower():sub(-#want)==want then pick=c end end
        for _,c in ipairs(s.clips) do if not pick and c.name:lower():find(want,1,true) then pick=c end end
        if not pick then return false,'no clip of the shown '..s.name..' ends with or holds '..want end
        s.held,s.next=pick,0
        return true,'Leviathan '..s.name..' holds '..pick.name..' looping'..with_cam()
            ..'; coop leviathan play goes back to the cycle.'
    end
    -- cam: the free camera on or off; cam <m/s>: its speed.
    local function cam_command(a)
        if a then
            speed=tonumber(a)*100
            log('cam speed '..m(speed)..' m/s')
            return true,'Free camera speed '..m(speed)..' m/s, '..FAST..' times that with Shift.'
        end
        if cam then return cam_off('coop leviathan cam') end
        local ok,why=cam_on()
        if not ok then return false,'no free camera: '..tostring(why) end
        return true,'Free camera on: W or Z, S, A or Q, D move it, Space or E up, LeftControl or C down, Shift '..FAST
            .." times faster, the mouse or the arrow keys turn it; coop leviathan cam again gives the game's camera "
            ..'back.'
    end
    -- A distance or a height word: 'auto' when none or auto, else m within lo..hi; nil when it is not that.
    local function where(x,lo,hi) return (x==nil or x=='auto') and 'auto' or num(x,lo,hi) end
    -- show's words: [mesh] [distance m|auto] [height m|auto] [scale]; nil when they are not that.
    local function show_words(a,b,c,d,e)
        local which='body'
        if Leviathan.MESHES[a] then which,a,b,c,d=a,b,c,d,e end
        local dist,up,scale=where(a,0,FAR),where(b,-FAR,FAR),c==nil and 1 or num(c,0.01,100)
        if d==nil and dist and up and scale then return which,dist,up,scale end
    end
    -- Is the free camera on (commands/cut.lua: turning it off is never refused).
    function self.filming() return cam~=nil end
    function self.command(sub,a,b,c,d,e)
        if sub=='show' then
            local which,dist,up,scale=show_words(a,b,c,d,e)
            if which then return show(which,dist,up,scale) end
        elseif c==nil and d==nil then
            if b==nil then
                if (sub==nil or sub=='list') and a==nil then return list() end
                if sub=='play' then return play(a) end
                if sub=='skin' and Leviathan.SKINS[a]~=nil then return set_skin(a) end
                if sub=='cam' and (a==nil or num(a,0.1,500)) then return cam_command(a) end
                if sub=='off' and a==nil then
                    if not shown and not cam then return true,'No Leviathan is shown.' end
                    local said={}
                    if shown then
                        remove('coop leviathan off')
                        said[1]='Leviathan removed.'
                    end
                    if cam then said[#said+1]=select(2,cam_off('coop leviathan off')) end
                    return true,table.concat(said,' ')
                end
            end
            local dist,up=a~=nil and where(a,0,FAR),where(b,-FAR,FAR)
            if sub=='move' and dist and up then return move(dist,up) end
        end
        return false,USE
    end
    -- EVE on another map (or none) removes it, and so does its actor no longer being the one spawned, with no call on
    -- it. Then a held clip, played once; else, once the last clip played twice, the next of the cycle, logged.
    local function step(now)
        local s=shown
        local pawn=valid(UE.GetPlayer())
        if not pawn or U.map_of(pawn)~=s.map then return 'map change' end
        if not Doro.same(s.d.actor,s.d.path) then return 'its actor is gone' end
        if now<s.next then return end
        local c=s.held
        if c then
            s.next=math.huge
            log('play '..c.name..' looping')
        elseif #s.clips==0 then
            s.next=math.huge
            return
        else
            s.k=s.k%#s.clips+1
            c=s.clips[s.k]
            s.next=now+2*c.seconds
            log(string.format('show %s step %d/%d %s %.2f s twice',s.name,s.k,#s.clips,c.name,c.seconds))
        end
        Doro.apply(s.d,{asset=c.path,loop=true,rate=1,at=0})
    end
    -- Each frame, on the game thread. Returns ok, message when it removed the display (the free camera going with it)
    -- or turned the free camera off by itself.
    function self.tick()
        local now=os.clock()
        if shown then
            local ok,why=pcall(step,now)
            if not (ok and not why) then
                local name=shown.name
                remove(ok and why or 'error: '..tostring(why))
                cam_off(ok and why or 'error')
                if ok then return true,'Leviathan '..name..' removed: '..why..'.' end
                return false,'Leviathan '..name..' removed on an error: '..tostring(why)
            end
        end
        if not cam then return end
        local ok,why=pcall(fly,cam,now)
        if ok and not why then return end
        cam_off(ok and why or 'error: '..tostring(why))
        if ok then return true,'Free camera off: '..why..'.' end
        return false,'Free camera off on an error: '..tostring(why)
    end
    -- coop off.
    function self.stop()
        if shown then remove('coop off') end
        cam_off('coop off')
    end
    return self
end
return Leviathan
