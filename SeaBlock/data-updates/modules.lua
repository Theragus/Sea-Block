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
    -- Circuit Processing also puts five polished topaz straight into
    -- Agriculture module 1, which kept it behind blue science after the other
    -- first modules moved forward. Move them to Agriculture module 2, which
    -- needs blue science anyway and uses four tier 1 modules, so tier 2 and
    -- later still cost the same topaz. If the topaz is not where expected,
    -- give the technology Gem processing 3, which it found only through Modules.
    local bio1 = data.raw.recipe["angels-bio-yield-module"]
    local bio2 = data.raw.recipe["angels-bio-yield-module-2"]
    local topaz
    for _, ingredient in pairs(bio1 and bio1.ingredients or {}) do
      if ingredient.name == "bob-topaz-5" then
        topaz = ingredient.amount
      end
    end
    if topaz and bio2 then
      bobmods.lib.recipe.remove_ingredient(bio1.name, "bob-topaz-5")
      bobmods.lib.recipe.add_ingredient(bio2.name, { type = "item", name = "bob-topaz-5", amount = 4 * topaz })
    elseif data.raw.technology["angels-bio-yield-module"] then
      bobmods.lib.tech.add_prerequisite("angels-bio-yield-module", "bob-gem-processing-3")
    end
  end
end
