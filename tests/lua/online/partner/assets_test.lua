-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/partner/assets.lua with fake slot files and a fake LoadAsset: one loader for every ghost slot, one load each
-- 0.25 s for all of them, a path two slots name loaded once, a slot's loaded line once all its paths are in, each
-- object of the wrong class refused, a collected one loaded again with a new line (one whose address went to another
-- object of its class too), a failed load said once and not
-- tried again, a mod's path only when both players have it (through the crash sentinel), the slot's names read again
-- from 0 after a reset, a kind the slot does not want never loaded, a path checked as each class a key names it,
-- unwatch() keeping the loaded file and off() removing it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local next_address=0x1000
local function object(name,class)
    next_address=next_address+0x100
    local at=next_address
    local o={name=name,class=class}
    function o.type() return 'UObject' end
    function o.IsValid(self) return not self.dead end
    function o.GetAddress() return at end
    function o.GetClass(self) assert(not self.dead,'GetClass on a collected object') return self.class end
    function o.GetFullName(self)
        assert(not self.dead,'GetFullName on a collected object')
        return (self.class and self.class.name or 'Class')..' '..self.name
    end
    function o.IsA(self,c) return self.class==c or self.class.super==c end
    return o
end
local classes={}
for _,path in ipairs({'/Script/Engine.SoundBase','/Script/Engine.SoundClass','/Script/Engine.SoundAttenuation',
    '/Script/Niagara.NiagaraSystem','/Script/Engine.ParticleSystem','/Script/Engine.Texture2D'}) do
    classes[path]=object(path)
end
classes.cue=object('/Script/Engine.SoundCue')
classes.cue.super=classes['/Script/Engine.SoundBase']
StaticFindObject=function(path) return classes[path] or object('missing') end
-- What each path loads as: a sound cue, a sound class, a texture (a wrong class for a sound).
local kinds={['/Game/Sound/A.A']=classes.cue,['/Game/Sound/B.B']=classes.cue,
    ['/Game/Sound/C/PC.PC']=classes['/Script/Engine.SoundClass'],['/Game/Mods/X/Y.Y']=classes.cue,
    ['/Game/Art/FX/D.D']=classes['/Script/Niagara.NiagaraSystem'],
    ['/Game/Art/T/Tex.Tex']=classes['/Script/Engine.Texture2D'],
    ['/Game/Art/FX/E.E']=classes['/Script/Niagara.NiagaraSystem']}
local loads,loads_of,objects,fail_next=0,{},{},false
LoadAsset=function(path)
    loads=loads+1
    loads_of[path]=(loads_of[path] or 0)+1
    if fail_next then fail_next=false; return nil end
    objects[path]=object(path,kinds[path])
    return objects[path]
end
local sentinel_calls,marked=0,nil
local sentinel={call=function(path,f,...)
    sentinel_calls=sentinel_calls+1
    marked=path
    local r=table.pack(f(...))
    marked=nil
    return table.unpack(r,1,r.n)
end,aside=function(path) return path=='/Game/Sound/Aside.Aside' end}
local shared={}
-- A slot's files as core/link.lua gives them: names(from) the text past byte from and the offset after it (false: the
-- file is shorter, the slot was reset), loaded(line) appended, loaded(nil) removes the file.
local function slot_files()
    local s={text='',appended={}}
    s.names=function(from)
        if #s.text<from then return false end
        return s.text:sub(from+1),#s.text
    end
    s.loaded=function(line)
        if line==nil then s.removed=true; s.appended={}; return true end
        s.appended[#s.appended+1]=line
        return true
    end
    return s
end
local Assets=require('online.partner.assets')
local a=Assets.new(sentinel,function(path) return shared[path] end)
local said=0
local function at(t)
    clock=t
    if a.tick() then said=said+1 end
end
local slot={slot_files(),slot_files()}
slot[1].text='name 1 sound /Game/Sound/A.A - - -\nname 2 sound /Game/Sound/B.B /Game/Sound/C/PC.PC - -\n'
    ..'name 3 sound /Game/Mods/X/Y.Y - - -\n'
slot[2].text='name 1 sound /Game/Sound/B.B /Game/Sound/C/PC.PC - -\n'
a.watch(1,slot[1])
a.watch(2,slot[2])
at(0)
at(0.1)
assert(loads==1,'one load each 0.25 s for every slot together')
assert(slot[1].appended[1]:match('^loaded 1 0x%x+ 0x%x+ 0x0 0x0$'),slot[1].appended[1])
at(0.25)
at(0.5)
at(0.75)
assert(loads==3 and loads_of['/Game/Sound/B.B']==1 and loads_of['/Game/Sound/C/PC.PC']==1,
    'a path two slots name loads once')
assert(slot[1].appended[2]:match('^loaded 2 0x%x+ 0x%x+ 0x%x+ 0x0$') and #slot[2].appended==1,slot[1].appended[2])
assert(slot[2].appended[1]:match('^loaded 1 ')=='loaded 1 ','her key 1 is slot 2\'s own')
local b=objects['/Game/Sound/B.B']
assert(slot[2].appended[1]==string.format('loaded 1 0x%x 0x%x 0x%x 0x0',b.GetAddress(),classes.cue.GetAddress(),
    objects['/Game/Sound/C/PC.PC'].GetAddress()),'the object, its class and its sound class')
assert(not loads_of['/Game/Mods/X/Y.Y'],'a mod path neither of you shares is never loaded')
objects['/Game/Sound/A.A'].dead=true
for i=1,4 do at(0.75+i*0.25) end
assert(loads_of['/Game/Sound/A.A']==2 and slot[1].appended[3]:match('^loaded 1 '),'collected: loaded again, a new line')
assert(#slot[1].appended==3 and #slot[2].appended==1,'only the slot naming it')
fail_next=true
slot[1].text=slot[1].text..'name 4 niagara /Game/Art/FX/D.D - -\n'
at(2)
at(2.25)
at(2.5)
assert(said==1 and loads==5,'a failed load is said once and not tried again')
shared['/Game/Mods/X/Y.Y']=true
slot[1].text=slot[1].text..'name 5 sound /Game/Mods/X/Y.Y - - -\n'
at(2.75)
at(3)
assert(sentinel_calls==1 and loads_of['/Game/Mods/X/Y.Y']==1,'a shared mod asset goes through the sentinel')
assert(slot[1].appended[4]:match('^loaded 3 ') and slot[1].appended[5]:match('^loaded 5 '),'both keys naming it')
-- The wrong class for its kind (a texture named as a sound): refused, said once, never a line.
slot[2].text=slot[2].text..'name 2 sound /Game/Art/T/Tex.Tex - - -\n'
at(3.25)
at(3.5)
at(3.75)
assert(said==2 and loads_of['/Game/Art/T/Tex.Tex']==1 and #slot[2].appended==1,'a texture is no sound')
-- Set aside by the crash sentinel: never loaded.
slot[2].text=slot[2].text..'name 3 sound /Game/Sound/Aside.Aside - - -\n'
at(4)
at(4.25)
assert(not loads_of['/Game/Sound/Aside.Aside'])
-- The slot reset (her member left, the file started again): its names read from 0, its lines appended again.
slot[2].text='name 1 sound /Game/Sound/A.A - - -\n'
at(4.5)
at(4.75)
assert(slot[2].appended[2]:match('^loaded 1 ') and slot[2].appended[2]:find(string.format('0x%x',
    objects['/Game/Sound/A.A'].GetAddress()),1,true),'her new key 1 names A')
-- A kind the slot does not want (effects off) is never loaded; watched again with it, it is.
local third=slot_files()
third.text='name 1 niagara /Game/Art/FX/E.E - -\nname 2 sound /Game/Sound/A.A - - -\n'
a.watch(3,third,{sound=true})
at(5)
at(5.25)
assert(not loads_of['/Game/Art/FX/E.E'] and #third.appended==1 and third.appended[1]:match('^loaded 2 '))
-- Unwatched (its ghost went): nothing read or loaded for it, its loaded file kept (removing it could race the
-- native part's read offset); watched again, no line it already has is appended twice.
a.unwatch(3)
third.text=third.text..'name 3 sound /Game/Sound/B.B - - -\n'
at(5.5)
at(5.75)
assert(not third.removed and #third.appended==1,'unwatched: nothing new, the file kept')
a.watch(3,third,{sound=true,niagara=true})
at(6)
at(6.25)
assert(loads_of['/Game/Art/FX/E.E']==1 and #third.appended==3,'watched again: the new key and the kind now wanted')
assert(third.appended[2]:match('^loaded 1 ') and third.appended[3]:match('^loaded 3 '),third.appended[2])
-- One path named as a sound by one key and as a sound class by another: each is checked as its own class.
local fourth=slot_files()
fourth.text='name 1 sound /Game/Sound/C/PC.PC - - -\n'
a.watch(4,fourth)
at(6.5)
at(6.75)
assert(loads_of['/Game/Sound/C/PC.PC']==2 and #fourth.appended==0,'a sound class is no sound')
a.off()
assert(slot[1].removed and slot[2].removed,'off: the loaded files go')
local before=loads
at(8)
at(9)
assert(loads==before,'nothing watched: nothing loaded')
-- Collected while still cached: a later load writes the lines again without asking the dead object its class. The
-- check finds it a tick later and it is loaded again with a new line.
for i=1,3 do kinds['/Game/Sound/F'..i..'.F'..i]=classes.cue end
local fresh=Assets.new(sentinel,function() return false end)
local fifth=slot_files()
fifth.text='name 1 sound /Game/Sound/F1.F1 - - -\nname 2 sound /Game/Sound/F2.F2 - - -\n'
fresh.watch(5,fifth)
local function at_fresh(t) clock=t; fresh.tick() end
at_fresh(10)
at_fresh(10.25)
assert(#fifth.appended==2,'both keys in')
local first=fifth.appended[1]
objects['/Game/Sound/F1.F1'].dead=true
fifth.text=fifth.text..'name 3 sound /Game/Sound/F3.F3 - - -\n'
at_fresh(10.5) -- checks F2, loads F3, writes the lines with F1 still cached
assert(#fifth.appended==3 and fifth.appended[3]:match('^loaded 3 '),'the new key only')
at_fresh(10.75)
at_fresh(11) -- finds F1 collected, loads it again
assert(loads_of['/Game/Sound/F1.F1']==2 and #fifth.appended==4 and fifth.appended[4]:match('^loaded 1 ') and
    fifth.appended[4]~=first,'collected: loaded again, a new line')
-- Collected and its address given to another object of the same class (the UE4SS object at that address still reads
-- as valid): found by its full name, loaded again with a new line.
local f2=objects['/Game/Sound/F2.F2']
f2.name='/Game/Sound/Other.Other'
for i=1,4 do at_fresh(11+i*0.25) end
assert(loads_of['/Game/Sound/F2.F2']==2 and fifth.appended[5] and fifth.appended[5]:match('^loaded 2 ') and
    fifth.appended[5]~=string.format('loaded 2 0x%x 0x%x 0x0 0x0',f2.GetAddress(),classes.cue.GetAddress()),
    'its address taken by another sound: loaded again, a new line')
print('assets_test: ok')
