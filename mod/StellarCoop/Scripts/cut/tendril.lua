-- coop tendril fight: the cut Naytiba 6, the Tendril (/Game/Art/Character/Monster/CH_M_NA_06/: a test mesh whose one
-- material slot is empty, its skeleton, physics asset, blueprint, AnimBP and 42 clips, but no table row and no Show),
-- spawned as a real enemy to fight, on the game thread. Its 107 rows (cut/lion_rows.lua's R.TENDRIL, the native part's
-- third batch, lion/rows.h's kTendrilRecipe) are authored as the Lion's: 11 skills on its own clips with their
-- commands and steps, the areas their hits strike, a stance, two anim sets, its dead, appearance and CharacterTable
-- rows (M_TendrilC, 50060, the Lion's Skulling test tree).
-- No pak holds a Show of its clips, so before a spawn this file builds the 12 Shows its steps and its death name
-- (R.TENDRIL_SHOWS): each a copy of the Gardener's one-clip Show M_Gardener_ToxicBeam, made by StaticConstructObject
-- with that Show as its template, in that Show's package and in the root set (never collected), with its own copy of
-- the anim key set to play one Tendril clip for its length. A step names one as "<that package>.<its name>"; SB loads
-- a step's Show through StaticLoadObject("/Game/Art/Show/" + ShowPath), which finds an object of a package in memory
-- before it reads a file. Each Show is read back: its own anim key (not the template's), the clip and lengths as set,
-- and found by the path its steps name. A Lua reload finds the Shows already built and sets them again. Once a second
-- while a Tendril lives, a Show the game collected is built again.
-- The flow is cut/enemy.lua's, as coop lion's: the tables, the tendril rows request, the wait on the tendril line, the
-- read-back, the Shows, then one spawn call 8 m ahead of EVE and 1 m above her middle, facing her, and the lines that
-- follow the body. Once found, its mesh turns to yaw 0: its skeleton faces +X (its head in front of its pelvis, a
-- planted foot sliding toward -X in its Walk clip), and its blueprint turns the mesh -90 degrees as for a skeleton
-- facing +Y, so it would show its side. Its mesh takes the Hydra's tentacle material, as coop tendril skin hydra does
-- in the viewer. The boss bar shows <M_TendrilC> (no Tendril text in CharacterStringTable): cut/enemy.lua writes
-- Tendril there. No entrance: none of its clips is one.
local U=require('core.unreal')
local Doro=require('race.doro')
local Enemy=require('cut.enemy')
local valid,value_of,text,why=U.valid,U.value_of,U.text,Enemy.why
local Tendril={}
-- The only ID the spawn call takes, with what it is.
Tendril.IDS={[50060]='M_TendrilC'}
local TENDRIL=50060
local USE='Use: coop tendril fight [rows]'
local ROWS=require('cut.lion_rows')
-- The rows as the native part writes them: cut/lion_rows.lua's R.TENDRIL (tests/lua/cut/lion_test.lua checks it
-- against rows.h's kTendrilRecipe), in Enemy.rows' form, and the tendril line's counts once they are in.
Tendril.ROWS=Enemy.rows(ROWS.TENDRIL)
Tendril.IN=Enemy.counts(Tendril.ROWS)
-- The Shows to build: {template=<a ShowPath>, key=<its anim key's name>, folder=<the clips'>, {name, clip, seconds},
-- ...}.
Tendril.SHOWS=ROWS.TENDRIL_SHOWS
-- The tendril line (glue's rows_status) as fields (Enemy.parse).
function Tendril.parse(status) return Enemy.parse(status,'tendril') end
local SHOWS='/Game/Art/Show/'
local SHOW_CLASS,KEY_CLASS='/Script/SB.SBShowData','/Script/SB.SBShowAnimKey'
local PUBLIC,ROOT_SET=0x1,0x40000000 -- RF_Public; EInternalObjectFlags::RootSet: the game never collects it.
local HYDRA='/Game/Art/Character/Monster/CH_M_NA_09/Materials/MI_M_NA_09_V03_Tentacle.MI_M_NA_09_V03_Tentacle'

-- o: log (the [TD] lines), ask(line) the native request (ok, message), status() the native status text.
function Tendril.new(o)
    local log=o.log
    local T=Tendril.SHOWS
    local built={} -- Each Show built, by name.
    -- An object of name in outer: UE's StaticFindObject in that outer, which a miss leaves fast; the full path when
    -- that form raises (a miss of it took 25 to 35 ms in game).
    local function inside(class,outer,name,path)
        local ok,found=pcall(StaticFindObject,class,outer,name,false)
        if ok then return valid(found) end
        return valid(StaticFindObject(path))
    end
    -- One Show: found where it was built (rooted, it outlives a Lua reload), else made from the template; its own anim
    -- key set to its clip and length, and everything read back. Returns whether it was made now.
    local function build(template,s)
        local path=SHOWS..T.template..'.'..s.name
        local show=inside(template:GetClass(),template:GetOuter(),s.name,path)
        local made=show==nil
        if made then
            show=assert(valid(StaticConstructObject(template:GetClass(),template:GetOuter(),FName(s.name,1),PUBLIC,
                ROOT_SET,false,false,template)),'not made')
        end
        local key=inside(U.find(KEY_CLASS),show,T.key,path..':'..T.key)
        assert(key and U.address(key:GetOuter())==U.address(show),'no anim key of its own')
        local clip=T.folder..s.clip
        key.AnimResourcePath=clip
        key.bAbsoluteResourcePath=true
        key.bUseCharacterCustomAnim=false
        key.PlayStartTime=0
        key.PlayEndTime=s.seconds
        key.Duration=s.seconds
        show.EndTime=s.seconds
        show.bUseStep=false
        assert(text(key.AnimResourcePath)==clip,'its clip reads '..text(key.AnimResourcePath))
        for _,v in ipairs({value_of(key.PlayEndTime),value_of(key.Duration),value_of(show.EndTime)}) do
            assert(math.abs((tonumber(v) or -1)-s.seconds)<1e-3,'a length reads '..tostring(v))
        end
        assert(value_of(key.bAbsoluteResourcePath)==true and value_of(key.bUseCharacterCustomAnim)==false,
            'its path flags did not take')
        local found=valid(StaticFindObject(path)) -- In memory now: a hit.
        assert(found and U.address(found)==U.address(show),'not found by its steps\' path')
        built[s.name]=show
        return made
    end
    -- Every Show not built yet, or gone: the template Show (in memory, else loaded) first. Returns how many it made
    -- and how many it found built before; raises at the first that fails, naming it.
    local function ready()
        local made,kept=0,0
        local template
        for _,s in ipairs(T) do
            if not valid(built[s.name]) then
                template=template or assert(Doro.resolve(SHOWS..T.template..'.'..T.template:match('[^/]+$'),
                    SHOW_CLASS),T.template..' does not load')
                local fine,new=pcall(build,template,s)
                if not fine then error(s.name..': '..why(new),0) end
                if new then made=made+1 else kept=kept+1 end
            end
        end
        return made,kept
    end
    -- cut/enemy.lua's prepare: every Show ready before the spawn.
    local function prepare()
        local made,kept=ready()
        log(string.format('shows: %d/%d ready (%d made, %d found built), each with its own anim key on its clip and '
            ..'found by the path its steps name',#T,#T,made,kept))
    end
    -- Once a second while a Tendril lives: a Show the game collected built again.
    local function watch()
        local lost={}
        for _,s in ipairs(T) do if not valid(built[s.name]) then lost[#lost+1]=s.name end end
        if not lost[1] then return end
        local fine,e=pcall(ready)
        log(string.format('shows: %s gone: %s',table.concat(lost,', '),fine and 'built again'
            or 'not built again ('..why(e)..')'))
    end
    local e=Enemy.new(o,{word='tendril',name='Tendril',command='coop tendril fight',tag='[TD]',rows=Tendril.ROWS,
        ids=Tendril.IDS,class='CH_M_NA_06_Blueprint_C',
        -- cm: its strikes reach 4 to 7.5 m, so it starts out of their reach; above EVE's middle, as the Lion's spot.
        ahead=function() return 800 end,up=100,mesh_yaw=0,material=HYDRA,
        boss={shown='^<M_TendrilC[%w_]*>$',name='Tendril'},skipped='none of its clips is an entrance',
        prepare=prepare,alive={name='shows',run=watch}})
    local self={}
    -- The words after coop tendril fight (commands/cut.lua hands them over): none spawns one (the co-op save check is
    -- commands/cut.lua's), rows asks for the rows, reads them back and builds the Shows only.
    function self.command(sub,extra)
        if extra~=nil or not (sub==nil or sub=='rows') then return false,USE end
        local busy=e.busy()
        if busy then return false,busy end
        return e.start(TENDRIL,false,sub=='rows')
    end
    self.tick,self.stop=e.tick,e.stop
    return self
end
return Tendril
