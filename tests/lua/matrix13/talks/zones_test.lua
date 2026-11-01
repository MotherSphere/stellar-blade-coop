-- Matrix XIII's zone talks (matrix13/talks/zone1.lua to zone4.lua), merged: each scene once, in the zone file its
-- number names.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local ZONES={}
for z=1,4 do
    for name,lines in pairs(require('matrix13.talks.zone'..z)) do
        assert(name:sub(1,1)==tostring(z) and not ZONES[name],name)
        ZONES[name]=lines
    end
end
-- The zone talks: every line has a speaker, an English and a French line; 168 lines in 36 scenes from 1A to 4N (3E was cut).
do
    local n,scenes,keys=0,0,{Seq_Actor_Lily=1,Seq_Actor_EVE=1,Seq_Actor_Announcement=1,Noa=1,Yohan=1,Mila=1}
    for name,lines in pairs(ZONES) do
        scenes=scenes+1
        assert(name:match('^[1-4]%u$'),name)
        for _,l in ipairs(lines) do
            n=n+1
            assert(keys[l[1]] and type(l[2])=='string' and #l[2]>0 and type(l[3])=='string' and #l[3]>0,name)
        end
    end
    assert(n==168 and scenes==36,n..' lines, '..scenes..' scenes')
    assert(ZONES['3B'][8].oblivion and not ZONES['3B'][7].oblivion,'Noa knows EVE only after Oblivion')
end
print('matrix13/talks/zones_test: ok')
