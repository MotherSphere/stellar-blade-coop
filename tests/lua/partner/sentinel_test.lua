-- partner/sentinel.lua with fake files: the marker written before a call with a declared mod asset and emptied after
-- it, whether it returns or raises, never for another path or inside another call's span; a marker left full by the
-- last Lua load sets that asset aside (logged by main.lua), on the list under the mod's version; a list of another
-- version dropped; reset; no files, nothing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Sentinel=require('partner.sentinel')
local SUIT,MAT,GAME='/Game/OutfitMods/Foo/SK_Foo.SK_Foo','/Game/OutfitMods/Foo/MI_Foo.MI_Foo','/Game/Art/X/Y.Y'
local disk,writes={},{} -- writes: each write_now, in order.
local cns={[SUIT]='Foo_Suit',[MAT]='Foo_Suit'}
local files={read_file=function(name) return disk[name] end,
    write_file=function(name,text) disk[name]=text; return true end,
    write_now=function(name,text) disk[name]=text; writes[#writes+1]=text; return true end,
    cns_assets=function() return cns end}
-- Nothing on disk: nothing set aside, nothing written.
local s,crashed=Sentinel.new(files,'v1')
assert(crashed==nil and next(disk)==nil and #writes==0)
-- A call with a declared asset: marked while it runs, emptied after; its results returned.
local during
local a,b=s.call(SUIT,function(x) during=disk[Sentinel.MARKER]; return x,2 end,1)
assert(a==1 and b==2 and during==SUIT..' Foo_Suit\n' and disk[Sentinel.MARKER]=='' and #writes==2,tostring(during))
-- A game asset or an undeclared one: no write.
s.call(GAME,function() during=disk[Sentinel.MARKER] end)
s.call('/Game/Mods/Other/X.X',function() end)
assert(#writes==2 and during=='')
-- An error inside: the marker emptied all the same, the error raised again as it was.
local ok,why=pcall(s.call,MAT,function() error('no material',0) end)
assert(not ok and why=='no material' and disk[Sentinel.MARKER]=='' and #writes==4,tostring(why))
-- A call inside another's span keeps the outer marker: two writes, not four.
s.call(SUIT,function() s.call(MAT,function() during=disk[Sentinel.MARKER] end) end)
assert(during==SUIT..' Foo_Suit\n' and #writes==6 and disk[Sentinel.MARKER]=='')
-- The game died inside a call: the next load sets that asset aside, empties the marker and says which.
disk[Sentinel.MARKER]=SUIT..' Foo_Suit\n'
s,crashed=Sentinel.new(files,'v1')
assert(crashed and crashed.path==SUIT and crashed.outfit=='Foo_Suit' and disk[Sentinel.MARKER]=='')
assert(s.aside(SUIT)=='Foo_Suit' and not s.aside(MAT))
assert(disk[Sentinel.LIST]=='version v1\n'..SUIT..' Foo_Suit\n',disk[Sentinel.LIST])
-- Kept across loads; a second crash adds to it, once each.
disk[Sentinel.MARKER]=MAT..' Foo_Suit\n'
s,crashed=Sentinel.new(files,'v1')
assert(crashed.path==MAT and s.aside(SUIT) and s.aside(MAT) and #s.list()==2)
disk[Sentinel.MARKER]=MAT..' Foo_Suit\n'
s=Sentinel.new(files,'v1')
assert(#s.list()==2 and s.list()[1].path==SUIT and s.list()[2].path==MAT)
-- An empty marker (a crash outside every call): nothing set aside, nothing written.
local list_before=disk[Sentinel.LIST]
disk[Sentinel.MARKER]=''
writes={}
s,crashed=Sentinel.new(files,'v1')
assert(crashed==nil and #writes==0 and disk[Sentinel.LIST]==list_before and #s.list()==2)
-- Another version of the mod: the list dropped, on disk too.
s=Sentinel.new(files,'v2')
assert(not s.aside(SUIT) and #s.list()==0 and disk[Sentinel.LIST]=='version v2\n',disk[Sentinel.LIST])
-- reset empties it and says how many it held.
disk[Sentinel.MARKER]=SUIT..' Foo_Suit\n'
s=Sentinel.new(files,'v2')
assert(s.reset()==1 and not s.aside(SUIT) and disk[Sentinel.LIST]=='version v2\n')
s=Sentinel.new(files,'v2')
assert(#s.list()==0,'Reset stays reset')
-- No files (no native part): calls run plain, nothing set aside.
s,crashed=Sentinel.new(nil,'v1')
assert(crashed==nil and s.call(SUIT,function() return 7 end)==7 and not s.aside(SUIT) and s.reset()==0)
print('sentinel_test ok')
