-- coop gardener fight: the cut Naytiba 1, the Gardener (/Game/Art/Character/Monster/CH_M_NA_01/), an artillery tower
-- about 20 m tall that never walks, spawned as a real enemy to fight, on the game thread. The game ships its blueprint,
-- Shows, skill kit, shells, appearance, dead and detect rows but no CharacterTable row and no tree; its 13 rows
-- (cut/lion_rows.lua's R.GARDENER, the native part's second batch, lion/rows.h's kGardenerRecipe) are near copies of
-- shipped ones: three skills the flag trees pick (SingleShot and MultipleShot on their shipped steps, ToxicBeam on
-- three new steps that play its Show), their commands, a stance at speed 0, and three CharacterTable rows over the
-- Maelstrom's: M_Gardener (50010, the Tentacle tree, made for monsters that stay put), M_Gardener_Half (50012, the
-- same at half scale) and M_Gardener_Skulling (50011, the Lion's Skulling test tree).
-- The flow is cut/enemy.lua's, as coop lion's: the tables, the gardener rows request, the wait on the gardener line,
-- the read-back, then one spawn call 25 m ahead of EVE (12.5 m for the half-scale row) and 7.5 m above her feet (the
-- blueprint's unscaled capsule half-height plus 50 cm, so the capsule never starts underground), facing her, and the
-- lines that follow the body. Its skeleton faces +Y where SB's monsters face +X, so once found its mesh turns -90
-- degrees about its root (and again if the game turns it back), which brings its front and the shells' socket to EVE.
-- The entrance: as for the Lion, a clip on the real mesh would replace the anim instance SB plays its skills on, so
-- coop gardener fight intro plays Mon_Gardener_C_Appear on a display copy first (coop gardener play in the viewer
-- previews the other spawn clips), then spawns where the copy stands. No Hide or UnHide: no Show plays them.
local Enemy=require('cut.enemy')
local Gardener={}
-- The only IDs the spawn call takes, with what each is.
Gardener.IDS={[50010]='M_Gardener',[50011]='M_Gardener_Skulling',[50012]='M_Gardener_Half'}
local IDS={half=50012,skulling=50011} -- fight half and fight skulling; any other spawn is M_Gardener's.
local GARDENER=50010
local DIR='/Game/Art/Character/Monster/CH_M_NA_01/'
local USE='Use: coop gardener fight [intro|half|skulling|rows]'
-- The rows as the native part writes them: cut/lion_rows.lua's R.GARDENER (tests/lua/cut/lion_test.lua checks it
-- against rows.h's kGardenerRecipe), in Enemy.rows' form, and the gardener line's counts once they are in.
Gardener.ROWS=Enemy.rows(require('cut.lion_rows').GARDENER)
Gardener.IN=Enemy.counts(Gardener.ROWS)
-- The gardener line (glue's rows_status) as fields (Enemy.parse).
function Gardener.parse(status) return Enemy.parse(status,'gardener') end

-- o: log (the [GD] lines), ask(line) the native request (ok, message), status() the native status text.
function Gardener.new(o)
    local e=Enemy.new(o,{word='gardener',name='Gardener',command='coop gardener fight',tag='[GD]',rows=Gardener.ROWS,
        ids=Gardener.IDS,class='CH_M_NA_01_BluePrint_C',
        -- cm: about 1.6 times its bounding radius at its scale, clear of its 11 m reach in front of its root.
        ahead=function(id) return id==50012 and 1250 or 2500 end,up=750,feet=true,mesh_yaw=-90,
        -- Its own mesh at the fight's scale, turned as the body's mesh is; its 15.5 s appear clip.
        entrance={mesh=DIR..'CH_M_NA_01.CH_M_NA_01',clip=DIR..'Animation/Mon_Gardener_C_Appear.Mon_Gardener_C_Appear',
            scale=1,yaw=-90,seconds=15.5},
        skipped='off by default: a clip on its mesh would replace the anim instance SB plays its skills on; coop '
            ..'gardener fight intro plays Mon_Gardener_C_Appear on a display copy before the spawn'})
    local self={}
    -- The words after coop gardener fight (commands/cut.lua hands them over): none, intro, half or skulling spawn one
    -- (the co-op save check is commands/cut.lua's), rows asks and reads back the rows only.
    function self.command(sub,extra)
        if extra~=nil or not (sub==nil or sub=='intro' or sub=='rows' or IDS[sub]) then return false,USE end
        local busy=e.busy()
        if busy then return false,busy end
        if sub=='rows' then return e.start(GARDENER,false,true) end
        return e.start(IDS[sub] or GARDENER,sub=='intro',false)
    end
    self.tick,self.stop=e.tick,e.stop
    return self
end
return Gardener
