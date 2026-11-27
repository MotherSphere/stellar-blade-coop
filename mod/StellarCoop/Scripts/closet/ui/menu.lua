-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's menu (coop closet menu): opens, draws its screen (closet/ui/view.lua) and closes. The tabs, rows and
-- tiles are closet/ui/model.lua's over closet/fits.lua, with what is worn read from the dress (closet/dress.lua's
-- choices). It opens out of combat in the game world, the SBO lobby world included; it refuses on the first guard that
-- fails, with one notice. o.busy (closet/wiring.lua) names SBO's own state that holds EVE's body (the bike ride, the
-- Doro look, the rifle out, an emote, a coop wear suit) as a key of closet.refused, or nil. Open, it holds the kit's
-- input as closet_menu with the mouse cursor, taken again when the game takes it back (the kit's again) or another
-- holder gave it to the game (the host's question, answered). The tab shown is kept
-- across opens; the first open shows the first tab, Full outfit. Each close drops every game part first (the
-- game holds EVE still while one is up) and hides the group. The input comes back BACK s after the close, so the key
-- that closed it (Esc would open the pause menu) never reaches the game. It is asked again each tick while closed until
-- the kit has given it (no player controller at the close); an open before then takes it on. close('revert') wears the
-- confirmed look again (dress.revert), close('keep') leaves the look as it is, close('stop') (coop off) does neither,
-- plays no sound and gives the input back at once. A revert that fails at the close (no EVE during a map change) is
-- asked again each RETRY s while closed and not paused until it works; an open or coop off drops it. A draw that
-- raises closes the menu with a revert and one log line.
-- Focus: the tabs, the rows or the grid (col). E and Q change the tab; the window of View.TABS tabs follows the
-- focused tab. Up and down walk the rows and wrap past either end. Right or select on a row of pieces goes
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
-- origin's badge. The Full tab lists every installed pack's suit by name (closet/fits.lua's Fits.all), then Shift Up's
-- own suits under the closet.original header row, which does nothing. Each tile shows its piece's picture (closet/thumbs.lua's cached PNG), else its outfit's Image, else
-- its slot's glyph (closet/slots.lua); the None tile None's glyph. The Full tab's outfit row shows one tile, its
-- outfit's whole picture (full.png), else its Image, else the Full outfit glyph; Select still wears the row. An outfit
-- row whose full.png is there shows it large (s.preview) in place of the tile. Which pictures are there is read again
-- at each open. Preview picture, the camera row's last chip (P on the keyboard, View held on a pad: main/keys.lua and
-- main/input.lua's word picture), takes the worn whole outfit's full.png as the screen shows EVE (closet/thumbs.lua's
-- snap with camera.shot()) and tells closet.picture.saved, none (no one whole outfit worn) or failed (logged). With
-- thumbs, the Full tab's row before the last, Clear preview pictures, asks with the game's Yes/No popup; Yes deletes
-- every picture (thumbs.clear), tells closet.thumbs.cleared (busy while a run goes, failed otherwise; logged) and
-- reads which pictures are there again; No and Back stay.
-- A preview whose plan switched the body or leaves skin showing under a piece tells closet.switched or closet.clips,
-- once until that changes. The menu shows the same lines under its rows as long as the look on EVE has them (the
-- chat feed draws under the menu's shade). The Full tab's last row, Reset Stellar Closet (hint Select), asks with the
-- game's Yes/No popup: Yes runs coop closet off (dress.off), turns every colour off (colour.off: its file cleared),
-- sets every shape value to 0 (shape.off: its file cleared), tells closet.reset_done, closes without the Keep popup or
-- a revert and has the camera forget its mode and pose (its file cleared); No and Back stay.
-- The Colour tab (after Full outfit) has a row for each role of closet/colour.lua; its value is the role's swatch.
-- Right and Select (a click on the row too) take the next swatch, left the one before (colour.step): the palette is
-- saved at once, apart from the look, so it never asks Keep this look? Its detail says what the role colours and how
-- to pick. The fitting tabs (Head..Body, Intimate) are labelled through closet.beta ("Head (Beta)").
-- The Body tab lists, below its Body row, a row for each name of closet/shape.lua's rows (the look as last put on);
-- its value is the name's value in percent. Left and right step it by Shape.STEP from 0 to 100, Select (a click on the
-- row too) takes the next step, 0 after 100: the value is saved at once, apart from the look. Rows that change with the
-- look are drawn again at the next tick.
-- Right (the hint Options on UI_DPad_Right) on a pack outfit's row with toggles opens its options page (model.options:
-- the outfit's name as a header row, Variant, each section and its pieces, the Shape section, Reset this outfit),
-- focused on its first setting. An outfit EVE does not wear is worn as a preview first (as Select wears it: Keep this
-- look? at the menu's Back), since the options layer writes the worn outfits only. A control row says its kind
-- (closet.options.kinds), then its name when that differs from its piece's (closet.options.named). A piece, a control
-- and a channel start with Menu.CHILD, deeper rows after Menu.INDENT, so they read as children of the section row
-- above them. Left, right and Select (a click too) change a row (change: closet/options.lua saves
-- it at once, its tick shows it on the worn look), so it never asks Keep this look? Select on a piece with controls
-- opens them as rows below it (a colour with a kit swatch right of the row, a Custom colour's channels, a finish, a
-- number), brought into the window as far as the focused piece stays in it; left and right still turn the piece. F (refresh, UI_FaceButton_Top) gives the focused row its pack value
-- back; Select on Reset this outfit gives every one. Back closes an open piece's controls (the focus on the piece),
-- then the page: the focus goes back to the outfit's row. Up stops on the page's header row. A tab change or an open
-- drops the page; the pad chord's undo keeps it. The page's hints: Back, Change on UI_DPad_Left and UI_DPad_Right,
-- Reset on UI_FaceButton_Top (Select instead on a piece with controls), Move. The detail's open line and help follow
-- the device: a device switch draws them again at the next tick.
-- With presets (o.presets, closet/presets.lua) the Full tab starts with Save look as preset (Select saves the worn
-- whole outfit as Preset n, told), each preset (Select wears it as a preview; a close that does not keep the look gives
-- its outfit the variant and values from before; F, UI_FaceButton_Top, asks Delete this
-- preset? with the game's Yes/No popup: Yes deletes it, No and Back stay; a gone outfit's preset is greyed and does
-- not wear) and the filter row (right and Select turn All, Favourites, Original, Custom, left turns back, kept for this
-- Lua load). On an outfit's row F then marks it as a favourite or not (its hint Favourite or Unfavourite) instead of
-- wearing it.
-- Each GUARD s while open: a map change, photo mode, a cutscene or the input given back (coop ui reset) closes it with
-- a revert and a closet.closed notice; combat is read each COMBAT s. A preview ended by a typed coop closet wear or off
-- closes it without a revert.
-- The camera (closet/ui/camera.lua, when given): opened after a good open, closed on every close path (stopped by coop
-- off, also while the menu is closed), ticked each frame with the region of the focused slot (of the tab on the tab
-- row or a row with no slot; nil while closed). The camera words (cam_left, cam_right, cam_up, cam_down, cam_in,
-- cam_out, cam_mode, cam_reset) and the light words (light_next, light_up, light_down) go to it; while it runs, the
-- camera hint row shows the light preset on V (the pad's L3), its mode on C (the pad's X) and Reset on Backspace (the
-- pad's R3), each a chip a click runs. The detail ends with the camera's moves and light level keys in its mode.
-- Both follow SB's input device (o.uidev): pad glyphs and pad words after a pad input, the keyboard's keys after a
-- keyboard one; a switch redraws them at the next tick. The preset's intensity shows after its name on every preset
-- but Game. A
-- Back while the camera says right mouse is held (hold_back) waits: the camera runs it at the release when the mouse
-- did not drag (take_back, read each tick).
-- o: {kit=ui/kit/kit.lua's, dress=closet/dress.lua's, words=function() the ui/text table to show, tell=function(build)
-- (main/base.lua's M.tell), log=, world=function() M.hud_shown, photo=function() M.photo_state(), status=function()
-- the link's status text or nil, adult=the Intimate tab shown (closet/wiring.lua never passes it),
-- now=function() the time in s (os.clock when nil), camera=closet/ui/camera.lua's or nil, folder=the mod folder (main.lua's M.folder: the pictures' root) or nil,
-- thumbs=closet/thumbs.lua's or nil, colour=closet/colour.lua's or nil (the Colour rows then show Off and pick
-- nothing), shape=closet/shape.lua's or nil (no shape row then), options=closet/options.lua's or nil (no options
-- page then), presets=closet/presets.lua's or nil (no Presets rows, filter or favourites then),
-- uidev=function() SB's input device byte or nil
-- (core/link.lua's uidev; nil: the keyboard), nav_held=function() the up and down keys held (main/boot.lua's
-- nav_held: 1 up, 2 down, 0 none) or nil}.
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
-- s: a held up or down key repeats its move after REPEAT_DELAY, then every REPEAT_EVERY (ui/pad.h's kPadRepeatDelayMs
-- and kPadRepeatEveryMs, the D-pad's repeat).
Menu.REPEAT_DELAY,Menu.REPEAT_EVERY=0.4,0.12
-- An options page row under its section starts with CHILD, after INDENT for each depth past the first (model.options's
-- depth): a piece reads as a child of its section, a control of its piece, a channel of its colour.
Menu.CHILD,Menu.INDENT='- ','    '

function Menu.new(o)
    local kit,dress=o.kit,o.dress
    local log=o.log or function() end
    local now=o.now or os.clock
    -- The Full tab's filter: its place in FILTERS (kept for this Lua load).
    local FILTERS={'all','favourites','original','custom'}
    local filter=1
    local deleting -- The preset the Delete this preset? popup asks about.
    local held_dir,repeat_at -- The up or down key held at the last tick, when it repeats next.
    -- The backs of the presets worn since the open (closet/presets.lua's wear): a close that does not keep the look
    -- runs them last first, so each outfit gets its variant and values from before the open.
    local unwear={}
    local model=Model.new({slots=Slots,fits=Fits,installed=dress.installed,adult=o.adult==true,
        shapes=o.shape and o.shape.rows,presets=o.presets,filter=function() return FILTERS[filter] end,
        pictures=o.thumbs~=nil})
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
    -- page: the options page shown ({fit=<UniqueFitID>, open=<a piece's controls shown, none yet>}) or nil; from_row:
    -- the outfit's row it opened from.
    local page,from_row=nil,1
    local drawn_pad -- The device of the last draw: the detail's key lines follow it (tick).
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
    -- Whether SB's last input came from a pad: its device byte (core/link.lua's uidev, as ui/kit/kit.lua reads it) is 1
    -- or 2 for a keyboard, 3 to 6 for a pad, 0 or nil before its first report (read as the keyboard).
    local function pad()
        local d=o.uidev and o.uidev()
        return d~=nil and d>=3 and d<=6
    end
    -- What the camera hints show now: false with no camera running. The device is in it: a switch redraws (tick).
    local function camera_shown()
        if not (camera and camera.running()) then return false end
        local preset,factor=camera.light()
        return camera.mode()..'|'..preset..'|'..factor..'|'..(pad() and 'pad' or 'key')
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
        if kit.holding() and not kit.holding(View.GROUP) then return 'panel' end -- Still ours since a close: none.
        if kit.paused(true) then return 'screen' end
        if o.photo()~='0' then return 'photo' end
        local eve=U.her(UE.GetPlayer())
        if cutscene(eve) then return 'cutscene' end
        if combat(eve) then return 'combat' end
        if dress.game_look()~=nil then return 'tachy' end
        return o.busy and o.busy() or nil -- SBO's own state that holds EVE's body (closet/wiring.lua's busy).
    end
    -- While open: the key of the first guard that fails (closet.closed.<key>), or nil. Combat each COMBAT s.
    local function closing(t)
        if not (kit.ready() and o.world() and view.alive()) then return 'map' end
        if o.photo()~='0' then return 'photo' end
        local eve=U.her(UE.GetPlayer())
        if cutscene(eve) then return 'cutscene' end
        -- Another holder took the input over the menu and gave it to the game (the host's question, answered): taken
        -- again, as at the open. coop ui reset closes the menu itself.
        if not kit.holding() then kit.input(true,View.GROUP,true,true) end
        if not kit.holding() then return 'input' end
        if t>=combat_at then
            combat_at=t+Menu.COMBAT
            if combat(eve) then return 'combat' end
        end
        return nil
    end

    -- The rows shown: the options page's (the open piece's controls, a Custom colour's channels), else the tab's.
    local function list()
        if page then
            local v=o.options.variant(page.fit)
            return model.options(page.fit,page.open,function(n) return o.options.choice(page.fit,v,n)=='custom' end)
        end
        return model.rows(model.tabs()[tab])
    end
    -- The options key of a control row (a channel's is its colour's), or nil.
    local function key_of(item)
        if item.colour or item.channel then return 'colour:'..(item.colour or item.channel) end
        for _,kind in ipairs({'finish','number','shape'}) do
            if item[kind] then return kind..':'..item[kind] end
        end
    end
    -- Whether F (refresh) gives an options row its pack value back: the rows that show the Reset hint.
    local function resettable(item)
        return item and (item.variant or item.toggles and #item.toggles>0 or item.toggle and not item.controls
            or key_of(item)~=nil) or false
    end
    -- A colour channel in 0-255; a number with the decimals of its step (3 at most).
    local function byte(x) return tostring(math.floor(x*255+0.5)) end
    local function digits(step) return math.min(3,#((('%g'):format(step or 1)):match('%.(%d+)$') or '')) end
    local function decimals(x,step) return ('%.'..digits(step)..'f'):format(x) end
    -- A slider row's place: x in lo..hi as 0..1 (a value outside the range shows at its end).
    local function place(x,lo,hi) return hi>lo and math.max(0,math.min(1,(x-lo)/(hi-lo))) or 0 end
    -- Whether an outfit's row opens an options page: an installed pack outfit with toggles, with the options layer.
    local function has_options(item)
        local fit=item and item.whole and not item.locked and o.options and Fits.get(item.whole)
        return fit and #model.options(item.whole)>1 or false
    end
    -- A control row's title: its kind (Finish, Colour, Number), then its name when that differs from its piece's.
    local function kind_title(w,item,kind)
        local name=item.name
        if name and name~='' and name~=item.of then return w.options.named:format(w.options.kinds[kind],name) end
        return w.options.kinds[kind]
    end
    -- The help line of an options row on this device.
    local function help(w) return w.options.help[pad() and 'pad' or 'key'] end
    -- The focused row's item; on a row of pieces also its tiles and the worn tile's index (None when none is worn).
    local function focused(choices)
        local item=list()[row]
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
        local s={tabs={},tab=tab,tab_top=tab_top,rows={},hints={{t.hint.back,'Negative',word='back'}},camera_hints={},
            pad=pad()}
        drawn_pad=s.pad
        for i,id in ipairs(ids) do
            s.tabs[i]=w.tabs[id] or id
            if ids.beta[id] then s.tabs[i]=w.beta:format(s.tabs[i]) end
        end
        listed=o.shape and o.shape.rows()
        local shown_rows=list()
        row=math.max(1,math.min(row,#shown_rows))
        s.row=#shown_rows>0 and row or nil
        local choices=dress.choices() or {}
        local plan=dress.plan() -- The look on EVE now: its body and notice.
        local v=page and o.options.variant(page.fit)
        for i,item in ipairs(shown_rows) do
            if item.whole then -- locked read only when the view draws the row (the model's row loads its mesh).
                s.rows[i]=setmetatable({title=item.outfit,value=item.fav and w.presets.fav:format(item.pack) or item.pack},
                    {__index=function(_,k) if k=='locked' then return item.locked end end})
            elseif item.save_preset then
                s.rows[i]={title=w.presets.save,value=''}
            elseif item.preset then -- Its name, else Preset n; its outfit as the value.
                local fit=Fits.get(item.fit)
                s.rows[i]={title=item.name or w.presets.name:format(item.preset),value=fit and fit.Outfit or item.fit,
                    locked=item.locked}
            elseif item.filter then
                local show=FILTERS[filter]
                s.rows[i]={title=w.presets.filter,value=show=='original' and w.origin.original or w.presets[show]}
            elseif item.reset or item.clear_thumbs then
                s.rows[i]={title=item.reset and w.row.reset or w.row.clear_thumbs,
                    value=''}
            elseif item.header then -- The Original header above Shift Up's own suits, or the options page's outfit.
                s.rows[i]={title=page and item.header or w.original,value='',header=true}
            elseif item.variant then -- Its name, else its number of the count.
                local all=Fits.get(page.fit).Variants
                s.rows[i]={title=w.options.variant,value=all[v].Name or ('%d/%d'):format(v,#all)}
            elseif item.toggle then -- A piece (its section named too).
                local on=o.options.get(page.fit,v,'toggle:'..item.toggle)
                s.rows[i]={title=item.name,value=on and w.options.on or w.options.off}
            elseif item.section then -- How many of its pieces show (none for a section of controls only).
                local on=0
                for _,index in ipairs(item.toggles) do
                    if o.options.get(page.fit,v,'toggle:'..index) then on=on+1 end
                end
                s.rows[i]={title=item.section=='Shape' and w.options.shape or w.slots[item.section] or w.options.other,
                    value=#item.toggles>0 and ('%d/%d'):format(on,#item.toggles) or ''}
            elseif item.reset_fit then
                s.rows[i]={title=w.options.reset,value=''}
            elseif item.colour or item.channel then -- Pack colour, a swatch's name or R G B; a channel in 0-255.
                local n=item.colour or item.channel
                local c=o.options.get(page.fit,v,'colour:'..n)
                local choice=o.options.choice(page.fit,v,n)
                local value=item.channel and byte(c[item.c:upper()]) or choice=='pack' and w.options.pack or
                    choice=='custom' and byte(c.R)..' '..byte(c.G)..' '..byte(c.B) or w.colour.swatches[choice]
                s.rows[i]={title=item.channel and w.options.channels[item.c] or kind_title(w,item,'colour'),value=value,
                    swatch=item.colour and {R=c.R,G=c.G,B=c.B} or nil,
                    -- A channel's slider in 0-255, as its value shows.
                    slider=item.channel and {pct=tonumber(value)/255,lo=0,hi=255,digits=0} or nil}
            elseif item.finish then -- Its option's name, else its number.
                local at=o.options.get(page.fit,v,'finish:'..item.finish)
                local c=Fits.get(page.fit).Controls.TextureOptions[item.finish]
                local name=type(c.OptionNames)=='table' and c.OptionNames[at+1]
                s.rows[i]={title=kind_title(w,item,'finish'),value=type(name)=='string' and name or tostring(at+1)}
            elseif item.number or item.shape then
                local key=key_of(item)
                local lo,hi,step=o.options.range(page.fit,key)
                local x=o.options.get(page.fit,v,key)
                s.rows[i]={title=item.number and kind_title(w,item,'number') or item.name,value=decimals(x,step),
                    slider=lo and {pct=place(x,lo,hi),lo=lo,hi=hi,digits=digits(step)} or nil}
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
            -- A child row of the options page: its lead mark (the detail's title keeps the plain one).
            if item.depth then
                local one=s.rows[i]
                one.plain,one.title=one.title,Menu.INDENT:rep(item.depth-1)..Menu.CHILD..one.title
            end
            -- The open piece's controls: the view brings the last of them into its window too (s.show).
            if page and page.open and item.toggle==page.open then s.show=i
            elseif s.show==i-1 and item.depth and item.depth>1 then s.show=i end
        end
        local item,shown=shown_rows[row],s.rows[row]
        region=Camera.region(col~='tabs' and item and item.slot or ids[tab])
        hinted=camera_shown()
        if hinted then
            local preset,factor=camera.light()
            local light=w.light[preset]..(preset~='game' and (' x%g'):format(factor) or '')
            -- UI_FaceButton_Left: SB's UI action for the left face button (the pad's X), the 26123051 exe's
            -- FUN_14254baf0 case 0 (string 0x145c34890); UI_RightThumbstick and UI_LeftThumbstick: action names of the
            -- same exe (FNames at FUN_1407f2100 and FUN_1407f2050, strings 0x145c4ec00 and 0x145c4ebd8). The view
            -- shows them only on a pad: on the keyboard SB would draw its own key for them, so it shows key, the
            -- closet's bind (main/keys.lua), as kit text. No label names a key.
            s.camera_hints={{w.camera.title:format(w.camera[camera.mode()]),'UI_FaceButton_Left',word='cam_mode',
                key=w.keys.mode},{w.camera.reset_hint,'UI_RightThumbstick',word='cam_reset',key=w.keys.reset},
                {w.light.title:format(light),'UI_LeftThumbstick',word='light_next',key=w.keys.light},
                -- UI_SpecialLeft: SB's UI action for the pad's View button, a UTF-16 string of the same exe at
                -- 0x145c4ec28 (Ghidra, 27 Nov 2026), in the list with UI_LeftThumbstick; held, it takes the picture.
                {s.pad and w.picture.pad or w.picture.hint,'UI_SpecialLeft',word='picture',key=w.keys.picture}}
        end
        s.detail={title=shown and (shown.plain or shown.title) or '',desc=''}
        if item and item.whole then
            s.detail.desc=(item.locked and w.row.locked:format(item.pack) or w.row.whole)..'\n'..origin(w,item.whole)
            s.detail.badge=Fits.origin(item.whole)
            s.preview=picture(item.whole,Thumbs.FULL) -- Its picture large, in place of the tile.
            s.tiles=not s.preview and {{name=item.outfit,locked=item.locked,picture=nil,
                image=Fits.get(item.whole).Image,icon=Slots.glyph(Slots.FULL_OUTFIT)}} or nil
            if not item.locked then s.hints[2]={w.hints.whole,'Positive',word='select'} end
            -- UI_DPad_Right: SB's UI action for the D-pad's right (its keyboard key on a keyboard), a UTF-16 string of
            -- the 26123051 exe at 0x145c4e940 (Ghidra), as online/lobby/ui/lobby.lua's Change hint uses it.
            if has_options(item) then
                s.detail.desc=s.detail.desc..'\n'..w.options.open[s.pad and 'pad' or 'key']
                s.hints[3]={w.hints.options,'UI_DPad_Right',word='right'}
            end
            -- UI_FaceButton_Top (F, the pad's Y): as the refresh hint of a row of pieces below (its UTF-16 string at
            -- 0x145c4e728 of the 26123051 exe, Ghidra, read again 26 Nov 2026). SB draws the key or the pad's button
            -- for it, so the hint follows the device.
            if o.presets then
                s.hints[#s.hints+1]={item.fav and w.hints.unfav or w.hints.fav,'UI_FaceButton_Top',word='refresh'}
            end
        elseif item and item.save_preset then
            s.detail.desc=w.presets.save_desc
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.preset then -- Select wears it (not a gone outfit's); F (UI_FaceButton_Top) deletes it.
            local fit=Fits.get(item.fit)
            s.detail.desc=w.detail.outfit:format(fit and fit.Outfit or item.fit)..
                (item.locked and '\n'..w.row.locked:format(fit and fit.Pack or item.fit) or '')
            if not item.locked then s.hints[2]={w.hints.wear,'Positive',word='select'} end
            s.hints[#s.hints+1]={w.hints.delete,'UI_FaceButton_Top',word='refresh'}
        elseif item and item.filter then
            s.detail.desc=w.presets.filter_desc
            s.hints[2]={w.hints.change,'UI_DPad_Left','UI_DPad_Right',word='right'}
        elseif item and page and item.reset_fit then -- Reset this outfit.
            s.detail.desc=w.options.reset_desc
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and page and item.toggle and item.controls then -- Select opens or closes its controls.
            s.detail.desc=(item.desc and item.desc..'\n' or '')..w.options.piece_help[s.pad and 'pad' or 'key']
            s.hints[2]={t.hint.select,'Positive',word='select'}
            s.hints[3]={w.hints.change,'UI_DPad_Left','UI_DPad_Right',word='right'}
        elseif item and page and resettable(item) then
            s.detail.desc=(item.desc and item.desc..'\n' or '')..help(w)
            s.hints[2]={w.hints.change,'UI_DPad_Left','UI_DPad_Right',word='right'}
            -- UI_FaceButton_Top (F, the pad's Y): as the refresh hint of a row of pieces below.
            s.hints[3]={w.hints.reset,'UI_FaceButton_Top',word='refresh'}
        elseif item and page then -- A section of controls only: Back and Move.
        elseif item and (item.reset or item.clear_thumbs) then
            s.detail.desc=item.reset and w.popup.reset_desc or w.row.clear_thumbs_desc
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.role then
            s.detail.desc=w.colour.about[item.role]..'\n'..w.colour.help
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.morph then
            s.detail.desc=w.shape.about..'\n'..w.shape.help
            s.hints[2]={t.hint.select,'Positive',word='select'}
        elseif item and item.header then -- Nothing to do on it: Back and Move only.
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
            -- online/session/ui/sessions.lua; the 26123051 exe names it in FUN_14254baf0 case 1 (string 0x145c4e728;
            -- UI_LeftShoulder is case 4).
            local one=tiles[col=='grid' and tile or at]
            if one and one.fit and not one.locked then s.hints[3]={w.hints.whole,'UI_FaceButton_Top',word='refresh'} end
        end
        -- While the camera runs, the detail ends with its moves and light level keys in this mode, on this device.
        if hinted then
            local line=w.camera.title:format(w.camera.moves[camera.mode()][s.pad and 'pad' or 'key'])
            s.detail.desc=s.detail.desc~='' and s.detail.desc..'\n'..line or line
        end
        -- Move last, on the D-pad's up and down icons, as the lobby shows it (the keyboard's keys or the pad's buttons).
        s.hints[#s.hints+1]={t.hint.move,'UI_DPad_Up','UI_DPad_Down'}
        -- The plan's body switch and clip warning, shown as long as the look on EVE has them.
        local notes={}
        if plan and plan.switched then notes[1]=w.switched:format(Fits.get(plan.switched).Outfit) end
        if plan and plan.clips then notes[#notes+1]=w.clips:format(names(plan.clips,w.regions)) end
        s.notice=table.concat(notes,'\n')
        if asking=='reset' then s.popup={title=w.popup.reset_title,desc=w.popup.reset_desc}
        elseif asking=='clear' then s.popup={title=w.popup.clear_title,desc=w.popup.clear_desc}
        elseif asking=='delete' then
            local name=w.presets.name:format(deleting)
            for _,p in ipairs(o.presets.list()) do if p.n==deleting and p.name then name=p.name end end
            s.popup={title=w.presets.delete_title,desc=w.presets.delete_desc:format(name)}
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
        if how=='revert' or how=='stop' then -- A preset's preview turned down: its outfit's options as before.
            for i=#unwear,1,-1 do
                local ran,why=pcall(unwear[i])
                if not ran then log('menu: a preset\'s options not given back: '..tostring(why)) end
            end
        end
        unwear={}
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
        if page then row,page=from_row,nil end -- Each open shows the tab: an options page opens from its row.
        col,tile,asking,changed,due,said,undo='rows',1,false,false,nil,nil,nil
        bare=not dress.previewing() and #(dress.choices() or {})==0
        back_at,owed,unreverted=nil,false,false -- An owed revert: Back or No on this open reverts.
        opened=now()
        guard_at,combat_at=opened+Menu.GUARD,opened+Menu.COMBAT
        there={} -- The pictures read again: coop closet thumbs may have made some since.
        view.reread()
        kit.input(true,View.GROUP,true,true) -- Taken again when the game takes it back (ui/kit/kit.lua's tick).
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
        return ran and good==true
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

    -- Preview picture: the one whole outfit EVE wears now, as the closet camera shows her, saved as its full.png; told.
    local function snapshot()
        local choices=dress.choices() or {}
        local fit=#choices==1 and not choices[1].slots and choices[1].fit or nil
        if not fit then return o.tell(function(t) return t.closet.picture.none end) end
        local ran,good,why=pcall(function()
            if not o.thumbs then return false,'no coop closet thumbs' end
            return o.thumbs.snap(fit,camera and camera.shot())
        end)
        if not (ran and good) then
            log('menu: preview picture not taken: '..tostring(ran and why or good))
            return o.tell(function(t) return t.closet.picture.failed end)
        end
        there={} -- Read again: the focused outfit's row shows the new picture.
        view.reread()
        kit.sound('change')
        local name=Fits.get(fit) and Fits.get(fit).Outfit or fit
        o.tell(function(t) return t.closet.picture.saved:format(name) end)
        redraw()
    end

    local function set_tab(i)
        tab,row,due,page=(i-1)%#model.tabs()+1,1,nil,nil
        if col=='grid' then col='rows' end
        kit.sound('change')
    end
    local function answer(yes)
        if asking=='delete' then -- Delete this preset?: Yes deletes it, the menu stays.
            if yes then o.presets.delete(deleting); kit.sound('change') end
            asking=false
            return redraw()
        end
        if asking=='clear' then -- Clear preview pictures?: Yes deletes them, the menu stays; the tiles read again.
            asking=false
            if not yes then return redraw() end
            local ran,good,why=pcall(o.thumbs.clear)
            if not (ran and good) then
                log('menu: preview pictures not cleared: '..tostring(ran and why or good))
                local busy=ran and o.thumbs.running and o.thumbs.running()
                o.tell(function(t) return busy and t.closet.thumbs.busy or t.closet.thumbs.failed end)
                return redraw()
            end
            there={}
            kit.sound('change')
            o.tell(function(t) return t.closet.thumbs.cleared end)
            return redraw()
        end
        if asking=='reset' and not yes then asking=false; return redraw() end
        if asking=='reset' then -- coop closet off: the kept look cleared, nothing of the closet left on EVE.
            local ran,why=pcall(dress.off)
            if not ran then
                log('menu: reset failed: '..tostring(why))
                return self.close('revert')
            end
            if o.colour then o.colour.off() end
            if o.shape then o.shape.off() end
            if o.options then o.options.off() end
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
            tab,row,col,tile,tab_top,page,from_row=table.unpack(undo,1,7)
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
    -- An options page row changed (closet/options.lua: saved at once, shown on the worn look by its tick): Variant
    -- A slider row's value at place pct (0..1) of its bar: a channel's in 0..1 (the colour becomes Custom), a number's or
    -- a shape key's in its range on its step.
    local function slide_to(item,pct)
        local fit,options=page.fit,o.options
        local v,key=options.variant(fit),key_of(item)
        local lo,hi,step=options.range(fit,key,item.c)
        if not lo then return end
        local value=options.get(fit,v,key)
        if item.channel then
            value.custom=true
            value[item.c:upper()]=math.max(lo,math.min(hi,pct))
        else
            value=lo+(hi-lo)*pct
            if step and step>0 then value=lo+math.floor((value-lo)/step+0.5)*step end
            value=math.max(lo,math.min(hi,value))
        end
        options.set(fit,v,key,value)
    end
    -- steps left or right (select: right) past variants whose mesh does not load (dress.loads), a section turns all its
    -- pieces off when every one shows, else on, a piece turns. A left keeps what puts it back for the pad chord.
    -- A colour takes the choice after or before (closet/options.lua's cycle: Pack colour, the swatches, Custom), a
    -- channel, a number or a shape key steps (options.step), a finish takes the next option whose texture loads.
    local function change(item,word)
        local fit,options=page.fit,o.options
        local v=options.variant(fit)
        local key,dir=key_of(item),word=='left' and -1 or 1
        local back
        if key then
            local was=options.get(fit,v,key)
            if item.colour then options.cycle(fit,v,item.colour,dir)
            elseif item.channel then options.step(fit,v,key,dir,item.c)
            elseif item.finish then
                local list,at=options.finishes(fit,item.finish),nil
                for k,i in ipairs(list) do if i==was then at=k end end
                local to=at and list[(at-1+dir)%#list+1] or list[dir>0 and 1 or #list]
                if to then options.set(fit,v,key,to) end
            else options.step(fit,v,key,dir) end
            back=function() options.set(fit,v,key,was) end
        elseif item.variant then
            local all=Fits.get(fit).Variants
            local dir=word=='left' and -1 or 1
            for k=1,#all-1 do
                local to=(v-1+dir*k)%#all+1
                if dress.loads(all[to].Mesh) then
                    options.set_variant(fit,to)
                    back=function() options.set_variant(fit,v) end
                    break
                end
            end
        else
            local was,all={},true
            for _,index in ipairs(item.toggles or {item.toggle}) do
                was[index]=options.get(fit,v,'toggle:'..index)
                all=all and was[index]
            end
            for index in pairs(was) do options.set(fit,v,'toggle:'..index,not all) end
            back=function() for index,on in pairs(was) do options.set(fit,v,'toggle:'..index,on) end end
        end
        if word=='left' and back then stepped={at=frame,back=back} end
        kit.sound('change')
    end
    -- F (refresh) on an options row: its pack value back (Variant: the first, when its mesh loads; a section: each
    -- of its pieces').
    local function reset_row(item)
        local fit,options=page.fit,o.options
        local v,key=options.variant(fit),key_of(item)
        if item.variant then
            if dress.loads(Fits.get(fit).Variants[1].Mesh) then options.set_variant(fit,1) end
        elseif key then options.set(fit,v,key,options.default(fit,key))
        else
            for _,index in ipairs(item.toggles or {item.toggle}) do
                options.set(fit,v,'toggle:'..index,options.default(fit,'toggle:'..index))
            end
        end
        kit.sound('change')
    end
    -- A menu word from main/keys.lua: up, down, left, right, select, back, tab_left, tab_right, refresh, a camera or
    -- light word, or click (a left click: the tab, row, hint chip or popup button under the mouse). yes and no answer
    -- the popup too; refresh is its No.
    function self.nav(word)
        if not open then return end
        if camera_word(word) then return cam_word(word) end
        if word=='picture' then return snapshot() end
        -- A right press may start a camera drag: its Back waits for the release (self.tick, camera.take_back).
        if word=='back' and camera and camera.hold_back() then return end
        if word=='tab_left' then undo={tab,row,col,tile,tab_top,page,from_row,at=frame} -- The pad chord (self.toggle).
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
            if chip=='picture' then return snapshot()
            elseif chip and camera_word(chip) then return cam_word(chip)
            elseif chip then word=chip
            else
                i=view.row_hovered()
                if not i then return end
                row,col,due,word=i,'rows',nil,'select'
                -- On a slider's bar (a channel, a number or a shape key): its value at that place.
                local x=kit.pointer and kit.pointer()
                local item=page and list()[i]
                local slides=item and (item.channel or item.number or item.shape)
                if x and slides and x>=View.SLIDER_X0-20 and x<=View.SLIDER_X1+20 then
                    slide_to(item,math.max(0,math.min(1,(x-View.SLIDER_X0)/(View.SLIDER_X1-View.SLIDER_X0))))
                    kit.sound('change')
                    return redraw()
                end
            end
        end
        local item,tiles,at=focused()
        if word=='tab_left' or word=='tab_right' then set_tab(tab+(word=='tab_left' and -1 or 1))
        elseif word=='select' and col=='rows' and item and item.reset then asking='reset'
        elseif word=='select' and col=='rows' and item and item.clear_thumbs then asking='clear'
        elseif word=='refresh' and page then
            if resettable(item) then reset_row(item) end
        elseif word=='refresh' and item and item.whole and o.presets then -- F: a favourite or not.
            o.presets.fav(item.whole)
            kit.sound('change')
        elseif word=='refresh' and item and item.preset then deleting,asking=item.preset,'delete'
        elseif word=='select' and item and item.save_preset then -- Saved as Preset n; renamed by command.
            local n,why=o.presets.save()
            if n then o.tell(function(t) return t.closet.presets.saved:format(t.closet.presets.name:format(n)) end)
            else
                log('menu: no preset saved: '..tostring(why))
                o.tell(function(t) return t.closet.presets.none end)
            end
            kit.sound(n and 'change' or 'move')
        elseif word=='select' and item and item.preset then -- Worn as a preview: Keep this look? at the Back.
            if not item.locked then
                -- A preview that failed (told by wear) hands the failure to presets.wear, which gives the options back.
                local failed=false
                local good,why=o.presets.wear(item.preset,function(choices,back)
                    if not wear(choices) then failed=true; return false,'menu: the preview failed' end
                    unwear[#unwear+1]=back
                    return true
                end)
                if not good and not failed then
                    log('menu: preset not worn: '..tostring(why))
                    o.tell(function(t) return t.closet.failed end)
                end
            end
        elseif item and item.filter and (word=='left' or word=='right' or word=='select') then
            filter=(filter-1+(word=='left' and -1 or 1))%#FILTERS+1
            kit.sound('change')
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
        elseif word=='back' and page then -- An open piece's controls close first (the focus on it), then the page.
            if page.open then
                local open=page.open
                page.open=nil
                for i,one in ipairs(list()) do if one.toggle==open then row=i end end
            else row,page=from_row,nil end
            kit.sound('move')
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
        elseif page and item and item.reset_fit and word=='select' then -- Reset this outfit.
            o.options.reset(page.fit)
            kit.sound('change')
        elseif page and item and item.toggle and item.controls and word=='select' then -- Its controls open or close.
            page.open=page.open~=item.toggle and item.toggle or nil
            kit.sound('move')
        elseif page and (resettable(item) or item and item.toggle) and (word=='left' or word=='right' or word=='select')
            then
            change(item,word)
        elseif word=='up' or word=='down' then
            local n=#list()
            -- Past either end the focus wraps to the other: Up on the first row takes the last (Make preview pictures
            -- and Reset are one press away on a long list). Q and E change the tab.
            row=n>0 and (row-1+(word=='up' and -1 or 1))%n+1 or 1
            kit.sound('move')
        elseif word=='right' and has_options(item) then -- The outfit's options page, on its first setting.
            -- An outfit EVE does not wear is worn as a preview (as Select does: Keep this look? at the menu's Back),
            -- since the options layer writes the worn outfits only.
            local worn=false
            for _,c in ipairs(dress.choices() or {}) do worn=worn or c.fit==item.whole end
            if not worn then wear(model.whole(item.whole)) end
            page,from_row,row={fit=item.whole},row,2
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
        if camera and camera.take_back() then self.nav('back') end -- A right click with no drag.
        if not open then
            -- Owed while the kit still holds it for us (no player controller at the give-back); a panel that took it
            -- meanwhile has it, nothing is owed.
            if owed and t>=back_at then kit.input(false,View.GROUP); owed=kit.holding(View.GROUP) end
            -- Like the dress's restore, it waits while the game is paused or shows a screen (a loading screen).
            if unreverted and t>=guard_at and not kit.paused(true) then
                guard_at=t+Menu.RETRY
                local ran,good=pcall(function() return not dress.previewing() or dress.revert() end)
                unreverted=not (ran and good)
                if not unreverted then log('menu: the owed revert is done') end
            end
            return
        end
        -- A held up or down key repeats its move (UE4SS's binds see the press only); the press moved once already. Not
        -- while another holder has the input over the menu (the host's question takes those keys).
        local held=kit.holding(View.GROUP) and o.nav_held and o.nav_held()
        local dir=held==1 and 'up' or held==2 and 'down' or nil
        if dir~=held_dir then held_dir,repeat_at=dir,t+Menu.REPEAT_DELAY
        elseif dir and t>=repeat_at then
            repeat_at=repeat_at+Menu.REPEAT_EVERY
            if repeat_at<=t then repeat_at=t+Menu.REPEAT_EVERY end -- A late tick: one move, not a burst.
            self.nav(dir)
        end
        -- The grid builds its entries on later frames too. They take the keyboard focus: back to the kit's root.
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
        if camera and camera_shown()~=hinted then redraw()
        elseif pad()~=drawn_pad then redraw() end -- A device switch: the detail's key or button words.
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
