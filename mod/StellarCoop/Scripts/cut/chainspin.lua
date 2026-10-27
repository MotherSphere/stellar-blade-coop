-- coop chainspin: EVE's cut Tachy Mode ChainSpin, on a co-op save only. SB ships her clip P_Eve_Tachy_Skill_ChainSpin1,
-- its two moves and an icon, but no skill row, no step of hers and no Show in her folder; the prologue's Tachy NPC kept
-- a Show that plays her clip (CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain). The native part adds the skill
-- P_Eve_Tachy_Skill_ChainSpin1_1, its 9 steps on that Show and the effect P_Eve_Tachy_Skill_ChainSpin1_Use that starts
-- it (lion/rows.h, the lion rows batch: Lion.rows gets them in as for the shop's cut items). This file then asks SB to
-- apply that effect on EVE through the player controller's Cheat request: its logic job (FSBCheat::Simulate, the
-- SBApplyEffectMe word) finds the actor by GUID and runs SB's effect call (0x141ad08b0, the call the shared fight's job
-- makes) with EVE as target and caster. The effect's UseSkill action starts the skill by its SkillTable name, and only
-- while EVE has P_Eve_TachyMode: outside Tachy Mode the request changes nothing. No button starts it: the four Tachy
-- skill commands (BetaSkill1-4) are taken; a fifth could be appended to the P_Eve_Tachy stance's CommandArray in place,
-- as lion/shock.h does for the gun stances, and none was added. Nothing of it is saved: no acquisition, no skill slot,
-- no trophy tag.
-- Called here: ServerRequest_Cheat(EVE's GUID, 0, 'SBApplyEffectMe', an effect's ID) once a command, after the rows
-- are in, and for coop devmenu (cut/devmenu.lua) once for each effect of the row asked, from its fixed list (its clear
-- and lockswitch rows also at coop off). Never called here: another cheat word.
local N=require('nightop.probe')
local ChainSpin={}
ChainSpin.EFFECT='P_Eve_Tachy_Skill_ChainSpin1_Use'
-- The effect's ID as the generator wrote it (cut/lion_rows.lua, from the same recipe as lion/rows.h).
for _,r in ipairs(require('cut.lion_rows').ROWS) do
    if r[1]=='EffectTable' and r[2]==ChainSpin.EFFECT then ChainSpin.ID=r[3] end
end
assert(math.type(ChainSpin.ID)=='integer','cut/lion_rows.lua lacks '..ChainSpin.EFFECT)
local USE='Use: coop chainspin'
local MASK=0xFFFFFFFF
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
-- The one call: SB's cheat request, SBApplyEffectMe with an EffectTable ID as its argument, on EVE's GUID; no player
-- ID (that word reads none). ChainSpin's effect, or one of coop devmenu's.
function ChainSpin.apply(pc,guid,id)
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    assert(math.type(id)=='integer' and id>0 and id<=0x7FFFFFFF,'not an effect ID')
    pc:ServerRequest_Cheat(guid,0,'SBApplyEffectMe',tostring(id))
end
function ChainSpin.cast(pc,guid) return ChainSpin.apply(pc,guid,ChainSpin.ID) end
-- Whom the call goes to: EVE's GUID from the native engine line (me=, the key the world's player map holds, which the
-- revive uses too), with no respawn or warp under way, EVE in the world and her controller. The GUID and the
-- controller, or nil and why.
function ChainSpin.target(status)
    local warp,me=(('\n'..(status or '')):match('\nengine=([^\r\n]*)') or ''):match(' warp=(%a+) me=(%d+)')
    if not warp then return nil,'the native status has no warp read yet: try again in a moment' end
    if warp~='idle' then return nil,'a respawn or a warp is under way: try again once it ends' end
    local guid=math.tointeger(tonumber(me))
    if not guid or guid==0 then return nil,"EVE's GUID reads 0: nothing asked" end
    if not N.her() then return nil,'no EVE in the world' end
    local pc=N.controller()
    if not pc then return nil,'no SB player controller' end
    return guid,pc
end
-- o: log(text) writes a [CS] line; status() is the native part's status text; rows(done) is cut/lion.lua's Lion.rows,
-- which gets the rows in, then calls done(ok, message) and returns what done returns, or returns ok, message, true
-- while it waits (done follows, and coop lion's tick reports its result).
function ChainSpin.new(o)
    local log,status,rows=o.log,o.status,o.rows
    local self={}
    -- Once the rows are in: the target (ChainSpin.target), then the call.
    local function spin()
        local guid,pc=ChainSpin.target(status())
        if not guid then return false,pc end
        local called,e=pcall(ChainSpin.cast,pc,guid)
        if not called then
            log('ChainSpin request failed: '..why(e))
            return false,'the game call failed: '..why(e)
        end
        log(string.format('ChainSpin asked: SBApplyEffectMe %d on EVE (guid %d)',ChainSpin.ID,guid))
        return true,'ChainSpin asked of the game: EVE spins if she is in Tachy Mode'
    end
    function self.command(extra)
        if extra~=nil then return false,USE end
        if not rows then return false,'coop lion is not loaded: its rows carry the ChainSpin' end
        local ok,said,waiting=rows(function(rows_in,message)
            if not rows_in then
                log('ChainSpin: its rows are not in ('..tostring(message)..')')
                return false,'the ChainSpin rows cannot be added to the game ('..tostring(message)..')'
            end
            return spin()
        end)
        if not waiting then return ok,said end
        log('ChainSpin waits for its rows ('..tostring(said)..')')
        return true,'the ChainSpin rows are asked of the native part; EVE spins once they are in'
    end
    return self
end
return ChainSpin
