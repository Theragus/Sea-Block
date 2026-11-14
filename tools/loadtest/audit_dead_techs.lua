-- No visible technology may be a dead end: something the player can research
-- that grants nothing and leads nowhere.
--
-- A technology is dead when no usable technology requires it and every effect
-- it has is an unlock of a recipe the player gets anyway: one that is already
-- enabled, hidden, missing, or unlocked by another usable technology. The player
-- pays the science, the tree shows it researched, and nothing changes. That is
-- how Wood processing 3 ended up (Theragus/Sea-Block#33): Angel's 2.x moved
-- Cellulose fiber from raw wood to Arboretum 1, Sea Block kept adding it to Wood
-- processing 3, and once Sea Block took resin wood reprocessing away its only
-- other unlock, the Bioprocessor, was already on Farming 1. Charcoal processing 3
-- and Electric mining drill were the same.
--
-- Any other effect (a bonus, an item, a mining tool) counts as a reward, and a
-- technology that something requires is a stepping stone even if it unlocks
-- nothing itself. The fix for a finding is usually to hide the technology, or
-- to stop Sea Block moving its last unique unlock away.
--
-- Technologies whose reward is runtime behaviour have no effects to see here,
-- so they are listed below with the mod whose control script checks them.

local scripted = {
  -- Bob's Inserters' control.lua reads these to allow adjusting inserter
  -- pickup and drop positions in its GUI.
  ["bob-long-inserters-1"] = "bobinserters",
  ["bob-long-inserters-2"] = "bobinserters",
  ["bob-near-inserters"] = "bobinserters",
  ["bob-more-inserters-1"] = "bobinserters",
  ["bob-more-inserters-2"] = "bobinserters",
}

return function(data, mods, settings)
  local technologies = data.raw.technology
  local recipes = data.raw.recipe

  local function usable(technology)
    return not technology.hidden and technology.enabled ~= false
  end

  local required, unlockers = {}, {}
  for name, technology in pairs(technologies) do
    if usable(technology) then
      for _, prerequisite in pairs(technology.prerequisites or {}) do
        required[prerequisite] = true
      end
      for _, effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe then
          unlockers[effect.recipe] = unlockers[effect.recipe] or {}
          unlockers[effect.recipe][name] = true
        end
      end
    end
  end

  -- Why an unlock gives the player nothing, or nil if it gives them something.
  local function redundant(technology_name, recipe_name)
    local recipe = recipes[recipe_name]
    if not recipe then
      return "does not exist"
    elseif recipe.hidden then
      return "is hidden"
    elseif recipe.enabled ~= false then
      return "is enabled from the start"
    end
    local others = {}
    for other in pairs(unlockers[recipe_name] or {}) do
      if other ~= technology_name then
        table.insert(others, other)
      end
    end
    if #others > 0 then
      table.sort(others)
      return "is also unlocked by " .. table.concat(others, ", ")
    end
    return nil
  end

  local findings = {}
  for name, technology in pairs(technologies) do
    local script_mod = scripted[name]
    if usable(technology) and not required[name] and not (script_mod and mods[script_mod]) then
      local reasons, rewarded = {}, false
      for _, effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" then
          local why = redundant(name, effect.recipe)
          if why then
            table.insert(reasons, ("%s %s"):format(effect.recipe, why))
          else
            rewarded = true
          end
        else
          rewarded = true
        end
      end
      if not rewarded then
        table.sort(reasons)
        table.insert(findings, { name = name, reasons = reasons })
      end
    end
  end

  table.sort(findings, function(a, b)
    return a.name < b.name
  end)

  for _, finding in ipairs(findings) do
    io.stderr:write(("  technology %q grants nothing and nothing requires it\n"):format(finding.name))
    if #finding.reasons == 0 then
      io.stderr:write("    it has no effects\n")
    end
    for _, reason in ipairs(finding.reasons) do
      io.stderr:write(("    %s\n"):format(reason))
    end
  end

  if #findings == 0 then
    print("dead technology audit: every visible technology grants something or leads somewhere")
  else
    io.stderr:write(
      ("\ndead technology audit: %d visible technologies grant nothing and lead nowhere\n"):format(#findings)
    )
  end
  return #findings
end
