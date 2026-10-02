-- A "craft an item" technology must not become available before the item can be made.
--
-- Factorio offers a trigger technology as soon as its prerequisites are done, so
-- the prerequisites are the only thing telling the player when to go for it. If
-- the item's recipe is unlocked somewhere off that chain, the technology sits in
-- the tree asking for something the player cannot make yet. That is what the
-- Cobalt steel axe did: Angel's swapped its Cobalt processing prerequisite for
-- Brass processing, but cobalt steel comes from Cobalt steel smelting 1, which
-- costs blue science.
--
-- An item counts as makeable when some visible recipe for it is enabled from the
-- start, or is unlocked by a technology in the trigger technology's prerequisite
-- chain, or by one whose whole chain is research triggers rather than science
-- packs. The last case is the startup tutorial: copper plates come from
-- sb-startup1, which electronics does not name but the player always completes
-- by playing.

return function(data)
  local technologies = data.raw.technology or {}

  local function researchable(technology)
    return technology and technology.hidden ~= true and technology.enabled ~= false
  end

  local function chain(name, seen)
    seen = seen or {}
    if not seen[name] then
      seen[name] = true
      for _, prerequisite in pairs((technologies[name] or {}).prerequisites or {}) do
        chain(prerequisite, seen)
      end
    end
    return seen
  end

  local function triggers_only(name)
    for tech in pairs(chain(name)) do
      if not technologies[tech] or technologies[tech].unit then
        return false
      end
    end
    return true
  end

  local unlocked_by = {}
  for name, technology in pairs(technologies) do
    if researchable(technology) then
      for _, effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe then
          unlocked_by[effect.recipe] = unlocked_by[effect.recipe] or {}
          table.insert(unlocked_by[effect.recipe], name)
        end
      end
    end
  end

  local function recipes_for(item)
    local found = {}
    for name, recipe in pairs(data.raw.recipe or {}) do
      if recipe.hidden ~= true then
        for _, result in pairs(recipe.results or {}) do
          if result.name == item then
            table.insert(found, name)
            break
          end
        end
      end
    end
    return found
  end

  local findings, checked = {}, 0
  for name, technology in pairs(technologies) do
    local trigger = technology.research_trigger
    if researchable(technology) and trigger and trigger.type == "craft-item" then
      checked = checked + 1
      local item = type(trigger.item) == "table" and trigger.item.name or trigger.item
      local before = chain(name)
      before[name] = nil

      local makeable, elsewhere = false, {}
      for _, recipe in ipairs(recipes_for(item)) do
        if data.raw.recipe[recipe].enabled ~= false then
          makeable = true
        end
        for _, unlocker in ipairs(unlocked_by[recipe] or {}) do
          if before[unlocker] or triggers_only(unlocker) then
            makeable = true
          else
            elsewhere[unlocker] = true
          end
        end
      end

      if not makeable then
        local list = {}
        for unlocker in pairs(elsewhere) do
          table.insert(list, unlocker)
        end
        table.sort(list)
        table.insert(findings, {
          name = name,
          item = item,
          from = #list > 0 and table.concat(list, ", ") or "no researchable technology",
        })
      end
    end
  end

  table.sort(findings, function(a, b)
    return a.name < b.name
  end)

  for _, finding in ipairs(findings) do
    io.stderr:write(
      ("  technology %q asks for crafted %q, which only %s unlocks, and that is not among its prerequisites\n"):format(
        finding.name,
        finding.item,
        finding.from
      )
    )
  end

  if #findings == 0 then
    print(("trigger item audit: all %d craft-item technologies can be completed once available"):format(checked))
  else
    io.stderr:write(
      ("\ntrigger item audit: %d of %d craft-item technologies become available before their item\n"):format(
        #findings,
        checked
      )
    )
  end
  return #findings
end
