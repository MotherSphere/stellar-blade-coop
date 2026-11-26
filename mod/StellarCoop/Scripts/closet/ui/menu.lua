-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's menu (coop closet menu): opens, draws its screen (closet/ui/view.lua) and closes. The tabs, rows and
-- tiles are closet/ui/model.lua's over closet/fits.lua, with what is worn read from the dress (closet/dress.lua's
-- choices). It opens out of combat in the game world, the SBO lobby world included; it refuses on the first guard that
-- fails, with one notice. Open, it holds the kit's input as closet_menu with the mouse cursor. The tab shown is kept
-- across opens; the first open shows the first tab with a row of pieces. Each close drops every game part first (the
-- game holds EVE still while one is up), hides the group and gives the input back. close('revert') wears the confirmed
-- look again (dress.revert), close('keep') leaves the look as it is, close('stop') (coop off) does neither and plays no
-- sound. A draw that raises closes the menu with a revert and one log line.
-- o: {kit=ui/kit/kit.lua's, dress=closet/dress.lua's, words=function() the ui/text table to show, tell=function(build)
-- (main/base.lua's M.tell), log=, world=function() M.hud_shown, photo=function() M.photo_state(), status=function()
-- the link's status text or nil, adult=the Intimate tab shown}.
local U=require('core.unreal')
local UE=require('UEHelpers')
local Player=require('core.player')
local Fits=require('closet.fits')
local Model=require('closet.ui.model')
local View=require('closet.ui.view')
local T=require('ui.text')
local Menu={}
Menu.NEAR=3000 -- cm: an engaged enemy that near is combat (online/lobby/wiring.lua's fight check; no source).

function Menu.new(o)
    local kit,dress=o.kit,o.dress
    local log=o.log or function() end
    local model=Model.new({slots=require('closet.slots'),fits=Fits,installed=dress.installed,adult=o.adult==true})
    local view=View.new(kit,log)
    local self={}
    local open=false
    local tab,row -- Kept across opens; nil until the first.
    local function words() return o.words and o.words() or T.en end

    -- The key of the first guard that fails (closet.refused.<key>), or nil.
    local function refused()
        if not (kit and kit.ready() and not kit.off()) then return 'ui' end
        if not o.world() then return 'loading' end
        if kit.holding() then return 'panel' end
        if kit.paused(true) then return 'screen' end
        if o.photo()~='0' then return 'photo' end
        local eve=U.her(UE.GetPlayer())
        local theater=(o.status() or ''):match('theater=(%S+)')
        if theater and theater~='none' and theater~='fault' then return 'cutscene' end
        if eve and eve:IsAttachedToLevelSequenceWithoutPlayable()==true then return 'cutscene' end
        if eve and (eve:IsBattle()==true or Player.engaged(eve,Menu.NEAR)) then return 'combat' end
        if dress.game_look()~=nil then return 'tachy' end
        return nil
    end

    -- The first tab with a row of pieces and that row, else the first tab and row.
    local function first()
        for i,id in ipairs(model.tabs()) do
            for r,item in ipairs(model.rows(id)) do
                if item.state=='pieces' then return i,r end
            end
        end
        return 1,1
    end

    -- What view.draw shows now.
    local function state()
        local t=words()
        local w=t.closet
        local ids=model.tabs()
        tab=math.min(tab,#ids)
        local s={tabs={},tab=tab,rows={},hints={{t.hint.back,'Negative'}}}
        for i,id in ipairs(ids) do s.tabs[i]=w.tabs[id] or id end
        local list=model.rows(ids[tab])
        row=math.max(1,math.min(row,#list))
        s.row=#list>0 and row or nil
        local choices=dress.choices() or {}
        for i,item in ipairs(list) do
            if item.whole then
                s.rows[i]={title=item.outfit,value=item.pack,locked=item.locked}
            else
                local worn=model.worn(choices,item.slot)
                local value=item.state=='soon' and w.row.soon or item.state=='empty' and '' or
                    worn and Fits.piece(worn,item.slot).Name or w.row.none
                s.rows[i]={title=w.slots[item.slot] or item.slot,value=value,locked=item.state=='soon'}
            end
        end
        local item,shown=list[row],s.rows[row]
        s.detail={title=shown and shown.title or '',desc=''}
        if item and item.whole then
            s.detail.desc=item.locked and w.row.locked:format(item.pack) or w.row.whole
        elseif item and item.state~='pieces' then
            s.detail.desc=w.row[item.state]
        elseif item then
            local worn=model.worn(choices,item.slot)
            s.tiles={}
            for i,tile in ipairs(model.tiles(item.slot)) do
                local equipped=tile.none and worn==nil or tile.fit==worn
                s.tiles[i]={name=tile.none and w.row.none or tile.name,equipped=equipped,locked=tile.locked}
                if equipped then s.tile=i end
            end
            s.detail.equipped=worn~=nil
            if worn then s.detail.desc=w.detail.outfit:format(Fits.get(worn).Outfit) end
            s.hints[2]={t.hint.select,'Positive'}
        end
        return s
    end

    -- Every part dropped first, then the group hidden and the input given back; how: 'revert' (default), 'keep',
    -- 'stop'.
    function self.close(how)
        how=how or 'revert'
        if not open then return true,'closet menu: not open' end
        open=false
        local dropped,why=pcall(view.drop_all)
        if not dropped then log('menu: drop failed: '..tostring(why)) end
        kit.show(View.GROUP,false)
        kit.input(false,View.GROUP)
        if how~='stop' then kit.sound('close') end
        if how=='revert' then dress.revert() end
        log('menu: closed ('..how..')')
        return true,'closet menu: closed'
    end

    function self.open()
        if open then return true,'closet menu: open' end
        local read,key=pcall(refused)
        if not read then
            log('menu: a guard could not be read: '..tostring(key))
            return false,'closet menu: not opened (UE4SS.log says why)'
        end
        if key then
            o.tell(function(t) return t.closet.refused[key] end)
            return false,T.en.closet.refused[key]
        end
        if not tab then tab,row=first() end
        kit.input(true,View.GROUP,true)
        kit.sound('open')
        kit.show(View.GROUP,true)
        open=true
        log('menu: open')
        local drawn,why=pcall(function() view.draw(state()) end)
        if not drawn then
            log('menu: draw failed: '..tostring(why))
            self.close('revert')
            return false,'closet menu: closed, it could not draw (UE4SS.log says why)'
        end
        return true,'closet menu: open'
    end

    function self.is_open() return open end
    -- A menu word from main/keys.lua (up, down, left, right, select, back, tab_left, tab_right, refresh): back closes.
    function self.nav(word)
        if open and word=='back' then self.close('revert') end
    end
    -- Each frame (closet/wiring.lua, through main/frame.lua's guard): nothing to watch yet.
    function self.tick() end
    -- coop off: closed without a revert (the dress gives EVE her own look back).
    function self.stop() self.close('stop') end
    return self
end

return Menu
