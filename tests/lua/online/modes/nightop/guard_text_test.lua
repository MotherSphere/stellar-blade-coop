-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/nightop/guard_text.lua over fakes: the native part's status text, the language library (its reads
-- counted; a nil language raises) and the asks. Covered: every culture's guardtext request (its seven lines in order,
-- under the native part's 2048 bytes, each line as core/line.lua's clean() leaves it, the twin of the native check);
-- nothing, not even a language read, without a guardtext= line or while it reads off; the game's language asked once
-- while the native part waits, fr-FR as fr, an unreadable one as en, asked again after a language change (back to one
-- asked before too); the TEXT=yes line once a culture; the fault line once, with no ask; a failed ask said once and not
-- asked again; after a Ctrl+R, nothing asked when the native part already holds the game's language. No log line holds
-- a line of his.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local language,reads='fr-FR',0
local function object(t)
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    return t
end
local objects={
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=object({GetCurrentLanguage=function()
        reads=reads+1
        return language or error('no language',0)
    end}),
}
StaticFindObject=function(path) return objects[path] end
local G=require('online.modes.nightop.guard_text')
local R=require('online.modes.nightop.recruiter_text')
local clean=require('core.line').clean

-- The request: the culture, then his seven lines in G.LINES's order, each after a tab, each one the native part keeps.
assert(table.concat(G.LINES,',')=='T,Q,J,C,A1,A2,A3')
for c,t in pairs(R.TEXT) do
    assert(G.request(c)=='guardtext '..c..'\t'..t.T..'\t'..t.Q..'\t'..t.J..'\t'..t.C..'\t'..t.A1..'\t'..t.A2..'\t'..
        t.A3,c)
    assert(#G.request(c)<2048,c..': over the native part\'s 2048 bytes')
    for _,k in ipairs(G.LINES) do assert(t[k]==clean(t[k]),c..'.'..k..': not as clean() leaves it') end
end

local status,asks,lines=nil,{},{}
-- A guard_text whose ask succeeds (said holds the line, as core/link.lua's does) or gives ok, why.
local function new(ok,why)
    asks,lines={},{}
    return G.new({log=function(m) lines[#lines+1]=m end,status=function() return status end,
        ask=function(line)
            asks[#asks+1]=line
            if ok==false then return false,why end
            return true,'asked the native part: '..line
        end})
end
local g=new()
status=nil; g.tick()
status='engine=on\n'; g.tick()
assert(#asks==0 and #lines==0 and reads==0,'Nothing without a guardtext= line, not even a language read')
status,language='guardtext=wait\n','fr-FR'; g.tick()
assert(#asks==1 and asks[1]==G.request('fr'),tostring(asks[1]))
assert(#lines==1 and lines[1]=='text: game language fr-FR -> fr: his 7 lines asked of the native part',lines[1])
g.tick(); assert(#asks==1 and #lines==1,'Asked and said once')
status='guardtext=ready fr\n'; g.tick()
assert(#lines==2 and lines[2]=='text: the native part wrote his 12 texts in fr: TEXT=yes',lines[2])
g.tick(); assert(#asks==1 and #lines==2,'Said once')
language='de'; g.tick()
assert(#asks==2 and asks[2]==G.request('de'),'A language change asks again')
assert(#lines==3 and lines[3]=='text: game language de -> de: his 7 lines asked of the native part',lines[3])
status='guardtext=ready de\n'; g.tick()
assert(#lines==4 and lines[4]=='text: the native part wrote his 12 texts in de: TEXT=yes',lines[4])
language='fr'; g.tick()
assert(#asks==3 and asks[3]==G.request('fr'),'Back to a language asked before: asked again')
assert(#lines==5 and lines[5]=='text: game language fr -> fr: his 7 lines asked of the native part',lines[5])
status='guardtext=fault StellarCoop.dll+0x10\n'; g.tick(); g.tick()
assert(#asks==3 and #lines==6 and lines[6]=='STOP: text: the native part stopped at a fault (StellarCoop.dll+0x10): '
    ..'his texts stay as they are until the game restarts: TEXT=no',lines[6])
local read=reads
status='guardtext=off\n'; g.tick()
assert(#asks==3 and #lines==6 and reads==read,'Nothing while it reads off')

-- A language the library cannot give: English, its error never mapped.
g=new()
status,language='guardtext=wait\n',nil; g.tick()
assert(#asks==1 and asks[1]==G.request('en'),tostring(asks[1]))
assert(#lines==1 and lines[1]=='text: game language ? -> en: his 7 lines asked of the native part',lines[1])

-- An ask that fails: said once, with its reason, and not asked again.
g=new(false,'cannot write coop-request.txt')
language='fr'; g.tick()
assert(#asks==1 and #lines==1 and lines[1]=='STOP: text: game language fr -> fr: the request failed (cannot write '
    ..'coop-request.txt): TEXT=no',lines[1])
g.tick(); assert(#asks==1 and #lines==1,'Not asked again')

-- A Ctrl+R while the native part holds the game's language: nothing asked.
g=new()
status,language='guardtext=ready fr\n','fr'; g.tick(); g.tick()
assert(#asks==0 and #lines==1 and lines[1]=='text: the native part wrote his 12 texts in fr: TEXT=yes',lines[1])
print('guard_text_test ok')
