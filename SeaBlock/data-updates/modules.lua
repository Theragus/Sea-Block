-- Circuit Processing 2.x puts a polished gem into every tier 1 module processor
-- and makes Modules require Gem processing 3, which Sea Block costs blue science
-- (data-updates/misc.lua). That held the first modules back until after blue
-- science, while in 1.1 the first module tiers needed no gems at all. Move the
-- gems up to the tier 2 processors, which already need blue science, at four per
-- processor so that tier 2 and later modules cost exactly the gems they did.
if mods["CircuitProcessing"] and mods["bobmodules"] and data.raw.technology["bob-gem-processing-3"] then
  local moved = false
  for _, kind in pairs({ "speed", "efficiency", "productivity" }) do
    local tier1 = data.raw.recipe["cp-" .. kind .. "-processor"]
    local tier2 = "bob-" .. kind .. "-processor"
    if tier1 and data.raw.recipe[tier2] then
      for _, ingredient in pairs(tier1.ingredients or {}) do
        local gem = ingredient.name
        if gem and gem:match("^bob%-%a+%-5$") then
          bobmods.lib.recipe.remove_ingredient(tier1.name, gem)
          bobmods.lib.recipe.add_ingredient(tier2, { type = "item", name = gem, amount = 4 * ingredient.amount })
          moved = true
          break
        end
      end
    end
  end

  if moved then
    bobmods.lib.tech.remove_prerequisite("modules", "bob-gem-processing-3")
    bobmods.lib.tech.add_prerequisite("bob-modules-2", "bob-gem-processing-3")
    -- Circuit Processing gives Agriculture module 1 a polished topaz, and its
    -- technology found Gem processing 3 only through Modules.
    if data.raw.technology["angels-bio-yield-module"] then
      bobmods.lib.tech.add_prerequisite("angels-bio-yield-module", "bob-gem-processing-3")
    end
  end
end
