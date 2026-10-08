-- Technologies whose recipes use large alien artifacts require Artifact processing.
--
-- Artifact processing unlocks the only recipes that make large artifacts in Sea
-- Block (data-updates/military.lua unhides them). Bob's gated the equipment that
-- uses them behind alien research, which Sea Block hides, and military.lua drops
-- most of those prerequisites to keep the equipment. Without one, Energy shield
-- MK3, Battery MK4 and the rest become available long before the player can make
-- what they ask for. Find them from the recipes rather than by name, so a new tier
-- or a moved unlock is covered too.

local gate = "bob-artifact-processing"
local technology = data.raw.technology[gate]

local function usable(t)
  return t and not t.hidden and t.enabled ~= false
end

if usable(technology) then
  -- Everything Artifact processing's recipes make.
  local artifacts = {}
  for _, effect in pairs(technology.effects or {}) do
    local recipe = effect.type == "unlock-recipe" and data.raw.recipe[effect.recipe]
    if recipe and not recipe.hidden then
      for _, result in pairs(recipe.results or {}) do
        artifacts[result.name] = true
      end
    end
  end

  local function needs_artifacts(recipe)
    for _, ingredient in pairs(recipe and not recipe.hidden and recipe.ingredients or {}) do
      if artifacts[ingredient.name] then
        return true
      end
    end
    return false
  end

  local names = {}
  for name in pairs(data.raw.technology) do
    table.insert(names, name)
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local candidate = data.raw.technology[name]
    if name ~= gate and usable(candidate) and not seablock.lib.requires_technology(name, gate) then
      for _, effect in pairs(candidate.effects or {}) do
        if effect.type == "unlock-recipe" and needs_artifacts(data.raw.recipe[effect.recipe]) then
          if seablock.lib.requires_technology(gate, name) then
            log(("Sea Block: %s cannot require %s, it would close a loop"):format(name, gate))
          else
            bobmods.lib.tech.add_prerequisite(name, gate)
            log(("Sea Block: %s makes %s from alien artifacts, now requires %s"):format(name, effect.recipe, gate))
          end
          break
        end
      end
    end
  end
end
