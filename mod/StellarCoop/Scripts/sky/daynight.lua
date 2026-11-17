-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's engine side (tests/lua/sky/daynight_test.lua). main.lua's 250 ms loop calls slow(off): it reads
-- the map when EVE's address changes (a new world), decides the native part's request with sky/rule.lua and sends it
-- only when it changes. One log line per change of the request or its reason. coop off asks sky off once, then
-- nothing. The hour and the sun come from the native part's sky= status line (game/sky.h); coop daynight status reads
-- it. o: log, ask(line) -> ok and why, status() -> the native status text, settings (daynight), her() -> EVE or nil,
-- address(eve), map_of(eve), cutscene(), screen() (SB's pause menu or one of its screens), photo() -> '0', '1' or 's',
-- night() (Night Operation runs), lobby() (EVE stands in the SBO lobby in Xion's training room), find(path) -> object
-- or nil, actors_of(class path) -> list, load(path), exists(path), cps (the third-party plugin's file).
local Rule=require('sky.rule')
local Daynight={}
local FLAG_EVERY=8 -- Xion's story-night flag read every 8 passes of 250 ms: every 2 s.

function Daynight.new(o)
    local self={}
    local test,pinned=nil,nil -- coop daynight off ('off') and hour (a minute), until on, off or a reload.
    local asked,told=nil,nil -- The last line the native part took; the last log line's text.
    local line,why=nil,nil -- This pass's decision.
    local eve_at,map=nil,nil
    local flag,flag_wait,story=nil,0,false -- Xion's story-night volume this world, passes to its next read, its state.
    local first,stopped=true,false

    -- The story-night flag of a row that has one: looked up once per world, read every 2 s. A miss or a read that
    -- raises is logged once and leaves the cycle running in that world.
    local function story_night(row)
        if not row.flag then return false end
        if flag==nil then
            flag=o.find(row.flag) or false
            if not flag then o.log('daynight: no story-night flag in this world, '..row.flag..': the cycle runs') end
        end
        if not flag then return false end
        flag_wait=flag_wait-1
        if flag_wait<0 then
            flag_wait=FLAG_EVERY-1
            local ok,on=pcall(function() return flag.bActiveVolume end)
            if ok then story=on==true
            else
                o.log('daynight: the story-night flag is unreadable in this world: '..tostring(on))
                flag,story=false,false
            end
        end
        return story
    end

    local function send(want,reason)
        line,why=want,reason
        local ok,said=true,nil
        if want~=asked then
            ok,said=o.ask(want)
            if ok then asked=want end
        end
        local text='daynight: '..want:gsub('^sky ','')..' ('..reason..')'..(ok and '' or ': not asked: '..tostring(said))
        if text~=told then told=text; o.log(text) end
    end

    function self.slow(off)
        if first then
            first=false
            if o.cps and o.exists(o.cps) then
                o.log('daynight: the "Activate Day Night Cycle" plugin is installed (CPS/Plugins/'
                    ..'activate_day_night_cycle.cps). It and SBO write the same light: turn one of them off.')
            end
        end
        if off then
            if not stopped then
                stopped=true
                asked=nil -- Asked once more whatever came before: the native part may have missed it.
                send('sky off','coop off')
            end
            return
        end
        local her=o.her()
        local at=her and o.address(her)
        if at~=eve_at then
            eve_at,map=at,her and o.map_of(her) or nil
            flag,flag_wait,story=nil,0,false
        end
        local row=Rule.row(map)
        local s={setting=o.settings~=nil and o.settings.daynight==true,test=test,pinned=pinned,map=map}
        -- The engine reads only where a cycle may run.
        if s.setting and test~='off' and row and row.cycle=='on' then
            s.lobby=o.lobby()
            s.story_night=story_night(row)
            s.cutscene=o.cutscene()
            s.screen=o.screen()
            s.photo=o.photo()~='0'
            s.night=o.night()
        end
        send(Rule.decide(s))
    end

    -- coop daynight status: the decision, the map's row, the native part's hour, sun and volumes, the next night.
    function self.status()
        local parts={'daynight: '..(line and line:gsub('^sky ','')..' ('..why..')' or 'no pass yet')}
        local row=Rule.row(map)
        if not map then parts[#parts+1]='no map'
        elseif not row then parts[#parts+1]='map '..map..' is not in the table: its own light'
        elseif row.cycle~='on' then parts[#parts+1]='map '..map..' keeps its fixed light'
        else
            parts[#parts+1]=string.format('map %s: %s sky, horizon %d, noon heading %d',map,row.sky,row.hz,
                row.heading)
        end
        local n=Rule.native(o.status())
        if not n then
            parts[#parts+1]='the native part gives no sky line'
        else
            local h=n.h or 0
            local minute=math.floor(h*60)
            local left=Rule.until_night(h)
            parts[#parts+1]=string.format('native %s at %02d:%02d, sun at %.1f degrees, %d volumes, %d in the sun, %s',
                tostring(n.state),minute//60,minute%60,n.el or 0,n.n or 0,n.lit or 0,
                left>0 and 'night in '..left..' min' or 'night now')
        end
        return table.concat(parts,'; ')
    end

    -- coop daynight on (the clock again, a pinned hour cleared), off (SB's light) or hour <h> (pinned): until another
    -- word or a Lua reload, never saved. ok and the line to show.
    function self.command(word,arg)
        local setting=o.settings~=nil and o.settings.daynight==true
        if word=='on' then
            test,pinned=nil,nil
            if not setting then return true,"daynight: daynight=off in coop-settings.txt still keeps SB's light" end
            return true,'daynight: on, the sky follows the clock'
        elseif word=='off' then
            test,pinned='off',nil
            return true,"daynight: off until coop daynight on or a Lua reload: Stellar Blade's own light"
        elseif word=='hour' then
            if not setting then return false,'coop daynight hour: refused while daynight=off in coop-settings.txt' end
            local m,refused=Rule.minute(arg)
            if not m then return false,'coop daynight '..refused end
            test,pinned=nil,m
            return true,string.format('daynight: the hour stays at %02d:%02d until coop daynight on, off or a Lua '
                ..'reload',m//60,m%60)
        end
        return false,'daynight: on, off or hour <h>'
    end
    return self
end
return Daynight
