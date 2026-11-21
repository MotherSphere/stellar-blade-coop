-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The ghost bench (coop bench, a developer command): up to 64 local ghosts on rings around EVE that replay her own pose
-- with no Steam link. UE4SS.log gets one line a second: the frame time, the native tick's own time, Lua's time in the
-- bench ghosts, how many are drawn and rendered. It measures what a ghost of each tier costs (design A10, 5.8).
-- Each bench ghost is an online/partner/puppet.lua ghost on files of the bench (make(files, slot, look, name_tag)). Its
-- remote table is coop-bench-table.txt, her capture as the native part holds it. Its display stays in Lua. Its store
-- is its line of coop-bench-ghosts.txt. The native part reads every display from coop-bench.txt: "bench <table
-- generation>", then per ghost "ghost <dx cm> <dy cm> <stride>" and its display lines ("bench off" stops it). It writes
-- one pose of hers into each ghost due (every stride-th frame) with the ghost's offset added to its mailbox. Once a
-- second it writes its window to coop-bench-out.txt (Bench.parse_out).
-- Tiers (Bench.TIERS): full is today's ghost without faces, effects, sounds or drone (the bench makes none of their
-- native calls). mid forces LOD 1 (SetForcedLOD(2)) with no shadow, no cloth and no tag, written every 2nd frame. far
-- draws the base suit's body and hair alone at their lowest LOD (SetForcedLOD(99): the exec takes the mesh's LOD count
-- past it) with no shadow, no cloth, no dyes and no tag, written every 4th frame. nocloth and noshadow take cloth or
-- shadows off any tier. Bench ghosts use ghost slots 101 to 164 (online/partner/assets.lua's keys), never 0 to 6.
-- tick() each frame before the native tick, place() after it, sync() every 250 ms (online/partner/wiring.lua runs them
-- with M.ghosts'); each returns a list of {ok, message}. off(why) at coop bench off and coop off. A map change needs
-- nothing here: each ghost goes and is built again on the new table, as any ghost is. A Lua reload ends the bench: the
-- next load's first tick destroys the actors coop-bench-ghosts.txt lists and writes "bench off".
local U=require('core.unreal')
local Bench={}
Bench.MAX,Bench.FIRST_SLOT=64,101
-- main/input.lua passes six words after coop bench: ring and its metres take two of them.
Bench.USAGE='Use: coop bench ghosts <0-64> [full|mid|far] [ring <1-300 m>] [nocloth] [noshadow] [add] | off'
Bench.FILE,Bench.TABLE,Bench.OUT,Bench.LIST='coop-bench.txt','coop-bench-table.txt','coop-bench-out.txt',
    'coop-bench-ghosts.txt'
-- stride: the native part writes the ghost every stride-th frame. tag: it has a name tag. The rest goes into its look.
Bench.TIERS={
    full={stride=1,tag=true},
    mid={stride=2,lod=2,shadow=false,cloth=false},
    far={stride=4,lod=99,shadow=false,cloth=false,dyes=false,basesuit=true,bare=true},
}
-- coop bench ghosts' words: {n, tier, ring (m), nocloth, noshadow, add}, or nil and the usage. 0 ghosts gives the lines
-- alone, for a baseline.
function Bench.parse(count,...)
    local o={n=type(count)=='string' and count:match('^%d+$') and tonumber(count),tier='full',ring=5}
    if not o.n or o.n>Bench.MAX then return nil,Bench.USAGE end
    local words,k,tier,ring={...},1,false,false
    while words[k]~=nil do
        local w=words[k]
        if Bench.TIERS[w] and not tier then
            o.tier,tier=w,true
        elseif w=='ring' and not ring then
            local m=type(words[k+1])=='string' and words[k+1]:match('^%d+$') and tonumber(words[k+1])
            if not m or m<1 or m>300 then return nil,Bench.USAGE end
            o.ring,ring,k=m,true,k+1
        elseif (w=='nocloth' or w=='noshadow' or w=='add') and not o[w] then
            o[w]=true
        else
            return nil,Bench.USAGE
        end
        k=k+1
    end
    return o
end
-- n offsets in cm on a circle of that radius around her: ghost j at the angle 2 pi j / n + turn.
function Bench.ring(n,metres,turn)
    local out={}
    for j=0,n-1 do
        local a=2*math.pi*j/n+(turn or 0)
        out[j+1]={metres*100*math.cos(a),metres*100*math.sin(a)}
    end
    return out
end
-- coop-bench.txt's text: the head, then a block per ghost that has a display, in whole centimetres.
function Bench.file(generation,ghosts)
    local out={'bench '..generation..'\n'}
    for _,g in ipairs(ghosts) do
        if g.display then
            out[#out+1]=string.format('ghost %d %d %d\n',math.floor(g.dx+0.5),math.floor(g.dy+0.5),g.stride)..g.display
        end
    end
    return table.concat(out)
end
local OUT_FIELDS={'seq','ghosts','taken','frames','gap','gap_max','tick','tick_max','written','refused','generation',
    'count'}
-- coop-bench-out.txt, the native part's last second: "bench <seq> ghosts <blocks read> taken <blocks taken> frames <f>
-- gap <mean us> <max us> tick <mean us> <max us> written <w> refused <r> table <generation> <count>" (the gap between
-- two native ticks, the native tick's own time, the ghost writes, the table it wrote to coop-bench-table.txt: 0 0 for
-- none), then " memory <working set MB> <private MB>" on the lines of a new measure (every 10 s). nil for another text.
function Bench.parse_out(text)
    local v={(text or ''):match('^bench (%d+) ghosts (%d+) taken (%d+) frames (%d+) gap (%d+) (%d+) tick (%d+) (%d+) '
        ..'written (%d+) refused (%d+) table (%d+) (%d+)')}
    if not v[1] then return nil end
    local o={}
    for k,name in ipairs(OUT_FIELDS) do o[name]=tonumber(v[k]) end
    local ws,private=text:match(' memory (%d+) (%d+)')
    o.ws,o.private=tonumber(ws),tonumber(private)
    return o
end
-- The UE4SS.log line of one window w. lua: {ghosts, groups (text), drawn, rendered, ms (Lua's bench time a frame)}.
function Bench.line(w,lua)
    local line=string.format('Bench: %d ghosts%s, %d of %d taken, %d drawn, %d rendered; frame mean %.1f ms, worst '
        ..'%.1f ms (%d frames); native tick mean %.2f ms, max %.2f ms; Lua ghosts %.3f ms a frame; %d written, %d '
        ..'refused',lua.ghosts,lua.groups~='' and ' ('..lua.groups..')' or '',w.taken,w.ghosts,lua.drawn,lua.rendered,
        w.gap/1000,w.gap_max/1000,w.frames,w.tick/1000,w.tick_max/1000,lua.ms,w.written,w.refused)
    if w.ws then line=line..string.format('; working set %d MB, private %d MB',w.ws,w.private) end
    return line
end
-- o: link (core/link.lua's read_file, write_file and mod_assets), make(files, slot, look, name_tag) (a ghost), look
-- (the ghost's looks, copied into each group's), name_tag (the setting), log, active() (slot 0's ghost on, which
-- publishes her capture).
function Bench.new(o)
    local link,log=o.link,o.log
    local self,ghosts,groups,raised={},{},{},{}
    local on,swept,generation,seq=false,false,0,nil
    local written,listed -- What coop-bench.txt and coop-bench-ghosts.txt hold, as last written.
    local spent,frames=0,0 -- Since the last line: Lua's time in the bench ghosts' tick and place, the frames.
    -- A ghost that raises is said once a Lua load for that call: the others still run.
    local function call(out,k,name,...)
        local key=name..k
        local ran,ok,message=xpcall(ghosts[k].puppet[name],function(e) return raised[key] and e or debug.traceback(e,2)
            end,...)
        if not ran then
            if raised[key] then return end
            raised[key]=true
            ok,message=false,'error (said once until the mod reloads): '..tostring(ok)
        end
        if message then out[#out+1]={ok,'bench '..k..': '..tostring(message)} end
    end
    -- The text now in the file: text when written, else nil, so the next pass writes it again.
    local function put(name,text,last)
        if text==last then return last end
        return link.write_file(name,text) and text or nil
    end
    -- The first tick, or a command before it: the actors an earlier Lua load listed are destroyed when still a ghost's
    -- (a Poseable root, as online/partner/puppet.lua's sweep checks). That load's bench file becomes bench off.
    local function sweep(out)
        if swept then return end
        swept=true
        local list,n=link.read_file(Bench.LIST),0
        for path in (list or ''):gmatch('[^\r\n]+') do
            local actor=U.valid(StaticFindObject(path))
            local root=actor and U.valid(actor:K2_GetRootComponent())
            if root and root:IsA(U.find('/Script/Engine.PoseableMeshComponent')) then
                actor:K2_DestroyActor()
                n=n+1
            end
        end
        listed=put(Bench.LIST,'',list or '')
        written=put(Bench.FILE,'bench off\n',link.read_file(Bench.FILE) or 'bench off\n')
        if n>0 then
            out[#out+1]={true,string.format('Bench: %d ghost%s of an earlier Lua load removed.',n,n==1 and '' or 's')}
        end
    end
    local function files_of(g)
        return {
            remote_table=function() return link.read_file(Bench.TABLE) end,
            display=function(text) g.display=text; return true end,
            store=function()
                return {save=function(path) g.path=path end,load=function() end,clear=function() g.path=nil end}
            end,
            mod_assets=link.mod_assets,
        }
    end
    -- Each ghost toggled off (its actor destroyed, its display and path gone); what failed goes into out.
    local function remove(out)
        local said={}
        for k=1,#ghosts do if ghosts[k].puppet.active() then call(said,k,'toggle') end end
        for _,r in ipairs(said) do if not r[1] then out[#out+1]=r end end
        local n=#ghosts
        ghosts,groups={},{}
        return n
    end
    local function failures(out)
        local text={}
        for _,r in ipairs(out) do if not r[1] then text[#text+1]=r[2] end end
        return text[1] and ' Failed: '..table.concat(text,'; ') or ''
    end
    -- Drawn: the ghosts whose body() shows. Rendered: those the engine drew within 0.2 s
    -- (UPrimitiveComponent::WasRecentlyRendered, exec 0x1448f6f10; shadow passes may count).
    local function counts()
        local drawn,rendered=0,0
        for _,g in ipairs(ghosts) do
            local body=g.puppet.body()
            if body then
                drawn=drawn+1
                local ok,seen=pcall(function() return body:WasRecentlyRendered(0.2) end)
                if ok and seen==true then rendered=rendered+1 end
            end
        end
        return drawn,rendered
    end
    local function named() return table.concat(groups,', ') end
    -- coop bench ghosts ...: a new set, or a group added to it (add).
    function self.ghosts(...)
        local a,why=Bench.parse(...)
        if not a then return false,why end
        if not o.active() then return false,'turn the ghost on first: coop puppet' end
        local out={}
        sweep(out)
        if a.add and #ghosts+a.n>Bench.MAX then
            return false,string.format('at most %d bench ghosts in all: %d now',Bench.MAX,#ghosts)
        end
        if not a.add then remove(out) end
        local tier=Bench.TIERS[a.tier]
        local look={}
        for key,v in pairs(o.look or {}) do look[key]=v end
        look.effects,look.faces,look.sounds,look.drone=false,false,false,false
        for key,v in pairs(tier) do if key~='stride' and key~='tag' then look[key]=v end end
        if a.nocloth then look.cloth=false end
        if a.noshadow then look.shadow=false end
        -- A group after the first turns by half a step, so two rings of the same size do not stack.
        for _,at in ipairs(Bench.ring(a.n,a.ring,#groups>0 and math.pi/a.n or 0)) do
            local g={dx=at[1],dy=at[2],stride=tier.stride}
            g.puppet=o.make(files_of(g),Bench.FIRST_SLOT+#ghosts,look,tier.tag and o.name_tag or false)
            ghosts[#ghosts+1]=g
            local said={}
            call(said,#ghosts,'toggle')
            for _,r in ipairs(said) do if not r[1] then out[#out+1]=r end end
        end
        if a.n>0 then
            groups[#groups+1]=string.format('%d %s at %d m%s%s',a.n,a.tier,a.ring,a.nocloth and ' nocloth' or '',
                a.noshadow and ' noshadow' or '')
        end
        if not on then -- A window left from an earlier run is not logged.
            on,spent,frames=true,0,0
            seq=(Bench.parse_out(link.read_file(Bench.OUT)) or {}).seq
        end
        return true,string.format('Bench on: %d ghost%s%s; a line a second goes to UE4SS.log (coop bench off ends it).',
            #ghosts,#ghosts==1 and '' or 's',groups[1] and ' ('..named()..')' or '')..failures(out)
    end
    function self.off(why)
        local out={}
        sweep(out)
        local n=remove(out)
        on=false
        written=put(Bench.FILE,'bench off\n',written)
        listed=put(Bench.LIST,'',listed)
        return true,string.format('Bench off (%s): %d ghost%s removed.',why,n,n==1 and '' or 's')..failures(out)
    end
    function self.status()
        if not on then return 'Bench off.' end
        return string.format('Bench on: %d ghosts%s, %d drawn (coop bench off ends it).',#ghosts,
            groups[1] and ' ('..named()..')' or '',(counts()))
    end
    function self.tick()
        local out={}
        sweep(out)
        local began=os.clock()
        for k=1,#ghosts do call(out,k,'tick') end
        spent=spent+os.clock()-began
        return out
    end
    function self.place()
        local out={}
        if not on then return out end
        local began=os.clock()
        for k=1,#ghosts do call(out,k,'place') end
        spent,frames=spent+os.clock()-began,frames+1
        return out
    end
    -- Every 250 ms: the native part's table to each ghost, the files when they changed, a line for a new window.
    function self.sync()
        local out={}
        if not on then return out end
        local w=Bench.parse_out(link.read_file(Bench.OUT))
        if w then
            generation=w.generation
            for k=1,#ghosts do
                if w.generation>0 then call(out,k,'remote',w.generation,w.count,'bench') else call(out,k,'remote') end
            end
        end
        local paths={}
        for _,g in ipairs(ghosts) do if g.path then paths[#paths+1]=g.path..'\n' end end
        listed=put(Bench.LIST,table.concat(paths),listed)
        written=put(Bench.FILE,Bench.file(generation,ghosts),written)
        if w and w.seq~=seq then
            seq=w.seq
            local drawn,rendered=counts()
            log(Bench.line(w,{ghosts=#ghosts,groups=named(),drawn=drawn,rendered=rendered,
                ms=frames>0 and spent*1000/frames or 0}))
            spent,frames=0,0
        end
        return out
    end
    return self
end
return Bench
