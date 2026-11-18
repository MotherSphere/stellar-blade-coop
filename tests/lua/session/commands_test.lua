-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- session/commands.lua over a fake link: coop host with a word hosts at once with it, ask added under public and
-- invitation while friends_ask=on; coop host alone opens the Create a session screen when it opens, else hosts as
-- who_can_join says; any other word is refused. coop list public|friends asks for a search; coop list alone numbers
-- the last list's rows, or searches the Public sessions when there is none; coop join <row> joins that row's lobby,
-- a lobby id and a join code as before.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Session=require('session.commands')
local Link=require('core.link')
local asked={}
local search,rows=nil,{} -- What link.list() says.
local link={request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    list=function() return search,rows end,valid_lobby=Link.new('C:\\Mod',{}).valid_lobby,join_code=Link.join_code}
local settings=Link.parse_settings('')
local screen=nil -- What o.create() gives: the Create a session screen once built.
local s=Session.new({link=link,settings=settings,
    ask=function(line) return function() return link.request(line) end end,create=function() return screen end})

-- coop host <word>: at once, as the native part takes the word.
for _,word in ipairs({'public','friends','invitation','closed'}) do
    assert(s.host(word) and asked[#asked]=='host '..word..' 4',word)
end
-- friends_ask=on: Steam friends wait too, under public and invitation only.
settings.friends_ask=true
for word,line in pairs({public='host public ask 4',invitation='host invitation ask 4',friends='host friends 4',
    closed='host closed 4'}) do
    assert(s.host(word) and asked[#asked]==line,word)
end
-- Any other word, or a second one, is refused; nothing asked.
local n=#asked
for _,bad in ipairs({{'code'},{'private'},{'Public'},{'public','ask'}}) do
    local ok,why=s.host(table.unpack(bad))
    assert(not ok and why=='Use: coop host [public|friends|invitation|closed]' and #asked==n,bad[1])
end
-- coop host alone: who_can_join's word with no screen, or a screen that does not open now; the screen once it opens.
-- max_players ends the line: the lobby's room.
settings.friends_ask,settings.who_can_join,settings.max_players=false,'invitation',3
assert(s.host() and asked[#asked]=='host invitation 3')
local opens=0
screen={open=function() opens=opens+1; return nil end}
assert(s.host() and asked[#asked]=='host invitation 3' and #asked==n+2 and opens==1,'It cannot open: hosts at once')
screen.open=function() opens=opens+1; return true,'Create a session opened' end
local ok,message=s.host()
assert(ok and message=='Create a session opened' and #asked==n+2 and opens==2,'Opened: nothing hosted')
assert(s.host('closed') and asked[#asked]=='host closed 3' and opens==2,'A word never opens the screen')

-- coop list: a search by its tab; alone, the Public one while there is no list.
assert(s.list('friends') and asked[#asked]=='list friends' and s.list('public') and asked[#asked]=='list public')
asked={}
assert(s.list() and asked[1]=='list public','No list yet: the Public sessions searched')
for _,bad in ipairs({{'all'},{'public','x'}}) do
    local ok,why=s.list(table.unpack(bad))
    assert(not ok and why=='Use: coop list [public|friends]' and #asked==1)
end
-- A list: its rows numbered, nothing asked.
search={tab='public',state='searching',rows=0}
ok,message=s.list()
assert(ok and message=='list public searching, 0 rows' and #asked==1,message)
search={tab='friends',state='done',rows=2}
rows={{lobby='900',owner='76561198000000009',players='1/2',ping=45,pal=true,zone='b07',camp='WLB10_Camp_01',
    rules='ebwqr200',name='Kaanta'},{lobby='901',owner='7',players='1/2',pal=false,name=''}}
ok,message=s.list()
assert(ok and message=='list friends done, 2 rows: 1. Kaanta 1/2 45 ms b07 WLB10_Camp_01 rules ebwqr200 (Steam friend)'
    ..' | 2. ? 1/2 - ms -' and #asked==1,message)
-- coop join <row>: that row's lobby; a row the list lacks is refused; a lobby id and a code as before.
assert(s.join('2') and asked[#asked]=='join 901' and s.join('01') and asked[#asked]=='join 900')
for _,bad in ipairs({'3','0','99'}) do
    ok,message=s.join(bad)
    assert(not ok and message=='the session list has no row '..bad..': coop list shows it' and #asked==3,bad)
end
assert(s.join('109775241234567890') and asked[#asked]=='join 109775241234567890')
assert(s.join('0cs-cbmh') and asked[#asked]=='join 0CS-CBMH' and s.join() and asked[#asked]=='join')
print('session_commands_test ok')
