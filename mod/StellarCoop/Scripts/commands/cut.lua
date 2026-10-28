-- coop leviathan, coop gardener, coop tendril, coop mann, coop nier, coop orcal and coop enya, a read and a display of
-- cut models with a free camera to film them (cut/leviathan.lua; test tools, left out of the usage line): show and cam
-- turning the camera on (not off, not its speed) on a co-op save only, as coop race probe doro. coop lion, the cut Lion
-- spawned as an enemy to fight (cut/lion.lua, left out of the usage line too): the words that spawn (none, intro,
-- control) on a co-op save only; rows and brain on any. coop gardener fight, the cut Gardener spawned as an enemy
-- (cut/gardener.lua; every other coop gardener word is the viewer's): the words that spawn (none, intro, half,
-- skulling) on a co-op save only, after the viewer's display and free camera are put away, so the two models never
-- stand in the same place; rows on any. coop tendril fight, the cut Tendril spawned as an enemy (cut/tendril.lua;
-- every other coop tendril word is the viewer's), the same way: the spawn on a co-op save only, rows on any. coop
-- scene, two cut scenes through the game's theater (cut/scene.lua): a scene's name on a co-op save only; the list and
-- stop on any. main.lua builds it with new(o) at each Lua load and merges it into its command table. o: main.lua's
-- coop_slot, leviathan (cut/leviathan.lua's, one command a creature), lion (cut/lion.lua's), gardener
-- (cut/gardener.lua's), tendril (cut/tendril.lua's), wear (cut/wear.lua's), scene (cut/scene.lua's), lines
-- (cut/lines.lua's), flight (cut/flight.lua's keys for coop fly), chainspin (cut/chainspin.lua's), glide
-- (cut/glide.lua's), ask (a native request; coop fly, coop slowmo, coop shortcut and coop devinfo) and devmenu
-- (cut/devmenu.lua's). coop chainspin, EVE's cut Tachy Mode ChainSpin (a test tool, left out of the usage line), runs
-- on a co-op save only. coop emote, one of EVE's clips (cut/emote.lua, o.emote), runs on any save. coop devmenu, the
-- developer menu's rows that still work (left out of the usage line too): its list on any save, a row on a co-op save
-- only. coop devinfo, two read-only panels of the game's developer UI (left out too), on any save. coop gift, the
-- cut mailbox as a co-op gift box (cut/mailbox.lua, o.mailbox, built with the Steam link only), runs on a co-op save
-- only: every word of it.
-- coop mxiii, the camp travel into the cut Matrix XIII dungeon (cut/mxiii.lua, o.mxiii; a test tool left out of the
-- usage line, needing the zMXIII_P test pak), coop mxiii 30, the same to its third zone's camp, and coop mxiii leave,
-- its way out, run on a co-op save only.
local Cut={}
function Cut.new(o)
    local coop_slot,leviathan,lion=o.coop_slot,o.leviathan,o.lion
    local self={}
    -- coop wear (cut/wear.lua, o.wear): every word to it, on any save, as nothing of it is saved.
    function self.wear(...) return o.wear.command(...) end
    -- coop lines (cut/lines.lua, o.lines): every word to it, on any save, as it only says lines in the feed and plays
    -- voice takes.
    function self.lines(...) return o.lines.command(...) end
    -- coop emote (cut/emote.lua, o.emote): every word to it, on any save, as nothing of it is saved.
    function self.emote(...) return o.emote.command(...) end
    -- coop fly and coop slowmo (the native part's game/debug_keys.h, test tools left out of the usage line): SB's
    -- developer flight and slow motion. on is asked on a co-op save only, off anywhere; coop off and the next Lua load
    -- end both in the native part.
    for _,name in ipairs({'fly','slowmo'}) do
        self[name]=function(sub,a)
            if a~=nil or sub~='on' and sub~='off' then return false,'Use: coop '..name..' on|off' end
            local ok,why=true,nil
            if sub=='on' then ok,why=coop_slot('coop '..name..' on') end
            if not ok then return false,why end
            ok,why=o.ask(name..' '..sub)()
            if name=='fly' and o.flight then -- Its keys: R2 only flies, Shift with a direction evades.
                if sub=='off' then o.flight.off() elseif ok then why=tostring(why)..'; '..o.flight.on() end
            end
            return ok,why
        end
    end
    -- coop shortcut (the native part's save/shortcut.h, left out of the usage line): the cut Load Shortcut menu's
    -- saves, read from the game's paks and listed in coop-link.log, on any save, as nothing is written. coop shortcut
    -- load <map> <1-4> (save/shortcut_load.h): one of them, without its achievement data, written as co-op slot 5's
    -- copy for the game's own Load Game. Refused unless coop-settings.txt has shortcut_load=on (developer saves with
    -- boss achievements done: docs/how-it-works.md), and asked of the native part only when the same words come twice
    -- within 10 s; the first says what it does. The native part checks the rest (the title, co-op saves on, the file).
    local SHORTCUT_MAPS={B07=true,F02=true,G03=true,Matrix_XI=true}
    local load_at,load_what=nil,nil -- The first of the two: when (os.clock) and which file.
    function self.shortcut(a,map,n,extra)
        if a==nil then
            local ok,why=o.ask('shortcut list')()
            if ok then why=tostring(why)..': the list goes to coop-link.log, its summary to this log' end
            return ok,why
        end
        if a~='load' or not SHORTCUT_MAPS[map] or not (n or ''):find('^[1-4]$') or extra~=nil then
            return false,'Use: coop shortcut (the list), or coop shortcut load <map> <1-4> (read docs/usage.md first)'
        end
        if not (o.settings and o.settings.shortcut_load) then
            return false,'loading a shortcut save is off: it can unlock Steam achievements for good. Read docs/usage.md, '
                ..'then set shortcut_load=on in coop-settings.txt on an account whose achievements do not matter'
        end
        local what,now=map..' '..n,os.clock()
        if load_what~=what or now-load_at>10 then
            load_at,load_what=now,what
            return false,'type coop shortcut load '..what..' again within 10 s to write it as co-op slot 5 '
                ..'(StellarBladeCoop04.sav, backed up first), without its achievement list; then choose Load Game, slot '
                ..'5. Steam achievements it unlocks stay unlocked'
        end
        load_at,load_what=nil,nil
        local ok,why=o.ask('shortcut load '..what)()
        if ok then why=tostring(why)..': its steps go to coop-link.log' end
        return ok,why
    end
    -- coop glide (cut/glide.lua, o.glide, a test tool left out of the usage line): EVE's cut glide, on asked on a co-op
    -- save only, off anywhere (cut/glide.lua checks the save again once a second while on).
    function self.glide(sub,extra)
        if sub=='on' and extra==nil then
            local ok,why=coop_slot('coop glide on')
            if not ok then return false,why end
        end
        return o.glide.command(sub,extra)
    end
    for name,command in pairs(leviathan.commands) do
        self[name]=function(sub,a,b,c,d,e)
            if sub=='show' or sub=='cam' and a==nil and not leviathan.filming() then
                local ok,why=coop_slot('coop '..name..' '..sub)
                if not ok then return false,why end
            end
            return command(sub,a,b,c,d,e)
        end
    end
    local view=self.gardener -- The viewer's coop gardener, for every word but fight.
    function self.gardener(sub,a,b,c,d,e)
        if sub~='fight' then return view(sub,a,b,c,d,e) end
        if (a==nil or a=='intro' or a=='half' or a=='skulling') and b==nil then
            local ok,why=coop_slot('coop gardener fight'..(a and ' '..a or ''))
            if not ok then return false,why end
            view('off')
        end
        return o.gardener.command(a,b)
    end
    local tendril=self.tendril -- The viewer's coop tendril, for every word but fight.
    function self.tendril(sub,a,b,c,d,e)
        if sub~='fight' then return tendril(sub,a,b,c,d,e) end
        if a==nil then
            local ok,why=coop_slot('coop tendril fight')
            if not ok then return false,why end
            tendril('off')
        end
        return o.tendril.command(a,b)
    end
    function self.lion(sub,a,b)
        if sub==nil or sub=='intro' or sub=='control' then
            local ok,why=coop_slot('coop lion'..(sub and ' '..sub or ''))
            if not ok then return false,why end
        end
        return lion.command(sub,a,b)
    end
    function self.gift(sub,a,b,c)
        if not o.mailbox then return false,'coop gift needs the Steam link' end
        local ok,why=coop_slot('coop gift')
        if not ok then return false,why end
        return o.mailbox.command(sub,a,b,c)
    end
    function self.chainspin(extra)
        local ok,why=coop_slot('coop chainspin')
        if not ok then return false,why end
        return o.chainspin.command(extra)
    end
    function self.devmenu(name,extra)
        if extra==nil and o.devmenu.row(name) then
            local ok,why=coop_slot('coop devmenu '..name)
            if not ok then return false,why end
        end
        return o.devmenu.command(name,extra)
    end
    -- coop devinfo quest|player|off: the native part opens SB's quest debugger or player info panel through the
    -- game's UI manager, or closes them (game/dev_panels.h). Both only read, so any save.
    function self.devinfo(which,extra)
        if extra~=nil or which~='quest' and which~='player' and which~='off' then
            return false,'Use: coop devinfo quest|player|off'
        end
        return o.ask('devinfo '..which)()
    end
    -- coop mxiii (cut/mxiii.lua, o.mxiii): a camp travel into a world the save has never been in, which the game may
    -- write into the save, so on a co-op save only; coop mxiii leave too, as coop travel probe.
    function self.mxiii(extra)
        local ok,why=coop_slot('coop mxiii')
        if not ok then return false,why end
        return o.mxiii.command(extra)
    end
    function self.scene(sub,extra)
        if o.scene.SCENES[sub] then
            local ok,why=coop_slot('coop scene '..sub)
            if not ok then return false,why end
        end
        return o.scene.command(sub,extra)
    end
    return self
end
return Cut
