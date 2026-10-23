-- The first-launch guide's words (ui/guide.lua) and its co-op menu row's (ui/menu.lua), kept apart from ui/text.lua.
-- G.en is English: nine pages, each a title and a body (\n starts a new line), then the rows, the page line and the
-- menu row. Another language's table sits under the culture name ui/text.lua gives it (G.fr, G['zh-Hans']...), empty
-- until it is translated, then with G.en's keys at every level. Keys, console commands, file names and the Discord
-- address are inside the strings and stay as written in every language. The game's language picks the table
-- (G.pick, as T.pick) unless ui_language=english; a language with no table, or a word missing from one (a page
-- included), reads English.
local G={}
G.en={
    pages={
        {title='Welcome to Stellar Blade Online',
         body='Stellar Blade Online connects two copies of Stellar Blade over Steam. Each player stays in their '
            .."own game. Your friend's EVE appears in your world and moves as they do in their game.\nA session "
            ..'holds 2 players for now. The goal is 100 players.\nYou can open this guide again from the co-op menu '
            ..'(F5).'},
        {title='Play together',
         body='Press F5 in the world to open the co-op menu (hold View on a controller). Its first row, Host a '
            ..'session, opens the Steam invite window.\nSomeone who is not on your Steam friends list can join with '
            ..'a code. Before you host, set Who can join to With a code in the Options. Then send them the '
            ..'7-character code from Copy my code. You accept them when they join.\nF6: status\nF8: leave the '
            ..'session\nEnter: chat\nAt a camp phone booth, F5 opens the co-op line instead of the menu.'},
        {title='Co-op saves',
         body='Shared enemies, shared quests, Night Operation, Doro races and Leviathan run on co-op saves. These '
            ..'are copies of your saves made by the mod. It never writes to your own save files and backs them up '
            ..'before the first copy.\nOn the title screen you pick co-op (the copies) or solo (your own saves).'},
        {title='A shared world',
         body='On the same map, common enemies have one HP bar for both of you and die on both screens at once. '
            ..'They stand in the same spot in both games and go after whoever hit them last. Bosses share their HP '
            ..'and their phases.\nBy default a kill counts for you if you fought or stood within 30 m.\nWhile the '
            .."host watches a cutscene, the guest's game waits. Shared quests and revives by your friend are off "
            ..'by default. Turn them on in the Options.'},
        {title='Night Operation',
         body='Night Operation is a wave survival mode that Shift Up cut before release. A run has five timed '
            ..'waves. When the host starts it during a session, you share the timer and the score. Points from a '
            ..'run buy items.\nType these in the console (F10 or ~) on a co-op save:\ncoop nightop start: start a '
            ..'run\ncoop nightop shop: list the items\ncoop nightop buy <n>: buy item n\ncoop challenge: four graded '
            ..'challenges'},
        {title='Doro races',
         body='In a Doro race both EVEs turn into Doro. Record a track first, then race on it:\ncoop race record '
            ..'<name>: start recording\nF9: add a checkpoint where you stand\ncoop race save: save the track\ncoop '
            ..'race start <name>: start the race (co-op save)\nThe race starts after a countdown. After GO, Doro '
            ..'handles like a car and speeds up over time. R2 or the B key drifts. Steering hard at speed drifts '
            ..'too. The ranking shows at the end.'},
        {title='Leviathan and the free camera',
         body='Leviathan is a Naytiba cut from the game. Its model and animations are still in the game files. On '
            ..'a co-op save, coop leviathan show places it in front of you and starts a free camera for filming. '
            ..'coop leviathan off removes both.\nW A S D or Z Q S D: fly\nSpace or E: up\nCtrl or C: down\nShift: '
            ..'faster\nMouse: look around'},
        {title='Settings and languages',
         body='The Options page of the co-op menu sets the keys, the partner HUD, who can join, the co-op saves, '
            .."the combat rules, the menu's size and its sounds. The values are stored in coop-settings.txt.\nThe "
            .."mod's text follows your game language. It covers the 23 languages the game ships with."},
        {title='Help',
         body='Ask questions or find a co-op partner on the Discord: discord.gg/tvFApEEVfj\nTo report a bug, close '
            ..'the game. Before you start it again, send coop-report.txt, coop-link.log and UE4SS.log.\nMother '
            ..'Sphere art by timediffer24.'},
    },
    -- The rows, the page line (the page's number, then how many) and the co-op menu's row.
    next='Next',back='Back',close='Close',never="Don't show again",page='Page %d of %d',row='Guide',
}
for _,name in ipairs({'fr','ar','da','de','es','es-MX','fi','it','ja','ko','nl','no','pl','pt','pt-BR','ru','sv',
        'th','tr','zh-Hans','zh-Hant'}) do
    G[name]={}
end
local culture=require('nightop.recruiter_text').culture
-- A table and the tables in it read G.en's word for a key they lack.
local function fallback(t,en)
    for k,v in pairs(t) do if type(v)=='table' and type(en[k])=='table' then fallback(v,en[k]) end end
    return setmetatable(t,{__index=en})
end
-- The words for the game's culture (nil when unread) and ui_language.
function G.pick(name,setting)
    local t=setting~='english' and G[culture(name)] or G.en
    if t~=G.en and not getmetatable(t) then fallback(t,G.en) end
    return t
end
return G
