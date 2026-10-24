-- The story dump's console command: coop story [dump|find], a test tool (story/dump.lua). main.lua builds it with
-- new(o) at each Lua load and merges it into its command table. o.story_dump: the dump built there with the mod folder.
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
    return self
end
return Story
