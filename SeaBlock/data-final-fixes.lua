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
-- After every pass that edits prerequisites, including ScienceCostTweakerM's folding
require("data-final-fixes/hidden-prerequisites")
require("data-final-fixes/alien-artifacts")
require("data-final-fixes/hidden-ingredients")

data.raw.recipe["copper-cable"].allow_decomposition = true
data.raw.recipe["angels-solid-paper"].allow_decomposition = true

for _, v in pairs(data.raw.character) do
  if v.crafting_categories then
    table.insert(v.crafting_categories, "sb-crafting-handonly")
  end
end

-- Last, so it sees every item any earlier stage has touched
require("data-final-fixes/fuel-categories")
