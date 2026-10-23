-- UE4SS-settings.ini's check, pure (no fakes): HookBeginPlay under [Hooks] and bUseUObjectArrayCache under [General],
-- each on when it reads 1, true, anything but 0 or false, or is missing from its section; names in any case, spaces
-- around '=', CRLF, a BOM, comment lines and a comment after the value; the last line wins; a text over LIMIT bytes is
-- not checked.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local S=require('core.ue4ss_settings')
-- The check's answer as one line, 'key=value' for each key on ('-' when missing), or 'nil <why>'.
local function on(text)
    local list,why=S.check(text)
    if not list then return 'nil '..why end
    local out={}
    for _,k in ipairs(list) do out[#out+1]=k.key..'='..(k.value or '-') end
    return table.concat(out,' ')
end

-- The Stellar Blade UE4SS 1.3 package's lines (its file pads HookBeginPlay with two spaces): both off.
local PACKAGE='[Overrides]\nModsFolderPath =\n\n[General]\n; Default: true\nbUseUObjectArrayCache = false\n\n'
    ..'[Hooks]\nHookProcessInternal = 1\nHookBeginPlay  = 0\nHookEndPlay  = 1\n'
assert(on(PACKAGE)=='',on(PACKAGE))
-- 1 or true, in any case, is on; each key keeps its notice's word.
local list=S.check('[Hooks]\nHookBeginPlay = 1\n[General]\nbUseUObjectArrayCache = True\n')
assert(#list==2 and list[1].key=='HookBeginPlay' and list[1].word=='hook' and list[1].value=='1')
assert(list[2].key=='bUseUObjectArrayCache' and list[2].word=='cache' and list[2].value=='True')
assert(on('[Hooks]\nHookBeginPlay=true\n[General]\nbUseUObjectArrayCache=FALSE\n')=='HookBeginPlay=true')
-- Missing: no line, no section, or the key under another section all leave UE4SS's default, on.
assert(on('')=='HookBeginPlay=- bUseUObjectArrayCache=-')
assert(on('[General]\nbUseUObjectArrayCache = false\n')=='HookBeginPlay=-')
assert(on('HookBeginPlay = 0\n[General]\nHookBeginPlay = 0\nbUseUObjectArrayCache = 0\n')=='HookBeginPlay=-',
    'A key before any section, or under another, is not the [Hooks] one')
-- Names in any case, spaces and tabs around, a BOM and CRLF (Notepad).
local crlf='\239\187\191[ hooks ]\r\n\thookbeginplay\t=\t0 \r\n[GENERAL]\r\nBUSEUOBJECTARRAYCACHE = 0\r\n'
assert(on(crlf)=='',on(crlf))
assert(on('\239\187\191[Hooks]\r\nHookBeginPlay = 1\r\n[General]\r\nbUseUObjectArrayCache = false')=='HookBeginPlay=1',
    'CRLF with no line end at the last line')
-- A comment line is no value; a comment after the value is not part of it.
assert(on('[Hooks]\n; HookBeginPlay = 0\n# HookBeginPlay = 0\n[General]\nbUseUObjectArrayCache = 0\n')
    =='HookBeginPlay=-')
assert(on('[Hooks]\nHookBeginPlay = 0 ; was 1\n[General]\nbUseUObjectArrayCache = false# off\n')=='')
-- The last line naming a key in its section wins, across a section opened again.
assert(on('[Hooks]\nHookBeginPlay = 0\nHookBeginPlay = 1\n[General]\nbUseUObjectArrayCache = 0\n')=='HookBeginPlay=1')
assert(on('[Hooks]\nHookBeginPlay = 1\n[General]\nbUseUObjectArrayCache = 0\n[Hooks]\nHookBeginPlay = 0\n')=='')
-- A value that is neither 0 nor false, empty included, counts as on.
assert(on('[Hooks]\nHookBeginPlay = 2\n[General]\nbUseUObjectArrayCache =\n')
    =='HookBeginPlay=2 bUseUObjectArrayCache=','Not 0 or false: on')
-- At most LIMIT bytes: one more is not checked (main.lua reads LIMIT+1 to tell).
assert(on(PACKAGE..(' '):rep(S.LIMIT-#PACKAGE))=='')
assert(on(PACKAGE..(' '):rep(S.LIMIT-#PACKAGE+1))=='nil over 65536 bytes')
print('ue4ss_settings_test ok')
