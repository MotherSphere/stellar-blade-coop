-- The co-op menu (UI-DESIGN 4.1, D-UI2, D-UI4): ui_model.lua's two pages drawn with the Uplink kit (ui.lua), opened and
-- closed by menu_key, in a world only and never while the game is paused or shows the mouse cursor (one of its
-- screens). While it is open the game ignores its own keys (the kit's input), and main.lua's binds hand it the
-- navigation keys: up, down, left and right to move and change, select and back (each a no-op while it is closed). Its
-- rows run the console commands (Host and Invite close it first: the Steam overlay takes the focus); Leave and Remove
-- <name> (a player let in who is not our Steam friend) ask for a second Select; Copy my code shows our join code and
-- asks the native part to copy it; Chat (in a session) and Join with a code close it and open the chat's box or the
-- code box (join.lua). A setting changed on the Options page rewrites its own line of coop-settings.txt (link.lua
-- keeps the file as it was as coop-settings.old.txt) and applies at once, but the name tag, at the next load; a key
-- row takes the next F-key pressed (capture), checked against the other keys. Each 250 ms while open: the status line,
-- the rows of the session's state and, unless a row said something, the newest notice (the feed hides under the
-- menu); the world gone, the game paused or showing the mouse cursor (UI-DESIGN 7.4), or the kit off, it closes. The
-- game's input comes back 150 ms after a close, so the key that closed it (Esc would open the pause menu) never
-- reaches the game, and is asked again each 250 ms while closed until the kit has given it. No engine call here: the
-- kit makes them.
local M=require('ui_model')
local Link=require('link')
local T=require('ui_text')
local Join=require('join')
local Menu={}
local ROWS,BACK=15,0.15 -- Rows shown at once (a longer page scrolls); seconds before the game's input comes back.
local KEYS={'menu_key','host_key','status_key','leave_key'}
local OFF='the co-op menu is off (the UI stopped, see the log): use the coop commands'
local ROW={} -- Options rows by setting name.
for _,row in ipairs(M.OPTIONS) do if row.key then ROW[row.key]=row end end
-- o: {kit=ui.kit's, link=, settings= (main.lua's, changed in place), look= (the ghost's), puppet=, run=function(name,
-- arg) -> ok, message (main.lua's: the console's checks and log line), log=, version=, chat=chat.lua's view or nil,
-- code=join.lua's code box}.
function Menu.new(o)
    local kit,link,settings=o.kit,o.link,o.settings
    local self,open,world,model,capturing,note,top,page,back_at={},false,false,nil,nil,nil,0,nil,nil
    local values,words={},T.en
    -- Scaled from its left middle: centred on the 2160-unit screen, all of it stays on screen up to ui_scale=150.
    kit.add('menu',{x=180,y=330,w=1240,h=1500,hit=true,pivot={X=0,Y=0.5}},function(b)
        b.panel(0,0,1240,1500)
        local v={title=b.text(48,36,'','title'),rows={}}
        b.text(300,58,o.version or '','num')
        for i=1,ROWS do v.rows[i]=b.row(24,130+(i-1)*76,1192) end
        v.status,v.note=b.text(48,1290,'','status'),b.text(48,1340,'','status')
        v.hints=b.hints(48,1400,320,{{'move',''},{'enter',''},{'escape',''}})
        return v
    end)
    local function context()
        local code=link.code()
        return {mode=link.mode(),chat=o.chat~=nil and o.chat.can(),code=code,stranger=link.stranger()}
    end
    local function stranger(ctx) return Join.name(ctx.stranger.name) or words.ask.someone end
    local function value(row)
        local v=values[row.key]
        if row.bind then return capturing==row.key and words.press or v end
        if row.values then return words.value[row.key..'_'..v] or words.value[v] or v end -- aggro_game before game.
        local n=tonumber(v)
        if row.key=='photo_freeze_max' then
            return n==0 and words.no_limit or (n%60==0 and words.minutes:format(n//60) or words.seconds:format(n))
        end
        if row.key=='enemy_hp_scale' or row.key=='enemy_balance_scale' then -- 1.35 in the file, 135 % here.
            return words.percent:format(math.floor(n*100+0.5))
        end
        return row.key=='ui_scale' and words.percent:format(n) or v
    end
    -- The page as it is now, scrolled to keep the cursor's row and the one above it in view.
    local function draw()
        local v=open and kit.view('menu')
        if not v then return end
        local ctx=context()
        local rows,current=model.rows(ctx),model.current(ctx)
        if page~=model.page() then page,top=model.page(),0 end
        local at=1
        for i,row in ipairs(rows) do if row==current then at=i end end
        top=math.max(0,math.min(top,#rows-ROWS))
        if at<=top+1 then top=math.max(0,at-2) elseif at>top+ROWS then top=at-ROWS end
        for i,w in ipairs(v.rows) do
            local row=rows[top+i]
            if not row then w.set('','','normal')
            elseif row.head then w.set(words.head[row.head],'','disabled')
            else
                local label,v=words.row[row.id or row.key],row.key and value(row) or ''
                if row.id=='copy' then v=ctx.code elseif row.id=='remove' then label=label:format(stranger(ctx)) end
                w.set(label,v,row==current and 'focus' or 'normal')
            end
        end
        local ping,_,linked=link.ping(),link.friend()
        v.title.set(words.title)
        v.status.set(link.summary(words)..(linked and ping and ' · '..ping..' ms' or ''))
        v.note.set(note or (o.chat and o.chat.notice()) or '')
        for i,hint in ipairs({'move','select','back'}) do v.hints[i].set(words.hint[hint]) end
    end
    -- A change in effect, from the file now written: every key (the file may hold another clash), else the one setting.
    local function apply(text,key)
        local s=Link.parse_settings(text)
        for _,k in ipairs(key:find('_key$') and KEYS or {key}) do settings[k]=s[k] end
        if o.look[key]~=nil then
            o.look[key]=s[key]
            o.puppet.rebuild('look')
        end
        if key=='ui_scale' then kit.scale(s.ui_scale) elseif key=='ui_sounds' then kit.sounds(s.ui_sounds)
        elseif key=='ui_language' then words=T.pick(kit.language(),s.ui_language) end
    end
    -- A setting's new value: its line rewritten in the file as it is now (D-UI4), then in effect or, for the one read
    -- at a load only, said so.
    local function set(key,text)
        local file=link.settings_text()
        if not file then note=words.unreadable; return end
        local new,why=M.write(file,key,text)
        local saved=new~=nil
        if saved then saved,why=link.write_settings(new) end
        if not saved then
            note=words.not_saved:format(tostring(why))
            return o.log('menu: '..key..'='..text..' not saved: '..tostring(why))
        end
        values=M.read(new)
        o.log('menu: '..key..'='..text..' saved in coop-settings.txt')
        if ROW[key].reload then note=words.reload else apply(new,key) end
    end
    function self.is_open() return open end
    -- menu_key: open, or close; when it cannot open, false, why for the log and the same for the screen in the menu's
    -- words (the kit off when it took the game's input: the menu would be open unseen).
    function self.toggle()
        if open then return self.close() end
        words=T.pick(kit.language(),settings.ui_language)
        if kit.off() then return false,OFF,words.refused.off end
        if not (world and kit.ready()) then
            return false,'the co-op menu opens in the game world only',words.refused.world
        end
        if kit.paused() then
            return false,'the co-op menu does not open while the game is paused or shows a menu',words.refused.paused
        end
        model,open,capturing,note,page,back_at=M.new(),true,nil,nil,nil,nil
        values=M.read(link.settings_text() or '')
        kit.show('menu',true,os.clock())
        kit.input(true)
        if kit.off() then self.close(); return false,OFF,words.refused.off end
        kit.sound('open')
        draw()
    end
    function self.close()
        if not open then return end
        open,capturing,note=false,nil,nil
        model.close()
        kit.show('menu',false,os.clock())
        kit.sound('close')
        back_at=os.clock()+BACK
    end
    -- A navigation key while open: 'up', 'down', 'left', 'right', 'select' or 'back'. While a key row waits for a key,
    -- back only, which stops waiting.
    function self.nav(what)
        if not open then return end
        if kit.off() then return self.close() end -- Unseen: no row runs.
        if capturing then
            if what=='back' then capturing,note=nil,nil; kit.sound('back'); draw() end
            return
        end
        local ctx=context()
        note=nil
        if what=='up' or what=='down' then
            model.move(ctx,what=='up' and -1 or 1)
            kit.sound('move')
        elseif what=='left' or what=='right' then
            local action,key,text=model.change(ctx,values,what=='left' and -1 or 1)
            if action then kit.sound('change'); set(key,text) end
        elseif what=='back' then
            kit.sound('back')
            if model.back()=='close' then return self.close() end
        elseif what=='select' then
            kit.sound('select')
            local action,key,text=model.select(ctx,os.clock(),values)
            if action=='confirm_leave' then note=words.confirm_leave
            elseif action=='confirm_remove' then note=words.confirm_remove:format(stranger(ctx))
            elseif action=='rebind' then capturing,note=key,words.capture
            elseif action=='set' then set(key,text)
            elseif action=='close' then return self.close()
            elseif action=='chat' then
                self.close()
                return o.chat.open()
            elseif action=='join_code' then
                self.close()
                return o.code.open()
            elseif action=='remove' then
                local ok,message=o.run('remove',ctx.stranger.id)
                if not ok then note=message end
            elseif action=='host' or action=='invite' then
                self.close()
                return o.run(action)
            elseif action=='leave' or action=='join' or action=='report' or action=='copy' then
                local ok,message=o.run(action)
                if not ok then note=message elseif action=='report' then note=words.report end
            end
        end
        draw()
    end
    -- A key pressed (keybind.text's: 'Shift+F7', 'Enter') while a key row waits for one: true when taken, as the new
    -- key once it is free, else with why.
    function self.capture(name)
        if not (open and capturing) then return false end
        if kit.off() then self.close(); return false end
        local action,a,b=M.rebind(values,capturing,name)
        if action then
            capturing=nil
            set(a,b)
        elseif a=='clash' then note=words.clash:format(words.row[b] or b)
        else note=a=='F10 opens the console' and words.f10 or words.keys end
        draw()
        return true
    end
    -- Each 250 ms: whether our HUD may show (a world, not our photo mode); closed when not, or when the game pauses or
    -- shows the mouse cursor. Closed, the game's input is given back again while still due (no player controller at the
    -- close: a map change).
    function self.slow(shown)
        world=shown==true
        if open and (not world or kit.off() or kit.paused()) then return self.close() end
        if not (open or back_at) then kit.input(false) end
        draw()
    end
    -- Each frame: the game's input back, once due.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false)
        end
    end
    -- coop off: closed (kit.stop gives the game its input back).
    function self.stop() open,capturing,back_at=false,nil,nil end
    return self
end
return Menu
