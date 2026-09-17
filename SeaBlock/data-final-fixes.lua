-- Adjust rubber production amount to how it was in petrochem 0.7.9.
-- TODO: Revisit this after Angel adds more liquid rubber recipes
seablock.lib.substresult("angels-liquid-rubber", "angels-liquid-rubber", nil, 20)

-- Reduce burner heat source neighbour bonus
local reactors = {
  "burner-reactor",
  "burner-reactor-2",
  "fluid-reactor",
  "fluid-reactor-2",
}

for _, v in pairs(reactors) do
  local r = data.raw.reactor[v]
  if r then
    r.neighbour_bonus = 0.125
  end
end

-- Give the tutorial cost items the icon of the thing they stand for, now that
-- every mod has finished moving icons around. Bob's renamed basic-circuit-board
-- to bob-basic-circuit-board in 2.0, so the old lookup here silently found
-- nothing and left a hardcoded icon_size behind that no longer matched the file.
for stand_in, real_item in pairs({
  ["sb-angelsore3-tool"] = "angels-ore3-crushed",
  ["sb-basic-circuit-board-tool"] = "bob-basic-circuit-board",
  ["sb-lab-tool"] = "lab",
}) do
  seablock.lib.copy_icon(data.raw.item[stand_in], data.raw.item[real_item])
end

require("data-final-fixes/logistics")
require("data-final-fixes/icons")
require("data-final-fixes/recipe")
require("data-final-fixes/tech-tree")
require("data-final-fixes/unobtainable_items")
require("data-final-fixes/research-triggers")
require("data-final-fixes/lab-coverage")
require("data-final-fixes/mapgen")
require("data-final-fixes/SpaceMod")
require("data-final-fixes/ScienceCostTweakerM")

data.raw.recipe["copper-cable"].allow_decomposition = true
data.raw.recipe["angels-solid-paper"].allow_decomposition = true

for _, v in pairs(data.raw.character) do
  if v.crafting_categories then
    table.insert(v.crafting_categories, "sb-crafting-handonly")
  end
end
