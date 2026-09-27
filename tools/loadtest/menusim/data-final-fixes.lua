-- Hand the menu simulations to the control stage, which cannot otherwise see
-- utility constants' Lua source.
local scenes, others = {}, {}
for name, simulation in pairs(data.raw["utility-constants"].default.main_menu_simulations or {}) do
  if name:find("^seablock_") then
    scenes[name] = {
      init = simulation.init,
      update = simulation.update,
      length = simulation.length or 0,
      init_update_count = simulation.init_update_count or 0,
    }
  else
    others[#others + 1] = name
  end
end
table.sort(others)

data:extend({
  {
    type = "mod-data",
    name = "sb-menusim-test",
    data = { scenes = scenes, others = others },
  },
})
