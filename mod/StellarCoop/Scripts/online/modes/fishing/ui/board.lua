-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's screens on the Uplink kit (ui/kit/kit.lua): the corner board at the top right, clear of the
-- partner card, the feed and the chat box at the top left (its title line: FISHING, then the countdown, the time left
-- or Time up; under it the last board's top three, then ours when we are not among them, ours in teal) and, from our
-- end, the result panel at the top centre in score attack's layout (online/modes/scoreattack/ui/board.lua: the
-- heading, our points and fish, a note, then one row per ranked player). The panel closes SHOW seconds after the
-- ranking or after the note that none came. Both are hidden while the game is paused or shows one of its screens. The
-- round's notices (the start, a sit-out, a reloaded game) and why a tournament ends with no ranking come as notices
-- whatever the kit shows. With the kit off or absent, GO, each change of our place or points, our end, the first
-- three and our place come as notices too. Its words follow the game's language unless ui_language=english.
-- tests/lua/online/modes/fishing/board_test.lua covers it on a fake kit.
local T=require('ui.text')
local Join=require('core.line')
local Fm=require('online.modes.fishing.model')
local Board={}
-- Kit layout units (3840 by 2160): the corner board's title glass over its rows, each row on its own glass, 96 in
-- from the top right; the result panel as score attack's (1040 wide, a heading, two lines, then the ranking's rows).
local SIDE,TOP=96,96
local CORNER_W,TITLE_H,ROW_H,CORNER_ROWS,GAP=720,96,52,4,12
local HUD_W,RESULT_H,RANK_ROWS=1040,720,8
local SHOW=20 -- Seconds the result panel stays after the ranking or the no-ranking note (DESIGN section 2, step 8).
local TOP_THREE=3
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
local GROUPS={'fishing','fishing_result'}
-- The corner board of tournament cur (online/modes/fishing/round.lua's) at now in words w: its title line and its
-- rows ({id=, points=, catches=, place=} each): the top three of the last board (before the first one, the go line's
-- players at 0), then ours when we are not among them.
function Board.corner(cur,now,w)
    local f=w.fishing
    local at,n=Fm.clock(cur.go,cur.minutes,now)
    local clock=at=='count' and f.count:format(n) or at=='play' and string.format('%d:%02d',n//60,n%60) or f.up
    local list=cur.board
    if not list then
        list={}
        for k,id in ipairs(cur.ids) do list[k]={id=id,points=0,catches=0,place=1} end
    end
    local rows={}
    for i,r in ipairs(list) do if i<=TOP_THREE or r.id==cur.me then rows[#rows+1]=r end end
    return f.head..'  '..clock,rows
end
-- The result panel of cur in words w: its heading, the line under it (our points and fish, from our row in the ranking
-- or else in the last board; '' without one), the note (Waiting for the host's ranking. before it, Not ranked. once a
-- ranking without us came, New personal best. when ours wrote one, No ranking came from the host. after the wait) and
-- one {label=, fish=, value=, ours=} per ranked player. name(id): her name as shown.
function Board.result(cur,w,name)
    local f=w.fishing
    local mine=nil
    for _,r in ipairs(cur.list or cur.board or {}) do if r.id==cur.me then mine=r end end
    local rows={}
    for i,r in ipairs(cur.list or {}) do
        rows[i]={label=r.place..'  '..name(r.id),fish=f.fish:format(r.catches),value=tostring(r.points),
            ours=r.id==cur.me}
    end
    local note=f.waiting
    if cur.list then note=not mine and f.unranked or cur.best and f.best or ''
    elseif cur.why=='norank' then note=f.norank end
    return f.title,mine and f.mine:format(mine.points,mine.catches) or '',note,rows
end
-- o: round() (round.lua's round(): our last tournament, or nil), name(id) (her Steam name, ours for our SteamID),
-- tell(build) (main.lua's notice: build(words) gives its text), clock() (round.lua's clock), log(line).
function Board.new(o)
    local self={}
    local hud=nil -- self.hud's {kit, theme, settings}; nil without one, or after a HUD error.
    -- seen: what this tournament showed or said {cur=, said={key=true}, standing= our last place and points said,
    -- closes= when the result panel closes}.
    local seen=nil
    local picked,lang,words=nil,nil,nil
    local function shown() return hud~=nil and not hud.kit.off() end
    local function name(id) return Join.name(o.name(id)) or id end
    local function tell(build) if o.tell then o.tell(build) end end
    -- A notice once a tournament: always (why), or only while the kit cannot show it (what the HUD shows).
    local function once(key,always,build)
        if seen.said[key] then return end
        seen.said[key]=true
        if always or not shown() then tell(build) end
    end
    local function hide() for _,g in ipairs(GROUPS) do hud.kit.show(g,false) end end
    local function colour(row,ours)
        local c=ours and hud.theme.teal or hud.theme.text
        row.label.color(c)
        row.value.color(c)
    end
    local function draw(cur,now,playing,result)
        local kit=hud.kit
        local away=kit.paused()
        local corner,res=kit.view('fishing'),kit.view('fishing_result')
        kit.show('fishing',playing and not away)
        kit.show('fishing_result',result and not away)
        if corner and (corner~=picked or hud.settings.ui_language~=lang) then
            picked,lang=corner,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        local w=words or T.en
        if playing and corner then
            local title,rows=Board.corner(cur,now,w)
            corner.title.set(title)
            for i,row in ipairs(corner.rows) do
                local e=rows[i]
                row.back.show(e~=nil)
                row.label.set(e and e.place..'  '..name(e.id) or '')
                row.value.set(e and tostring(e.points) or '')
                colour(row,e and e.id==cur.me)
            end
        end
        if result and res then
            local head,sub,note,rows=Board.result(cur,w,name)
            res.head.set(head)
            res.sub.set(sub)
            res.note.set(note)
            for i,row in ipairs(res.rows) do
                local e=rows[i]
                row.label.set(e and e.label or '')
                row.fish.set(e and e.fish or '')
                row.value.set(e and e.value or '')
                colour(row,e and e.ours)
            end
        end
    end
    -- Our row of a list, or nil.
    local function ours(cur,list)
        for _,r in ipairs(list or {}) do if r.id==cur.me then return r end end
    end
    local function step()
        local cur=o.round()
        if not cur then
            if hud then hide() end
            return
        end
        if not seen or seen.cur~=cur then seen={cur=cur,said={},standing='1:0'} end -- Every player starts 1st at 0.
        local now=o.clock()
        local at=cur.go and Fm.clock(cur.go,cur.minutes,now)
        local playing=cur.phase=='play' and cur.go~=nil
        if (cur.list or cur.why=='norank') and not seen.closes then seen.closes=now+SHOW end
        local result=(playing and at=='up' or cur.list~=nil or cur.why=='norank')
            and not (seen.closes and now>=seen.closes)
        if cur.phase=='over' then -- A tournament that ends without a ranking says why.
            if cur.why=='host_left' then once('why',true,function(w) return w.fishing.host_left end)
            elseif cur.why=='void' then once('why',true,function(w) return w.fishing.cancelled end)
            elseif cur.why=='norank' then once('why',false,function(w) return w.fishing.norank end) end
        end
        if playing and at=='play' then
            once('go',false,function(w) return w.fishing.go:format(cur.minutes) end)
        end
        local mine=ours(cur,cur.board)
        if playing and mine and not shown() and mine.place..':'..mine.points~=seen.standing then
            seen.standing=mine.place..':'..mine.points
            tell(function(w) return w.fishing.standing:format(mine.place,mine.points) end)
        end
        if playing and at=='up' then
            once('end',false,function(w)
                return w.fishing.end_notice:format(mine and mine.points or 0,mine and mine.catches or 0)
            end)
        end
        if cur.list then
            local list=cur.list
            if list[1] then
                once('top',false,function(w)
                    local f,each=w.fishing,{}
                    for i=1,math.min(TOP_THREE,#list) do
                        each[i]=f.entry:format(list[i].place,name(list[i].id),list[i].points)
                    end
                    return f.top:format(table.concat(each,f.sep))
                end)
            end
            once('placed',false,function(w)
                local r=ours(cur,list)
                return r and w.fishing.placed:format(r.place,#list) or w.fishing.unranked
            end)
        end
        if not shown() then return end
        draw(cur,now,playing,result)
    end
    -- Every 250 ms, after the round's pass and the game side's: the notices, then the HUD. An error in the HUD gives
    -- one STOP line and notices from then on.
    function self.tick()
        local ok,e=pcall(step)
        if ok then return end
        o.log('STOP: HUD: '..tostring(e))
        if hud then pcall(hide) end
        hud=nil
    end
    -- round.lua's tell(key, ...), said whatever the kit shows: starts (the host's name, the minutes), out (fish()'s
    -- why: off, slot, table), reloaded.
    function self.notice(key,a,b)
        tell(function(w)
            local f=w.fishing
            if key=='starts' then return f.start:format(Join.name(a) or tostring(a),b) end
            if key=='out' then return f.out[a] or f.out.table end
            return f.reloaded
        end)
    end
    -- coop off (or any stop): every group hidden now, as no tick may come after it to hide them.
    function self.stop() if hud then pcall(hide) end end
    -- The groups on the Uplink kit, before its first build (main/ui.lua's hud step, after score attack's): h is {kit,
    -- theme=ui.THEME, settings= (main.lua's, ui_language read at each update)}.
    function self.hud(h)
        hud=h
        local kit,theme=h.kit,h.theme
        kit.add('fishing',{x=3840-SIDE-CORNER_W,y=TOP,w=CORNER_W,h=TITLE_H+GAP+CORNER_ROWS*ROW_H,pivot={X=1,Y=0}},
            function(b)
                b.panel(0,0,CORNER_W,TITLE_H)
                local v={title=b.text(CORNER_W/2,TITLE_H/2,'','name',theme.warn,MIDDLE),rows={}}
                for i=1,CORNER_ROWS do
                    local y=TITLE_H+GAP+(i-1)*ROW_H
                    v.rows[i]={back=b.image(0,y,CORNER_W,ROW_H-4,nil,theme.panel),
                        label=b.text(32,y+ROW_H/2-2,'','body',theme.text,LEFT),
                        value=b.text(CORNER_W-32,y+ROW_H/2-2,'','body',theme.text,RIGHT)}
                end
                return v
            end)
        local x=(3840-HUD_W)/2
        kit.add('fishing_result',{x=x,y=TOP,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.teal,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.text,MIDDLE),
                note=b.text(HUD_W/2,186,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,RANK_ROWS do
                local y=250+(i-1)*56
                v.rows[i]={label=b.text(64,y,'','body',theme.text,LEFT),
                    fish=b.text(780,y,'','status',theme.grey,RIGHT),
                    value=b.text(HUD_W-64,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
    end
    return self
end
return Board
