-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Fishing tournament (online/modes/fishing/): new, it builds nothing yet. To fill in: what new builds and
-- sets in M (each field in exports), the modules it reads later through M (in uses) and its kit groups in build, as
-- docs/dev/structure.md (The manifest) says.
return {
uses={},
exports={},
new=function(M)
return require('online.modes.fishing.commands').new({})
end,
}
