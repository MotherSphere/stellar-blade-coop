-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The release gate: a settings text (coop-settings.txt's lines) and gun mode's defaults checked for test bindings and
-- debug flags before a build goes to a player (a left-mouse aim binding left over from testing reached the user's
-- build, 2026-11-18). Pure Lua (no game calls), so the deploy tool runs it outside the game too:
--   texlua release_check.lua <settings file>      exit 0 when clean, 1 with the problems listed
local Check={}

-- Settings that only testing uses (must be absent), and settings a release may carry only at one value.
Check.TEST_ONLY={'gun_facts','gun_g0','gun_g1','gun_g1_tag','gun_trace','gun_bs','gun_upper','gun_fire_key','gun_carry_ovr','gun_carry_spare','gun_carry_idle',
    'gun_carry_row'}
Check.RELEASE_VALUE={gun_probe='off',gun_aim_key='RightMouseButton'}
-- Words in a default's name that mark a debug flag.
Check.FLAG_WORDS={'debug','trace','probe','test','dev'}

-- text: the settings text (key=value lines, # comments); defaults: Config.DEFAULTS or nil. Returns ok, problems.
function Check.run(text,defaults)
    local bad={}
    local test={}
    for _,k in ipairs(Check.TEST_ONLY) do test[k]=true end
    for line in (text or ''):gmatch('[^\r\n]+') do
        local k,v=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if k and not line:match('^%s*[#;]') then
            if test[k] then
                bad[#bad+1]=('setting %s=%s (test only)'):format(k,v)
            elseif Check.RELEASE_VALUE[k] and v~=Check.RELEASE_VALUE[k] then
                bad[#bad+1]=('setting %s=%s (release value %s)'):format(k,v,Check.RELEASE_VALUE[k])
            end
        end
    end
    for k,v in pairs(defaults or {}) do
        if type(v)=='boolean' and v then
            for _,w in ipairs(Check.FLAG_WORDS) do
                if tostring(k):lower():find(w,1,true) then bad[#bad+1]=('default %s=true (debug flag)'):format(k) end
            end
        end
    end
    return #bad==0,bad
end

-- Run as a script: check a settings file.
if arg and arg[0] and arg[0]:match('release_check%.lua$') then
    local f=arg[1] and io.open(arg[1],'r')
    local text=f and f:read('a') or ''
    if f then f:close() end
    local ok,bad=Check.run(text,nil)
    if ok then print('release check: clean') os.exit(0) end
    print('release check FAILED:')
    for _,b in ipairs(bad) do print('  '..b) end
    os.exit(1)
end

return Check
