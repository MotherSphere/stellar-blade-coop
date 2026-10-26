-- coop leviathan, coop gardener, coop tendril, coop mann, coop nier, coop orcal and coop enya, a read and a display of
-- cut models with a free camera to film them (cut/leviathan.lua; test tools, left out of the usage line): show and cam
-- turning the camera on (not off, not its speed) on a co-op save only, as coop race probe doro. coop lion, the cut Lion
-- spawned as an enemy to fight (cut/lion.lua, left out of the usage line too): the words that spawn (none, intro,
-- control) on a co-op save only; rows and brain on any. coop scene, two cut scenes through the game's theater
-- (cut/scene.lua): a scene's name on a co-op save only; the list and stop on any. main.lua builds it with new(o) at
-- each Lua load and merges it into its command table. o: main.lua's coop_slot, leviathan (cut/leviathan.lua's, one
-- command a creature), lion (cut/lion.lua's), wear (cut/wear.lua's), scene (cut/scene.lua's), lines (cut/lines.lua's)
-- flight (cut/flight.lua's keys for coop fly), chainspin (cut/chainspin.lua's), glide (cut/glide.lua's) and ask (a
-- native request; coop fly, coop slowmo and coop devinfo) and devmenu (cut/devmenu.lua's). coop chainspin, EVE's cut
-- Tachy Mode ChainSpin (a test tool, left out of the usage line), runs on a co-op save only. coop devmenu, the
-- developer menu's rows that still work (left out of the usage line too): its list on any save, a row on a co-op save
-- only. coop devinfo, two read-only panels of the game's developer UI (left out too), on any save.
local Cut={}
function Cut.new(o)
    local coop_slot,leviathan,lion=o.coop_slot,o.leviathan,o.lion
    local self={}
    -- coop wear (cut/wear.lua, o.wear): every word to it, on any save, as nothing of it is saved.
    function self.wear(...) return o.wear.command(...) end
    -- coop lines (cut/lines.lua, o.lines): every word to it, on any save, as it only says lines in the feed.
    function self.lines(...) return o.lines.command(...) end
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
    function self.lion(sub,a,b)
        if sub==nil or sub=='intro' or sub=='control' then
            local ok,why=coop_slot('coop lion'..(sub and ' '..sub or ''))
            if not ok then return false,why end
        end
        return lion.command(sub,a,b)
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
