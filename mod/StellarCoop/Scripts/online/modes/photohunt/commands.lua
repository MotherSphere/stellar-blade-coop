-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop photohunt: alone or with status, the round's state line (online/modes/photohunt/round.lua's status: our last
-- round, its clock, the board and the ranking); start [<minutes>] starts one on the host (15 minutes without a number,
-- 1 to 60); stop cancels it on the host. online/modes/photohunt/wiring.lua builds it with new(o) at each Lua load and
-- main/loader.lua merges it into the command table. o: round (nil without the Steam link).
local Commands={}
local USE='Use: coop photohunt [status | start [<minutes>] | stop]'
-- round.lua's reasons, in words.
local WHY={usage=USE,session='A photo hunt runs in an online session.',guest='Only the host starts a photo hunt.',
    alone='Nobody else is in the online session yet.',on='A photo hunt is already on.',
    off='Photo hunt is off in Options.',slot='Load a co-op save to play the photo hunt.',
    checks='Photo checks are off in this game.',read='Could not read the photo targets.',
    few='This map has fewer than 3 photo targets. Try Xion, the Wasteland or the Great Desert.',
    none='No photo hunt is on.'}
function Commands.new(o)
    local self={}
    function self.photohunt(sub,word,extra)
        if extra~=nil or (sub~='start' and word~=nil) or (sub~=nil and sub~='status' and sub~='start' and sub~='stop')
        then
            return false,USE
        end
        if not o.round then return false,'A photo hunt needs the Steam link.' end
        if sub=='start' then
            local ok,why=o.round.start(word)
            if not ok then return false,WHY[why] or why end
            return true,'photohunt: '..o.round.status()
        end
        if sub=='stop' then
            local ok,why=o.round.cancel()
            if not ok then return false,why=='guest' and 'Only the host stops a photo hunt.' or WHY[why] end
            return true,'photohunt: the photo hunt was cancelled'
        end
        return true,'photohunt: '..o.round.status()
    end
    return self
end
return Commands
