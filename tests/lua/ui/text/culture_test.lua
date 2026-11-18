-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- ui/text/culture.lua: the game's 23 text cultures each as itself; culture()'s mapping of the names the game can
-- report, the cases of online/modes/nightop/recruiter_text_test.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local C=require('ui.text.culture')
local CULTURES={'ar','da','de','en','en-GB','es','es-MX','fi','fr','it','ja','ko','nl','no','pl','pt','pt-BR','ru',
    'sv','th','tr','zh-Hans','zh-Hant'}
local n=0
for _ in pairs(C.CULTURES) do n=n+1 end
assert(n==#CULTURES,n..' cultures, not 23')
for _,name in ipairs(CULTURES) do assert(C.CULTURES[name]==true and C.culture(name)==name,name) end
for _,case in ipairs({{'fr-FR','fr'},{'en-US','en'},{'en','en'},{'en-AU','en-GB'},{'en-GB','en-GB'},
        {'es-AR','es-MX'},{'es-ES','es'},{'zh-CN','zh-Hans'},{'zh-TW','zh-Hant'},{'zh-Hant-HK','zh-Hant'},
        {'pt-PT','pt'},{'pt-BR','pt-BR'},{'nb-NO','no'},{'xx-YY','en'},{'ko','ko'},{'','en'},{nil,'en'},{42,'en'},
        {'FR','fr'},{'fr-CA','fr'},{'es-419','es-MX'},{'zh','zh-Hans'},{'zh-HK','zh-Hant'},{'zh-MO','zh-Hant'},
        {'zh-Hans-CN','zh-Hans'},{'nn','no'},{'nn-NO','no'},{'-','en'},{'?','en'},{'pt-br','pt-BR'},{'EN','en'},
        {'ES','es'}}) do
    local got=C.culture(case[1])
    assert(got==case[2],string.format('culture(%s) is %s, not %s',tostring(case[1]),tostring(got),case[2]))
end
print('ui/text/culture_test: ok')
