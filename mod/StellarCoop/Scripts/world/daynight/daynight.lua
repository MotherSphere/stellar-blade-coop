-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's engine side (tests/lua/world/daynight/daynight_test.lua). main.lua's 250 ms loop calls
-- slow(off): it reads the map when EVE's address changes (a new world), decides the native part's request with
-- world/daynight/rule.lua and sends it only when it changes. One log line per change of the request or its reason. coop
-- off asks sky off once, then nothing. The hour and the sun come from the native part's sky= status line
-- (world/daynight/sky.h); coop daynight status reads it. o: log, ask(line) -> ok and why, status() -> the native status
-- text, settings (daynight), her() -> EVE or nil, address(eve), map_of(eve), photo() -> '0', '1' or 's', frozen() (our
-- pause tag held for another player's photo mode or the host's cutscene), night() (Night Operation runs), lobby()
-- (EVE stands in the SBO lobby in Xion's training room), find(path) -> object or nil, actors_of(class path) -> list,
-- load(path), exists(path), cps (the third-party plugin's file), level(package) -> the streaming level of a sublevel in
-- EVE's world or nil, stars_ready() -> the star material can be had without a load on the game thread (the keep's).
-- The sky dressing, from the status line's sun while the native part's light is ours: the painted domes of a real-sky
-- map hidden; SBO's star layer (a StaticMeshComponent tagged SBO_Stars on the first dome's actor, the dome's
-- mesh with SB's star material, found again by its tag after a Lua reload) shown at night; each SkyCreator's own time
-- turned with our sun; Xion's night dome in place of its day dome at night. Each part is looked up once per world (a
-- new EVE address), a dome of a streamed sublevel each time that sublevel comes (its IsLevelVisible read every 2 s
-- while live), each write made only when its value changes. A dome SB shows again while live (a talk or cutscene may)
-- is read every 2 s and hidden again (recheck). SB's look comes back at an off, coop off included,
-- except Xion's domes during its story night, which SB owns. SBO's own maps (the hall lobbies, Matrix XIII) have no SB
-- env settings: there the Sun actor turns with the status line's light, its intensity and colour follow it, the
-- SkyLight follows the sky light factor and Matrix XIII's zone 0 exposure volume goes 2 EV down at full night, each
-- from the values its lookup read.
-- Those values and each SkyCreator's own time are the originals of one world (its map and address, read when EVE's
-- address changes): kept for this Lua load, so a new EVE in the same world finds them again; also in coop-sky.txt
-- (o.store, link.store's), so a Lua reload that starts while the native part still holds a cycle reads them there, not
-- the light it dimmed. o.world(eve) gives the world's address.
local Rule=require('world.daynight.rule')
local U=require('core.unreal')
local Daynight={}
local FLAG_EVERY=8 -- Xion's story-night flag read every 8 passes of 250 ms: every 2 s.
local LOOK_EVERY=8 -- Every 8 live passes (2 s): the sublevels of the domes and SkyCreators, the domes it hid, read.
-- Looks a dome SB keeps shown is left to it before one more try (30 s): a sequence that keys its visibility sets it
-- again each frame it evaluates.
local LEAVE_LOOKS=15
local TAG='SBO_Stars'
local MESH_COMPONENT='/Script/Engine.StaticMeshComponent'
local MATH='/Script/Engine.Default__KismetMathLibrary'
local LIVE={cycle=true,pinned=true,held=true,forced=true} -- The native states where the sky follows our sun.
local FADES={'Emissive','Bright','Intens','Opacity'} -- A star material scalar holding one of these fades the layer.
local SUN,SKY_LIGHT='/Script/Engine.DirectionalLight','/Script/Engine.SkyLight'
local VOLUME='/Script/Engine.PostProcessVolume'
-- An 8-bit sRGB channel (FColor's) as linear light, as FLinearColor(FColor) reads it.
local function linear(c)
    c=c/255
    return c<=0.04045 and c/12.92 or ((c+0.055)/1.055)^2.4
end

function Daynight.new(o)
    local self={}
    local test,pinned=nil,nil -- coop daynight off ('off') and hour (a minute), until on, off or a reload.
    local asked,told=nil,nil -- The last line the native part took; the last log line's text.
    local line,why=nil,nil -- This pass's decision.
    local eve_at,map,where=nil,nil,nil -- EVE's address, her world's map and its key (the map and its address).
    local flag,flag_wait,story=nil,0,false -- Xion's story-night volume this world, passes to its next read, its state.
    local first,stopped=true,false
    local w=nil -- This world's dressing: the parts found at its first live pass, each with the state last written.
    local leftover=nil -- Whether an earlier Lua load may have left its dressing in the world this load starts in.
    local kept=nil -- The originals of one world: {key=where, v={name -> list of numbers}}.
    local unsaved=false -- kept has values coop-sky.txt lacks.
    local store=o.store or {save=function() return true end,load=function() end}

    -- The story-night flag of a row that has one: looked up once per world, read every 2 s. A miss or a read that
    -- raises is logged once and leaves the cycle running in that world.
    local function story_night(row)
        if not row.flag then return false end
        if flag==nil then
            flag=U.valid(o.find(row.flag)) or false
            if not flag then o.log('daynight: no story-night flag in this world, '..row.flag..': the cycle runs') end
        end
        if not flag then return false end
        flag_wait=flag_wait-1
        if flag_wait<0 then
            flag_wait=FLAG_EVERY-1
            local ok,on=pcall(function() return assert(U.valid(flag),'it is gone').bActiveVolume end)
            if ok then story=on==true
            else
                o.log('daynight: the story-night flag is unreadable in this world: '..U.why(on))
                flag,story=false,false
            end
        end
        return story
    end

    -- A write to a part in a pcall, on a part still valid: a failure is logged once and the part left alone in this
    -- world.
    local function try(part,what,f)
        if part.dead then return end
        local ok,e=pcall(function() assert(U.valid(part.c),'it is gone'); f(part.c) end)
        if not ok then
            part.dead=true
            o.log('daynight: '..part.what..', '..what..': '..U.why(e)..'; left alone in this world')
        end
    end
    -- A dome shown or hidden: through its mesh, never its children (the star layer is one), or through its actor when
    -- SB ships it hidden there (Xion's night dome: its actor's bHidden set, its mesh visible).
    local function show(part,on)
        if part and part.on~=on then
            part.on=on
            try(part,'visibility',function(c)
                if part.actor_level then part.actor:SetActorHiddenInGame(not on) else c:SetVisibility(on,false) end
            end)
        end
    end
    local function set_time(c,t) try(c,'SetTime',function(a) a:SetTime(t) end) end
    -- A part's value written through write(c, v) only when it differs from the value last written (the original first).
    local function put(part,key,v,write)
        if part and part[key]~=v then
            part[key]=v
            try(part,key,function(c) write(c,v) end)
        end
    end
    -- The Sun turned to pitch p and yaw y when either moved 0.01 degree or more.
    local function turn(part,p,y)
        if math.abs(p-part.p)<0.01 and math.abs(y-part.y)<0.01 then return end
        part.p,part.y=p,y
        try(part,'rotation',function() part.actor:K2_SetActorRotation({Pitch=p,Yaw=y,Roll=0},false) end)
    end
    -- The Sun's colour: the one it had times the tint t.
    local function color(part,t)
        local r,g,b=part.color[1]*t[1],part.color[2]*t[2],part.color[3]*t[3]
        put(part,'tint',string.format('%.4f %.4f %.4f',r,g,b),function(c) c:SetLightColor({R=r,G=g,B=b,A=1},true) end)
    end
    -- The actor of class cls named name in this world: by its name, else the only one of its class unless exact. One
    -- log line when there is none.
    local function named(cls,name,exact)
        local ok,list=pcall(o.actors_of,cls)
        local actors=ok and list or {}
        for _,a in ipairs(actors) do if U.text(a:GetFName())==name then return a end end
        if not exact and #actors==1 then return actors[1] end
        o.log('daynight: no '..name..' in this world'..(ok and '' or ': '..U.why(list)))
    end
    -- The originals named name in this world: the ones kept (as many numbers as now), else now (the values read now),
    -- kept from then on.
    local function original(name,now)
        if not kept.v[name] or #kept.v[name]~=#now then kept.v[name],unsaved=now,true end
        return kept.v[name]
    end
    -- A light actor's part: its light component with its original intensity, colour and rotation, the values it holds
    -- now as the last written, or nil with one log line.
    local function light(a,name)
        if not a then return nil end
        local ok,part=pcall(function()
            local c=assert(U.valid(a.LightComponent),'no light component')
            local rgb,rot=c.LightColor,a:K2_GetActorRotation()
            local now={c.Intensity,linear(rgb.R),linear(rgb.G),linear(rgb.B),rot.Pitch,rot.Yaw}
            local v=original(name,now)
            return {c=c,actor=a,what=name,original=v[1],intensity=now[1],color={v[2],v[3],v[4]},
                tint=string.format('%.4f %.4f %.4f',now[2],now[3],now[4]),rot={v[5],v[6]},p=now[5],y=now[6]}
        end)
        if ok then return part end
        o.log('daynight: '..name..' is unreadable: '..U.why(part))
    end
    -- A dome: its actor and root component (the mesh it shows), shown through its actor when actor_level, or nil with
    -- one log line.
    local function dome(path,actor_level)
        local actor=U.valid(o.find(path))
        local root=actor and U.valid(actor.RootComponent)
        if not root then o.log('daynight: no dome '..path..' in this world') return nil end
        return {c=root,actor=actor,what=path:match('[^.:]+$'),actor_level=actor_level}
    end
    local mesh_class=nil -- StaticMeshComponent's class, found once a Lua load.
    local function class()
        mesh_class=U.valid(mesh_class) or assert(U.valid(o.find(MESH_COMPONENT)),MESH_COMPONENT..' is missing')
        return mesh_class
    end
    -- The star layer an earlier Lua load put on actor: its component tagged SBO_Stars, or nil.
    local function find_layer(actor)
        local found=nil
        U.each(actor:K2_GetComponentsByClass(class()),function(_,c)
            c=U.valid(c)
            if not found and c and c:ComponentHasTag(FName(TAG))==true then found=c end
        end)
        return found and {c=found,what='the star layer'}
    end
    -- A number as coop-sky.txt keeps it, with a decimal point whatever the locale.
    local function number(v) return (string.format('%.9g',v):gsub(',','.')) end
    -- coop-sky.txt's line: the world's key, then name=v,v,... for each originals, tab-separated, names sorted.
    local function save_kept()
        local names,fields={},{kept.key}
        for name in pairs(kept.v) do names[#names+1]=name end
        table.sort(names)
        for _,name in ipairs(names) do
            local v={}
            for i,x in ipairs(kept.v[name]) do v[i]=number(x) end
            fields[#fields+1]=name..'='..table.concat(v,',')
        end
        local ran,saved,e=pcall(store.save,table.concat(fields,'\t'))
        unsaved=not (ran and saved)
        if unsaved then
            o.log('daynight: coop-sky.txt not written ('..U.why(ran and e or saved)..'): a Lua reload in this world '
                ..'reads its lights as they are then')
        end
    end
    -- coop-sky.txt's originals, or nil when it has none or cannot be read.
    local function load_kept()
        local ran,text=pcall(store.load)
        if not ran or type(text)~='string' then return nil end
        local t=nil
        for field in (text..'\t'):gmatch('([^\t]*)\t') do
            if not t then t={key=field,v={}}
            else
                local name,list=field:match('^([%w_]+)=(.*)$')
                if name then
                    local v={}
                    for x in list:gmatch('[^,]+') do v[#v+1]=tonumber(x) end
                    t.v[name]=v
                end
            end
        end
        return t
    end
    -- This world's SkyCreators with their own day and time, those listed before kept as they are. Read through the
    -- class hash: at world entry, then when a sublevel came or went.
    local function list_creators()
        local listed,list=pcall(o.actors_of,Rule.CREATOR)
        if not listed then return o.log('daynight: no SkyCreator list: '..U.why(list)) end
        local had,now={},{}
        for _,c in ipairs(w.creators) do had[c.at]=c end
        for _,a in ipairs(list) do
            local ok,c=pcall(function()
                local at=o.address(a)
                if had[at] and U.valid(had[at].c) then return had[at] end
                local t=a:GetTime()
                local time=original('c'..at,{t})[1]
                -- h: the hour last given; -1 when it holds an earlier load's time, which an off puts back.
                return {c=a,at=at,what='SkyCreator',rise=a.SunriseTime,set=a.SunsetTime,original=time,
                    h=t~=time and -1 or nil}
            end)
            if ok then now[#now+1]=c else o.log('daynight: a SkyCreator is unreadable: '..U.why(c)) end
        end
        w.creators=now
    end
    -- Whether slot s's sublevel shows (its streaming level's IsLevelVisible). A level no longer valid is never read
    -- (pcall does not catch an access violation inside ProcessEvent). It and a read that raises are logged, the level
    -- dropped and the sublevel taken as shown: its dome gets one lookup, as with no level.
    local function visible(s)
        local ok,on=pcall(function() return assert(U.valid(s.level),'it is gone'):IsLevelVisible()==true end)
        if ok then return on end
        o.log('daynight: the sublevel of '..(s.path or s.package)..' is unreadable: '..U.why(on)..'; looked up once')
        s.level=nil
        return true
    end
    -- A slot for a dome path (role dome, day or night) or a sublevel alone (role level, a SkyCreator's): its streaming
    -- level, through SB's GameplayStatics GetStreamingLevel (none for a level that is not streamed). A dome is looked
    -- up now unless its sublevel does not show yet: then it waits for it, with no lookup that would miss (25 to 35 ms).
    local function slot(path,role,package)
        local s={path=path,role=role,package=package or path:match('^[^.]+')}
        local ok,level=pcall(function() return o.level and U.valid(o.level(s.package)) or nil end)
        s.level=ok and level or nil
        if s.level then s.shown=visible(s) end
        if path and s.shown~=false then s.part=dome(path,role=='night') end
        return s
    end
    -- The parts the dressing uses, from the slots: the domes in order, Xion's two.
    local function sync()
        w.domes,w.day,w.night={},nil,nil
        for _,s in ipairs(w.slots) do
            if s.part and s.role=='dome' then w.domes[#w.domes+1]=s.part end
            if s.role=='day' or s.role=='night' then w[s.role]=s.part end
        end
    end
    -- The star layer on the first dome's actor: an earlier load's, found by its tag, or none yet. w.host is that dome's
    -- part, not its actor. UE4SS 4.0.0 compares two objects by address: a dome looked up again after its sublevel came
    -- back may sit at the freed one's address.
    local function host_layer()
        w.layer,w.mid,w.fade,w.host=nil,nil,nil,w.domes[1]
        if w.row.stars~='layer' or not w.host then return end
        local ok,layer=pcall(find_layer,w.host.actor)
        if ok then w.layer=layer else o.log('daynight: the star layer is not looked for: '..U.why(layer)) end
    end
    -- The domes' count for the log: found, wanted and waiting for their sublevel.
    local function count()
        local found,wanted,waiting=0,0,0
        for _,s in ipairs(w.slots) do
            if s.path then
                wanted=wanted+1
                if s.part then found=found+1 elseif s.shown==false then waiting=waiting+1 end
            end
        end
        return string.format('%d of %d domes%s',found,wanted,waiting>0 and ' ('..waiting..' wait for their sublevel)'
            or '')
    end
    -- Every 2 s while live: a slot whose sublevel came is looked up (a hit), one whose sublevel went drops its part,
    -- one whose part died while its sublevel showed (out and in between two looks) is looked up again; then the
    -- SkyCreators are listed again. One log line when something moved.
    local function watch()
        local began,moved=os.clock(),false
        for _,s in ipairs(w.slots) do
            local on=s.level and visible(s)
            if on~=nil and (on~=s.shown or on and s.part and not U.valid(s.part.c)) then
                s.shown,moved=on,true
                s.part=on and s.path and dome(s.path,s.role=='night') or nil
            end
        end
        if not moved then return end
        sync()
        if w.domes[1]~=w.host then host_layer() end
        if w.row.stars=='creator' then list_creators() end
        if unsaved and where then save_kept() end
        o.log(string.format('daynight: a sublevel came or went: %s, %d SkyCreators, %.1f ms',count(),#w.creators,
            (os.clock()-began)*1000))
    end
    -- This world's parts, looked up once: the domes (each when its sublevel shows), Xion's two, the SkyCreators with
    -- their own day and time, an earlier load's star layer. One log line with the time the lookups took. The originals
    -- come from kept when it is this world's (no key: never), else from the values read now, then saved.
    local function enter(row)
        local began=os.clock()
        if not kept or kept.key~=where or not where then kept,unsaved={key=where,v={}},false end
        w={row=row,slots={},creators={},wait=0}
        for _,path in ipairs(row.sky=='real' and row.domes or {}) do w.slots[#w.slots+1]=slot(path,'dome') end
        if row.day_dome then
            w.slots[#w.slots+1]=slot(row.day_dome,'day')
            w.slots[#w.slots+1]=slot(row.night_dome,'night')
        end
        for _,package in ipairs(row.levels or {}) do w.slots[#w.slots+1]=slot(nil,'level',package) end
        for _,s in ipairs(w.slots) do w.watched=w.watched or s.level~=nil end
        sync()
        if row.stars=='creator' then list_creators() end
        host_layer()
        local e=row.engine
        if e then
            w.sun,w.sky=light(named(SUN,e.sun),e.sun),light(named(SKY_LIGHT,e.sky),e.sky)
            local v=e.ppv and named(VOLUME,e.ppv,true)
            local ok,bias=pcall(function() return v.Settings.AutoExposureBias end)
            if v and not ok then o.log('daynight: '..e.ppv..' is unreadable: '..U.why(bias)) end
            w.ppv=v and ok and {c=v,what=e.ppv,original=original(e.ppv,{bias})[1],bias=bias} or nil
        end
        if unsaved and where then save_kept() end
        local lights=e and string.format(', %s %s, %s %s%s',e.sun,w.sun and 'found' or 'missing',e.sky,
            w.sky and 'found' or 'missing',e.ppv and ', '..e.ppv..' '..(w.ppv and 'found' or 'missing') or '') or ''
        o.log(string.format('daynight: %s: %s, %d SkyCreators%s%s, lookups %.1f ms',map,count(),#w.creators,
            w.layer and ", an earlier load's star layer" or '',lights,(os.clock()-began)*1000))
    end
    -- SB's star material, loaded once a world when the layer first shows, with the scalar that fades it (or none).
    local function star_material()
        local began=os.clock()
        -- shortcut: without the keep (o.load then loads), a synchronous LoadAsset once per world entry on star-layer
        -- maps; the keep (core/keep.lua) brings it in through SB's async load.
        local loaded,e=pcall(o.load,Rule.STARS)
        local m=U.valid(o.find(Rule.STARS))
        if not m then
            o.log('daynight: the star material does not load'..(loaded and '' or ' ('..U.why(e)..')')
                ..': no stars in this world')
            return false
        end
        U.each(m.ScalarParameterValues,function(_,p)
            local name=U.text(U.value_of(p.ParameterInfo).Name)
            for _,word in ipairs(FADES) do if not w.scalar and name:find(word,1,true) then w.scalar=name end end
        end)
        o.log(string.format('daynight: star material loaded in %.1f ms, %s',(os.clock()-began)*1000,
            w.scalar and 'faded by '..w.scalar or 'shown from the dark sky on'))
        return m
    end
    -- A new star layer on the first dome's actor: the dome's mesh with the star material, no collision, no shadow,
    -- tagged so a Lua reload finds it. Raises, with nothing left, when it cannot be made.
    local function make_layer()
        local d=w.domes[1]
        local identity=assert(U.valid(o.find(MATH)),MATH..' is missing'):MakeTransform({X=0,Y=0,Z=0},
            {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
        local c=assert(U.valid(d.actor:AddComponentByClass(class(),false,identity,false)),'no component added')
        local ok,e=pcall(function()
            c:SetStaticMesh(d.c.StaticMesh)
            c:SetMaterial(0,w.material)
            c:SetCollisionEnabled(0)
            c:SetCastShadow(false)
        end)
        if not ok then
            pcall(function() c:K2_DestroyComponent(d.actor) end)
            error(e,0)
        end
        -- A new component's ComponentTags is empty: UE4SS 3.0.1 lands a write at 1 there (vehicles/bike/ride.lua's
        -- part).
        local tagged=pcall(function()
            c.ComponentTags[1]=FName(TAG)
            assert(c:ComponentHasTag(FName(TAG))==true)
        end)
        if not tagged then o.log('daynight: the star layer is untagged: a Lua reload adds another') end
        return {c=c,what='the star layer'}
    end
    -- The star layer at the sun's elevation el: with a fading scalar, shown while the fade is above 0 at that value;
    -- without one, shown from the dark sky on (Rule.dress).
    local function stars(row,el)
        local fade=Rule.star_fade(el)
        if fade>0 and w.material==nil and o.stars_ready() then w.material=star_material() end
        local on
        if w.scalar then on=fade>0 else on=Rule.dress(row,el).stars end
        if on and not w.layer and w.material then
            local ok,layer=pcall(make_layer)
            w.layer=ok and layer or {dead=true}
            if not ok then o.log('daynight: no star layer in this world: '..U.why(layer)) end
        end
        if not w.layer then return end
        if on and w.scalar and fade~=w.fade then
            w.fade=fade
            try(w.layer,'fade',function(c)
                w.mid=U.valid(w.mid) or assert(U.valid(c:CreateDynamicMaterialInstance(0,w.material,FName('None'))),
                    'no dynamic material instance')
                w.mid:SetScalarParameterValue(FName(w.scalar),fade)
            end)
        end
        show(w.layer,on)
    end
    -- The domes we hid, read every 2 s while live: one SB showed again (a sequence may) is written hidden in this pass
    -- with one line. One SB shows again at the next look too is left to it until LEAVE_LOOKS looks found it shown, then
    -- tried once more; a look that finds it hidden starts over. A read that raises leaves the part as it is. The star
    -- layer is not among them. The lines are told once per slot: a streamed dome looked up again stays told.
    local function recheck()
        for _,s in ipairs(w.slots) do
            local part=s.part -- The domes and Xion's two; a SkyCreator's sublevel has none.
            if part and not part.dead and part.on==false and U.valid(part.c) then
                local ok,shown=pcall(function()
                    if part.actor_level then return part.actor.bHidden==false end
                    return part.c.bVisible==true
                end)
                if ok and not shown then part.seen=nil
                elseif ok then
                    part.seen=(part.seen or 0)+1
                    if part.seen==1 or part.seen%LEAVE_LOOKS==0 then
                        part.on=nil -- show writes it hidden again in this pass.
                        if not s.told then
                            s.told=true
                            o.log('daynight: SB showed '..part.what..', hidden again')
                        end
                    elseif part.seen==2 and not s.told_kept then
                        s.told_kept=true
                        o.log('daynight: SB keeps '..part.what..' shown; left to it, tried again in 30 s')
                    end
                end
            end
        end
    end
    -- This pass's dressing: live, the sky for the sun at el and the hour h; else SB's look back (Xion's domes kept
    -- during its story night).
    local function dress(row,live,n,story_held)
        if not w then
            if not (live or leftover) then return end
            leftover=false
            enter(row)
        end
        if w.watched and live then -- At once when the sky becomes ours again: a sublevel may have come meanwhile.
            w.wait=w.wait-1
            if w.wait<0 or not w.live then
                w.wait=LOOK_EVERY-1
                watch()
            end
        end
        w.live=live
        if live then
            w.look=(w.look or 0)-1
            if w.look<0 then
                w.look=LOOK_EVERY-1
                recheck()
            end
            for _,d in ipairs(w.domes) do show(d,false) end
            if w.day then
                local night=Rule.dress(row,n.el).night_dome
                show(w.day,not night)
                show(w.night,night)
            end
            for _,c in ipairs(w.creators) do
                if c.h~=n.h then
                    c.h=n.h
                    set_time(c,Rule.creator_time(n.h,c.rise,c.set))
                end
            end
            if row.stars=='layer' and w.domes[1] then stars(row,n.el) end
            if w.sun then
                turn(w.sun,-n.le,n.ly)
                put(w.sun,'intensity',w.sun.original*n.k,function(c,v) c:SetIntensity(v) end)
                color(w.sun,n.tint)
            end
            if w.sky then put(w.sky,'intensity',w.sky.original*n.amb,function(c,v) c:SetIntensity(v) end) end
            if w.ppv then put(w.ppv,'bias',w.ppv.original+2*n.ev,function(c,v) c.Settings.AutoExposureBias=v end) end
            return
        end
        for _,d in ipairs(w.domes) do show(d,true) end
        if not story_held then
            show(w.day,true)
            show(w.night,false)
        else -- SB sets them for its story night: what we wrote no longer holds, so the next live pass writes again.
            if w.day then w.day.on=nil end
            if w.night then w.night.on=nil end
        end
        for _,c in ipairs(w.creators) do
            if c.h~=nil then
                c.h=nil
                set_time(c,c.original)
            end
        end
        show(w.layer,false)
        if w.sun then
            turn(w.sun,w.sun.rot[1],w.sun.rot[2])
            put(w.sun,'intensity',w.sun.original,function(c,v) c:SetIntensity(v) end)
            color(w.sun,{1,1,1})
        end
        if w.sky then put(w.sky,'intensity',w.sky.original,function(c,v) c:SetIntensity(v) end) end
        if w.ppv then put(w.ppv,'bias',w.ppv.original,function(c,v) c.Settings.AutoExposureBias=v end) end
    end

    local function send(want,reason)
        line,why=want,reason
        local ok,said=true,nil
        if want~=asked then
            ok,said=o.ask(want)
            if ok then asked=want end
        end
        local text='daynight: '..want:gsub('^sky ','')..' ('..reason..')'
            ..(ok and '' or ': not asked: '..tostring(said))
        if text~=told then told=text; o.log(text) end
    end

    function self.slow(off)
        if first then
            first=false
            if o.cps and o.exists(o.cps) then
                o.log('daynight: the "Activate Day Night Cycle" plugin is installed (CPS/Plugins/'
                    ..'activate_day_night_cycle.cps). It and SBO write the same light: turn one of them off.')
            end
            local n=Rule.native(o.status())
            leftover=n~=nil and n.state~='off'
            if leftover then kept=load_kept() end -- Its values may be the earlier load's: its originals are there.
        end
        if off then
            if not stopped then
                stopped=true
                if w then dress(w.row,false,nil,story) end
                asked=nil -- Asked once more whatever came before: the native part may have missed it.
                send('sky off','coop off')
            end
            return
        end
        local her=o.her()
        local at=her and o.address(her)
        if at~=eve_at then
            eve_at,map=at,her and o.map_of(her) or nil
            local found,place=pcall(function() return her and o.world(her) end)
            where=map and found and place and map..' '..tostring(place) or nil
            flag,flag_wait,story,w=nil,0,false,nil -- Looked up again: the old world's parts died with it.
        end
        local row=Rule.row(map)
        local s={setting=o.settings~=nil and o.settings.daynight==true,test=test,pinned=pinned,map=map}
        -- The engine reads only where a cycle may run.
        if s.setting and test~='off' and row and row.cycle=='on' then
            s.lobby=o.lobby()
            s.story_night=story_night(row)
            s.photo=o.photo()~='0'
            s.frozen=o.frozen()
            s.night=o.night()
        end
        send(Rule.decide(s))
        if row and row.cycle=='on' then
            local n=Rule.native(o.status())
            dress(row,line~='sky off' and n~=nil and LIVE[n.state]==true and n.el~=nil and n.h~=nil,n,
                why=='Xion story night')
        else leftover=false end
    end

    -- coop daynight status: the decision, the map's row, the native part's hour, sun and volumes, the next night.
    function self.status()
        local parts={'daynight: '..(line and line:gsub('^sky ','')..' ('..why..')' or 'no pass yet')}
        local row=Rule.row(map)
        if not map then parts[#parts+1]='no map'
        elseif not row then parts[#parts+1]='map '..map..' is not in the table: its own light'
        elseif row.cycle~='on' then parts[#parts+1]='map '..map..' keeps its fixed light'
        else
            parts[#parts+1]=string.format('map %s: %s sky, horizon %d, noon heading %d',map,row.sky,row.hz,
                row.heading)
        end
        local n=Rule.native(o.status())
        if not n then
            parts[#parts+1]='the native part gives no sky line'
        else
            local h=n.h or 0
            local minute=math.floor(h*60)
            local left=Rule.until_night(h)
            parts[#parts+1]=string.format('native %s at %02d:%02d, sun at %.1f degrees, %d volumes, %d in the sun, %s',
                tostring(n.state),minute//60,minute%60,n.el or 0,n.n or 0,n.lit or 0,
                left>0 and 'night in '..left..' min' or 'night now')
        end
        return table.concat(parts,'; ')
    end

    -- coop daynight on (the clock again, a pinned hour cleared), off (SB's light) or hour <h> (pinned): until another
    -- word or a Lua reload, never saved. ok and the line to show.
    function self.command(word,arg)
        local setting=o.settings~=nil and o.settings.daynight==true
        if word=='on' then
            test,pinned=nil,nil
            if not setting then return true,"daynight: daynight=off in coop-settings.txt still keeps SB's light" end
            return true,'daynight: on, the sky follows the clock'
        elseif word=='off' then
            test,pinned='off',nil
            return true,"daynight: off until coop daynight on or a Lua reload: Stellar Blade's own light"
        elseif word=='hour' then
            if not setting then return false,'coop daynight hour: refused while daynight=off in coop-settings.txt' end
            local m,refused=Rule.minute(arg)
            if not m then return false,'coop daynight '..refused end
            test,pinned=nil,m
            return true,string.format('daynight: the hour stays at %02d:%02d until coop daynight on, off or a Lua '
                ..'reload',m//60,m%60)
        end
        return false,'daynight: on, off or hour <h>'
    end
    return self
end
return Daynight
