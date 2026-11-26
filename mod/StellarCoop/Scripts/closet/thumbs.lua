-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies fight/gunmode/g0.lua's capture and export (a spawned SceneCapture2D, an RTF_RGBA8 render target,
-- CaptureScene, then ExportRenderTarget to a PNG, the folder made with mkdir when the export did not make it).
-- coop closet thumbs [redo] [<fit>]: a 256x256 picture of every piece of every installed outfit with a fit map
-- (closet/fits.lua), made once in game and kept in <mod folder>\closet-thumbs\<fit>\<slot>.png, the whole outfit as
-- full.png (the menu's tiles show them: closet/ui/menu.lua). <fit> is the fit id, or for an id with characters a
-- folder name may not hold, those turned into _ and 8 hex digits of its hash. <fit>\stamp.txt names the fit's mesh and
-- pieces: a fit whose stamp changed (its pack's mesh, its fit map) is captured again; redo captures all. The pictures
-- show creators' assets: they stay on the player's PC and are never shipped.
-- The rig, spawned at the first tick of a run, 50 m above EVE (a capture that only its owner sees is not proven in
-- this game): a SceneCapture2D with a 256x256 RTF_RGBA8 target, LDR final colour and a show-only list holding one
-- added SkeletalMeshComponent (manual attachment: placed where EVE's body is, 50 m up, turned as hers, so its front is
-- hers), no collision, full mips. One step a frame on the game thread (the closet tick, under main/frame.lua's guard):
-- per outfit its mesh (closet/dress.lua's resolve and skeleton guard), LOD 0 forced and its textures streamed, WAIT s;
-- per picture its sections shown on every LOD (every other section hidden), then in the next frame the capture framed
-- on its region's two bones (REGIONS), CaptureScene and ExportRenderTarget. A file still missing after the export gets
-- its folder made and one more export; then it counts as failed. A fit's stamp is written once all its files are there.
-- It logs a line a fit and the count. It waits (looked at once a second) while the closet menu is open, the game is
-- paused or shows a screen, EVE is not in the world, in a cutscene or in combat; a run refuses to start then, or while
-- one runs. The rig goes, its target released, at the end, at coop off (stop) and with its world (a map change). Its
-- path is kept in coop-closet-thumbs.txt (link.store): the next Lua load's first tick removes a rig a reload left.
-- o: {log=, folder=M.folder, installed=function(fit id) (dress.installed), store=link.store(Thumbs.FILE),
-- world=function() M.hud_shown, paused=function() the game paused or showing a screen, menu_open=function(),
-- status=function() the link's status text or nil}; tests give fits=, fs=, her=, find=, usable=, clock=.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   ASceneCapture2D (class registered by FUN_140ddbe00) .CaptureComponent2D: object at 0x2d8 (params 0x14664d258).
--   USceneCaptureComponent: PrimitiveRenderMode byte at 0x260 (params 0x14664d598), ESceneCapturePrimitiveRenderMode
--     PRM_UseShowOnlyList 2 (enumerators 0x14664d218); CaptureSource byte at 0x261 (params 0x14664d6e0),
--     ESceneCaptureSource SCS_FinalColorLDR 2 (enumerators 0x146549040); bCaptureEveryFrame and bCaptureOnMovement
--     bools (params 0x14664d710, 0x14664d670); ShowOnlyComponent(InComponent): native entry 0x14664d4d0, exec
--     0x144909500.
--   USceneCaptureComponent2D: FOVAngle float at 0x324 (params 0x14664ca50), TextureTarget object at 0x330 (params
--     0x14664cb30); CaptureScene(): native entry 0x14664c468, exec 0x144909e00.
--   UKismetRenderingLibrary (native table 0x1465a30c0): CreateRenderTarget2D(WorldContextObject, Width, Height,
--     Format, ClearColor, bAutoGenerateMips): entry 0x1465a3100, exec 0x1447feae0; ETextureRenderTargetFormat
--     RTF_RGBA8 2 (enumerators 0x14668bd10). ExportRenderTarget(WorldContextObject, TextureRenderTarget, FilePath,
--     FileName): entry 0x1465a3150, exec 0x1447fd710, impl FUN_1442b04f0, which joins the path and the name, opens
--     the file with the file manager's writer ("FileWrite failed to create." when it cannot) and writes PNG for every
--     format but RTF_RGBA16f (6: HDR or EXR). ReleaseRenderTarget2D(TextureRenderTarget): entry 0x1465a31e0, exec
--     0x1447fe010.
--   USkinnedMeshComponent.SetForcedLOD(int): entry 0x14665f160, exec 0x14492ac00 (0 automatic, else LOD n-1, clamped
--     to the LOD count). UMeshComponent.PrestreamTextures(Seconds, bPrioritizeCharacterTextures, CookieMask): entry
--     0x1465e6cb0, exec 0x1448891f0. UPrimitiveComponent.bForceMipStreaming bool (params 0x146626d20).
--   AActor.AddComponentByClass: entry 0x1464cb818, exec 0x1446be900; K2_SetActorLocationAndRotation: entry 0x1464cbcf8,
--     exec 0x1446bf7a0; K2_DestroyActor: entry 0x1464cbc48, exec 0x1446bf590.
--   USceneComponent K2_GetComponentLocation, K2_GetComponentRotation, GetSocketLocation: native entries 0x14664bb30,
--     0x14664bb40, 0x14664b9f0. UPrimitiveComponent.GetNumMaterials: entry 0x14662af80.
local U=require('core.unreal')
local Player=require('core.player')
local Fits=require('closet.fits')
local Dress=require('closet.dress')
local Camera=require('closet.ui.camera')
local Thumbs={}
Thumbs.DIR='closet-thumbs'
Thumbs.FULL='full' -- The whole outfit's picture: full.png.
Thumbs.FILE='coop-closet-thumbs.txt'
Thumbs.SIZE=256 -- px: the hair salon grid slot's icon size (its Image_Icon brush, widget JSON).
Thumbs.UP=5000 -- cm above EVE.
Thumbs.WAIT=1 -- s after an outfit's mesh goes on, for its textures to stream in.
Thumbs.CHECK=1 -- s between two looks at the waits during a run.
Thumbs.NEAR=3000 -- cm: the closet menu's combat distance.
Thumbs.FOV=30 -- degrees.
Thumbs.VIEW={25,5} -- degrees: the capture turned right of her front, then raised above it.
Thumbs.MARGIN=1.2 -- The framed span over the bones' span.
-- Each region's two bones on the rig mesh (EVE's skeleton names, online/partner/puppet.lua's COLLISION_BONES), the
-- least span framed (cm) and how far the middle is raised (cm). Starting values, to tune in game: the rig mesh stands
-- in its reference pose, arms out.
Thumbs.REGIONS={head={'Bip001-Head','Bip001-Neck',min=40,lift=10},torso={'Bip001-Neck','Bip001-Pelvis',min=60},
    arms={'Bip001-L-Hand','Bip001-R-Hand',min=60},hands={'Bip001-L-Hand','Bip001-R-Hand',min=40},
    hips={'Bip001-L-Thigh','Bip001-R-Thigh',min=45},legs={'Bip001-Pelvis','Bip001-L-Foot',min=90},
    feet={'Bip001-L-Foot','Bip001-R-Foot',min=35},full={'Bip001-Head','Bip001-L-Foot',min=170,lift=5}}
local CAPTURE,SKINNED='/Script/Engine.SceneCapture2D','/Script/Engine.SkeletalMeshComponent'
local RENDER='/Script/Engine.Default__KismetRenderingLibrary'
local RGBA8,FINAL_LDR,SHOW_ONLY=2,2,2 -- RTF_RGBA8, SCS_FinalColorLDR, PRM_UseShowOnlyList.
-- The refusals' words.
local WHY={menu='close the closet menu first',screen='not while the game is paused or shows a screen',
    loading='EVE is not in the world',cutscene='not during a cutscene',combat='not in combat'}

-- The files: present, the first line, written, a folder made.
Thumbs.fs={
    exists=function(p)
        local f=io.open(p,'rb')
        if f then f:close() end
        return f~=nil
    end,
    read=function(p)
        local f=io.open(p,'rb')
        if not f then return nil end
        local line=f:read('l')
        f:close()
        return line
    end,
    write=function(p,s)
        local f=io.open(p,'wb')
        if not f then return false end
        f:write(s,'\n')
        f:close()
        return true
    end,
    mkdir=function(d) os.execute('mkdir "'..d..'" 2>nul') end,
}

-- A fit id's folder name: the id, or with every character outside [A-Za-z0-9_-] turned into _ and 8 hex digits of
-- its FNV-1a hash added.
function Thumbs.key(id)
    if id:match('^[%w_%-]+$') then return id end
    local h=0x811c9dc5
    for i=1,#id do h=((h~id:byte(i))*0x01000193)&0xffffffff end
    return (id:gsub('[^%w_%-]','_'))..('-%08x'):format(h)
end
function Thumbs.folder(root,id) return root..'\\'..Thumbs.DIR..'\\'..Thumbs.key(id) end
function Thumbs.file(root,id,slot) return Thumbs.folder(root,id)..'\\'..slot..'.png' end
-- What a fit's pictures show: v1, its mesh, its skin slots, each piece's slot, materials and off mark.
function Thumbs.stamp(fit)
    local skin,pieces={},{}
    for index in pairs(fit.Skin or {}) do skin[#skin+1]=index end
    table.sort(skin)
    for _,p in ipairs(fit.Pieces) do
        pieces[#pieces+1]=p.Slot..'='..table.concat(p.Materials,',')..(p.Off and '-' or '')
    end
    return 'v1|'..fit.Mesh..'|'..table.concat(skin,',')..'|'..table.concat(pieces,';')
end
-- A fit's pictures: {slot, show={[material index]=true}, region} a piece, then full (the pieces it shows by default
-- and its skin).
function Thumbs.pictures(fit)
    local out,whole={},{}
    for index in pairs(fit.Skin or {}) do whole[index]=true end
    for _,p in ipairs(fit.Pieces) do
        local show={}
        for _,index in ipairs(p.Materials) do
            show[index]=true
            if not p.Off then whole[index]=true end
        end
        out[#out+1]={slot=p.Slot,show=show,region=Camera.region(p.Slot)}
    end
    out[#out+1]={slot=Thumbs.FULL,show=whole,region='full'}
    return out
end
-- The capture's place and turn for the bones at a and b of a region spec {min=, lift=}, the mesh's front turned yaw:
-- the middle seen from VIEW degrees right of the front and above, at the distance whose FOV holds the span with its
-- margin. Also gives that distance.
function Thumbs.frame(a,b,spec,yaw)
    local mid={X=(a.X+b.X)/2,Y=(a.Y+b.Y)/2,Z=(a.Z+b.Z)/2+(spec.lift or 0)}
    local span=math.max(math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2),spec.min or 0)*Thumbs.MARGIN
    local d=span/2/math.tan(math.rad(Thumbs.FOV/2))
    local az,el=math.rad(yaw+Thumbs.VIEW[1]),math.rad(Thumbs.VIEW[2])
    local eye={X=mid.X+d*math.cos(el)*math.cos(az),Y=mid.Y+d*math.cos(el)*math.sin(az),Z=mid.Z+d*math.sin(el)}
    return eye,{Pitch=-Thumbs.VIEW[2],Yaw=math.deg(az)+180,Roll=0},d
end

local function path_of(o) return U.text(o:GetFullName()):match('^%S+ (.+)$') end
-- o while it is still the object met at path (core/actors.lua's same).
local function same(o,path)
    o=U.valid(o)
    return o and path_of(o)==path and o or nil
end

function Thumbs.new(o)
    local log=o.log or function() end
    local fits=o.fits or Fits
    local fs=o.fs or Thumbs.fs
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local find=o.find or U.find
    local usable=o.usable or Dress.usable
    local clock=o.clock or os.clock
    local her=o.her or function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end
    local self={}
    -- run: {jobs={{fit, slot, show, region, file, last=<the fit's stamp on its last picture>}}, i=the next job,
    -- shoot=its sections are shown, rig={actor, path, c, m, rt, world, yaw}, fit=the fit on the mesh, count=its
    -- material slots, wait=no capture before, made, failed, fit_made, fit_failed, check_at, busy, dirs={made folders}}.
    local run
    local swept=false

    -- The key of the first wait (WHY), or nil.
    local function busy()
        if o.menu_open and o.menu_open() then return 'menu' end
        if o.paused and o.paused() then return 'screen' end
        if o.world and not o.world() then return 'loading' end
        local eve=her()
        if not eve then return 'loading' end
        local theater=(o.status and o.status() or ''):match('theater=(%S+)') -- closet/ui/menu.lua's cutscene.
        if theater and theater~='none' and theater~='fault' or eve:IsAttachedToLevelSequenceWithoutPlayable()==true then
            return 'cutscene'
        end
        if eve:IsBattle()==true or Player.engaged(eve,Thumbs.NEAR) then return 'combat' end
        return nil
    end
    -- The rig gone if it is still the one made, its target released, the link file cleared.
    local function remove(rig)
        local a=same(rig.actor,rig.path)
        if a then pcall(function() a:K2_DestroyActor() end) end
        if U.valid(rig.rt) then pcall(function() find(RENDER):ReleaseRenderTarget2D(rig.rt) end) end
        store.clear()
    end
    local function finish(why)
        local r=run
        run=nil
        if r.rig then remove(r.rig) end
        log(string.format('closet thumbs: %s, %d made, %d failed',why or 'done',r.made,r.failed))
    end
    -- An earlier Lua load's rig, by the path its file keeps: removed when it is still a SceneCapture2D.
    local function sweep()
        swept=true
        local p=store.load()
        if not p then return end
        local a=U.valid(StaticFindObject(p))
        if a and a:IsA(find(CAPTURE)) then
            a:K2_DestroyActor()
            log('closet thumbs: an earlier Lua load\'s capture rig removed')
        end
        store.clear()
    end
    -- The rig, 50 m above EVE; its path kept before anything else can fail.
    local function spawn()
        local eve=her()
        local body=U.valid(eve.Mesh)
        local at,turn=U.value_of(body:K2_GetComponentLocation()),U.value_of(body:K2_GetComponentRotation())
        local base={X=at.X,Y=at.Y,Z=at.Z+Thumbs.UP}
        local world=eve:GetWorld()
        local a=U.valid(world:SpawnActor(find(CAPTURE),base,{Pitch=0,Yaw=0,Roll=0}))
        if not a then error('no SceneCapture2D could be spawned',0) end
        local rig={actor=a,path=path_of(a),world=world,yaw=U.value_of(eve:K2_GetActorRotation()).Yaw}
        run.rig=rig
        store.save(rig.path)
        local c=a.CaptureComponent2D
        rig.rt=find(RENDER):CreateRenderTarget2D(world,Thumbs.SIZE,Thumbs.SIZE,RGBA8,{R=0,G=0,B=0,A=1},false)
        c.TextureTarget=rig.rt
        c.bCaptureEveryFrame=false
        c.bCaptureOnMovement=false
        c.CaptureSource=FINAL_LDR
        c.PrimitiveRenderMode=SHOW_ONLY
        c.FOVAngle=Thumbs.FOV
        local m=U.valid(a:AddComponentByClass(find(SKINNED),true,
            {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}},false))
        if not m then error('no mesh could be added to the rig',0) end
        m:SetCollisionEnabled(0)
        m.bForceMipStreaming=true
        m:K2_SetWorldLocationAndRotation(base,turn,false,{},true)
        c:ShowOnlyComponent(m)
        rig.c,rig.m=c,m
    end
    -- The fit's mesh on the rig, or its pictures skipped.
    local function load(job)
        local fit=fits.get(job.fit)
        local mesh,why=usable(fit.Mesh)
        if not mesh then
            log('closet thumbs: '..job.fit..' skipped: '..tostring(why))
            while run.jobs[run.i] and run.jobs[run.i].fit==job.fit do run.i,run.failed=run.i+1,run.failed+1 end
            return
        end
        local m=run.rig.m
        m:SetSkeletalMesh(mesh,true)
        m:SetForcedLOD(1) -- LOD 0.
        m:PrestreamTextures(2,true,0)
        run.fit,run.count,run.wait,run.shoot=job.fit,m:GetNumMaterials(),clock()+Thumbs.WAIT,false
        run.fit_made,run.fit_failed=0,0
    end
    -- The picture framed, captured and exported; the next job once its file is there or it failed again.
    local function shoot(job)
        local rig=run.rig
        local spec=Thumbs.REGIONS[job.region] or Thumbs.REGIONS.full
        local eye,rot=Thumbs.frame(U.value_of(rig.m:GetSocketLocation(FName(spec[1]))),
            U.value_of(rig.m:GetSocketLocation(FName(spec[2]))),spec,rig.yaw)
        rig.actor:K2_SetActorLocationAndRotation(eye,rot,false,{},false)
        rig.c:CaptureScene()
        local dir=Thumbs.folder(o.folder,job.fit)
        find(RENDER):ExportRenderTarget(rig.world,rig.rt,dir,job.slot..'.png')
        if fs.exists(job.file) then run.made,run.fit_made=run.made+1,run.fit_made+1
        elseif not run.dirs[dir] then -- The export made no folder: made once, the picture exported again.
            run.dirs[dir]=true
            fs.mkdir(dir)
            return
        else
            run.failed,run.fit_failed=run.failed+1,run.fit_failed+1
            log('closet thumbs: '..job.file..' not written')
        end
        run.i,run.shoot=run.i+1,false
        if job.last then
            if run.fit_failed==0 then fs.write(dir..'\\stamp.txt',job.last) end
            log(string.format('closet thumbs: %s %d/%d',job.fit,run.fit_made,run.fit_made+run.fit_failed))
        end
    end
    local function step()
        local job=run.jobs[run.i]
        if not job then return finish() end
        if not run.rig then return spawn() end
        if run.fit~=job.fit then return load(job) end
        if clock()<run.wait then return end
        if not run.shoot then -- Its sections on every LOD, the others hidden; the capture in the next frame.
            Dress.show_only(run.rig.m,run.count,job.show)
            run.shoot=true
            return
        end
        shoot(job)
    end

    -- coop closet thumbs: the pictures to make queued, the run started; or why not.
    function self.run(redo,only)
        if run then return false,'closet thumbs: already running' end
        if only and not fits.get(only) then return false,'closet thumbs: no fit map for '..tostring(only) end
        if only and not o.installed(only) then return false,'closet thumbs: '..only..' is not installed' end
        if not o.folder then return false,'closet thumbs: the mod folder is not known' end
        local why=busy()
        if why then return false,'closet thumbs: '..WHY[why] end
        local ids={}
        for id in pairs(fits.BY_ID) do if (not only or id==only) and o.installed(id) then ids[#ids+1]=id end end
        table.sort(ids)
        local jobs,outfits,cached={},0,0
        for _,id in ipairs(ids) do
            local fit=fits.get(id)
            local stamp=Thumbs.stamp(fit)
            local kept=not redo and fs.read(Thumbs.folder(o.folder,id)..'\\stamp.txt')==stamp
            local first=#jobs+1
            for _,p in ipairs(Thumbs.pictures(fit)) do
                p.fit,p.file=id,Thumbs.file(o.folder,id,p.slot)
                if kept and fs.exists(p.file) then cached=cached+1 else jobs[#jobs+1]=p end
            end
            if #jobs>=first then jobs[#jobs].last,outfits=stamp,outfits+1 end
        end
        if #jobs==0 then
            return true,'closet thumbs: every picture is there ('..cached..'); coop closet thumbs redo makes them again'
        end
        run={jobs=jobs,i=1,shoot=false,made=0,failed=0,check_at=0,dirs={}}
        local line=string.format('closet thumbs: %d picture(s) of %d outfit(s) to make, one a frame, %d cached',#jobs,
            outfits,cached)
        log(line)
        return true,line..' (UE4SS.log follows)'
    end
    -- Each frame on the game thread: an earlier load's rig swept once; while running, one step unless it waits.
    function self.tick()
        if not swept then
            local ran,why=pcall(sweep)
            if not ran then log('closet thumbs: the sweep failed: '..tostring(why)) end
        end
        if not run then return end
        local rig=run.rig
        if rig and not same(rig.actor,rig.path) then return finish('stopped, the map changed') end
        -- A raise ends the run with its rig removed: main/frame.lua's guard logs a function's first raise only.
        local ran,why=pcall(function()
            local t=clock()
            if t>=run.check_at then run.check_at,run.busy=t+Thumbs.CHECK,busy() end
            if not run.busy then step() end
        end)
        if not ran then finish('stopped: '..tostring(why)) end
    end
    -- coop off: the run ends, its rig removed.
    function self.stop() if run then finish('stopped') end end
    function self.running() return run~=nil end
    return self
end

return Thumbs
