-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The co-op saves' wiring (online/saves/): the co-op saves' question on the title screen and their commands.
return {
uses={},
exports={'saves_ui'},
new=function(M)
local print,log=M.print,M.log
return require('online.saves.commands').new({ask=M.ask,settings=M.settings})
end,
build={
saves=function(M,Ui)
    M.saves_ui=M.guide.front(require('online.saves.saves').new({kit=M.kit,link=M.link,settings=M.settings,
        theme=Ui.THEME,
        say=M.say,log=M.log,wait=M.guide.waiting}))
end,
},
}
