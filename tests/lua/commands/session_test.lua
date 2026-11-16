-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- commands/session.lua over a fake link: coop host with a word hosts at once with it, ask added under public and
-- invitation while friends_ask=on; coop host alone opens the Create a session screen when it opens, else hosts as
-- who_can_join says; any other word is refused.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Session=require('commands.session')
local Link=require('core.link')
local asked={}
local link={request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end}
local settings=Link.parse_settings('')
local screen=nil -- What o.create() gives: the Create a session screen once built.
local s=Session.new({link=link,settings=settings,
    ask=function(line) return function() return link.request(line) end end,create=function() return screen end})

-- coop host <word>: at once, as the native part takes the word.
for _,word in ipairs({'public','friends','invitation','closed'}) do
    assert(s.host(word) and asked[#asked]=='host '..word,word)
end
-- friends_ask=on: Steam friends wait too, under public and invitation only.
settings.friends_ask=true
for word,line in pairs({public='host public ask',invitation='host invitation ask',friends='host friends',
    closed='host closed'}) do
    assert(s.host(word) and asked[#asked]==line,word)
end
-- Any other word, or a second one, is refused; nothing asked.
local n=#asked
for _,bad in ipairs({{'code'},{'private'},{'Public'},{'public','ask'}}) do
    local ok,why=s.host(table.unpack(bad))
    assert(not ok and why=='Use: coop host [public|friends|invitation|closed]' and #asked==n,bad[1])
end
-- coop host alone: who_can_join's word with no screen, or a screen that does not open now; the screen once it opens.
settings.friends_ask,settings.who_can_join=false,'invitation'
assert(s.host() and asked[#asked]=='host invitation')
local opens=0
screen={open=function() opens=opens+1; return nil end}
assert(s.host() and asked[#asked]=='host invitation' and #asked==n+2 and opens==1,'It cannot open: hosts at once')
screen.open=function() opens=opens+1; return true,'Create a session opened' end
local ok,message=s.host()
assert(ok and message=='Create a session opened' and #asked==n+2 and opens==2,'Opened: nothing hosted')
assert(s.host('closed') and asked[#asked]=='host closed' and opens==2,'A word never opens the screen')
print('commands_session_test ok')
