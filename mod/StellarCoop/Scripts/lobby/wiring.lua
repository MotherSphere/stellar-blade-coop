-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The SBO lobby's wiring (lobby/): the lobby, its hall rows, its arrivals, its passes and its screens.
return {
uses={'nightop','cut.eve','session'},
exports={'sbo','halls','lobby_room','lobby_key','seat_hint','arrival_pass','lobby_pass','hud_pass','lobby',
    'lobby_last'},
new=function(M)
local print,log=M.print,M.log
local U=require('core.unreal')
-- The SBO lobby (lobby/sbo.lua), logging [SB] lines, with the Steam link only: the entry from the recruiter's Join or
-- coop sbo enter, the return, the waiting room, and the rows put back at each title and at coop off. Its notices are
-- keys of ui/text.lua, said in the menu's words. Its engine: SB's game instance, the player controller, EVE, the first
-- actor of a class, FNames, the table rows, each read through a fresh FindRow, and the menu camera (race/doro.lua's
-- free camera actor in EVE's world), and SB's chairs at the hall seats. A fight: EVE's, or an enemy within 30 m that
-- fights. The hall seats SB's chairs leave to menu_key: coop emote plays their loop.
if M.link then
    local Player=require('core.player')
    local Doro=require('core.actors')
    local Row=require('core.row_edit')
    local function row_of(t,name) return U.find('/Game/Local/Data/'..t..'.'..t):FindRow(name) end
    local function eve()
        local her=U.valid(require('UEHelpers').GetPlayer())
        return her and her:IsA(U.find('/Script/SB.SBCharacter')) and her or nil
    end
    local function sbo_log(m) print('[StellarCoop][SB] '..tostring(m)..'\n') end
    -- The hold at each lobby arrival (lobby/arrival.lua): SB's black (LoadingScreenFadeAuto, tag 5 Load, its fades
    -- 0.5 s each) from the new world's controller until the lobby is ready, the kit veiled under it, then SB's own end
    -- of it through the native part (loading lift). The controller is the one ClientRestart's hook sees (Engine's, as
    -- the warp's map load makes a new one); without the hook no lobby warp holds anything.
    local Arrival=require('lobby.arrival')
    local arrival=Arrival.new({log=sbo_log,
        fade=function()
            U.find('/Script/SB.Default__SBBlueprintLibrary'):LoadingScreenFadeAuto(Arrival.LIFETIME,Arrival.FADE,0,1,
                Arrival.FADE,1,0,5)
        end,
        lift=function() return M.link.request('loading lift') end,
        veil=function(on) if M.kit then M.kit.veil(on) end end})
    local hooked,unhooked=pcall(RegisterHook,'/Script/Engine.PlayerController:ClientRestart',function()
        arrival.restart()
    end)
    if not hooked then
        sbo_log('arrival: no hold at the lobby arrivals: ClientRestart not hooked: '..tostring(unhooked))
    end
    -- The hall lobby maps' world, zone and seat rows (lobby/halls_rows.lua), asked at the title on the co-op save
    -- files (main/pass.lua: halls.title) once the lobby pak gate passed (the SBO lobby's, built next).
    M.halls=require('lobby.halls_rows').new({log=sbo_log,status=function() return M.link.status() end,
        ask=function(line) return M.ask(line)() end,gate=function() return M.sbo.gate() end})
    -- The lobby pak gate's inputs: SB/Content/Paks from the mod folder and the file reader; the hall rows' ok().
    M.sbo=require('lobby.sbo').new({link=M.link,settings=M.settings,recruiter=require('main.loader').view(M,
        'recruiter'),nightop=require('main.loader').view(M,'night'),halls=M.halls,
        paks=require('core.pak_gate').paks_of(M.folder),read=require('core.link').files.read,
        log=sbo_log,emote=require('main.loader').view(M,'emote'),arrival=arrival,
        riding=function() return M.riding() end,
        say=function(key) M.tell(function(w) for part in key:gmatch('[^.]+') do w=w[part] end return w end) end,
        fight=function()
            local her=eve()
            return her~=nil and (her:IsBattle()==true or Player.engaged(her,3000))
        end,
        ue={game_instance=function() return FindFirstOf('SBGameInstance') end,pc=U.controller,eve=eve,
            first=function(class) return U.valid(FindFirstOf(class)) end,
            find_name=Row.find_name,index_of=Row.index_of,
            rows={read=function(t,name,field) local r=row_of(t,name); return r and U.value_of(r[field]) end,
                write=function(t,name,field,v) local r=row_of(t,name); if r then r[field]=v end end},
            camera=function(at,rotation)
                return Doro.spawn(assert(eve(),'no EVE in the world'):GetWorld(),at,rotation,{camera=true})
            end,
            alive=function(d) return Doro.same(d.actor,d.path) end,
            sweep=function(path) return Doro.sweep(path,'camera') end,
            -- SB's chair blueprint at a hall seat: the class in memory, else loaded (raises when neither). The actor
            -- spawned deferred in EVE's world as matrix13/world/breakables.lua spawns its boxes, AlwaysSpawn (1): its
            -- EnvActorName set to the seat's row before FinishSpawningActor runs its BeginPlay (FUN_142590850, which
            -- registers the name and binds the row), then each named part hidden with its collision off. A step that
            -- raises destroys the actor and raises.
            chair_class=function(asset)
                local path=asset..'_C'
                local c=U.valid(StaticFindObject(path))
                local loaded,why=true,nil
                if not c then
                    loaded,why=pcall(LoadAsset,asset)
                    c=U.valid(StaticFindObject(path))
                end
                return c or error(path..' does not load'..(loaded and '' or ': '..tostring(why)),0)
            end,
            -- The actors of a chair class (its short name: name) in EVE's world, an earlier Lua load's chairs.
            chairs_of=function(class,name) return (U.actors_of(class,name,eve())) end,
            chair=function(class,row,at,parts)
                local gs=U.find('/Script/Engine.Default__GameplayStatics')
                local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=at.X,Y=at.Y,Z=at.Z},
                    {Pitch=0,Yaw=at.Yaw,Roll=0},{X=1,Y=1,Z=1})
                local a=U.valid(gs:BeginDeferredActorSpawnFromClass(eve() or error('no EVE in the world',0),class,t,1,
                    nil)) or error('no actor',0)
                local ok,why=pcall(function()
                    a.EnvActorName=FName(row)
                    a=U.valid(gs:FinishSpawningActor(a,t)) or error('FinishSpawningActor gave nothing',0)
                    for _,name in ipairs(parts) do
                        local part=U.valid(a[name]) or error('no component '..name,0)
                        part:SetVisibility(false,false)
                        part:SetCollisionEnabled(0)
                    end
                end)
                if not ok then
                    pcall(function() a:K2_DestroyActor() end)
                    error(why,0)
                end
                return a
            end,
            bound=function(a)
                a=U.valid(a)
                if a then return U.text(a.BindZoneAlias),U.text(a.EnvSpawnAlias) end
            end}})
    if M.settings.sbo_lobby and not M.off then M.sbo.on_load() end
    -- The lobby's passes, which main/pass.lua calls each 250 ms.
    -- The lobby's screens each 250 ms (design-lobby 2.2 step 5, 2.7, 2.8): the countdown from the match line; a new
    -- start line of a round that lists us closes them and gives the view back to EVE (stage 4 goes on from there; the
    -- fence is lobby/sbo.lua's); the arrival in the lobby world opens B over the menu camera, once B can open on the
    -- UI root's whole look and while no round of ours plays (the kit builds no new root while B shows, so B on a build
    -- whose look still warms keeps the logo and shades missing); leaving that world closes them and the room's overlay.
    -- R25: a start is new when its number differs from the last one handled, or after an end line.
    local counting,start_n,round_kind,was_here,due=false,nil,nil,false,false
    local framed=false -- The menu camera asked under the arrival's hold, once an arrival in the lobby world.
    -- The arrival's hold, before lobby_pass: SB's black up at the pass after the new controller, lifted once the lobby
    -- holds nothing back (lobby/sbo.lua's unready) and the kit's root has its whole look. A Lua load under an earlier
    -- load's hold (Ctrl+R) knows nothing of that black: the first pass of this load in the lobby world asks the lift
    -- unless a hold of its own was up before this pass or is up after it (the lift ends tag-5 entries only, which only
    -- this mod puts up). Read after arrival.pass: a black this pass put up is this load's, so no lift for it.
    local stale=true
    function M.arrival_pass()
        local was_held=arrival.held()
        arrival.pass(function()
            local missing=M.sbo.unready()
            if not M.kit.whole() then missing[#missing+1]='ui' end
            return missing
        end)
        if stale and M.sbo.in_lobby() then
            stale=false
            if not (was_held or arrival.held()) then
                local ok,why=M.link.request('loading lift')
                print('[StellarCoop][SB] arrival: loading lift '..(ok and 'asked' or 'not asked: '..tostring(why))
                    ..' at the first lobby pass of this Lua load\n')
            end
        end
    end
    function M.lobby_pass()
        local m=M.link.match()
        if m and m.state=='countdown' then
            counting=true
            M.lobby.count(m.left or 0,os.clock())
        elseif counting then
            counting=false
            M.lobby.stop_count()
        end
        local r,me=M.link.round(),(M.link.saves() or {}).steamid
        local ours=false
        if r and r.kind=='start' then for _,id in ipairs(r.ids) do ours=ours or id==me end end
        if r and r.kind=='start' and (r.n~=start_n or round_kind=='end') then
            start_n=r.n
            if ours then
                M.lobby.close()
                counting=false
                M.lobby.stop_count()
                M.sbo.to_room()
                log('round start: stage 4 not built')
            end
        end
        round_kind=r and r.kind
        local here=M.sbo.in_lobby()
        if here~=was_here then
            was_here,due,framed=here,here,false
            if not here then M.lobby.close(); M.lobby.room(false) end
        end
        if not (due and not ours and M.kit.whole()) then return end
        if arrival.held() then -- Under SB's black: the camera now (a refusal is logged once), B at the lift.
            if not framed then framed=true; M.sbo.to_menu() end
        elseif M.lobby.open('menu') then
            due=false
            M.sbo.to_menu()
        end
    end
    -- SB's HUD hidden while B, C or the leave question shows, through SB's own keyed request (the native part's hud
    -- hide); each way they close comes back here. Also under the arrival's hold once in the lobby world, so the hide is
    -- asked before the lift and SB's HUD does not show through the black's fade-out. nil until the first pass of a Lua
    -- load, which sends off. A request that cannot be written is asked again at each pass and logged once (hud_refused:
    -- its line).
    local hud_hidden,hud_refused=nil,nil
    function M.hud_pass()
        local hide=M.lobby.is_open()~=nil or (arrival.held() and M.sbo.in_lobby())
        if hide==hud_hidden then return end
        local line=hide and 'hud hide on' or 'hud hide off'
        local ok,why=M.link.request(line)
        if ok then hud_hidden,hud_refused=hide,nil; return end
        local text='hud: '..line..' not asked: '..tostring(why)
        if text~=hud_refused then hud_refused=text; log(text) end
    end
end
-- The lobby's screens closed, the view back to EVE and the room's overlay on (design-lobby 2.7): Back and "Waiting
-- room" on B, menu_key or View held 1 s while B or C is open.
function M.lobby_room() M.lobby.close(); M.sbo.to_room(); M.lobby.room(true) end
-- In the lobby world, menu_key and View held 1 s away from a seat: B, then the view on the menu camera.
local function lobby_menu()
    local ok,why=M.lobby.open('menu')
    if ok then M.sbo.to_menu() else M.report(false,why) end
end
-- In the lobby world with no lobby screen open, menu_key and View held 1 s: EVE stands up while she sits on a hall seat,
-- sits on one within reach that SB's chairs left to menu_key (no chair bound there), else B opens.
function M.lobby_key()
    if M.sbo.seated() then return M.report(M.sbo.stand()) end
    local seat=M.sbo.near_seat()
    if seat then return M.report(M.sbo.sit(seat)) end
    lobby_menu()
end
-- The hint for lobby_key at the bottom centre while no lobby screen is open: Stand up while EVE sits, Sit near a seat
-- SB's chairs left to menu_key (ui/kit/menu.lua's booth hint, with this word).
function M.seat_hint()
    if not M.sbo.in_lobby() or M.lobby.is_open() then return nil end
    if M.sbo.seated() then return {word='stand'} end
    return M.sbo.near_seat() and {word='sit'} or nil
end
return require('lobby.commands').new({link=M.link,settings=M.settings,ask=M.ask,sbo=M.sbo,
    lobby=function() return M.lobby end})
end,
build={
screens=function(M,Ui)
    -- The lobby's view keeps our last match request ('search', 'create', or 'join' from the code box), when its Code
    -- row copied the code, and the map picked on C for a Private match ('random' or a hall's key, for this Lua load).
    local last,copied_at,room=nil,nil,'random'
    function M.lobby_last(v) last=v end -- The code box's Join sets it (session/wiring.lua).
    -- The SBO lobby's screens (lobby/ui/lobby.lua), over the rest: B and C, the leave question, the countdown and the
    -- room's overlay. view: Model.view's input, read fresh at each call (L15 R25, L12-R1); act: what a row asks for.
    local LAST={['match search']='search',['match create']='create',join='join'}
    local function view()
        local version,proto=('\n'..(M.link.status() or '')):match('\nmod=(%S+) proto=(%d+)')
        return {match=M.link.match(),members=M.link.members(),role=M.link.mode() or 'none',limit=M.link.cap(),
            code=(M.link.code()),
            me={id=(M.link.saves() or {}).steamid,name=M.link.me()},owner=M.link.owner(),last=last,copied_at=copied_at,
            now=os.clock(),version=version,proto=tonumber(proto),settings=M.settings,halls=M.sbo.hall()~='xion',
            room=room}
    end
    local function act(a)
        if a.request then -- Search (with the SBO lobby's room and hall words), Private, Cancel, and C's mute rows.
            local ok,why
            if a.lobby and a.request:find('^match create') then ok,why=M.sbo.create(a.request,room) -- On C's map.
            else ok,why=M.link.request(a.lobby and a.request..' '..M.sbo.lobby_words() or a.request) end
            M.report(ok,why)
            local word=a.request:match('^match %a+') or a.request:match('^join')
            if ok and LAST[word or ''] then last=LAST[word] end
        elseif a.open=='join' then -- As the co-op menu's row opens the code box.
            M.lobby_room()
            M.code_box.open()
        elseif a.open=='settings' then M.lobby.open('settings')
        elseif a.close=='room' then M.lobby_room()
        elseif a.popup=='leave' then
            local ok,why=M.lobby.popup('leave',function(yes)
                if not yes then return end
                M.lobby_room() -- The view back to EVE before the return holds her.
                M.report(M.sbo.leave())
            end)
            if not ok then M.report(false,why) end
        elseif a.copy then
            if M.run('copy') then copied_at=os.clock() end
        elseif a.set=='room' then room=a.value -- Not a coop-settings.txt setting: menu.set knows no such key.
        elseif a.set then M.menu.set(a.set,a.value)
        elseif a.run then M.run(a.run) end
    end
    M.lobby=require('lobby.ui.lobby').new({kit=M.kit,words=M.words,view=view,act=act,log=M.ui_log})
end,
},
}
