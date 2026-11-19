-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The keep (game/keep.h): the assets SBO uses where the player sees them (a talk, an arrival, a screen), loaded off
-- the frame by SB's own async loader and held for the game run by the native part's handles, so the collector never
-- frees them and nothing loads them on the game thread. Modules want their paths when they are made. slow(), once a
-- 250 ms pass right after link.changes(), writes the whole list to coop-keep.txt when it grew (one file: link's
-- request queue keeps 8), reads the status field keep=<asked> <settled> <in> once, then looks one kept path up a pass
-- through the soft path (find: core/unreal.lua's object_at, a name-hash find, never a load or a walk) and holds it.
-- ready(), serves() and get() read no file. Off for the Lua load (wanted() false, ready() true: every module loads as
-- before) without setup(), on keep=fault, on an engine line that says off (coop off too: the native part keeps nothing
-- after it), or after STALL passes with no progress. Never calls LoadAsset or StaticFindObject.
-- tests/lua/core/keep_test.lua covers it.
local U=require('core.unreal')
local Keep={MAX=128,LONGEST=192,STALL=40} -- game/keep.h's kMaxPaths and kMaxPath; 40 passes are 10 s.
-- state: 'wait' until every path asked is settled, 'ready', or 'off' for the Lua load. stall: passes with no progress
-- while waiting; last: the settled count it last saw.
local o,order,asked,held,missing,told,dirty,state,stall,last
function Keep.reset()
    o,order,asked,held,missing,told,dirty,state,stall,last=nil,{},{},{},{},{},false,'wait',0,-1
end
Keep.reset()
local function log(line) if o then o.log(line) else print('[StellarCoop] '..line..'\n') end end
-- An object path the native part takes: <dir>/<name>.<name>, or the class <dir>/<name>.<name>_C, under /Game/ or
-- /Engine/, of letters, digits, '_', '/' and '.' (game/keep.h's path_ok).
function Keep.path_ok(p)
    if type(p)~='string' or #p>Keep.LONGEST or p:find('[^%w_/%.]') then return false end
    if not (p:find('^/Game/') or p:find('^/Engine/')) then return false end
    local name,object=p:match('/([^/%.]+)%.([^/%.]+)$')
    return name~=nil and (object==name or object==name..'_C')
end
-- Keeps each path once, before setup too.
function Keep.want(paths)
    for _,p in ipairs(paths) do
        if asked[p] or told[p] then -- Kept already, or refused and said.
        elseif not Keep.path_ok(p) then
            told[p]=true
            log('keep: '..tostring(p)..' is no object path; not kept')
        elseif #order>=Keep.MAX then
            if not told.full then told.full=true; log('keep: '..Keep.MAX..' paths kept already; '..p..' not kept') end
        else
            asked[p]=true
            order[#order+1]=p
            dirty=true
        end
    end
end
-- opts: write(text) (coop-keep.txt: ok, why), status() (the pass's status text), log(line), find(path) (the object
-- in memory and true; nil and nil while it cannot tell yet). Once a Lua load.
function Keep.setup(opts) o=opts end
function Keep.wanted(p) return o~=nil and state~='off' and asked[p]==true end
-- Every path asked is settled by the native part (in memory, or failed to load); true while off.
function Keep.ready() return o==nil or state~='wait' end
function Keep.serves(p) return Keep.wanted(p) and state=='ready' end
local function off(why)
    state='off'
    o.log('keep: off for this Lua load ('..why..'); assets load as before')
end
local function find(p)
    local x,known=o.find(p)
    if not known then return nil end -- No pawn yet for the soft path's proof: the next pass tries again.
    x=U.valid(x)
    if x then
        held[p]=x
        return x
    end
    missing[p]=true
    o.log('keep: '..p..' is not in memory after its load: missing on this PC')
end
-- A served path's held object while it is still that object (its full name, as Doro.same checks), else looked up
-- once; nil while not served, or missing on this PC.
function Keep.get(p)
    if not Keep.serves(p) or missing[p] then return nil end
    local x=held[p] and U.valid(held[p])
    if x and U.text(x:GetFullName()):match('^%S+ (.+)$')==p then return x end
    held[p]=nil
    return find(p)
end
function Keep.slow()
    if not o or state=='off' then return end
    local text=o.status() or ''
    if text:find('keep=fault',1,true) then return off('the native part faulted') end
    -- engine=off reason=<why> for another build; engine=on reason=coop_off after coop off.
    local why=text:match('engine=%a+ reason=([^\r\n]*)')
    if why and not why:find('^not checked yet') then return off('the native part is off: '..why) end
    local a,s=text:match('keep=(%d+) (%d+) %d+')
    a,s=tonumber(a),tonumber(s)
    if dirty or (a or 0)<#order and stall%4==3 then -- The whole list; again while the native count lags.
        local ok,e=o.write(table.concat(order,'\n')..'\n')
        dirty=not ok
        if not ok and not told.write then
            told.write=true
            o.log('keep: coop-keep.txt not written ('..tostring(e)..'); tried again each pass')
        end
    end
    if not (#order==0 or a and a>=#order and s>=a) then
        state='wait'
        stall=(s or -1)>last and 0 or stall+1
        last=s or last
        if stall>=Keep.STALL then
            return off(string.format('%d of %d settled, none more in %d s',s or 0,#order,Keep.STALL//4))
        end
        return
    end
    state,stall='ready',0
    for _,p in ipairs(order) do
        if not (held[p] or missing[p]) then
            find(p)
            return
        end
    end
end
return Keep
