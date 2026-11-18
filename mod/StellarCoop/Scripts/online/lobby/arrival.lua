-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hold at an SBO lobby arrival (a hall or Xion's room): from the new world's player controller after the warp's map
-- load (PlayerController:ClientRestart) until the lobby is ready, SB's own black covers the screen and the kit's root
-- stays collapsed; then the black fades out the game's way, onto the lobby menu. SB hides its travel screen at the end
-- of its enter-game flow (state 0xd, FUN_141cd2f50) whatever we do, so the black is SB's second loading screen,
-- USBBlueprintLibrary::LoadingScreenFadeAuto (exec 0x1426641e0): a WB_Loading_Basic at z-order 10, under our kit (100),
-- that SB's loading controller ends with its own end fade LIFETIME s after its fade-in, Lua or not; the native part's
-- loading lift ends it earlier the same way (online/lobby/loading_game.inc). The rules here, with no engine call:
-- o.fade() puts the black up (raises when it cannot), o.lift() asks its end (ok, why), o.veil(on) collapses the kit's
-- root or shows it again, o.log(line), o.clock() (s). Time-outs: CAP s after the black went up it lifts whatever is
-- missing; a lobby warp with no new controller ARM_CAP s later (the native part's arrival time-out) is dropped.
local Arrival={}
Arrival.CAP=8
Arrival.ARM_CAP=60
Arrival.LIFETIME=10
Arrival.FADE=0.5 -- The black's fade in and out, SB's own black fade length.
function Arrival.new(o)
    local clock=o.clock or os.clock
    local self={}
    -- When the last lobby warp was asked (nil: none waits), whether its new controller came, when the black went up.
    local armed,restarted,held=nil,false,nil
    local function lift(why)
        local took=clock()-held
        held=nil
        o.veil(false)
        local ok,err=o.lift()
        o.log(string.format('arrival: lifted after %.1f s (%s)%s',took,why,
            ok and '' or string.format('; SB ends its black within %d s: %s',Arrival.LIFETIME,tostring(err))))
    end
    -- A warp into a lobby was asked. Under the hold (a guest's warp to her host's hall) the black and the veil stay,
    -- and the next controller puts up a new black.
    function self.arm() armed,restarted=clock(),false end
    -- PlayerController:ClientRestart, from its hook: the new world's controller, if a lobby warp waits for one.
    function self.restart() if armed then restarted=true end end
    -- Nothing more to wait for (the warp refused, coop off): a waiting warp dropped, a black up lifted now.
    function self.disarm(why)
        armed,restarted=nil,false
        if held then lift(why) end
    end
    function self.held() return held~=nil end
    -- Each 250 ms pass. missing() gives the words of what the lobby still waits for (empty once ready); read only
    -- while a black is up and no warp waits.
    function self.pass(missing)
        local now=clock()
        if armed and restarted then
            local since=now-armed
            armed,restarted=nil,false
            local ok,err=pcall(o.fade)
            if not ok then return o.log('arrival: SB\'s black not shown: '..tostring(err)) end
            if not held then o.veil(true) end
            held=now
            return o.log(string.format('arrival: SB\'s black up %.1f s after the lobby warp',since))
        end
        if armed and now-armed>=Arrival.ARM_CAP then
            armed=nil
            o.log(string.format('arrival: no new world %d s after the lobby warp: nothing held',Arrival.ARM_CAP))
            if held then lift('the lobby warp never arrived') end
            return
        end
        if not held or armed then return end
        local read,m=pcall(missing)
        if read and #m==0 then return lift('ready') end
        if now-held>=Arrival.CAP then
            lift(string.format('the %d s cap; missing: %s',Arrival.CAP,read and table.concat(m,', ') or tostring(m)))
        end
    end
    return self
end
return Arrival
