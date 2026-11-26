-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's menu (coop closet menu): opens, draws its screen (closet/ui/view.lua) and closes. The tabs, rows and
-- tiles are closet/ui/model.lua's over closet/fits.lua, with what is worn read from the dress (closet/dress.lua's
-- choices). It opens out of combat in the game world, the SBO lobby world included; it refuses on the first guard that
-- fails, with one notice. Open, it holds the kit's input as closet_menu with the mouse cursor. The tab shown is kept
-- across opens; the first open shows the first tab, Full outfit. Each close drops every game part first (the
-- game holds EVE still while one is up) and hides the group. The input comes back BACK s after the close, so the key
-- that closed it (Esc would open the pause menu) never reaches the game. It is asked again each tick while closed until
-- the kit has given it (no player controller at the close); an open before then takes it on. close('revert') wears the
-- confirmed look again (dress.revert), close('keep') leaves the look as it is, close('stop') (coop off) does neither,
-- plays no sound and gives the input back at once. A revert that fails at the close (no EVE during a map change) is
-- asked again each RETRY s while closed and not paused until it works; an open or coop off drops it. A draw that
-- raises closes the menu with a revert and one log line.
-- Focus: the tabs, the rows or the grid (col). E and Q change the tab; the window of View.TABS tabs follows the
-- focused tab. Up and down walk the rows; up on the first row reaches the tabs. Right or select on a row of pieces goes
-- into its grid; left and right walk its tiles, up and down its rows of View.COLUMNS tiles (down to a shorter last row
-- stops on its last tile; up on the first row and down on the last stay); left on the first tile or back returns to the
-- rows. A tile focused for PREVIEW s is worn as a preview (dress.preview); select wears it at once and returns to the
-- rows; refresh wears the whole outfit of the focused tile (the worn one in the rows) or of the Full tab's row, which
-- select wears too. Locked tiles and soon or empty rows never wear. The hints:
-- Back, then Wear on a row of pieces or Whole outfit on the Full tab's row (both on Select's icon), then Whole outfit
-- on the top face button's icon when refresh has an outfit to wear. Back in the rows or the tabs closes
-- with a revert when nothing changed since the open. Else the popup asks "Keep this look?": Yes confirms
-- (dress.confirm), No reverts, Back stays. For the keyboard and the pad, Select is Yes and refresh (F, the pad's Y) is
-- No. Select does nothing for ARM s after the open: the console's Enter that typed coop closet menu reaches our Enter
-- bind too (main/base.lua's M.typed_at note). The None tile on the last piece worn previews her own look; when the menu
-- opened on her own look, it reverts instead: nothing changed since the open.
-- Mouse: a click on a hint chip runs that hint's word (view.hint_hovered); a tile a left click picked is worn at once,
-- a tile the grid picked otherwise (hover, focus) once it stayed picked PREVIEW s.
-- The Body tab's Body row (BaseBody) lists None (the body rule picks the body) then each outfit with skin: its tile
-- picks that outfit's body. The row's value is the body in use: the picked one, else the one the look on EVE wears
-- (dress.plan). A tile's detail and the Full tab's rows name the origin: Original, or Custom and the pack, with the
-- origin's badge. Each tile shows its piece's picture (closet/thumbs.lua's cached PNG), else its outfit's Image, else
-- its slot's glyph (closet/slots.lua); the None tile None's glyph. The Full tab's outfit row shows one tile, its
-- outfit's whole picture (full.png), else its Image, else the Full outfit glyph; Select still wears the row. Which
-- pictures are there is read again at each open. The Full tab's row before the last, Make preview pictures (hint
-- Select), starts coop closet thumbs (closet/thumbs.lua) for every picture not there yet. That run waits for the
-- menu's close. It tells closet.thumbs.started (also when a run is going), cached (every picture is there) or failed
-- (the reason logged); the menu stays open.
-- A preview whose plan switched the body or leaves skin showing under a piece tells closet.switched or closet.clips,
-- once until that changes. The menu shows the same lines under its rows as long as the look on EVE has them (the
-- chat feed draws under the menu's shade). The Full tab's last row, Reset Stellar Closet (hint Select), asks with the
-- game's Yes/No popup: Yes runs coop closet off (dress.off), turns every colour off (colour.off: its file cleared),
-- sets every shape value to 0 (shape.off: its file cleared), tells closet.reset_done, closes without the Keep popup or
-- a revert and has the camera forget its mode and pose (its file cleared); No and Back stay.
-- The Colour tab (after Body) has a row for each role of closet/colour.lua; its value is the role's swatch. Right and
-- Select (a click on the row too) take the next swatch, left the one before (colour.step): the palette is saved at
-- once, apart from the look, so it never asks Keep this look? Its detail says what the role colours and how to pick.
-- The Body tab lists, below its Body row, a row for each name of closet/shape.lua's rows (the look as last put on);
-- its value is the name's value in percent. Left and right step it by Shape.STEP from 0 to 100, Select (a click on the
-- row too) takes the next step, 0 after 100: the value is saved at once, apart from the look. Rows that change with the
-- look are drawn again at the next tick.
-- Each GUARD s while open: a map change, photo mode, a cutscene or the input given back (coop ui reset) closes it with
-- a revert and a closet.closed notice; combat is read each COMBAT s. A preview ended by a typed coop closet wear or off
-- closes it without a revert.
-- The camera (closet/ui/camera.lua, when given): opened after a good open, closed on every close path (stopped by coop
-- off, also while the menu is closed), ticked each frame with the region of the focused slot (of the tab on the tab
-- row or a row with no slot; nil while closed). The camera words (cam_left, cam_right, cam_up, cam_down, cam_in,
-- cam_out, cam_mode, cam_reset) and the light words (light_next, light_up, light_down) go to it; while it runs, the
-- camera hint row shows its mode on C (the pad's X), Reset camera on Backspace (the pad's R3) and the light preset on V
-- (the pad's L3), each a chip a click runs. The preset's intensity shows after its name on every preset but Game.
-- o: {kit=ui/kit/kit.lua's, dress=closet/dress.lua's, words=function() the ui/text table to show, tell=function(build)
-- (main/base.lua's M.tell), log=, world=function() M.hud_shown, photo=function() M.photo_state(), status=function()
-- the link's status text or nil, adult=the Intimate tab shown, now=function() the time in s (os.clock when nil),
-- camera=closet/ui/camera.lua's or nil, folder=the mod folder (main.lua's M.folder: the pictures' root) or nil,
-- thumbs=closet/thumbs.lua's or nil, colour=closet/colour.lua's or nil (the Colour rows then show Off and pick
-- nothing), shape=closet/shape.lua's or nil (no shape row then)}.
local U=require('core.unreal')
local UE=require('UEHelpers')
local Player=require('core.player')
local Fits=require('closet.fits')
local Slots=require('closet.slots')
local Model=require('closet.ui.model')
local View=require('closet.ui.view')
local Camera=require('closet.ui.camera')
local Thumbs=require('closet.thumbs')
local Shape=require('closet.shape')
local T=require('ui.text')
local Menu={}
Menu.NEAR=3000 -- cm: an engaged enemy that near is combat (online/lobby/wiring.lua's fight check; no source).
Menu.PREVIEW,Menu.ARM,Menu.GUARD,Menu.COMBAT=0.25,0.3,0.25,1 -- s.
Menu.BACK=0.15 -- s before the game's input comes back after a close (ui/kit/menu.lua's BACK).
Menu.RETRY=1 -- s between two asks of a failed close revert (the dress watchdog's pace).

function Menu.new(o)
    local kit,dress=o.kit,o.dress
    local log=o.log or function() end
    local now=o.now or os.clock
    local model=Model.new({slots=Slots,fits=Fits,installed=dress.installed,adult=o.adult==true,
        shapes=o.shape and o.shape.rows})
    local view=View.new(kit,log)
    local self={}
    local open=false
    local tab,row -- Kept across opens; nil until the first.
    local tab_top=1 -- The first tab shown, kept across opens.
    -- col: 'tabs', 'rows' or 'grid'; tile: the focused tile in the grid; asking: the popup shows (true: Keep this
    -- look?, 'reset': Reset Stellar Closet?); changed: a preview since the open; due: when the focused tile is worn
    -- (nil: none waits); opened, guard_at, combat_at: times in s; bare: the menu opened on her own look (nothing worn,
    -- no preview going); said: the body switch and clips last told since the open.
    local col,tile,asking,changed,due,opened,guard_at,combat_at,bare,said='rows',1,false,false,nil,0,0,0,false,nil
    -- back_at: when the input is given back after a close; owed: the kit still holds it for us since a close;
    -- unreverted: a close's revert failed (no EVE during a map change), asked again each RETRY s while closed.
    local back_at,owed,unreverted=nil,false,false
    -- frame: ticks so far; undo: the focus before the last tab_left while only left followed it ({tab, row, col, tile,
    -- tab_top, at=the frame of the last of them}), for the pad chord (self.toggle); stepped: a left on a Colour or
    -- shape row ({at=its frame, back=what puts the swatch or value back}), given back by the chord.
    local frame,undo,stepped=0,nil,nil
    local listed -- closet/shape.lua's rows as of the last draw: new ones are drawn at the next tick.
    local clicked -- The frame of the last left click (nav 'click'), until a tile pick uses it.
    -- camera: closet/ui/camera.lua's or nil; region: the focused one, as of the last draw; hinted: the camera's mode,
    -- light preset and intensity the camera hints show (false: none); ticked: the last tick's time.
    local camera,region,hinted,ticked=o.camera,'full',false,nil
    local function words() return o.words and o.words() or T.en end
    local there={} -- Picture file -> whether it is there, read again at each open.
    -- The cached picture of a fit's slot (Thumbs.FULL: the whole outfit), or nil.
    local function picture(fit,slot)
        if not (o.folder and fit) then return nil end
        local file=Thumbs.file(o.folder,fit,slot)
        if there[file]==nil then there[file]=Thumbs.fs.exists(file) end
        return there[file] and file or nil
    end
    -- What the camera hints show now: false with no camera running.
    local function camera_shown()
        if not (camera and camera.running()) then return false end
        local preset,factor=camera.light()
        return camera.mode()..'|'..preset..'|'..factor
    end
    local function camera_word(w) return w:sub(1,4)=='cam_' or w:sub(1,6)=='light_' end
    local function swatch(role) return o.colour and o.colour.get(role) or 'off' end

    local function cutscene(eve)
        local theater=(o.status() or ''):match('theater=(%S+)')
        if theater and theater~='none' and theater~='fault' then return true end
        return eve~=nil and eve:IsAttachedToLevelSequenceWithoutPlayable()==true
    end
    local function combat(eve) return eve~=nil and (eve:IsBattle()==true or Player.engaged(eve,Menu.NEAR)) end

    -- The key of the first guard that fails (closet.refused.<key>), or nil.
    local function refused()
        if not (kit and kit.ready() and not kit.off()) then return 'ui' end
        if not o.world() then return 'loading' end
        if kit.holding() and not owed then return 'panel' end -- Held for us since a close: not another panel.
        if kit.paused(true) then return 'screen' end
        if o.photo()~='0' then return 'photo' end
        local eve=U.her(UE.GetPlayer())
        if cutscene(eve) then return 'cutscene' end
        if combat(eve) then return 'combat' end
        if dress.game_look()~=nil then return 'tachy' end
        return nil
    end
    -- While open: the key of the first guard that fails (closet.closed.<key>), or nil. Combat each COMBAT s.
    local function closing(t)
        if not (kit.ready() and o.world() and view.alive()) then return 'map' end
        if o.photo()~='0' then return 'photo' end
        local eve=U.her(UE.GetPlayer())
        if cutscene(eve) then return 'cutscene' end
        if not kit.holding() then return 'input' end -- coop ui reset gave the game its input back.
        if t>=combat_at then
            combat_at=t+Menu.COMBAT
            if combat(eve) then return 'combat' end
        end
        return nil
    end

    -- The focused row's item; on a row of pieces also its tiles and the worn tile's index (None when none is worn).
    local function focused(choices)
        local item=model.rows(model.tabs()[tab])[row]
        if not item or item.state~='pieces' then return item end
        local tiles,worn=model.tiles(item.slot),model.worn(choices or dress.choices() or {},item.slot)
        for i,one in ipairs(tiles) do
            if one.fit==worn then return item,tiles,i end
        end
        return item,tiles,1
    end

    local function names(ids,from)
        local out={}
        for i,id in ipairs(ids) do out[i]=from[id] or id end
        return table.concat(out,', ')
    end
    -- An outfit's origin line: Original, or Custom and its pack.
    local function origin(w,fit)
        return Fits.origin(fit)=='original' and w.origin.original or w.origin.custom:format(Fits.get(fit).Pack)
    end
    -- A tile's detail lines: its outfit, slot, origin, covers, what else it takes, hidden by default, locked.
    local function lines(w,one,slot)
        local out={}
        if not one.none then out[#out+1]=w.detail.outfit:format(one.outfit) end
        out[#out+1]=w.detail.slot:format(w.slots[slot] or slot)
        if one.fit then out[#out+1]=origin(w,one.fit) end
        if one.covers then out[#out+1]=w.detail.covers:format(names(one.covers,w.regions)) end
        if one.also then out[#out+1]=w.detail.also:format(names(one.also,w.slots)) end
        if one.off then out[#out+1]=w.detail.off end
        if one.locked then out[#out+1]=w.row.locked:format(one.pack) end
        return table.concat(out,'\n')
    end

    -- What view.draw shows now.
    local function state()
        local t=words()
        local w=t.closet
        local ids=model.tabs()
        tab=math.min(tab,#ids)
        -- The window moves only when the focused tab leaves it, as the rows' window does.
        tab_top=math.max(1,math.min(math.max(tab_top,tab-View.TABS+1),tab,#ids-View.TABS+1))
        local s={tabs={},tab=tab,tab_top=tab_top,rows={},hints={{t.hint.back,'Negative',word='back'}},camera_hints={}}
        for i,id in ipairs(ids) do s.tabs[i]=w.tabs[id] or id end
        listed=o.shape and o.shape.rows()
        local list=model.rows(ids[tab])
        row=math.max(1,math.min(row,#list))
        s.row=#list>0 and row or nil
        local choices=dress.choices() or {}
        local plan=dress.plan() -- The look on EVE now: its body and notice.
        for i,item in ipairs(list) do
            if item.whole then
                s.rows[i]={title=item.outfit,value=item.pack,locked=item.locked}
            elseif item.reset or item.thumbs then
                s.rows[i]={title=item.reset and w.row.reset or w.row.thumbs,value=''}
            elseif item.role then
                s.rows[i]={title=w.colour.roles[item.role],value=w.colour.swatches[swatch(item.role)]}
            elseif item.morph then -- The morph name as its mesh writes it.
                s.rows[i]={title=item.morph,value=w.shape.value:format(o.shape.get(item.morph))}
            else
                local worn=model.worn(choices,item.slot)
                -- The Body row names the body in use: the picked one, else the plan's (switched or the rule's).
                local body=item.slot=='BaseBody' and not worn and plan and Fits.get(plan.body.fit).Outfit
                local value=item.state=='soon' and w.row.soon or item.state=='empty' and '' or
                    worn and model.piece(worn,item.slot).Name or body or w.row.none
                s.rows[i]={title=w.slots[item.slot] or item.slot,value=value,locked=item.state=='soon'}
            end
        end
        local item,shown=list[row],s.rows[row]
        region=Camera.region(col~='tabs' and item and item.slot or ids[tab])
        hinted=camera_shown()
        if hinted then
            local preset,factor=camera.light()
            local light=w.light[preset]..(preset~='game' and (' x%g'):format(factor) or '')
            -- UI_FaceButton_Left: SB's UI action for the left face button (the pad's X), the 26123051 exe's
            -- FUN_14254baf0 case 0; UI_RightThumbstick and UI_LeftThumbstick: action names of the same exe (FNames at
            -- FUN_1407f2100 and FUN_1407f2050, strings 0x145c4ec00 and 0x145c4ebd8). The keyboard keys are in the
            -- labels: SB's own key map for those actions is not read.
            s.camera_hints={{'C  '..w.camera[camera.mode()],'UI_FaceButton_Left',word='cam_mode'},
                {'Backspace  '..w.camera.reset,'UI_RightThumbstick',word='cam_reset'},
                {'V  '..light,'UI_LeftThumbstick',word='light_next'}}
        end
        s.detail={title=shown and shown.title or '',desc=''}
        if item and item.whole then
            s.detail.desc=(item.locked and w.row.locked:format(item.pack) or w.row.whole)..'\n'..origin(w,item.whole)
            s.detail.badge=Fits.origin(item.whole)
            s.tiles={{name=item.outfit,locked=item.locked,picture=picture(item.whole,Thumbs.FULL),
                image=Fits.get(item.whole).Image,icon=Slots.glyph(Slots.FULL_OUTFIT)}}
            if not item.locked then s.hints[2]={w.hints.whole,'Positive',word='select'} end
        elseif item and (item.reset or item.thumbs) then
            s.detail.desc=item.reset and w.popup.reset_desc or w.row.thumbs_desc
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.role then
            s.detail.desc=w.colour.about[item.role]..'\n'..w.colour.help
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.morph then
            s.detail.desc=w.shape.about..'\n'..w.shape.help
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.state~='pieces' then
            s.detail.desc=w.row[item.state]
        elseif item then
            local worn=model.worn(choices,item.slot)
            local _,tiles,at=focused(choices)
            s.tiles={}
            for i,one in ipairs(tiles) do
                s.tiles[i]={name=one.none and w.row.none or one.name,equipped=i==at,locked=one.locked,
                    picture=picture(one.fit,item.slot),image=one.fit and Fits.get(one.fit).Image,
                    icon=one.none and 'none' or Slots.glyph(item.slot)}
            end
            if col=='grid' then
                tile=math.max(1,math.min(tile,#tiles))
                s.tile=tile
                s.detail={title=s.tiles[tile].name,desc=lines(w,tiles[tile],item.slot),equipped=tile==at,
                    badge=tiles[tile].fit and Fits.origin(tiles[tile].fit)}
            else
                s.tile=at
                s.detail.equipped=worn~=nil
                if worn then
                    s.detail.desc=w.detail.outfit:format(Fits.get(worn).Outfit)..'\n'..origin(w,worn)
                    s.detail.badge=Fits.origin(worn)
                end
            end
            s.hints[2]={w.hints.wear,'Positive',word='select'}
            -- UI_FaceButton_Top: the game's UI action for the top face button (F, the pad's Y), as in
            -- online/session/ui/sessions.lua; the 26123051 exe names it in FUN_14254baf0 (case 1) beside UI_LeftShoulder.
            local one=tiles[col=='grid' and tile or at]
            if one and one.fit and not one.locked then s.hints[3]={w.hints.whole,'UI_FaceButton_Top',word='refresh'} end
        end
        -- Move last, on the D-pad's up and down icons, as the lobby shows it (the keyboard's keys or the pad's buttons).
        s.hints[#s.hints+1]={t.hint.move,'UI_DPad_Up','UI_DPad_Down'}
        -- The plan's body switch and clip warning, shown as long as the look on EVE has them.
        local notes={}
        if plan and plan.switched then notes[1]=w.switched:format(Fits.get(plan.switched).Outfit) end
        if plan and plan.clips then notes[#notes+1]=w.clips:format(names(plan.clips,w.regions)) end
        s.notice=table.concat(notes,'\n')
        if asking=='reset' then s.popup={title=w.popup.reset_title,desc=w.popup.reset_desc}
        elseif asking then s.popup={title=w.popup.title,desc=w.popup.desc} end
        return s
    end

    -- Every part dropped first, then the group hidden and the input given back; how: 'revert' (default), 'keep',
    -- 'stop', 'reset' (after coop closet off: as keep); why: the guard that closed it, for the log.
    function self.close(how,why)
        how=how or 'revert'
        if not open then return true,'closet menu: not open' end
        open,asking,due=false,false,nil
        if camera and how=='stop' then camera.stop() elseif camera then camera.close() end
        local dropped,fault=pcall(view.drop_all)
        if not dropped then log('menu: drop failed: '..tostring(fault)) end
        kit.show(View.GROUP,false)
        if how=='stop' then kit.input(false,View.GROUP); back_at,owed=nil,false
        else back_at,owed=now()+Menu.BACK,true end
        if how~='stop' then kit.sound('close') end
        -- The dress tick re-mixes the preview on the new EVE, not the confirmed look: the revert is owed until it works.
        if how=='revert' then
            local ran,good,failed=pcall(dress.revert)
            unreverted=not (ran and good)
            if unreverted then log('menu: revert failed, asked again: '..tostring(ran and failed or good)) end
        else unreverted=false end
        guard_at=now()+Menu.GUARD
        log('menu: closed ('..how..(why and ', '..why or '')..')')
        return true,'closet menu: closed'
    end

    -- Draws the state; a draw that raises closes the menu with a revert.
    local function redraw()
        if not open then return end
        local drawn,why=pcall(function() view.draw(state()) end)
        if not drawn then
            log('menu: draw failed: '..tostring(why))
            self.close('revert')
        end
        return drawn
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
        if not tab then tab,row=1,1 end
        col,tile,asking,changed,due,said,undo='rows',1,false,false,nil,nil,nil
        bare=not dress.previewing() and #(dress.choices() or {})==0
        back_at,owed,unreverted=nil,false,false -- An owed revert: Back or No on this open reverts.
        opened=now()
        guard_at,combat_at=opened+Menu.GUARD,opened+Menu.COMBAT
        there={} -- The pictures read again: coop closet thumbs may have made some since.
        view.reread()
        kit.input(true,View.GROUP,true)
        kit.sound('open')
        kit.show(View.GROUP,true)
        open=true
        log('menu: open')
        local drawn=redraw()
        if drawn and camera then -- After a good draw only, then drawn again with its hints.
            camera.open()
            drawn=redraw()
        end
        if not drawn then return false,'closet menu: closed, it could not draw (UE4SS.log says why)' end
        return true,'closet menu: open'
    end

    -- choices worn as a preview; a failure is told and logged, so is the plan's body switch or skin under a piece.
    local function wear(choices)
        due=nil
        local ran,good,why,plan=pcall(dress.preview,choices)
        if not (ran and good) then
            log('menu: preview failed: '..tostring(ran and why or good))
            o.tell(function(t) return t.closet.failed end)
        elseif plan then
            local key=(plan.switched or '')..'|'..table.concat(plan.clips or {},',')
            if key~=said then
                said=key
                if plan.switched then
                    o.tell(function(t) return t.closet.switched:format(Fits.get(plan.switched).Outfit) end)
                end
                if plan.clips then
                    o.tell(function(t) return t.closet.clips:format(names(plan.clips,t.closet.regions)) end)
                end
            end
        end
        changed=changed or dress.previewing()
    end
    -- The focused tile worn, None taking the slot off; a locked tile or the worn one: nothing.
    local function wear_tile()
        local choices=dress.choices() or {}
        local item,tiles,at=focused(choices)
        local one=tiles and tiles[tile]
        due=nil
        if not one or one.locked or tile==at then return end
        local to=model.choose(choices,item.slot,one.fit)
        -- The last piece off on a bare open is the look it opened on: reverted, so Back asks no popup. Else the empty
        -- look is a preview of her own look (dress.preview({})).
        if #to==0 and bare then dress.revert(); changed=false; return end
        wear(to)
    end
    -- refresh: the whole outfit of the focused tile (the worn one in the rows) or of the Full tab's row.
    local function wear_whole()
        local item,tiles,at=focused()
        local one=item and item.whole and {fit=item.whole,locked=item.locked}
        if tiles then one=tiles[col=='grid' and tile or at] end
        if one and one.fit and not one.locked then wear(model.whole(one.fit)) end
    end

    -- Make preview pictures: coop closet thumbs started from the menu (it waits for the close), told; a run going is
    -- told the same way, not started again.
    local function pictures()
        local thumbs=o.thumbs
        local ran,good,why=true,true,nil
        if not (thumbs and thumbs.running()) then
            ran,good,why=pcall(function() return thumbs.run(false,nil,true) end)
        end
        if not (ran and good) then
            log('menu: preview pictures not started: '..tostring(ran and why or good))
            return o.tell(function(t) return t.closet.thumbs.failed end)
        end
        local key=thumbs.running() and 'started' or 'cached' -- Not running after a good run: every picture is there.
        o.tell(function(t) return t.closet.thumbs[key] end)
    end

    local function set_tab(i)
        tab,row,due=(i-1)%#model.tabs()+1,1,nil
        if col=='grid' then col='rows' end
        kit.sound('change')
    end
    local function answer(yes)
        if asking=='reset' and not yes then asking=false; return redraw() end
        if asking=='reset' then -- coop closet off: the kept look cleared, nothing of the closet left on EVE.
            local ran,why=pcall(dress.off)
            if not ran then
                log('menu: reset failed: '..tostring(why))
                return self.close('revert')
            end
            if o.colour then o.colour.off() end
            if o.shape then o.shape.off() end
            o.tell(function(t) return t.closet.reset_done end)
            self.close('reset')
            if camera then camera.forget() end -- After its close, which writes the camera file.
            return
        end
        if not yes then return self.close('revert') end
        local good,why=dress.confirm()
        if not good then
            log('menu: confirm failed: '..tostring(why))
            return self.close('revert')
        end
        o.tell(function(t) return t.closet.saved end)
        self.close('keep')
    end

    function self.is_open() return open end
    -- closet_key (main/keys.lua): closed, open(); open, the Back of the rows level (the popup when the look changed, a
    -- revert close when not; on the popup, its Back). The pad chord LB + D-pad Left (main/input.lua's closet) reaches
    -- the open menu as tab_left at LB's press, then left and this toggle in one frame at D-pad Left's (native pad.h;
    -- both pressed in one poll: left, tab_left, toggle). That toggle first puts the focus back as it was before the
    -- tab_left, so the chord leaves the tab and row as they were. A swatch or shape value the chord's left took on a
    -- Colour or shape row (saved at once) is put back, so the palette and the shape stay as they were. Q, then F1 in a
    -- later frame, keeps Q's tab.
    -- shortcut: a chord whose D-pad Left comes with no left (D-pad Up or Down held too) keeps LB's tab move; read the
    -- pad's held LB in Lua if players hit it.
    function self.toggle()
        if not open then return self.open() end
        if undo and undo.at==frame then
            tab,row,col,tile,tab_top=table.unpack(undo,1,5)
            if stepped and stepped.at==frame then stepped.back() end
            stepped=nil
        end
        if col=='grid' then col,due='rows',nil end -- As the grid's Back: a tile preview due is dropped.
        return self.nav('back')
    end
    -- A camera or light word to the camera, then drawn again (the mode's and the preset's hints).
    local function cam_word(word)
        if camera then camera.word(word) end
        return redraw()
    end
    -- A menu word from main/keys.lua: up, down, left, right, select, back, tab_left, tab_right, refresh, a camera or
    -- light word, or click (a left click: the tab, row, hint chip or popup button under the mouse). yes and no answer
    -- the popup too; refresh is its No.
    function self.nav(word)
        if not open then return end
        if camera_word(word) then return cam_word(word) end
        if word=='tab_left' then undo={tab,row,col,tile,tab_top,at=frame} -- For the pad chord (self.toggle).
        elseif word=='left' and undo then undo.at=frame
        else undo=nil end
        if word=='select' and now()<opened+Menu.ARM then return end
        if asking then
            if word=='click' then word=view.popup_hit() end
            if word=='select' or word=='yes' then answer(true)
            elseif word=='no' or word=='refresh' then answer(false)
            elseif word=='back' then asking=false; redraw() end
            return
        end
        if word=='click' then -- The row under the mouse takes the focus and Select runs, as in the lobby.
            clicked=frame -- A tile the click picks is worn at once (self.tick).
            local i=view.tab_hovered()
            if i then set_tab(i); return redraw() end
            local chip=view.hint_hovered() -- A hint chip runs its word.
            if chip and camera_word(chip) then return cam_word(chip)
            elseif chip then word=chip
            else
                i=view.row_hovered()
                if not i then return end
                row,col,due,word=i,'rows',nil,'select'
            end
        end
        local item,tiles,at=focused()
        if word=='tab_left' or word=='tab_right' then set_tab(tab+(word=='tab_left' and -1 or 1))
        elseif word=='select' and col=='rows' and item and item.reset then asking='reset'
        elseif word=='select' and col=='rows' and item and item.thumbs then pictures()
        elseif word=='refresh' or word=='select' and col=='rows' and item and item.whole then wear_whole()
        elseif col=='grid' then
            local C=View.COLUMNS
            if word=='back' or word=='left' and tile==1 then col,due='rows',nil
            elseif word=='left' or word=='right' or word=='up' or word=='down' then
                local to=math.max(1,math.min(tile+(word=='left' and -1 or 1),#tiles))
                if word=='up' then to=tile>C and tile-C or tile
                elseif word=='down' then
                    to=math.ceil(tile/C)<math.ceil(#tiles/C) and math.min(tile+C,#tiles) or tile -- A row below only.
                end
                if to~=tile then tile,due=to,now()+Menu.PREVIEW; kit.sound('move') end
            elseif word=='select' then wear_tile(); col='rows' end
        elseif word=='back' then
            if not changed then return self.close('revert') end
            asking=true
        elseif col=='tabs' then
            if word=='left' or word=='right' then set_tab(tab+(word=='left' and -1 or 1))
            elseif word=='down' then col='rows'; kit.sound('move') end
        elseif item and item.role and (word=='left' or word=='right' or word=='select') then
            if o.colour then
                local role=item.role
                o.colour.step(role,word=='left' and -1 or 1)
                -- For the pad chord (self.toggle).
                if word=='left' then stepped={at=frame,back=function() o.colour.step(role,1) end} end
                kit.sound('change')
            end
        elseif item and item.morph and (word=='left' or word=='right' or word=='select') then
            local name,was=item.morph,o.shape.get(item.morph)
            if word=='select' then o.shape.set(name,was>=100 and 0 or was+Shape.STEP)
            else o.shape.step(name,word=='left' and -1 or 1) end
            if word=='left' then stepped={at=frame,back=function() o.shape.set(name,was) end} end -- The pad chord.
            kit.sound('change')
        elseif word=='up' or word=='down' then
            local n=#model.rows(model.tabs()[tab])
            if word=='up' and row==1 then col='tabs' else row=math.max(1,math.min(row+(word=='up' and -1 or 1),n)) end
            kit.sound('move')
        elseif (word=='right' or word=='select') and tiles then col,tile='grid',at end
        redraw()
    end
    -- Each frame (closet/wiring.lua, through main/frame.lua's guard): closed, the input given back once due and asked
    -- again until the kit has given it; open, the guards each GUARD s, a preview ended by a typed coop closet wear or
    -- off, a tile the mouse picked, the focused tile worn once due.
    function self.tick()
        local t=now()
        frame=frame+1
        if camera then camera.tick(t-(ticked or t),open and region or nil) end
        ticked=t
        if not open then
            -- shortcut: kit.holding() does not say for whom, so a panel that took the input meanwhile keeps owed set
            -- (open then skips the panel guard); read the holder once the kit says it.
            if owed and t>=back_at then kit.input(false,View.GROUP); owed=kit.holding() end
            -- Like the dress's restore, it waits while the game is paused or shows a screen (a loading screen).
            if unreverted and t>=guard_at and not kit.paused(true) then
                guard_at=t+Menu.RETRY
                local ran,good=pcall(function() return not dress.previewing() or dress.revert() end)
                unreverted=not (ran and good)
                if not unreverted then log('menu: the owed revert is done') end
            end
            return
        end
        -- The grid builds its entries on later frames too, and they take the keyboard focus: back to the kit's root.
        kit.refocus()
        view.tick(t) -- The shown tiles' glyphs after a fill.
        if t>=guard_at then
            guard_at=t+Menu.GUARD
            local read,key=pcall(closing,t)
            if not read then
                log('menu: a guard could not be read: '..tostring(key))
                return self.close('revert','guard unread')
            end
            if key then
                o.tell(function(w) return w.closet.closed[key] end)
                return self.close('revert',key)
            end
            if changed and not dress.previewing() then return self.close('keep') end
        end
        -- The camera's mode or light preset changed by the pad, or the camera stopped: its hints drawn again.
        if camera and camera_shown()~=hinted then redraw() end
        -- The shape layer put a new look's shape on (its tick runs before this one): its rows drawn again.
        if o.shape and o.shape.rows()~=listed then redraw() end
        if asking then return end
        local _,tiles=focused()
        local picked=tiles and view.picked()
        if picked then
            -- A left click in this frame or the last wears at once (the same tick's due check below): the click bind
            -- (through ExecuteInGameThread) and Slate's selection can land a frame apart, on either side of this tick.
            -- Any other pick (SB's grid on hover or focus) waits PREVIEW s, so a tile passed over is never worn.
            local click=clicked~=nil and frame-clicked<=2
            col,tile,due,clicked='grid',picked,click and t or t+Menu.PREVIEW,nil
            redraw()
        end
        if due and t>=due then
            wear_tile()
            redraw()
        end
    end
    -- coop off: closed without a revert (the dress gives EVE her own look back), the input given back at once.
    function self.stop()
        self.close('stop')
        if camera then camera.stop() end -- Closed before: a camera still blending out goes at once.
        back_at,owed,unreverted=nil,false,false -- kit.stop gives the input back; coop off ends the look.
    end
    return self
end

return Menu
