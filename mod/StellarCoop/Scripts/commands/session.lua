-- The session's console commands: coop host (as who_can_join says), invite, join, leave, status, report, copy, mark,
-- allow, deny and remove, with coop revive test, coop travel and coop saves. main.lua builds them with new(o) at each
-- Lua load and merges them into its command table, whose run() logs each result and, after coop off, refuses all but
-- status and report. o: main.lua's link, settings, puppet, ask (a line for the native part) and coop_slot, and group()
-- and travel(), read at each call: the revive and the follow are built later, with the Steam link only.
local Session={}
-- Host by who_can_join: code (an invisible lobby with a join code), private (invited only), friends.
local HOSTS={code='host code',private='host private'}
function Session.new(o)
    local link,settings,puppet,ask,coop_slot=o.link,o.settings,o.puppet,o.ask,o.coop_slot
    local self={}
    -- The host's answers about a player (allow, deny: one who is not her Steam friend and waits; remove: anyone in the
    -- lobby), by SteamID only.
    local function answer(verb)
        return function(id)
            if type(id)~='string' or not id:match('^%d+$') or #id>20 then
                return false,'Use: coop '..verb..' <SteamID>'
            end
            return ask(verb..' '..id)()
        end
    end
    local refresh_asked=nil -- coop saves refresh: the slot typed and when ({slot=, at=}), until typed again.
    function self.host() return ask(HOSTS[settings and settings.who_can_join] or 'host')() end
    self.invite,self.leave,self.report,self.copy=ask('invite'),ask('leave'),ask('report'),ask('copy')
    -- Every word typed after mark (the console handler joins them), cleaned like a chat line; the native part numbers
    -- the mark, logs it and sends it to the friend. A console tool: no key, no text on screen.
    function self.mark(text)
        if not link then return false,'coop mark needs the Steam link' end
        text=require('session.chat').clean(text or '')
        return link.request(text~='' and 'mark '..text or 'mark')
    end
    self.allow,self.deny,self.remove=answer('allow'),answer('deny'),answer('remove')
    -- A lobby id, or a join code as the native part takes it.
    function self.join(lobby)
        if lobby and link then
            lobby=link.valid_lobby(lobby) and lobby or link.join_code(lobby)
            if not lobby then return false,'a lobby id is digits only, a join code 7 letters and digits' end
        end
        return ask(lobby and 'join '..lobby or 'join')()
    end
    -- test: the revive's solo probe at the death screen, on a co-op save only (session/group.lua says why not).
    function self.revive(sub,extra)
        if sub~='test' or extra~=nil then return false,'Use: coop revive test' end
        local group=o.group() -- main.lua builds it after the commands, with the Steam link only.
        if not group then return false,'the Steam link needs the native part' end
        local ok,why=coop_slot('coop revive test')
        if not ok then return false,why end
        return group.test()
    end
    -- host: as follow_key (the travel to the camp nearest the host, or always's start cancelled); probe <camp>: its
    -- solo test, the native call alone (session/travel.lua says why not).
    function self.travel(sub,arg,extra)
        local travel=o.travel() -- Likewise.
        if not travel then return false,'the Steam link needs the native part' end
        if sub=='host' and arg==nil then return travel.press() end
        if sub=='probe' and arg~=nil and extra==nil then return travel.probe(arg) end
        return false,'Use: coop travel host'
    end
    -- The co-op saves by hand (the question at the title asks for them): probe logs what the native part reads and the
    -- next copy pass's plan; convert makes the copies; coop makes them and switches the save name; main switches back;
    -- refresh <0-4> replaces that slot's co-op copy, played or not, with a new copy of the player's save (the native
    -- part backs the old one up first), once typed twice for the same slot within 10 s. The native part refuses all but
    -- probe off the title screen, and says why in coop-link.log.
    function self.saves(sub,extra,more)
        if sub=='refresh' and more==nil and type(extra)=='string' and extra:match('^[0-4]$') then
            local now=os.clock()
            if not (refresh_asked and refresh_asked.slot==extra and now-refresh_asked.at<=10) then
                refresh_asked={slot=extra,at=now}
                return false,'coop saves refresh '..extra..' replaces the co-op copy StellarBladeCoop0'..extra..'.sav, '
                    ..'played in co-op or not, with a new copy of your save StellarBladeSave0'..extra..'.sav (the old '
                    ..'copy goes to StellarCoopBackups first): type it again within 10 s to go on'
            end
            refresh_asked=nil
            return ask('saves refresh '..extra)()
        end
        if extra~=nil or not ({probe=true,convert=true,coop=true,main=true})[sub or ''] then
            return false,'Use: coop saves probe | convert | coop | main | refresh <0-4>'
        end
        return ask('saves '..sub)()
    end
    -- The native part's status on one line, our CNS packs in words when there are some, then the ghost's.
    function self.status()
        local text=link and link.status()
        if not text then return false,'no Steam link status yet; '..puppet.status() end
        local cns=link.cns()
        return true,text:gsub('[\r\n]+',' | ')..(cns and cns..' | ' or '')..puppet.status()
    end
    return self
end
return Session
