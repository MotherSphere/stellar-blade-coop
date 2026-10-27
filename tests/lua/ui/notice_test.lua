-- Notices on screen with fake UE4SS objects and clock: 4 s each, in order, at most 4 queued; dropped with no EVE; the
-- line 120 cm above her, turned to the camera, wrapped at 40 columns (the shared fight's longest on two lines); in
-- Latin-1 only (the engine's default font): a notice whose words go past it in English, '?' for what is left past it;
-- hidden during our own photo mode, the queue kept;
-- spawned again once invalid or once its address holds another object; a frame with a stale player controller skipped; the first engine error turns it off with
-- one line, and no engine call follows; so does coop off, which hides it first.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local calls=0 -- Every engine call the fakes see.
local function object(fields)
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=function(self) calls=calls+1; return not self.destroyed end
    return o
end
FText=function(text) return {text=text} end
local spawned,fail_spawn={},false
local function label_of()
    local l=object({})
    for _,f in ipairs({'SetWorldSize','SetHorizontalAlignment','SetTextRenderColor','SetAbsolute'}) do
        l[f]=function(self,...) calls=calls+1; self[f]={...} end
    end
    function l:K2_SetText(t) calls=calls+1; self.text=t.text; self.texts=(self.texts or 0)+1 end
    function l:K2_SetWorldLocationAndRotation(at,r) calls=calls+1; self.at,self.rot=at,r end
    return l
end
local map_name='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
local world={GetFullName=function() return map_name end,SpawnActor=function(_,class,at)
    calls=calls+1
    if fail_spawn then error('no spawn here') end
    assert(class.path=='/Script/Engine.Actor' and at.Z==120)
    local a=object({})
    local full='Actor /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.Actor_'..#spawned
    function a:GetFullName() calls=calls+1; return self.reused or full end
    function a:SetActorEnableCollision(on) calls=calls+1; self.collision=on end
    function a:SetActorHiddenInGame(hidden) calls=calls+1; self.hidden=hidden end
    function a:AddComponentByClass(class_of,manual)
        calls=calls+1
        assert(class_of.path=='/Script/Engine.TextRenderComponent' and manual==false)
        self.label=label_of(); return self.label
    end
    spawned[#spawned+1]=a
    return a
end}
-- EVE at the origin; only read.
local eve=object({IsA=function(_,class) calls=calls+1; return class.path=='/Script/SB.SBCharacter' end,
    GetWorld=function() calls=calls+1; return world end,
    K2_GetActorLocation=function() calls=calls+1; return {X=0,Y=0,Z=0} end})
eve=setmetatable({},{__index=eve,__newindex=function(_,key) error('the notice wrote '..key..' on EVE',2) end})
local menu=object({IsA=function() calls=calls+1; return false end}) -- The title screen's pawn.
local player,camera=eve,{X=100,Y=100,Z=300}
-- stale: the controller UEHelpers keeps holds another object (its address reused after a map change).
local stale=false
package.loaded.UEHelpers={
    GetPlayer=function() calls=calls+1; return player end,
    GetPlayerController=function()
        calls=calls+1
        if stale then return object({IsA=function() calls=calls+1; return false end}) end
        return object({IsA=function(_,class) calls=calls+1; return class.path=='/Script/Engine.PlayerController' end,
            PlayerCameraManager=object({GetCameraLocation=function() calls=calls+1; return camera end})})
    end,
}
StaticFindObject=function(path)
    calls=calls+1
    local c=object({path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then c.MakeTransform=function() return 'identity' end end
    return c
end
local Notice=require('ui.notice')

local n=Notice.new()
assert(n.tick()==nil and calls==0,'Nothing queued: no engine call at all')
n.say('one'); n.say('two')
assert(n.tick()==nil and #spawned==1,'Spawned when there is something to show')
local actor=spawned[1]
local label=actor.label
assert(actor.collision==false and label.SetWorldSize[1]==10 and label.SetHorizontalAlignment[1]==1)
assert(label.SetTextRenderColor[1].R==255 and label.SetTextRenderColor[1].A==255)
assert(label.SetAbsolute[1]==false and label.SetAbsolute[2]==true and label.SetAbsolute[3]==false,'Its rotation is the world\'s')
assert(label.text=='one' and label.at.X==0 and label.at.Z==120,'120 cm above EVE')
assert(math.abs(label.rot.Yaw-45)<1e-9 and label.rot.Pitch==0 and label.rot.Roll==0,'Turned to the camera')
camera={X=-50,Y=0,Z=0}
n.tick(); assert(math.abs(label.rot.Yaw-180)<1e-9,'Each frame')
camera={X=0,Y=-10,Z=0}
n.tick(); assert(math.abs(label.rot.Yaw+90)<1e-9)
clock=3.9; n.tick(); assert(label.text=='one' and label.texts==1,'4 s each, the text set once')
clock=4; n.tick(); assert(label.text=='two' and label.texts==2 and not actor.hidden)
clock=7.9; n.tick(); assert(label.text=='two')
clock=8; n.tick(); assert(actor.hidden==true,'Hidden when the queue is empty')
calls=0
n.tick(); n.tick(); assert(calls==0,'Idle: no engine call')
-- The same text twice is two notices.
n.say('two'); n.tick(); assert(label.text=='two' and label.texts==3 and actor.hidden==false and #spawned==1)
clock=12; n.tick(); assert(label.texts==3 and actor.hidden==true)

-- A fifth notice drops the oldest.
for i=1,5 do n.say('n'..i) end
local seen={}
for t=12,40,0.5 do
    clock=t; n.tick()
    if not actor.hidden and seen[#seen]~=label.text then seen[#seen+1]=label.text end
end
assert(table.concat(seen,' ')=='n2 n3 n4 n5',table.concat(seen,' '))
-- Again with the oldest on screen: the next one goes up in its place at once, and none is skipped.
n.say('h'); n.tick(); assert(label.text=='h' and not actor.hidden)
for i=2,5 do n.say('n'..i) end
seen={}
for t=40,70,0.5 do
    clock=t; n.tick()
    if not actor.hidden and seen[#seen]~=label.text then seen[#seen+1]=label.text end
end
assert(table.concat(seen,' ')=='n2 n3 n4 n5',table.concat(seen,' '))

-- No EVE (the title screen): nothing is spawned and the queue is dropped.
local m=Notice.new()
local before=#spawned
for _,pawn in ipairs({false,menu}) do
    player=pawn or nil
    m.say('lost'); m.tick()
    player=eve; m.tick()
    assert(#spawned==before,'Nothing spawned, nothing left to show')
end
-- An EVE on the title screen's map (the lobby) counts as no world either.
map_name='World /Game/Lobby/Lobby.LOBBY'
m.say('title'); m.tick()
assert(#spawned==before,'Nothing spawned on the title map')
map_name='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
-- And a line on screen goes when EVE does.
n.say('shown'); n.tick(); assert(actor.hidden==false and label.text=='shown')
player=nil; n.tick(); assert(actor.hidden==true)
player=eve; n.tick(); assert(actor.hidden==true and label.text=='shown','Its queue went with it')

-- Wrapped at 40 columns, on spaces; a longer word is cut between characters, and so is text with no spaces.
n.say('Hosting: invite a friend from the Steam overlay (Shift+Tab).'); n.tick()
assert(label.text=='Hosting: invite a friend from the Steam\noverlay (Shift+Tab).',label.text)
local a,c,e=string.rep('a',38),string.rep('c',39),string.rep('e',40)
clock=clock+4; n.say(a..' b '..c..' d '..e..'eeeee f'); n.tick()
assert(label.text==a..' b\n'..c..'\nd\n'..e..'\neeeee f',label.text) -- 40 fits, 41 does not.
clock=clock+4; n.say(string.rep('敵',45)); n.tick()
assert(label.text==string.rep('?',40)..'\n'..string.rep('?',5),'Past Latin-1 with no English: one ? a character')
-- The shared fight's notices (main.lua): the short ones on one line, the longest reason (the slot line) on two.
clock=clock+4; n.say('Shared fight on: 12 enemies linked'); n.tick()
assert(label.text=='Shared fight on: 12 enemies linked',label.text)
clock=clock+4; n.say('Shared fight off: not on the co-op save (slot=main index=0 marker=4)'); n.tick()
assert(label.text=='Shared fight off: not on the co-op save\n(slot=main index=0 marker=4)',label.text)


-- The default font draws Latin-1 only. Words past it (Japanese, Polish, Turkish...): the English line given with them.
-- A name past it, in a line whose words are within it: that line, the name's characters past Latin-1 as '?'.
local function shown_for(text,en) clock=clock+4; n.say(text,en); n.tick(); return label.text end
assert(shown_for('共有敵：オン（3 体の敵がリンク中）','Shared enemies on: 3 enemies linked.')
    =='Shared enemies on: 3 enemies linked.','Japanese')
assert(shown_for('Wspólni wrogowie włączeni: 3 połączonych wrogów.','Shared enemies on: 3 enemies linked.')
    =='Shared enemies on: 3 enemies linked.','Polish: one letter past Latin-1 is enough')
assert(shown_for('Ennemis partagés : Kaanta est à terre.','Shared enemies: Kaanta is down.')
    =='Ennemis partagés : Kaanta est à terre.','French is Latin-1: kept, accents and all')
assert(shown_for('Ennemis partagés : Кот est à terre.','Shared enemies: Кот is down.')
    =='Ennemis partagés : ??? est à terre.','A Cyrillic name in French words: the French line')
assert(shown_for('共有敵：Котはダウン','Shared enemies: Кот is down.')=='Shared enemies: ??? is down.',
    'A Cyrillic name in Japanese words: the English line')
assert(shown_for('Кот: привет')=='???: ??????','No English (a chat line, a native notice): ? for each')
assert(shown_for('Ünlü ğ','Famous g')=='Famous g' and shown_for('Ünlü','Famous')=='Ünlü','Ü is Latin-1, ğ is not')

-- Our own photo mode (main.lua's veil): the line goes at once and nothing is drawn, the queue kept; once it ends, the
-- head notice goes up again for its full 4 s.
clock=clock+4; n.tick(); assert(actor.hidden==true)
n.say('photo'); n.tick(); assert(not actor.hidden and label.text=='photo')
clock=clock+3; n.veil(true); assert(actor.hidden==true)
n.say('queued')
calls=0
for _=1,3 do clock=clock+4; n.tick() end
n.veil(true)
assert(calls==0 and actor.hidden,'Veiled: no engine call')
n.veil(false); n.tick(); assert(not actor.hidden and label.text=='photo','The head notice again')
clock=clock+3.9; n.tick(); assert(label.text=='photo','Its full 4 s')
clock=clock+0.1; n.tick(); assert(label.text=='queued')
clock=clock+4; n.tick(); assert(actor.hidden==true)

-- A stale controller: that frame is skipped, the line stays on and turns again once the controller is one.
n.say('stale'); n.tick(); assert(label.text=='stale' and not actor.hidden)
stale=true
assert(n.tick()==nil and n.tick()==nil,'Skipped, not off')
stale=false
camera={X=-50,Y=0,Z=0}; n.tick(); assert(math.abs(label.rot.Yaw-180)<1e-9 and label.text=='stale')
clock=clock+4; n.tick(); assert(actor.hidden==true)

-- A line whose level went away is spawned again, with its text.
clock=clock+4; n.tick()
n.say('again'); n.tick(); assert(label.text=='again')
actor.destroyed=true
n.tick()
assert(#spawned==before+1 and spawned[#spawned].label.text=='again','Spawned again once invalid')
assert(spawned[#spawned].label.at.Z==120)

-- A map change frees the line, and its address may hold another object that still passes IsValid: never touched (not
-- hidden, no text set), and a line of our own is spawned in its place.
local freed=spawned[#spawned]
freed.reused='SBCharacter /Game/Art/BG/WorldMap/Level_P/F02.F02:PersistentLevel.BP_NPC_C_3'
player=nil; n.tick()
assert(not freed.hidden,'The other object is not hidden')
player=eve
n.say('moved'); n.tick()
assert(#spawned==before+2 and spawned[#spawned].label.text=='moved' and freed.label.text=='again',
    'Spawned again, the other object left alone')

-- coop off: the line on screen goes at once, and no engine call follows.
local shown=spawned[#spawned]
assert(not shown.hidden and shown.label.text=='moved')
n.stop(); assert(shown.hidden==true)
calls=0
n.say('later'); n.tick(); n.stop()
assert(calls==0,'Stopped: no engine call')

-- The first engine error: one line, then no engine call ever again.
fail_spawn=true
local o=Notice.new()
o.say('x')
local ok,message=o.tick()
assert(ok==false and message:find('^Screen notices off: .*no spawn here; notices stay in UE4SS%.log%.$'),message)
calls=0
o.say('y')
for _=1,3 do assert(o.tick()==nil) end
assert(calls==0,'Off: no engine call')
print('notice_test ok')
