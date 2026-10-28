-- The story dump's console command: coop story [dump|find], a test tool (story/dump.lua), and Lily's signal by hand:
-- coop lily signal [status|quest|travel] (story/lily.lua, experimental). main.lua builds it with new(o) at each Lua load
-- and merges it into its command table. o.story_dump: the dump built there with the mod folder; o.lily: Lily's signal,
-- set after this is built, so read at each call; o.coop_slot: main.lua's co-op save check.
local Story={}
function Story.new(o)
    local story_dump=o.story_dump
    local self={}
    -- The save object the running game holds, read only, in the lines tools/story.py prints from a save file; find
    -- lists the story-shaped classes and objects instead, for when it is somewhere else.
    function self.story(sub,extra)
        if extra~=nil then return false,'Use: coop story [dump|find]' end
        return story_dump.run(sub)
    end
    -- The quest and the camp travel may go into the save, so on a co-op save only; status anywhere.
    function self.lily(sub,what,extra)
        if sub~='signal' or extra~=nil or not o.lily then return false,'Use: coop lily signal [status|quest|travel]' end
        if what~='status' then
            local ok,why=o.coop_slot('coop lily signal')
            if not ok then return false,why end
        end
        return o.lily.command(what)
    end
    return self
end
return Story
