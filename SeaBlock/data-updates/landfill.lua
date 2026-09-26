-- Will need a lot of landfill
bobmods.lib.recipe.set_ingredients("landfill", { { type = "item", name = "angels-stone-crushed", amount = 10 } })
for k, v in pairs(data.raw.item) do
  if string.sub(k, 1, 8) == "landfill" then
    v.stack_size = 1000
  end
end

local function BuffLandfill(recipe)
  bobmods.lib.recipe.set_ingredient(recipe, { type = "item", name = "angels-solid-mud", amount = 5 })
  bobmods.lib.recipe.set_energy_required(recipe, 2)
end

BuffLandfill("angels-solid-mud-landfill")

local default_landfill = "landfill"

-- Make landfill a red science tech, straight after the Water washing 1 that
-- makes the mud, as Sea Block 0.5 had it. The 2.0 rewrite kept the cost but
-- lost these lines, which left the base game's Logistic science pack
-- prerequisite in place: a 10 red science tech behind over 20 others, and mud
-- landfill behind green science with Water washing 2.
data.raw.technology["landfill"].prerequisites = { "angels-water-washing-1" }
data.raw.technology["landfill"].unit = {
  count = 10,
  ingredients = { { "automation-science-pack", 1 } },
  time = 15,
}
bobmods.lib.tech.ignore_tech_cost_multiplier("landfill", true)
bobmods.lib.tech.remove_prerequisite("angels-water-washing-2", "landfill")
bobmods.lib.tech.remove_recipe_unlock("angels-water-washing-2", "angels-solid-mud-landfill")
bobmods.lib.tech.add_recipe_unlock("landfill", "angels-solid-mud-landfill")

-- For blueprint pasting on water
local tile = data.raw.item[default_landfill].place_as_tile.result
data.raw.tile["water"].default_cover_tile = tile
data.raw.tile["deepwater"].default_cover_tile = tile

if mods["LandfillPainting"] then
  -- Set prefered type for basic landfill crafting
  if settings.startup["sb-default-landfill"] then
    local stripped = settings.startup["sb-default-landfill"].value:gsub("^sb%-default%-landfill%-", "")
    local recipe = data.raw.recipe["landfill"]
    if data.raw.item[stripped] and default_landfill ~= stripped then
      default_landfill = stripped
      recipe.results = { { type = "item", name = default_landfill, amount = 1 } }
      recipe.localised_name = { "item-name." .. default_landfill }
    else
      recipe.always_show_products = true
    end
  end

  BuffLandfill("landfill-dry-dirt")
  BuffLandfill("landfill-dirt")
  BuffLandfill("landfill-grass")
  BuffLandfill("landfill-red-desert")
  BuffLandfill("landfill-sand")

  -- Adds SeaBlock tiles to tile condition so they can be replaced with landfill when placing
  local sounds = require("__base__/prototypes/entity/sounds")
  for _, item_name in pairs({
    "landfill-dry-dirt",
    "landfill-dirt",
    "landfill-grass",
    "landfill-red-desert",
    "landfill-sand",
  }) do
    local tile_cond = data.raw.item[item_name].place_as_tile.tile_condition
    if tile_cond then
      table.insert(tile_cond, "sand-4")
      table.insert(tile_cond, "sand-5")
    end
    local tile = data.raw.tile[data.raw.item[item_name].place_as_tile.result]
    tile.minable = { mining_time = 0.5, result = item_name }
    tile.mined_sound = sounds.deconstruct_bricks(0.8)
    tile.is_foundation = true
  end
end

-- Paste over sand-4 and -5
local tile_cond = data.raw.item["landfill"].place_as_tile.tile_condition

table.insert(tile_cond, "sand-4")
table.insert(tile_cond, "sand-5")
