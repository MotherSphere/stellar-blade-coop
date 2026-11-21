-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro race's HUD on the Uplink kit (ui/kit/kit.lua). online/modes/race/run.lua keeps the race's events and calls
-- it each frame. The panel at the top centre (DORO RACE over the time, CP, LAP and POS among up to 8 racers, or the
-- wait for her), in its place once the race ends the results (the heading, the fin flags, a note, then 8 rows: place,
-- name, time or DNF; ours in Beta blue), the banner over the middle, the marker and the edge arrow. In a match round
-- the results show from our own end: our row alone until the host's ranking comes, with the note Results still to
-- come, then the ranking with Not ranked. when it has no place for us, or New personal best. when our finish wrote
-- one. All hidden while the game is paused or on one of its screens. Its words follow the game's language unless
-- ui_language=english, picked again at each build of the kit's root. tests/lua/online/modes/race/ui/hud_test.lua covers
-- it on a fake kit.
local P=require('ui.kit.hud_parts')
local T=require('ui.text')
local R=require('online.modes.race.model')
local Join=require('core.line')
local Hud={}
local ABOVE=220 -- cm over a checkpoint's centre (EVE's feet there) for its marker: about her head.
-- Kit layout units (3840 by 2160). The panel and, in its place once the race ends, the results at the top centre, where
-- Night Operation's card goes (a race never arms during a run); the results as score attack's result panel (a heading,
-- two lines, then 8 rows 56 apart); the banner over the middle; the marker and the edge arrow as the partner's
-- (online/partner/hud.lua), in Beta blue.
local HUD_W,PANEL_H,RESULT_H,HUD_Y=1040,160,720,96
local ROWS=8
local BANNER_W,BANNER_H,BANNER_Y=1600,160,520
local MW,MH,AW,AH,AC=320,120,160,180,80
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
Hud.GROUPS={'race_panel','race_results','race_banner','race_marker','race_arrow'}

-- A race time as the panel shows it: 1:23.45.
function Hud.clock(ms)
    local cs=math.max(0,math.floor(ms/10))
    return string.format('%d:%02d.%02d',cs//6000,cs//100%60,cs%100)
end
-- The panel's line in words w: the time, then CP, LAP and POS, two spaces apart.
function Hud.line(w,ms,cp,cps,lap,laps,pos,of)
    local r=w.race
    return Hud.clock(ms)..'  '..r.cp:format(cp,cps)..'  '..r.lap:format(lap,laps)..'  '..r.pos:format(pos,of)
end
-- Who we are in a race's results: model.lua's host or guest, match/model.lua's me.
function Hud.mine(r) return r.role=='host' and 'host' or r.role=='match' and 'me' or 'guest' end
-- Our live place in race r and of how many: in a match among the round's racers (r.heard.racers, each {ms=, why=,
-- passed=, pos=} from the round and her ghost), else model.lua's place against her (her_feet: her ghost's feet).
function Hud.place(r,her_feet)
    local m=r.m
    if r.role~='match' then
        return R.place(m,her_feet and {x=her_feet.X,y=her_feet.Y,z=her_feet.Z})
    end
    local list={{ms=m.me.ms,why=m.me.why,passed=m.me.passed or 0,pos=r.pos}}
    for _,e in ipairs(r.heard and r.heard.racers or {}) do list[#list+1]=e end
    return R.places(m.track,list)[1],#list
end
-- The results panel's note and rows of race r in words w: the note ('' in a session; in a match Not ranked. once a
-- ranking without us came, the results still to come before it, else New personal best. when our finish wrote one)
-- and one {label=, value=, ours=} per entry, placed finishers first, then the DNFs. Before the host's ranking a match
-- shows our row alone. name(entry): a racer's name as shown.
function Hud.results(r,w,name)
    local m,me=r.m,Hud.mine(r)
    local list,note={},''
    if r.role=='match' and m.phase~='results' then
        list[1]={who='me',ms=m.me.ms}
        local left=r.heard and r.heard.waiting or 0
        if left>0 then note=w.race.still:format(left)
        elseif r.heard and r.heard.best then note=w.race.best end
    else
        for _,entry in ipairs(m.results or {}) do list[#list+1]=entry end
        if r.role=='match' then
            local placed=false
            for _,entry in ipairs(list) do placed=placed or entry.who==me end
            note=not placed and w.race.unranked or r.heard and r.heard.best and w.race.best or ''
        end
    end
    local order={}
    for k,entry in ipairs(list) do order[entry]=k end
    table.sort(list,function(a,c)
        if (a.pos or 99)~=(c.pos or 99) then return (a.pos or 99)<(c.pos or 99) end
        return order[a]<order[c]
    end)
    local rows={}
    for i,entry in ipairs(list) do
        rows[i]={label=(entry.pos and tostring(entry.pos) or '-')..'  '..(entry.who==me and w.chat.you or name(entry)),
            value=entry.ms and Hud.clock(entry.ms) or w.race.dnf,ours=entry.who==me}
    end
    return note,rows
end

-- o: clock() (the race's clock in ms), name(w) (her name in a session, in words w), anchor() (her ghost's marker point
-- and feet in a session, puppet.anchor's).
function Hud.new(o)
    local self={}
    local hud=nil -- self.add's {kit, theme, settings}.
    local picked,lang,words,was_on=nil,nil,T.en,false
    function self.shown() return hud~=nil and not hud.kit.off() end
    function self.sound(name) if hud then hud.kit.sound(name) end end
    function self.hide() if hud then for _,g in ipairs(Hud.GROUPS) do hud.kit.show(g,false) end end end
    -- A racer's name in the results: hers in a session, a round player's cut as core/line.lua's name cuts it.
    local function name(r,w)
        return function(entry)
            if r.role~='match' then return entry.name or o.name(w) end
            return Join.name(entry.name) or w.chat.partner
        end
    end
    -- The HUD each frame of race r: the panel (the time, CP, LAP and POS, or the wait for her) or the results in its
    -- place, the banner, and the marker on our start before GO, then on the next checkpoint (the edge arrow when it is
    -- off screen or behind). away: the game paused or on one of its screens.
    function self.draw(r,away)
        if not hud or hud.kit.off() then return end
        local kit=hud.kit
        local panel=kit.view('race_panel')
        if panel and (panel~=picked or hud.settings.ui_language~=lang) then
            picked,lang=panel,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        local w,m=words,r.m
        local t=m.track
        local up=t~=nil and not away
        local results=up and (m.phase=='results' or r.role=='match' and (m.me.ms or m.me.why)~=nil)
        kit.show('race_panel',up and not results)
        kit.show('race_results',results)
        local b=r.banner
        if b and b.til and os.clock()>=b.til then r.banner,b=nil,nil end
        kit.show('race_banner',up and b~=nil)
        local bv=kit.view('race_banner')
        if bv and b then
            bv.text.set(b.build(w))
            bv.text.color(hud.theme[b.color] or hud.theme.text)
        end
        if panel and up and not results then
            local n,run,me,her=#t.cps,m.runner,m.me,m.her
            local ms=me.ms or r.stop_ms or (m.phase=='race' and o.clock()-m.t_go) or 0
            local cp=me.ms and n or run and run.next-1 or 0
            local lap=math.min(run and run.lap or 1,t.laps)
            local pos,of=Hud.place(r,r.role~='match' and select(2,o.anchor()) or nil)
            panel.title.set(w.race.title)
            if m.phase=='ready' and me.ready and her.joined and not her.ready and not her.out then
                panel.line.set(w.race.waiting:format(o.name(w)))
            else
                panel.line.set(Hud.line(w,ms,cp,n,lap,t.laps,pos,of))
            end
        end
        if results then
            local res=kit.view('race_results')
            if res then
                local f,flags=m.me.flags or 0,{}
                if f&1~=0 then flags[#flags+1]=w.race.fast end
                if f&2~=0 then flags[#flags+1]=w.race.pause end
                res.head.set(w.race.results)
                res.sub.set(table.concat(flags,' · '))
                local note,rows=Hud.results(r,w,name(r,w))
                res.note.set(note)
                for i,row in ipairs(res.rows) do
                    local e=rows[i]
                    row.label.set(e and e.label or '')
                    row.value.set(e and e.value or '')
                    local c=e and e.ours and hud.theme.beta or hud.theme.text
                    row.label.color(c)
                    row.value.color(c)
                end
            end
        end
        local target,label
        if up and (m.phase=='ready' or m.phase=='countdown') then
            local s=R.slot(t,m.slot or (r.role=='host' and 0 or 1))
            target,label={X=s.x,Y=s.y,Z=s.z},w.race.slot
        elseif up and m.phase=='race' and m.runner and not m.runner.done then
            local c=t.cps[m.runner.next]
            target,label={X=c.x,Y=c.y,Z=c.z},''
        end
        local mk,ar=kit.view('race_marker'),kit.view('race_arrow')
        local v=target and mk and ar and kit.project({X=target.X,Y=target.Y,Z=target.Z+ABOVE},os.clock())
        if not v then
            kit.show('race_marker',false)
            kit.show('race_arrow',false)
            return
        end
        local on,x,y,angle=P.place(v,was_on)
        was_on=on
        local far=r.pos and P.distance({X=r.pos.x,Y=r.pos.y,Z=r.pos.z},target,on) or ''
        if on then
            kit.show('race_arrow',false)
            kit.move('race_marker',x-MW/2,y-MH)
            mk.label.set(label)
            mk.far.set(far)
            kit.show('race_marker',true)
        else
            kit.show('race_marker',false)
            kit.move('race_arrow',x-AC,y-AC)
            ar.chevron.turn(angle+90) -- Its art points up.
            ar.far.set(far)
            kit.show('race_arrow',true)
        end
    end
    -- The HUD's groups on the Uplink kit, before its first build (main.lua, after Night Operation's): h is {kit,
    -- theme=ui.THEME, settings=main.lua's}.
    function self.add(h)
        hud=h
        local kit,theme=h.kit,h.theme
        local x=(3840-HUD_W)/2
        kit.add('race_panel',{x=x,y=HUD_Y,w=HUD_W,h=PANEL_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,PANEL_H)
            return {title=b.text(HUD_W/2,48,'','name',theme.beta,MIDDLE),
                line=b.text(HUD_W/2,104,'','item',theme.text,MIDDLE)}
        end)
        kit.add('race_results',{x=x,y=HUD_Y,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.beta,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.grey,MIDDLE),
                note=b.text(HUD_W/2,186,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,ROWS do
                local y=250+(i-1)*56
                v.rows[i]={label=b.text(96,y,'','body',theme.text,LEFT),
                    value=b.text(HUD_W-96,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
        kit.add('race_banner',{x=(3840-BANNER_W)/2,y=BANNER_Y,w=BANNER_W,h=BANNER_H,pivot={X=0.5,Y=0.5}},function(b)
            b.panel(0,0,BANNER_W,BANNER_H)
            return {text=b.text(BANNER_W/2,BANNER_H/2,'','title',theme.beta,MIDDLE)}
        end)
        -- Scaled from its bottom centre, over the checkpoint.
        kit.add('race_marker',{x=0,y=0,w=MW,h=MH,pivot={X=0.5,Y=1},inside=true},function(b)
            return {label=b.text(MW/2,22,'','hint',theme.beta,MIDDLE),
                diamond=b.image(MW/2-16,40,32,32,'diamond',theme.beta),far=b.text(MW/2,96,'','num',nil,MIDDLE)}
        end)
        -- The chevron turns around the diamond, at the group's (80, 80): the point on the edge.
        kit.add('race_arrow',{x=0,y=0,w=AW,h=AH,pivot={X=0.5,Y=AC/AH},inside=true},function(b)
            return {chevron=b.image(64,16,32,32,'chevron',theme.beta,{X=0.5,Y=2}),
                diamond=b.image(64,64,32,32,'diamond',theme.beta),far=b.text(52,116,'','num')}
        end)
    end
    return self
end
return Hud
