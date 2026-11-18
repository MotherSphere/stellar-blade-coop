-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The co-op saves' console commands: coop saves and coop shortcut. online/saves/wiring.lua builds them with new(o) at
-- each Lua load and main/loader.lua merges them into the command table. o: ask (a line for the native part) and
-- settings.
local Save={}
function Save.new(o)
    local ask=o.ask
    local self={}
    local twice=nil -- coop saves refresh and export: the request typed and when ({line=, at=}), until typed again.
    -- The co-op saves by hand (the question at the title asks for them): probe logs what the native part reads and the
    -- next copy pass's plan; convert makes the copies; coop makes them and switches the save name; main switches back;
    -- refresh <0-4> replaces that slot's co-op copy, played or not, with a new copy of the player's save (the native
    -- part backs the old one up first); export <0-4> <0-4> writes that co-op slot's copy over that save of the player's
    -- (backed up first), to play on without the mod, and the native part refuses a copy that holds the mod's items or
    -- stands in Matrix XIII, or a developer save coop shortcut load wrote. Each is asked once typed twice the same
    -- within 10 s. The native part refuses all but probe off the title screen, and says why in coop-link.log.
    local function confirmed(line)
        local now=os.clock()
        if twice and twice.line==line and now-twice.at<=10 then
            twice=nil
            return true
        end
        twice={line=line,at=now}
        return false
    end
    function self.saves(sub,extra,more,rest)
        local function slot(word) return type(word)=='string' and word:match('^[0-4]$')~=nil end
        if sub=='refresh' and more==nil and slot(extra) then
            if not confirmed('saves refresh '..extra) then
                return false,'coop saves refresh '..extra..' replaces the co-op copy StellarBladeCoop0'..extra..'.sav, '
                    ..'played in co-op or not, with a new copy of your save StellarBladeSave0'..extra..'.sav (the old '
                    ..'copy goes to StellarCoopBackups first): type it again within 10 s to go on'
            end
            return ask('saves refresh '..extra)()
        end
        if sub=='export' and rest==nil and slot(extra) and slot(more) then
            if not confirmed('saves export '..extra..' '..more) then
                return false,'coop saves export '..extra..' '..more..' writes your co-op save StellarBladeCoop0'..extra
                    ..'.sav over your own save StellarBladeSave0'..more..'.sav (your save there, if any, goes to '
                    ..'StellarCoopBackups first), to play on without the mod; it is refused while that co-op save '
                    ..'holds the mod\'s items or stands in Matrix XIII, and for a developer save coop shortcut load '
                    ..'wrote: type it again within 10 s to go on'
            end
            return ask('saves export '..extra..' '..more)()
        end
        if extra~=nil or not ({probe=true,convert=true,coop=true,main=true})[sub or ''] then
            return false,'Use: coop saves probe | convert | coop | main | refresh <0-4> | export <0-4> <0-4>'
        end
        return ask('saves '..sub)()
    end
    -- coop shortcut (the native part's game/shortcut.h, left out of the usage line): the cut Load Shortcut menu's
    -- saves, read from the game's paks and listed in coop-link.log, on any save, as nothing is written. coop shortcut
    -- load <map> <1-4> (game/shortcut_load.h): one of them, without its achievement data, written as co-op slot 5's
    -- copy for the game's own Load Game. Refused unless coop-settings.txt has shortcut_load=on (developer saves with
    -- boss achievements done: docs/internals/README.md), and asked of the native part only when the same words come
    -- twice within 10 s; the first says what it does. The native part checks the rest (the title, co-op saves on, the
    -- file).
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
    return self
end
return Save
