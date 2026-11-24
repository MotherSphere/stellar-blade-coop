-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The cut models' page of the co-op menu's TEST TOOLS (ui/kit/model.lua says a page's shape): the viewer of coop
-- leviathan, coop gardener, coop tendril, coop mann, coop nier, coop orcal and coop enya (fight/bosses/leviathan.lua).
-- Model and Part pick what Show shows (no command); Skin asks coop <model> skin <word> (kept for the next show when
-- none is shown); Show asks coop <model> show <part> and reads what is shown now; Free camera asks coop <model> cam
-- (on asked on a co-op save only, as typed); Remove asks coop <model> off. Each runs through the console's own path
-- (run). A part's and a skin's words are the console's own. A refusal shows under the rows. The free camera reads no
-- key while the menu is open: close it to fly.
local Leviathan=require('fight.bosses.leviathan')
local Viewer={}
Viewer.ORDER={'leviathan','gardener','tendril','mann','nier','orcal','enya'}
-- The words of skin for a creature, in order, default last.
function Viewer.skins(who)
    local list={}
    for _,s in ipairs(who.skins) do list[#list+1]=s[1] end
    list[#list+1]='default'
    return list
end
local function at(list,value)
    for i,v in ipairs(list) do if v==value then return i end end
    return 1
end
-- o: {run=function(name, ...) -> ok, message (main/commands.lua's run), leviathan=fight/bosses/leviathan.lua's
-- (shown, skin, filming)}.
function Viewer.new(o)
    local page={}
    local model,part=1,{} -- The picked creature, and each one's picked mesh word.
    function page.title(w) return w.tools.viewer.title end
    local function answer(ok,why) if ok then return true end return false,why end
    function page.rows(w)
        local v=w.tools.viewer
        local name=Viewer.ORDER[model]
        local who=Leviathan.CREATURES[name]
        part[name]=part[name] or who.meshes[1]
        local skins=Viewer.skins(who)
        local shown,mesh=o.leviathan.shown()
        local function pick(dir) model=(model-1+dir)%#Viewer.ORDER+1; return true end
        local function pick_part(dir)
            part[name]=who.meshes[(at(who.meshes,part[name])-1+dir)%#who.meshes+1]
            return true
        end
        local function skin(dir)
            if #skins==1 then return true end
            return answer(o.run(name,'skin',skins[(at(skins,o.leviathan.skin(name))-1+dir)%#skins+1]))
        end
        return {{id='model',label=v.model,value=v[name],select=function() return pick(1) end,step=pick},
            {id='part',label=v.part,value=part[name],select=function() return pick_part(1) end,step=pick_part},
            {id='skin',label=v.skin,value=o.leviathan.skin(name),select=function() return skin(1) end,step=skin},
            {id='show',label=v.show,value=shown and v[shown]..' '..mesh or v.nothing,
                select=function() return answer(o.run(name,'show',part[name])) end},
            {id='cam',label=v.cam,value=w.value[o.leviathan.filming() and 'on' or 'off'],
                select=function() return answer(o.run(name,'cam')) end,
                step=function() return answer(o.run(name,'cam')) end},
            {id='remove',label=v.remove,value='',select=function() return answer(o.run(name,'off')) end}}
    end
    return page
end
return Viewer
