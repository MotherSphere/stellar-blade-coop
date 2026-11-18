-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Night Operation's wiring (online/modes/nightop/): the T6 probe, the run, the recruiter, Roxanne, the guard's lines,
-- its HUD.
return {
uses={'fight.bosses','online.group','online.partner','online.modes.race'},
exports={'nightop','night','recruiter','roxanne','guard_text'},
new=function(M)
local print,log=M.print,M.log
-- Its one entry, commands.no, runs only on a co-op save (coop_slot).
M.nightop=require('online.modes.nightop.probe').new(function(m) print('[StellarCoop][NO] '..tostring(m)..'\n') end,
    function(line) return M.ask(line)() end,function() return M.link and M.link.status() end)
-- Night Operation's run: commands.nightop starts it on a co-op save only; stop and coop off end it anywhere. It
-- ticks every 250 ms and logs [NR] lines; the game's pause is read even with the UI kit off. Its card and result panel
-- go on the kit (night.hud, below); with the kit off, what they show comes as notices (tell). Linked, its night line
-- goes out through link.night and the partner's name comes from link.friend. The shop's wallets are link.store files.
-- commands.challenge starts the challenges on the same run. Their best runs go in coop-records.txt in the mod folder
-- (none when it is unknown). No such file is no best yet; a file that cannot be opened raises, so nothing is written
-- over it. It is written through a temporary file: a write that fails before the old file is deleted leaves it as it
-- was, one that fails after leaves the new text in coop-records.txt.tmp. In a co-op run, a downed player's revive
-- (with her revive setting on) goes through the friend's revive (group), and the partner's ghost feet come from the
-- puppet.
M.night=require('online.modes.nightop.run').new({log=function(m) print('[StellarCoop][NR] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,
    paused=function() return M.kit~=nil and M.kit.paused(true) end,settings=M.settings,
    tell=M.tell,send=function(line) if M.link then return M.link.night(line) end end,
    friend=function() return M.link and (M.link.friend()) end,
    store=function(name) return M.link and M.link.store(name) end,
    rows=function(done,word)
        if M.off_modules['fight.bosses'] then return false,'coop lion is off until the mod reloads' end
        return M.lion.rows(done,word)
    end,ask=function(line) return M.ask(line)() end,
    revive=function(by)
        if not M.group then return false,'no Steam link' end
        if M.off_modules['online.group'] then return false,'group play is off until the mod reloads' end
        return M.group.night_revive(by)
    end,
    ghost=function() return select(2,M.puppet.anchor()) end,
    records=M.folder and {
        read=function()
            local text,e,code=require('core.link').files.read(M.folder..'\\coop-records.txt')
            if text==nil and code~=2 then error(e) end -- 2: ENOENT, no such file.
            return text
        end,
        write=function(text)
            local fs,p=require('core.link').files,M.folder..'\\coop-records.txt'
            if not fs.write(p..'.tmp',text) then return false end
            fs.remove(p) -- rename never replaces on Windows.
            -- The rename refused once the old file went (a virus scanner holding the .tmp): written in place.
            return fs.rename(p..'.tmp',p)==true or not fs.read(p) and fs.write(p,text)
        end} or nil})
-- commands.recruiter runs only on a co-op save; coop off despawns on any slot (cleanup). Once he is asked for (or found
-- there already), his Join is armed, with sbo_lobby=on only: arming swaps a slot in the game's image, and a player who has not turned the lobby
-- on gets no swap (his Join then does what the game's does). The native part counts each Join on the sbo line
-- (online/lobby/sbo.lua turns it into an entry, or a notice of what is missing).
local Recruiter=require('online.modes.nightop.recruiter')
M.recruiter=Recruiter.new(function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end,function()
    if M.link and M.settings and M.settings.sbo_lobby then
        M.link.request('sbo arm '..Recruiter.index_of(Recruiter.find_name(Recruiter.JOIN))..' 0')
    end
end)
-- Roxanne's Night Operation choices (online/modes/nightop/roxanne.lua), logging [NR] lines: on a co-op save, once EVE
-- is in Xion; a level picked is booked and started through coop nightop start, the supplies open coop nightop shop.
-- Ticked in the 250 ms loop of main/pass.lua (with the Steam link only), after coop off too: coop off puts her two
-- choices back.
M.roxanne=require('online.modes.nightop.roxanne').new({
    log=function(m) print('[StellarCoop][NR] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,ask=function(line) return M.ask(line)() end,
    paused=function() return M.kit~=nil and M.kit.paused(true) end,title=function() return M.at_title end,tell=M.tell,
    start=function(level) return M.commands.nightop('start',level) end,
    shop=function() return M.commands.nightop('shop') end,phase=function() return M.night.phase() end})
-- The Xion guard's lines in the game's language (online/modes/nightop/guard_text.lua), logging [RC] lines: ticked in
-- the 250 ms loop of main/pass.lua (with the Steam link only) until coop off, after which the native part puts his
-- Korean back.
M.guard_text=require('online.modes.nightop.guard_text').new({
    log=function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,ask=function(line) return M.ask(line)() end})
return require('online.modes.nightop.commands').new({coop_slot=M.coop_slot,nightop=M.nightop,night=M.night,
    race={armed=function() return M.race.armed() end},recruiter=M.recruiter,roxanne=M.roxanne})
end,
build={
hud=function(M,Ui)
    M.night.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings})
end,
},
}
