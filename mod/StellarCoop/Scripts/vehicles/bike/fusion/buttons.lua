-- Saroj's bike button profile on SBO's bike (dev build), ported from Eve Hoverbike's handling.lua (2026-11-19,
-- "Full table swap like EveHoverbike"). While she rides the game's own button table becomes the bike profile: every
-- gameplay action out (attack, dodge, guard, skills, lock-on...), menus, D-pad items, scan, photo mode and jump kept,
-- aim (LT) moved to LB and shoot (RT) to RB. Her own table comes back at the dismount; a journal puts it back at the
-- next start if the game closed while she rode. keys_bike.txt (beside SBO's coop-settings.txt) holds the riding
-- buttons; RT / LT then drive SBO's bike (Buttons.controls), the left stick steers, and without a trigger the stick
-- drives as SBO's bike always did. Stellar Blade's entries carry extra fields (bCustomizeKey, bMainKey, bAZERTY,
-- Priority, SortValue): every one is copied, or a removal does not match the game's entry.
local U=require('core.unreal')
local valid=U.valid
local Buttons={}

-- action names never touched (matched from the start of the name)
local KEEP={'UI_','GameMenu','GameOption','Theater_','Feedback','Debug','TrainingRoom','LoadTest','SaveTest',
    'LoadAfterDead','Photomode','CrossKey_','Scan','Item_Use','Jump'}
local MOVE_TO={Gamepad_LeftShoulder=true,Gamepad_RightShoulder=true}
local KEEP_KEYBOARD={TPSMode=true,TPSFire=true} -- keyboard aim and shoot stay, so they work without a pad

Buttons.DEFAULT=[[
# Buttons while riding Fusion Strider on SBO's bike (Saroj's profile, from Eve Hoverbike)
# Edit, save, then get off and on again. No game restart needed. Delete this file for the defaults.
#
# Line format:   name = button, button, ...   (one or more buttons, comma separated)
# Pad buttons:   Gamepad_FaceButton_Bottom (A / Cross)    Gamepad_FaceButton_Right (B / Circle)
#                Gamepad_FaceButton_Left (X / Square)     Gamepad_FaceButton_Top (Y / Triangle)
#                Gamepad_LeftShoulder (LB / L1)           Gamepad_RightShoulder (RB / R1)
#                Gamepad_LeftTriggerAxis (LT / L2)        Gamepad_RightTriggerAxis (RT / R2)
# Keyboard:      W, A, S, D, SpaceBar, LeftShift, and the other Unreal key names
# The left stick always steers. With no throttle or brake held, the stick drives as SBO's bike does.

# ---- the motorcycle ----
throttle = Gamepad_RightTriggerAxis, W
brake = Gamepad_LeftTriggerAxis, S
steer_left = A
steer_right = D
handbrake = Gamepad_FaceButton_Left, LeftShift

# ---- the game's own actions while riding ----
# These lines move the game's actions from one pad button to another while riding: aim (LT on foot) goes to LB and
# shoot (RT on foot) to RB, because LT and RT brake and accelerate.
move Gamepad_LeftTrigger = Gamepad_LeftShoulder
move Gamepad_RightTrigger = Gamepad_RightShoulder

# Game actions that stay on while riding, on top of menus, D-pad items, scan, photo mode and jump.
keep =

# no = the bike profile is not written into the game's settings file while riding (safer).
game_save_on_get_on = no
]]
local CONTROLS={throttle=true,brake=true,steer_left=true,steer_right=true,handbrake=true}

local function analog(k)
    return k:match('Axis$')~=nil or k:match('^Gamepad_[LR][a-z]+[XY]$')~=nil or k:match('^Mouse[XY]$')~=nil
end
function Buttons.parse(text)
    local bk={ctl={},move={},keep={},save=false,bad={}}
    for raw in (text..'\n'):gmatch('([^\n]*)\n') do
        local line=raw:gsub('#.*$',''):gsub('^%s+',''):gsub('%s+$','')
        if line~='' then
            local from,to=line:match('^move%s+([%w_]+)%s*=%s*([%w_]+)$')
            local name,list=line:match('^([%w_]+)%s*=%s*(.-)$')
            if from then bk.move[from]=to
            elseif name and CONTROLS[name] then
                local keys={}
                for k in list:gmatch('[^,%s]+') do keys[#keys+1]=k end
                bk.ctl[name]=keys
            elseif name=='keep' then for k in list:gmatch('[^,%s]+') do bk.keep[#bk.keep+1]=k end
            elseif name=='game_save_on_get_on' then bk.save=list:lower()=='yes' or list:lower()=='true'
            elseif name then -- Eve Hoverbike's other controls (light, nitro, jump, wheelie): no such part on this bike
            else bk.bad[#bk.bad+1]=line end
        end
    end
    return bk
end
local DEFAULTS=Buttons.parse(Buttons.DEFAULT)

local function flag(v) return v==true or v==1 end
local function num(v) v=U.value_of(v) return type(v)=='number' and v or 0 end
local function b(v) return v and 1 or 0 end
local function map_key(r)
    if r.t=='A' then
        return ('A|%s|%s|%d%d%d%d%d%d%d|%d|%d'):format(r.n,r.k,b(r.s),b(r.c),b(r.a),b(r.m),b(r.cu),b(r.mk),b(r.az),
            r.pr or 0,r.so or 0)
    end
    return ('X|%s|%s|%.3f|%d%d%d'):format(r.n,r.k,r.sc or 0,b(r.cu),b(r.mk),b(r.az))
end
Buttons.map_key=map_key
local function parse_key(line)
    local xn,xk,xs,xf=line:match('^X|([^|]*)|([^|]*)|(-?[%d%.]+)|(%d%d%d)$')
    if xn then
        local function bit(i) return xf:sub(i,i)=='1' end
        return {t='X',n=xn,k=xk,sc=tonumber(xs) or 0,cu=bit(1),mk=bit(2),az=bit(3)}
    end
    local n,k,f,pr,so=line:match('^A|([^|]*)|([^|]*)|(%d+)|(-?%d+)|(-?%d+)$')
    if not n or #f<7 then return nil end
    local function bit(i) return f:sub(i,i)=='1' end
    return {t='A',n=n,k=k,s=bit(1),c=bit(2),a=bit(3),m=bit(4),cu=bit(5),mk=bit(6),az=bit(7),pr=tonumber(pr) or 0,
        so=tonumber(so) or 0}
end
local function map_struct(r)
    return {ActionName=FName(r.n),bShift=r.s,bCtrl=r.c,bAlt=r.a,bCmd=r.m,bCustomizeKey=r.cu or false,
        bMainKey=r.mk or false,bAZERTY=r.az or false,Priority=r.pr or 0,SortValue=r.so or 0,Key={KeyName=FName(r.k)}}
end
local function axis_struct(r)
    return {AxisName=FName(r.n),Scale=r.sc or 0,Key={KeyName=FName(r.k)},bCustomizeKey=r.cu or false,
        bMainKey=r.mk or false,bAZERTY=r.az or false}
end

-- The JSON of the game's settings ("KeyMapping": actionMappings + axisMappings) as two lists.
function Buttons.parse_json(s)
    if type(s)~='string' then return nil end
    local ai=s:find('"actionMappings"%s*:%s*%[')
    local xi=s:find('"axisMappings"%s*:%s*%[')
    if not ai or not xi then return nil end
    local a_part=ai<xi and s:sub(ai,xi-1) or s:sub(ai)
    local x_part=xi<ai and s:sub(xi,ai-1) or s:sub(xi)
    local function fields(obj)
        local t={}
        for k,v in obj:gmatch('"([%w_]+)"%s*:%s*([^,}]+)') do
            v=v:gsub('^%s+',''):gsub('%s+$','')
            t[k]=v:match('^"(.*)"$') or v
        end
        return t
    end
    local function tb(v) return v=='true' end
    local acts,axes={},{}
    for obj in a_part:gmatch('{(.-)}') do
        local t=fields(obj)
        if t.actionName and t.key then
            acts[#acts+1]={t='A',n=t.actionName,k=t.key,s=tb(t.bShift),c=tb(t.bCtrl),a=tb(t.bAlt),m=tb(t.bCmd),
                cu=tb(t.bCustomizeKey),mk=tb(t.bMainKey),az=tb(t.bAZERTY),pr=math.floor(tonumber(t.priority) or 0),
                so=math.floor(tonumber(t.sortValue) or 0)}
        end
    end
    for obj in x_part:gmatch('{(.-)}') do
        local t=fields(obj)
        if t.axisName and t.key then
            axes[#axes+1]={t='X',n=t.axisName,k=t.key,sc=tonumber(t.scale) or 0,cu=tb(t.bCustomizeKey),
                mk=tb(t.bMainKey),az=tb(t.bAZERTY)}
        end
    end
    return acts,axes
end

-- o: log, dir (the folder for keys_bike.txt and the table files, with its trailing separator).
function Buttons.new(o)
    local log,dir=o.log,o.dir or ''
    local self={}
    local IS=nil
    local extra_keep={}
    local gate=nil -- while she rides: {removed, added, acts, axes}
    local bk=DEFAULTS
    local split=nil
    local path={bike=dir..'keys_bike.txt',journal=dir..'keys_restore.txt',backup=dir..'keys_backup.txt',
        map=dir..'keys_input_map.txt'}

    local function settings() IS=IS or StaticFindObject('/Script/Engine.Default__InputSettings') return IS end
    local function kept(name)
        if extra_keep[name] then return true end
        for _,p in ipairs(KEEP) do if name:sub(1,#p)==p then return true end end
        return false
    end
    local function removable(r)
        local pad=r.k:sub(1,8)=='Gamepad_'
        return r.k~='None' and not kept(r.n) and not (KEEP_KEYBOARD[r.n] and not pad)
    end
    local function looks_like_bike(acts)
        local n=0
        for _,r in ipairs(acts) do if r.t=='A' and removable(r) and not MOVE_TO[r.k] then n=n+1 end end
        return n<20
    end
    local function usable(acts,axes)
        return acts~=nil and #acts>=50 and axes~=nil and #axes>=20 and not looks_like_bike(acts)
    end
    local function read_mappings()
        local acts,axes={},{}
        local arr=settings().ActionMappings
        for i=1,arr:GetArrayNum() do
            local m=arr[i]
            local r={t='A',n=m.ActionName:ToString(),k=m.Key.KeyName:ToString(),s=flag(m.bShift),c=flag(m.bCtrl),
                a=flag(m.bAlt),m=flag(m.bCmd)}
            pcall(function()
                r.cu,r.mk,r.az=flag(m.bCustomizeKey),flag(m.bMainKey),flag(m.bAZERTY)
                r.pr,r.so=num(m.Priority),num(m.SortValue)
            end)
            acts[#acts+1]=r
        end
        arr=settings().AxisMappings
        for i=1,arr:GetArrayNum() do
            local m=arr[i]
            local r={t='X',n=m.AxisName:ToString(),k=m.Key.KeyName:ToString(),sc=num(m.Scale)}
            pcall(function() r.cu,r.mk,r.az=flag(m.bCustomizeKey),flag(m.bMainKey),flag(m.bAZERTY) end)
            axes[#axes+1]=r
        end
        return acts,axes
    end
    local function game_json()
        local list=FindAllOf('SBGameOptionSaveData')
        if not list then return nil end
        local found=nil
        for _,obj in ipairs(list) do
            if found then break end
            if valid(obj) then
                pcall(function()
                    obj.DataMap_FString:ForEach(function(k,v)
                        if not found and k:get():ToString()=='KeyMapping' then
                            local text=v:get():ToString()
                            if text:find('actionMappings',1,true) then found=text end
                        end
                    end)
                end)
            end
        end
        return found
    end
    local function write_table(p,header,acts,axes)
        local f=io.open(p,'w')
        if not f then return false end
        f:write('# ',header,'\n')
        for _,r in ipairs(acts) do f:write(map_key(r),'\n') end
        for _,r in ipairs(axes) do f:write(map_key(r),'\n') end
        f:close()
        return true
    end
    local function read_table(p)
        local f=io.open(p,'r')
        if not f then return nil end
        local acts,axes={},{}
        for line in f:lines() do
            local r=parse_key(line)
            if r then if r.t=='A' then acts[#acts+1]=r else axes[#axes+1]=r end end
        end
        f:close()
        return acts,axes
    end
    -- the player's table: game settings first, then the backup file, then the engine's table
    local function player_table()
        local acts,axes,src
        local ok,json=pcall(game_json)
        if ok and json then
            local a,x=Buttons.parse_json(json)
            if usable(a,x) then acts,axes,src=a,x,'game settings' end
        end
        if not acts then
            local a,x=read_table(path.backup)
            if usable(a,x) then acts,axes,src=a,x,'backup file' end
        end
        if not acts then
            local a,x=read_mappings()
            if usable(a,x) then acts,axes,src=a,x,'engine table' end
        end
        if acts and src~='backup file' then
            write_table(path.backup,"the player's own button table, "..os.date('%Y-%m-%d %H:%M:%S')..' (from '..src..')',
                acts,axes)
        end
        return acts,axes,src
    end
    -- the engine's table made to hold exactly these entries (only what differs is touched)
    local function sync(acts,axes)
        local want,want_x={},{}
        for _,r in ipairs(acts) do want[map_key(r)]=true end
        for _,r in ipairs(axes) do want_x[map_key(r)]=true end
        local ca,cx=read_mappings()
        local removed,added=0,0
        for _,r in ipairs(ca) do
            if not want[map_key(r)] then settings():RemoveActionMapping(map_struct(r),false) removed=removed+1 end
        end
        for _,r in ipairs(cx) do
            if not want_x[map_key(r)] then settings():RemoveAxisMapping(axis_struct(r),false) removed=removed+1 end
        end
        if removed>0 then ca,cx=read_mappings() end -- a removal can take out entries that look the same
        local have={}
        for _,r in ipairs(ca) do have[map_key(r)]=true end
        for _,r in ipairs(cx) do have[map_key(r)]=true end
        for _,r in ipairs(acts) do
            local k=map_key(r)
            if not have[k] then have[k]=true settings():AddActionMapping(map_struct(r),false) added=added+1 end
        end
        for _,r in ipairs(axes) do
            local k=map_key(r)
            if not have[k] then have[k]=true settings():AddAxisMapping(axis_struct(r),false) added=added+1 end
        end
        return removed,added
    end
    -- Stellar Blade keeps its own copy of the table; its developer command rebuilds it (and saves it in its settings)
    local function sb_rebuild(pc)
        local ok=pcall(function()
            local cm=valid(pc.CheatManager)
            if not cm then pc:EnableCheats() cm=valid(pc.CheatManager) end
            cm:SBInputKeyMappingForceRebuild()
        end)
        return ok
    end
    local function load_keys()
        local f=io.open(path.bike,'r')
        if not f then
            local w=io.open(path.bike,'w')
            if w then w:write(Buttons.DEFAULT) w:close() end
            return DEFAULTS
        end
        local parsed=Buttons.parse(f:read('a') or '')
        f:close()
        for name in pairs(CONTROLS) do parsed.ctl[name]=parsed.ctl[name] or DEFAULTS.ctl[name] end
        if #parsed.bad>0 then log('keys_bike.txt: lines not understood: '..table.concat(parsed.bad,' | ')) end
        return parsed
    end

    -- At the mount: the bike profile on. Returns the log line.
    function self.on(pc)
        if gate then return 'buttons: the bike profile is on already' end
        bk=load_keys()
        split=nil
        extra_keep={}
        for _,n in ipairs(bk.keep) do extra_keep[n]=true end
        local acts,axes,src=player_table()
        if not acts then return 'buttons: no usable button table found, controls left as they are' end
        local removed,added,seen,bike={},{},{},{}
        for _,r in ipairs(acts) do
            if removable(r) then
                if not seen[map_key(r)] then seen[map_key(r)]=true removed[#removed+1]=r end
                local to=bk.move[r.k]
                if to then
                    local n={}
                    for k2,v2 in pairs(r) do n[k2]=v2 end
                    n.k=to
                    if not seen['+'..map_key(n)] then seen['+'..map_key(n)]=true added[#added+1]=n end
                end
            else
                bike[#bike+1]=r
            end
        end
        if #removed==0 then return 'buttons: no gameplay actions found in the button table' end
        for _,r in ipairs(added) do bike[#bike+1]=r end
        -- journal first: a crash or a quit while she rides is repaired at the next start
        write_table(path.journal,'button table to put back (the game was closed while riding)',acts,axes)
        gate={removed=removed,added=added,acts=acts,axes=axes}
        local nr,na=sync(bike,axes)
        settings():ForceRebuildKeymaps()
        local saved=bk.save and sb_rebuild(pc)
        return ('buttons: bike profile on: %d on-foot entries off, %d moved to LB/RB (table from %s, %d out %d in%s)')
            :format(#removed,#added,tostring(src),nr,na,saved and ', game save' or '')
    end
    -- At the dismount: her own table back. Returns the log line, or nil when the profile was not on.
    function self.off(pc)
        local g=gate
        if not g then return nil end
        gate=nil
        local ok,err=pcall(function()
            sync(g.acts,g.axes)
            settings():ForceRebuildKeymaps()
        end)
        if pc then sb_rebuild(pc) end
        if ok then os.remove(path.journal) end
        return 'buttons: on-foot buttons back'..(ok and '' or ' (failed, journal kept: '..tostring(err)..')')
    end
    function self.active() return gate~=nil end
    -- At the first tick of a Lua load: a journal left by a game closed while she rode puts her table back.
    function self.repair(pc)
        local acts,axes=read_table(path.journal)
        if not acts then return nil end
        if not usable(acts,axes) then
            os.remove(path.journal)
            return 'buttons: journal unusable, dropped'
        end
        local ok,err=pcall(function()
            sync(acts,axes)
            settings():ForceRebuildKeymaps()
            if pc then sb_rebuild(pc) end
        end)
        if ok then os.remove(path.journal) end
        return ok and 'buttons: button table repaired after an unclean exit' or 'buttons: repair failed: '..tostring(err)
    end

    -- Each frame while she rides, for SBO's drive: the world stick from the bike's buttons, or nil when no throttle
    -- or brake is held (the stick then drives as before). heading: the bike's (degrees); steer from the left stick X
    -- and steer_left / steer_right; drift true while the handbrake is held.
    function self.controls(pc,heading)
        if not gate or not pc then return nil end
        if not split then
            split={}
            for name,keys in pairs(bk.ctl) do
                local a,bt={},{}
                for _,k in ipairs(keys) do if analog(k) then a[#a+1]=k else bt[#bt+1]=k end end
                split[name]={a=a,b=bt}
            end
            split.keys={}
        end
        local function key(name)
            split.keys[name]=split.keys[name] or {KeyName=FName(name)}
            return split.keys[name]
        end
        local function value(name)
            local v=0
            for _,k in ipairs(split[name].a) do
                local ok,x=pcall(function() return pc:GetInputAnalogKeyState(key(k)) end)
                x=ok and tonumber(x) or 0
                if math.abs(x)>=0.12 then v=math.max(v,math.abs(x)) end
            end
            for _,k in ipairs(split[name].b) do
                local ok,x=pcall(function() return pc:IsInputKeyDown(key(k)) end)
                if ok and x==true then v=1 end
            end
            return v
        end
        local thr,brk=value('throttle'),value('brake')
        local drift=value('handbrake')>0
        if thr==0 and brk==0 then return nil,drift end
        local ok,lx=pcall(function() return pc:GetInputAnalogKeyState(key('Gamepad_LeftX')) end)
        lx=ok and tonumber(lx) or 0
        if math.abs(lx)<0.12 then lx=0 end
        local steer=math.max(-1,math.min(1,lx+value('steer_right')-value('steer_left')))
        -- the stick SBO's model reads (vehicles/bike/model.lua controls): ahead of the nose with a turn of up to 45
        -- degrees for the steering is throttle; behind it is brake
        local mag,dir
        if thr>=brk then mag,dir=thr,heading+steer*45 else mag,dir=brk,heading+180-steer*45 end
        local r=math.rad(dir)
        return {x=math.cos(r)*mag,y=math.sin(r)*mag},drift
    end
    return self
end
return Buttons
