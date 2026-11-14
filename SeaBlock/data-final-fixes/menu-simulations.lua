-- Main menu simulations.
--
-- The vanilla scenes are replays of saves, and data-updates/misc.lua deletes
-- every resource prototype but the sea pump's, so any scene built on an ore
-- patch or an oil field loads with its drills and pumpjacks standing on bare
-- ground. Those are taken out and Sea Block's own scenes, built from script, go
-- in alongside the rest.
local simulations = data.raw["utility-constants"].default.main_menu_simulations
if not simulations then
  return
end

-- By scene, since the saves themselves do not ship with the headless build the
-- load test runs on. Uranium processing plays at night, when uranium ore glows:
-- it is the one scene left whose theme is a resource patch. The oil refinery,
-- nuclear power and the rest have recipes Sea Block keeps.
seablock.removed_menu_simulations = {
  "nauvis_burner_city",
  "nauvis_early_smelting",
  "nauvis_mining_defense",
  "nauvis_oil_pumpjacks",
  "nauvis_uranium_processing",
}
for _, name in ipairs(seablock.removed_menu_simulations) do
  simulations[name] = nil
end

local prelude = require("menu-simulations.prelude")

-- generate_map gives the scene a surface with chunks to paint over; the
-- prelude clears whatever the generator put there.
simulations.seablock_island = {
  checkboard = false,
  generate_map = true,
  length = 60 * 13,
  init = prelude .. require("menu-simulations.island"),
}

simulations.seablock_factory = {
  checkboard = false,
  generate_map = true,
  length = 60 * 12,
  -- Long enough for the water and mud to fill every pipe and the last
  -- washing plant to start, so the scene opens with the line already running.
  init_update_count = 60 * 30,
  init = prelude .. require("menu-simulations.factory"),
}
