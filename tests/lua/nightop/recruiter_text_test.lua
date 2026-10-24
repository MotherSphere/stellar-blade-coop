-- nightop/recruiter_text.lua, pure (no fakes): exactly the game's 23 text cultures, each with exactly the recruiter's 7
-- lines; every line one clean UTF-8 string the subtitle and choice widgets can show as it is (no control, invisible
-- format or rich-text character, no format brace, nothing outside the BMP, no edge space); no Korean and no developer
-- marker outside ko;
-- the French no-break space; the 12 keys, their lines and their Korean sources against a copy of the asset text kept
-- here; and culture()'s mapping of the names the game can report.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local R=require('nightop.recruiter_text')
local CULTURES={'ko','en','en-GB','fr','de','it','es','es-MX','pt','pt-BR','nl','da','no','sv','fi','pl','ru','tr','ar',
    'th','ja','zh-Hans','zh-Hant'}
local LINES={'T','Q','J','C','A1','A2','A3'}
-- t's keys are exactly list's: none missing, none extra.
local function exactly(t,list,what)
    local want={}
    for _,k in ipairs(list) do
        want[k]=true
        assert(t[k]~=nil,what..': no '..k)
    end
    for k in pairs(t) do assert(want[k],what..': an extra '..tostring(k)) end
end
local function hangul(cp) return cp>=0x1100 and cp<=0x11FF or cp>=0x3130 and cp<=0x318F or cp>=0xAC00 and cp<=0xD7A3 end
-- Unicode White_Space without its controls, which are refused everywhere.
local function space(cp)
    return cp==0x20 or cp==0xA0 or cp==0x1680 or cp>=0x2000 and cp<=0x200A or cp==0x202F or cp==0x205F or cp==0x3000
end
-- Invisible format characters a pasted line can carry (soft hyphen, zero widths, bidi marks and overrides, line and
-- paragraph separators, BOM): no line needs one, and the widgets would show a box, a break or reversed text.
local function invisible(cp)
    return cp==0xAD or cp==0x61C or cp>=0x200B and cp<=0x200F or cp>=0x2028 and cp<=0x202E
        or cp>=0x2060 and cp<=0x206F or cp==0xFEFF
end
assert(#CULTURES==23)
exactly(R.TEXT,CULTURES,'TEXT')
for culture,lines in pairs(R.TEXT) do
    exactly(lines,LINES,culture)
    for line,s in pairs(lines) do
        local at=culture..'.'..line
        assert(type(s)=='string' and s~='',at..': not a non-empty string')
        assert(utf8.len(s),at..': not valid UTF-8')
        assert(not s:find('[<>{}]'),at..': < > { or }')
        assert(not s:find('임시',1,true) and not s:find('멀티',1,true),at..': a developer marker')
        local first,last
        for _,cp in utf8.codes(s) do
            assert(cp>=0x20 and (cp<0x7F or cp>0x9F) and cp<=0xFFFF and not invisible(cp),
                string.format('%s: U+%04X',at,cp))
            assert(culture=='ko' or not hangul(cp),at..': Hangul outside ko')
            first,last=first or cp,cp
        end
        assert(not space(first) and not space(last),at..': a space at an edge')
    end
end
assert(R.TEXT.fr.Q:sub(-3)=='\u{A0}?','fr.Q: no no-break space before "?"')

-- The asset's keys with the line each one shows and its source, kept apart from the module: a key on the wrong line
-- shows another line's text (the question reading "Good luck."), and a registration whose source differs is undone
-- by the engine.
local SOURCES={
    ['1369C3D149FBA96B3A868A8DDB37F6DB']={'T','자이온 모병관'},
    ['90E21C7C499D1388F4FE8398516ADE70']={'T','자이온 모병관'},
    ['1D919BC54814EE9DEA9B86A353B9FB1A']={'T','(임시) 자이온 모병관'},
    ['845B85444BEB4A1DC834AC970B04E051']={'T','자이온 모병관'},
    ['4ED6720D4C01A463E14958BA0EFD74F3']={'Q','야간작전에 참여하시겠습니까?'},
    ['782D3CF24282FF4209C210AD8B19578C']={'J','(임시) 야간작전에 참여한다(멀티플레이 참여)'},
    ['1EC542C44399E9B5B68A5281A10096DA']={'J','(임시) 야간작전에 참여한다(멀티플레이 참여)'},
    ['17655DF64FCD86F91529FDB6E28F85DA']={'C','(임시) 취소'},
    ['8684A0504021287B7FB80FA6BDE723B6']={'C','(임시) 취소'},
    ['D0D5606146CF2F72244711A2943E8E11']={'A1','행운을 빕니다.'},
    ['D476C7694FDE4C24A96661809D99F648']={'A2','(임시) 준비가 되면 다시 알려주세요.'},
    ['9B0147424996337B530492A5E2F71030']={'A3','(임시) 현재 네트워크 연결이 불가능합니다. 옵션에서 활성 해주세요'},
}
local n=0
for key,entry in pairs(R.KEYS) do
    n=n+1
    local want=SOURCES[key]
    assert(want,tostring(key)..': not one of the asset\'s keys')
    local fields=0
    for _ in pairs(entry) do fields=fields+1 end
    assert(fields==2,key..': not {line, source}')
    assert(entry[1]==want[1],key..': on line '..tostring(entry[1])..', not '..want[1])
    assert(entry[2]==want[2],key..': its source is not the asset\'s')
end
assert(n==12,n..' keys, not 12')

for _,name in ipairs(CULTURES) do assert(R.culture(name)==name,name) end
for _,case in ipairs({{'fr-FR','fr'},{'en-US','en'},{'en','en'},{'en-AU','en-GB'},{'en-GB','en-GB'},
        {'es-AR','es-MX'},{'es-ES','es'},{'zh-CN','zh-Hans'},{'zh-TW','zh-Hant'},{'zh-Hant-HK','zh-Hant'},
        {'pt-PT','pt'},{'pt-BR','pt-BR'},{'nb-NO','no'},{'xx-YY','en'},{'ko','ko'},{'','en'},{nil,'en'},{42,'en'},
        {'FR','fr'},{'fr-CA','fr'},{'es-419','es-MX'},{'zh','zh-Hans'},{'zh-HK','zh-Hant'},{'zh-MO','zh-Hant'},
        {'zh-Hans-CN','zh-Hans'},{'nn','no'},{'nn-NO','no'},{'-','en'},{'?','en'},{'pt-br','pt-BR'},{'EN','en'},
        {'ES','es'}}) do
    local got=R.culture(case[1])
    assert(got==case[2],string.format('culture(%s) is %s, not %s',tostring(case[1]),tostring(got),case[2]))
end
print('recruiter_text_test ok')
