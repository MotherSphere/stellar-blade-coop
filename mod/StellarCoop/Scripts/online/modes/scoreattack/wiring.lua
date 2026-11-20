-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Score attack (online/modes/scoreattack/): its round on the Steam link (round.lua, M.scoreattack, nil
-- without the link), logging [SA] lines, and coop scoreattack. The host's draw reads the challenges the lobby's room
-- offers from online.lobby's sbo at each round's start; while that module is off its target is nothing, so the room
-- offers none and the host voids the round. Its 250 ms pass and the run itself come with the game side.
return {
uses={'online.lobby'},
exports={'scoreattack'},
new=function(M)
local Sa=require('online.modes.scoreattack.model')
local sbo=require('main.loader').view(M,'sbo')
M.scoreattack=M.link and require('online.modes.scoreattack.round').new({link=M.link,clock=os.clock,
    log=function(m) M.print('[StellarCoop][SA] '..tostring(m)..'\n') end,
    offered=function()
        local room=sbo.target()
        return room and Sa.offered(room)
    end})
return require('online.modes.scoreattack.commands').new({round=M.scoreattack})
end,
}
