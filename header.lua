local plugin = {}

plugin["name"] = "Fishermans Friend"
plugin["version"] = "0.1"
plugin["author"] = "HeftyHippo"
plugin["description"] = "Fishing profession utility"
plugin["load"] = true

-- Ensure the script only loads when in-game
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

return plugin