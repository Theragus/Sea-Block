-- Swap ingredients Sea Block removed for the ones the recipe used before.
--
-- data/misc.lua turns off Angel's nickel plate (nickel stays an ingot that goes into
-- alloys) and data-updates/unobtainable-items.lua hides bob-nickel-plate. Bob's 2.x
-- still swaps steel plate for nickel plate in a dozen recipes whenever the item
-- exists, which it does, so Boiler 3, Heat pipe 2, Roboport antenna 2, Roboport
-- chargepad 2 and others asked for a plate nothing makes. Steel is what each of those
-- recipes uses without nickel. Done across all recipes rather than by name, so a
-- recipe Bob's moves to nickel later is covered too.

local substitutes = {
  ["bob-nickel-plate"] = "steel-plate",
}

local names = {}
for name in pairs(data.raw.recipe) do
  table.insert(names, name)
end
table.sort(names)

for _, name in ipairs(names) do
  local recipe = data.raw.recipe[name]
  if not recipe.hidden then
    for from, to in pairs(substitutes) do
      for _, ingredient in pairs(recipe.ingredients or {}) do
        if ingredient.name == from then
          -- Merges into an existing steel plate ingredient instead of listing it twice
          bobmods.lib.recipe.replace_ingredient(name, from, to)
          log(("Sea Block: %s used hidden %s, now uses %s"):format(name, from, to))
          break
        end
      end
    end
  end
end
