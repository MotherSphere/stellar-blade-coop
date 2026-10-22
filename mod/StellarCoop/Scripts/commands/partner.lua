-- The ghost's console commands: coop puppet, basesuit, where, look, loopback, record and replay, and coop freeze, the
-- photo pause alone. main.lua builds them with new(o) at each Lua load and merges them into its command table. o:
-- main.lua's puppet, native_tick (nil without the native part), ask (a line for the native part), look (the table the
-- ghost holds) and looks.
local Partner={}
local function whole(text,max) -- A whole number from 0 to max, or nil.
    local n=type(text)=='string' and text:match('^%d+$') and tonumber(text)
    return n and n<=max and n or nil
end
function Partner.new(o)
    local puppet,native_tick,ask,look,looks=o.puppet,o.native_tick,o.ask,o.look,o.looks
    local self={}
    self.puppet=puppet.toggle
    function self.loopback(delay,jitter,loss)
        if not native_tick then return false,'the native tick is unavailable' end
        if delay=='off' then return ask('loopback off')() end
        delay,jitter,loss=whole(delay,1000),whole(jitter,500),whole(loss,100)
        if not (delay and jitter and loss) then
            return false,'Use: coop loopback <delay 0-1000 ms> <jitter 0-500 ms> <segment loss 0-100 %> | off'
        end
        if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
        return ask(string.format('loopback %d %d %d',delay,jitter,loss))()
    end
    self.basesuit,self.where=puppet.basesuit,puppet.where
    function self.look(feature,state)
        if feature==nil then
            return true,looks()..' (coop look <cloth|dyes|effects> <on|off> changes one until the mod reloads: game '
                ..'start or Ctrl+R)'
        end
        local named=({cloth='Cloth',dyes='Dyes',effects='Effects'})[feature]
        if not named or (state~='on' and state~='off') then
            return false,'Use: coop look [cloth|dyes|effects on|off]'
        end
        look[feature]=state=='on'
        puppet.rebuild('look')
        return true,named..' '..state..' until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
            ..'the ghost is built again.'
    end
    -- The photo pause alone (the solo tests): our pause tag held for 1 to 3600 s, or until off; the native part refuses
    -- it off the pinned build and says why in the log.
    function self.freeze(arg,extra)
        local seconds=arg~='off' and whole(arg,3600)
        if extra~=nil or not (arg=='off' or seconds and seconds>0) then
            return false,'Use: coop freeze <1-3600 seconds> | off'
        end
        if not native_tick then return false,'the native tick is unavailable' end
        return ask(seconds and 'freeze '..seconds or 'freeze off')()
    end
    -- coop record and coop replay: on (with the ghost on, which publishes her capture) or off.
    for _,name in ipairs({'record','replay'}) do
        self[name]=function(arg)
            if not native_tick then return false,'the native tick is unavailable' end
            if arg=='off' then return ask(name..' off')() end
            if arg~=nil then return false,'Use: coop '..name..' [off]' end
            if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
            return ask(name)()
        end
    end
    return self
end
return Partner
