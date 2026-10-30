-- Matrix XIII's Lion and Gardener when the game spawns them from their spawn rows (DLC02_40_E_CharS_051 and
-- DLC02_20_E_CharS_904, the mxspawn batch; cut/mxiii.lua ticks this file). cut/enemy.lua fixes only the bodies its own
-- spawn call made, so in world 2800, once a second, this file looks for a body of each boss's blueprint within NEAR of
-- its spawn point and fixes it once: the Lion through cut/lion.lua's adopt (the anim instance its mesh lacks, else the
-- hidden Behemoth leader), the Gardener's mesh turned -90 degrees about its root (its skeleton faces +Y). While a boss
-- it fixed lives, the boss bar's name reads its name instead of the row name (<M_LionC>, <M_Gardener>). One [MXBOSS]
-- line a fix. When EVE stands within ARENA of a boss point for WAIT s with no body there, one line says so and that
-- coop mxiii boss spawns one; that command is the key-0 fallback: coop lion's or coop gardener fight's own spawn,
-- with no spawn row (no saved death, no zone storage). It is never automatic: a boss killed in an earlier session
-- stays dead through its row's SaveType, and an automatic spawn would bring it back at every visit. The Stalker is a
-- plain row-backed character and needs neither.
local U=require('core.unreal')
local N=require('nightop.probe')
local Rows=require('cut.mxiii_rows')
local Boss={}
Boss.MAP='/mxiii_p'
Boss.LIST={
    {row='DLC02_40_E_CharS_051',name='Lion',class='CH_M_NA_02_BluePrint_Large_C',shown='^<M_LionC[%w_]*>$',fix='lion'},
    {row='DLC02_20_E_CharS_904',name='Gardener',class='CH_M_NA_01_BluePrint_C',shown='^<M_Gardener[%w_]*>$',
        fix='gardener',mesh_yaw=-90},
}
-- cm: a body this near its point is the row's; EVE this near a point is in its arena; a point this near EVE is looked
-- at (a body search may walk every object, 25 to 80 ms, so only near a boss); s EVE waits in an arena before the note.
Boss.NEAR,Boss.ARENA,Boss.LOOK,Boss.WAIT=3000,2500,8000,20
local EVERY,LOOK=1,10 -- s between passes, s between looks for the boss bar's text blocks.
local BOSS_TEXT,LIVE='TextBlock_BossName','/Engine/Transient'

local function far(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
local function xyz(t) return {X=t[1],Y=t[2],Z=t[3]} end

-- o: log (the [MXBOSS] lines), lion and gardener (cut/lion.lua's and cut/gardener.lua's instances; nil: no fix, no
-- fallback), points (cut/mxiii_rows.lua's BOSS by default).
function Boss.new(o)
    local log=o.log
    local points=o.points or Rows.BOSS
    local self={}
    local next_pass,next_look,blocks=0,0,{}
    local state={} -- By row: fixed (the body's address), waited (os.clock EVE came near), said.
    local function reset() for _,b in ipairs(Boss.LIST) do state[b.row]={} end end
    reset()
    local function in_world()
        local ok,map,eve=pcall(function()
            local x=U.valid(N.her())
            return x and U.map_of(x),x
        end)
        return ok and map and map:sub(-#Boss.MAP)==Boss.MAP and eve or nil
    end
    local function fix(b,c)
        if b.fix=='lion' then
            if not o.lion or not o.lion.adopt then return 'no coop lion to fix it' end
            return o.lion.adopt(c)
        end
        local m=assert(U.valid(c.Mesh),'no mesh on the body')
        m:K2_SetRelativeRotation({Pitch=0,Yaw=b.mesh_yaw,Roll=0},false,{},false)
        return string.format('mesh turned %d degrees',b.mesh_yaw)
    end
    -- The boss bar's name, while a fixed boss lives.
    local function names(now,living)
        if not next(living) then return end
        local held=false
        for _,t in ipairs(blocks) do held=held or U.valid(t)~=nil end
        if not held and now>=next_look then
            next_look,blocks=now+LOOK,{}
            U.each(FindAllOf('TextBlock') or {},function(_,t)
                t=U.valid(t)
                if t and U.text(t:GetFName())==BOSS_TEXT and U.text(t:GetFullName()):find(LIVE,1,true) then
                    blocks[#blocks+1]=t
                end
            end)
        end
        for _,t in ipairs(blocks) do
            local shown=U.valid(t) and U.text(t:GetText())
            for _,b in ipairs(Boss.LIST) do
                if shown and living[b.row] and shown:find(b.shown) then
                    t:SetText(FText(b.name))
                    log(string.format('boss name: %s -> %s',shown,b.name))
                end
            end
        end
    end
    local function pass(now,eve)
        local here=U.value_of(eve:K2_GetActorLocation())
        local living={}
        for _,b in ipairs(Boss.LIST) do
            local s,p=state[b.row],points[b.row]
            local spot=p and xyz(p.at)
            if spot and far(here,spot)<=Boss.LOOK then
                local found=U.actors_of(U.find('/Script/SB.SBCharacter'),b.class,eve)
                local body=nil
                for _,c in ipairs(found) do
                    local ok,d=pcall(function() return far(U.value_of(c:K2_GetActorLocation()),spot) end)
                    if ok and d<=Boss.NEAR and U.text(c:GetFullName()):match('^%S+')==b.class then body=c end
                end
                if body then
                    living[b.row]=true
                    local a=U.address(body)
                    if s.fixed~=a then
                        s.fixed=a
                        local ok,said=pcall(fix,b,body)
                        log(string.format('%s %s found near its point: %s',b.name,b.row,ok and said or 'not fixed ('
                            ..tostring(said)..')'))
                    end
                    s.waited=nil
                elseif far(here,spot)<=Boss.ARENA then
                    s.waited=s.waited or now
                    if now-s.waited>=Boss.WAIT and not s.said then
                        s.said=true
                        log(string.format('no %s body within %d m of %s after %d s: coop mxiii boss spawns one (key 0, '
                            ..'no saved death)',b.name,Boss.NEAR//100,b.row,Boss.WAIT))
                    end
                else
                    s.waited=nil
                end
            end
        end
        names(now,living)
    end
    function self.tick()
        local now=os.clock()
        if now<next_pass then return end
        next_pass=now+EVERY
        local eve=in_world()
        if not eve then return reset() end
        local ok,e=pcall(pass,now,eve)
        if not ok then log('pass failed: '..tostring(e)) end
    end
    -- coop mxiii boss: the boss whose point is nearest EVE within ARENA, spawned by its own command.
    function self.command()
        local eve=in_world()
        if not eve then return false,'coop mxiii boss works in Matrix XIII only' end
        local here=U.value_of(eve:K2_GetActorLocation())
        local best,d
        for _,b in ipairs(Boss.LIST) do
            local p=points[b.row]
            local x=p and far(here,xyz(p.at))
            if x and x<=Boss.ARENA and (not d or x<d) then best,d=b,x end
        end
        if not best then return false,'coop mxiii boss: no Lion or Gardener spawn point within 25 m' end
        log('fallback: '..best.name..' by its own command, key 0, no saved death')
        if best.fix=='lion' then
            if not o.lion then return false,'coop mxiii boss: no coop lion' end
            return o.lion.command()
        end
        if not o.gardener then return false,'coop mxiii boss: no coop gardener fight' end
        return o.gardener.command()
    end
    return self
end
return Boss
