-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Text helpers moved out of online/session/chat.lua, online/session/join.lua and online/group/travel.lua for every
-- module to read.
local Line={}
local MAX=200 -- Bytes a line.
local WIDE=70 -- Columns a row.
local NAME=16 -- Characters of a name shown.
local function control(c) -- C0, DEL, C1, and the bidi and zero-width controls.
    return c<0x20 or (c>=0x7F and c<=0x9F) or c==0x061C or (c>=0x200B and c<=0x200F) or (c>=0x2028 and c<=0x202E)
        or (c>=0x2060 and c<=0x206F) or c==0xFEFF
end
-- Spaces off both ends. Once the controls are gone only ASCII spaces are left to trim: no %s, which follows the C
-- locale (0xA0, the end of 'à', is a space in some code pages) and makes a pattern trim slow on long space runs.
local function trim(text)
    local first,last=text:find('[^ ]'),#text
    if not first then return '' end
    while text:byte(last)==32 do last=last-1 end
    return text:sub(first,last)
end
-- The line both players see: well-formed UTF-8 only (any other byte dropped), no controls, trimmed, at most 200
-- bytes, never cut inside a character. '' when nothing is left.
function Line.clean(text)
    local kept,at={},1
    while at<=#text do
        local _,bad=utf8.len(text,at)
        local stop=bad or #text+1 -- at..stop-1 is well-formed; the byte at stop is not.
        for _,c in utf8.codes(text:sub(at,stop-1)) do if not control(c) then kept[#kept+1]=utf8.char(c) end end
        at=stop+1
    end
    text=trim(table.concat(kept))
    if #text>MAX then
        local cut=MAX+1 -- Back to the first byte of the character the 201st byte belongs to.
        while text:byte(cut)>=0x80 and text:byte(cut)<0xC0 do cut=cut-1 end
        text=trim(text:sub(1,cut-1))
    end
    return text
end
-- Columns a character takes: an East Asian wide one (Chinese, Japanese, Korean) two, a combining mark none, any other
-- one, as ui/text_test.lua counts them.
local function columns(c)
    if c>=0x1100 and c<=0x115F or c>=0x2E80 and c<=0xA4CF or c>=0xAC00 and c<=0xD7A3 or c>=0xF900 and c<=0xFAFF
        or c>=0xFE30 and c<=0xFE4F or c>=0xFF00 and c<=0xFF60 or c>=0xFFE0 and c<=0xFFE6 then return 2 end
    if c>=0x300 and c<=0x36F or c>=0x64B and c<=0x65F or c==0x670 or c==0xE31 or c>=0xE34 and c<=0xE3A
        or c>=0xE47 and c<=0xE4E then return 0 end
    return 1
end
-- Rows of at most wide columns (WIDE unless said; the text is well-formed UTF-8), broken at the last space within
-- reach, else between two characters (Chinese, Japanese and Thai put no space between words). The break falls before
-- a character that takes a column, so a Thai or Arabic mark (no column) stays with the letter before it; between two
-- characters, never right after a Thai leading vowel (U+0E40 to U+0E44, written before the consonant it follows in
-- speech): the cut moves back before it, unless that would leave the row empty. The co-op saves' question and the
-- notice line wrap their text with it too.
local function wrap(text,wide)
    wide=wide or WIDE
    local rows={}
    while true do
        local n,cut=0,nil -- cut: the first byte of the first character past wide columns.
        for at,c in utf8.codes(text) do
            n=n+columns(c)
            if n>wide then cut=at; break end
        end
        if not cut then break end
        local space=text:sub(1,cut):match('.*() ')
        if space and space>1 then rows[#rows+1],text=text:sub(1,space-1),text:sub(space+1)
        else
            while cut>4 and text:sub(cut-3,cut-1):find('^\xE0\xB9[\x80-\x84]$') do cut=cut-3 end
            rows[#rows+1],text=text:sub(1,cut-1),text:sub(cut)
        end
    end
    rows[#rows+1]=text
    return rows
end
Line.wrap=wrap
-- Columns a text takes, as wrap counts them.
function Line.columns(text)
    local n=0
    for _,c in utf8.codes(text) do n=n+columns(c) end
    return n
end
-- A Steam name for the screen: cleaned as a chat line (a name may hold anything) with no < or > (SB's popup reads
-- its text as rich text, where they open a tag), at most 16 characters so the French title fits; nil when nothing is
-- left.
function Line.name(text)
    local name=Line.clean(((text or ''):gsub('[<>]','')))
    if name=='' then return nil end
    if utf8.len(name)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'...' end
    return name
end
-- The native part's join and leave notices that SB has words for: '<name> joined.' and '<name> was let in.' as
-- UI_Night_Message_ComeBackFriend ('{Name} has joined the game.'), '<name> left.' as UI_Night_Message_LeaveFriend
-- ('{Name} has left the game.'); the guest's 'Session ended: <host> left.' keeps its own words.
local FEED={{' joined%.$','UI_Night_Message_ComeBackFriend'},{' was let in%.$','UI_Night_Message_ComeBackFriend'},
    {' left%.$','UI_Night_Message_LeaveFriend'}}
-- A notice in SB's words, game=function(key) SB's word or nil: nil for any other notice, a nameless one, or when SB's
-- word is missing or has no {Name}.
function Line.feed(text,game)
    if text:find('^Session ended: ') then return nil end
    for _,f in ipairs(FEED) do
        local name=text:match('^(.+)'..f[1])
        if name then
            local line=game(f[2])
            if not (line and line:find('{Name}',1,true)) then return nil end
            return (line:gsub('{Name}',function() return name end))
        end
    end
end
-- The FName number UE splits off a name: a trailing _<digits> with no leading zero (or a lone 0), plus 1;
-- Xion_Camp_10 is Xion_Camp with 11, Xion_Camp_10_01 keeps its digits (0).
function Line.number(alias)
    local digits=alias:match('_(%d+)$')
    if digits and #digits<=10 and (#digits==1 or digits:sub(1,1)~='0') and tonumber(digits)<2147483647 then
        return math.tointeger(tonumber(digits)+1)
    end
    return 0
end
return Line
