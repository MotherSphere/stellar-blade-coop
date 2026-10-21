-- Notices on screen: one line of text about 30 cm above your EVE, turned to the camera each frame, each notice for 4 s
-- in turn. A plain actor of its own, never attached to EVE, so the player actor is never touched. Notices queued with
-- no EVE in the world (the title screen) are dropped: UE4SS.log already has them. During your own photo mode nothing is
-- drawn, so no notice lands in a photo: they wait. The first engine error turns the line off for this Lua load.
-- The line has no font of its own: the engine's default, RobotoDistanceField, has Latin-1's 256 characters only.
local UE=require('UEHelpers')
local U=require('unreal')
local valid,value_of,find=U.valid,U.value_of,U.find
local Chat=require('chat')
local Notice={}
local KEEP,SECONDS,WIDTH,SIZE,RISE=4,4,40,10,120 -- Notices queued, seconds each, columns a line, cm high, cm above EVE.
-- Lines of at most WIDTH columns (a Chinese, Japanese or Korean character two), broken at a space, else between two
-- characters: the feed's wrap.
local function wrap(text) return table.concat(Chat.wrap(text,WIDTH),'\n') end
local BEYOND='[\xC4-\xF4][\x80-\xBF]*' -- A character past Latin-1 (U+0100 on) in well-formed UTF-8.
-- What the default font can draw of a notice: its English (en) when its own words go past Latin-1 (it has more such
-- characters than en, whose only ones come from names), and '?' for each character past Latin-1 still left (a name or
-- a chat line as typed).
local function latin1(text,en)
    if en and select(2,text:gsub(BEYOND,''))>select(2,en:gsub(BEYOND,'')) then text=en end
    return (text:gsub(BEYOND,'?'))
end
function Notice.new()
    local self,queue={},{}
    local actor,label,since,visible,off=nil,nil,nil,false,false -- since: when the head notice went up, nil before.
    local veiled=false -- Our own photo mode: the line is hidden, the queue kept.
    -- A notice, and the same in English when it was put together from the menu's words (ui_text.lua).
    function self.say(text,en)
        queue[#queue+1]=latin1(text,en)
        if #queue>KEEP then table.remove(queue,1); since=nil end
    end
    local function hide()
        if visible and valid(actor) then actor:SetActorHiddenInGame(true) end
        visible=false
    end
    local function step()
        local eve=valid(UE.GetPlayer())
        -- No EVE in a world (the title screen, whose map is the lobby, may still have an SBCharacter): nothing shows.
        if not (eve and eve:IsA(find('/Script/SB.SBCharacter')) and U.map_of(eve)~='/game/lobby/lobby') then
            queue,since={},nil
            return hide()
        end
        if since and os.clock()-since>=SECONDS then table.remove(queue,1); since=nil end
        if not queue[1] then return hide() end
        local at=value_of(eve:K2_GetActorLocation())
        at={X=at.X,Y=at.Y,Z=at.Z+RISE}
        if not valid(actor) then -- First use, or the level it stood in is gone.
            actor=valid(eve:GetWorld():SpawnActor(find('/Script/Engine.Actor'),at,{Pitch=0,Yaw=0,Roll=0}))
            assert(actor,'the line could not be spawned')
            actor:SetActorEnableCollision(false,false)
            label=U.label(actor,SIZE)
            since,visible=nil,true
        end
        if not since then
            label:K2_SetText(FText(wrap(queue[1])))
            since=os.clock()
        end
        if not visible then actor:SetActorHiddenInGame(false); visible=true end
        local camera=value_of(UE.GetPlayerController().PlayerCameraManager:GetCameraLocation())
        label:K2_SetWorldLocationAndRotation(at,{Pitch=0,Yaw=U.yaw_to(at,camera),Roll=0},false,{},true)
    end
    -- coop off: a line on screen goes now, as the 1 ms loop that would hide it stops; no engine call after this one.
    function self.stop()
        if off then return end
        off,queue=true,{}
        pcall(hide)
    end
    -- Every 250 ms (main.lua): whether our own photo or selfie mode runs. On, the line goes at once; off, the head
    -- notice gets its full time again.
    function self.veil(on)
        if on==veiled then return end
        veiled,since=on,nil
        if on and not off then pcall(hide) end
    end
    -- Each frame: nothing at all while there is nothing to show or hide, or while veiled.
    function self.tick()
        if off or veiled or (not queue[1] and not visible) then return end
        local ok,why=pcall(step)
        if ok then return end
        off,queue=true,{}
        return false,'Screen notices off: '..tostring(why)..'; notices stay in UE4SS.log.'
    end
    return self
end
return Notice
