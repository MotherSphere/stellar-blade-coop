-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game's text culture pick, moved out of nightop/recruiter_text.lua; CULTURES holds its TEXT's names.
local CULTURES={ko=true,en=true,['en-GB']=true,fr=true,de=true,it=true,es=true,['es-MX']=true,pt=true,['pt-BR']=true,
    nl=true,da=true,no=true,sv=true,fi=true,pl=true,ru=true,tr=true,ar=true,th=true,ja=true,['zh-Hans']=true,
    ['zh-Hant']=true}
-- The game's text culture (GetCurrentLanguage) as one of TEXT's: its own name, else the game's fallbacks (en-* to
-- en-GB but en-US to en, es-* to es-MX but es-ES to es, zh by script or region, pt-BR, nb and nn to no), else the
-- base language, else English.
local function culture(name)
    if type(name)~='string' then return 'en' end
    if CULTURES[name] then return name end
    local lang,rest=name:match('^(%a+)%-?(.*)$')
    if not lang then return 'en' end
    lang,rest=lang:lower(),rest:upper()
    if lang=='zh' then
        return (rest:find('HANT',1,true) or rest=='TW' or rest=='HK' or rest=='MO') and 'zh-Hant' or 'zh-Hans'
    end
    if lang=='en' then return (rest=='' or rest=='US') and 'en' or 'en-GB' end
    if lang=='es' then return (rest=='' or rest=='ES') and 'es' or 'es-MX' end
    if lang=='pt' then return rest=='BR' and 'pt-BR' or 'pt' end
    if lang=='nb' or lang=='nn' then return 'no' end
    return CULTURES[lang] and lang or 'en'
end
return {culture=culture,CULTURES=CULTURES}
