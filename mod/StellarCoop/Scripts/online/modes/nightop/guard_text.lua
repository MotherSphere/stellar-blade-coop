-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Xion guard's lines (coop recruiter's, online/modes/nightop/recruiter_text.lua) in the game's language: one
-- culture's seven lines go to the native part (online/modes/nightop/guard_text.h) as one guardtext request, and it
-- writes them into the game's text manager under his 12 text keys. Asked again when the game's language changes. coop
-- off: main.lua stops ticking this, and the native part puts his Korean sources back. No log line holds one of his
-- lines.
local U=require('core.unreal')
local R=require('online.modes.nightop.recruiter_text')
local G={}
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
G.LINES={'T','Q','J','C','A1','A2','A3'} -- The request's order (guard_text.h's Lines).
-- 'guardtext <culture>' then each of the culture's lines, each after a tab.
function G.request(culture)
    local parts={'guardtext '..culture}
    for _,k in ipairs(G.LINES) do parts[#parts+1]=R.TEXT[culture][k] end
    return table.concat(parts,'\t')
end
-- o.log(text) writes an [RC] line; o.status() the native part's status text, or nil; o.ask(line) its request, giving
-- ok, said (said holds the line on success: never logged).
function G.new(o)
    local asked=nil -- The culture last asked in this Lua load: a refused or lost ask is not repeated every tick.
    local said=nil -- The last outcome line: each one is logged once until it changes.
    local function say(line)
        if line~=said then said=line; o.log(line) end
    end
    -- Every 250 ms, until coop off.
    local function tick()
        local state=('\n'..(o.status() or '')):match('\nguardtext=([^\r\n]*)')
        if not state or state=='off' then return end
        local where=state:match('^fault ?(.*)$')
        if where then
            return say('STOP: text: the native part stopped at a fault ('..(where~='' and where or '?')..'): his texts '
                ..'stay as they are until the game restarts: TEXT=no')
        end
        local read,raw=pcall(function() return U.text(U.find(LANGUAGE):GetCurrentLanguage()) end)
        local want=R.culture(read and raw or nil) -- Never the error's text: "no language" would read as no.
        if state=='ready '..want then return say('text: the native part wrote his 12 texts in '..want..': TEXT=yes') end
        if want==asked then return end
        asked=want
        local ok,why=o.ask(G.request(want))
        local from=string.format('text: game language %s -> %s: ',read and U.word(raw,16) or '?',want)
        if ok then return say(from..'his 7 lines asked of the native part') end
        say('STOP: '..from..'the request failed ('..(tostring(why):gsub('[^ -~]','_')):sub(1,120)..'): TEXT=no')
    end
    return {tick=tick}
end
return G
