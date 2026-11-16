-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game's text culture (GetCurrentLanguage) as 'fr' or 'en', the two cultures of quest/text.lua's TEXT and of
-- the talks' lines (matrix13/talks/): French for any French culture, else English.
return function(name) return require('nightop.recruiter_text').culture(name)=='fr' and 'fr' or 'en' end
