-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The developer menu's page of the co-op menu's TEST TOOLS (ui/kit/model.lua says a page's shape): coop devmenu's 20
-- rows and coop devinfo, run through the console's own path (run: logged, refused at coop off and, for a devmenu row,
-- off a co-op save, as typed). Under EVE and ENEMIES NEAR EVE, each lasting row is a switch: On runs it, Off runs
-- clear, which ends every lasting row but the lock-on's, so they all read Off after it; the lock-on's Off runs
-- lockswitch.
-- The attack rows (they add up) and the one-shot rows are buttons, as are Clear the enemies and Clear all. A switch
-- reads On while cutmenus/devmenu.lua saw its row taken and no dispel since, in this Lua load. Under PANELS, the
-- developer panel is a choice of Off, Quests and Player info (coop devinfo off, quest, player), as the native part
-- last took it. A refusal shows under the rows; a button that ran says so.
local DM={}
-- The page's rows in order: a heading (a T.tools.dev word), a switch, a button or the panel.
DM.LAYOUT={{head='eve'},{'nodamage'},{'stealth'},{'speed150'},{'speed200'},{'attack5',button=true},
    {'attack30',button=true},{'gauges'},{'tachy'},{'tachyfull',button=true},{'heal',button=true},{'hp1',button=true},
    {'nolockswitch',off='lockswitch'},{head='enemies'},{'enemynodamage'},{'enemynoai'},{'enemyimmortal'},
    {'enemyshield1',button=true},{'enemybalance1',button=true},{'enemyclear',button=true},{'clear',button=true},
    {head='panels'},{'devinfo'}}
local PANELS={'off','quest','player'}
-- o: {run=function(name, ...) -> ok, message (main/commands.lua's run), devmenu=cutmenus/devmenu.lua's (its on),
-- panel=function() -> 'off', 'quest' or 'player'}.
function DM.new(o)
    local page={}
    function page.title(w) return w.tools.dev.title end
    local function said(w,ok,why) if ok then return true,w.tools.done end return false,why end
    function page.rows(w)
        local d,rows=w.tools.dev,{}
        for _,l in ipairs(DM.LAYOUT) do
            local name=l[1]
            if l.head then rows[#rows+1]={id='head '..l.head,head=true,label=d[l.head]}
            elseif name=='devinfo' then
                local at=1
                for i,p in ipairs(PANELS) do if p==o.panel() then at=i end end
                local function step(dir)
                    local ok,why=o.run('devinfo',PANELS[(at-1+dir)%#PANELS+1])
                    if ok then return true end
                    return false,why
                end
                rows[#rows+1]={id=name,label=d.devinfo,value=at==1 and w.value.off or d[PANELS[at]],
                    select=function() return step(1) end,step=step}
            elseif l.button then
                rows[#rows+1]={id=name,label=d[name],value='',
                    select=function() return said(w,o.run('devmenu',name)) end}
            else
                local on=o.devmenu.on(name)
                local function flip()
                    local ok,why=o.run('devmenu',on and (l.off or 'clear') or name)
                    if ok then return true end
                    return false,why
                end
                rows[#rows+1]={id=name,label=d[name],value=w.value[on and 'on' or 'off'],select=flip,step=flip}
            end
        end
        return rows
    end
    return page
end
return DM
