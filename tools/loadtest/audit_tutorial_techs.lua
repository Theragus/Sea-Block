-- Sea Block's tutorial technologies must complete by research trigger, and the
-- player must be able to meet each trigger.
--
-- They come before any lab exists, so a science pack cost is a lie: it used to
-- be a hidden stand-in item that Factorio 2.1 made lab-coverage rewrite to one
-- automation science pack, and the tech tree then showed "Crush stiratite: 1
-- red science" to players who could not make red science yet. That read as a
-- soft-lock (issue #12). A research trigger shows what to do instead.
--
-- A trigger is only as good as the recipe behind it. If nothing that makes the
-- item is enabled from the start or unlocked on the way to the technology, the
-- tutorial stops there with nothing to research towards, so that is checked
-- too.
--
-- The tutorial set is seablock.scripted_techs, read from the data stage: that
-- table is what the rest of Sea Block means by a tutorial technology.

local function item_name(filter)
  if type(filter) == "table" then
    return filter.name
  end
  return filter
end

local function makes(recipe, item)
  for _, result in pairs(recipe.results or {}) do
    if result.type ~= "fluid" and result.name == item then
      return true
    end
  end
  return false
end

return function(data)
  local scripted = seablock and seablock.scripted_techs
  if type(scripted) ~= "table" then
    io.stderr:write("  seablock.scripted_techs is missing, so the tutorial technologies cannot be found\n")
    return 1
  end
  local technologies = data.raw.technology

  -- Every technology reachable back through prerequisites, including itself.
  local function lineage(name)
    local seen, stack = {}, { name }
    while #stack > 0 do
      local current = table.remove(stack)
      if not seen[current] and technologies[current] then
        seen[current] = true
        for _, prerequisite in pairs(technologies[current].prerequisites or {}) do
          table.insert(stack, prerequisite)
        end
      end
    end
    return seen
  end

  local findings, checked, skipped = 0, 0, 0
  local function report(fmt, ...)
    io.stderr:write("  " .. fmt:format(...) .. "\n")
    findings = findings + 1
  end

  -- ScienceCostTweakerM folds sct-automation-science-pack into the base game's
  -- automation-science-pack and deletes the sct- name, which Sea Block's table
  -- still uses; follow it the way data-final-fixes/ScienceCostTweakerM.lua does.
  local names = {}
  for name in pairs(scripted) do
    local base_name = name:match("^sct%-(.+)$")
    if not technologies[name] and base_name and technologies[base_name] then
      name = base_name
    end
    table.insert(names, name)
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local technology = technologies[name]
    if not technology or technology.hidden == true or technology.enabled == false then
      skipped = skipped + 1
    else
      checked = checked + 1
      local trigger = technology.research_trigger
      if technology.unit then
        report("tutorial technology %q has a science pack cost; it should complete by research trigger", name)
      end
      if not trigger then
        report("tutorial technology %q has no research trigger", name)
      elseif trigger.type == "craft-item" then
        local item = item_name(trigger.item)
        -- The technology itself is excluded: the unlock that pays out on
        -- completion cannot be what completes it.
        local unlocked = {}
        for ancestor in pairs(lineage(name)) do
          if ancestor ~= name then
            for _, effect in pairs(technologies[ancestor].effects or {}) do
              if effect.type == "unlock-recipe" then
                unlocked[effect.recipe] = true
              end
            end
          end
        end
        local reachable = false
        for recipe_name, recipe in pairs(data.raw.recipe) do
          if makes(recipe, item) and (recipe.enabled ~= false or unlocked[recipe_name]) then
            reachable = true
            break
          end
        end
        if not reachable then
          report(
            "tutorial technology %q waits for a crafted %s, but no recipe for it is enabled or unlocked on the way there",
            name,
            tostring(item)
          )
        end
      end
    end
  end

  if findings == 0 then
    print(
      ("tutorial tech audit: all %d tutorial technologies complete by a trigger the player can meet (%d hidden or absent)"):format(
        checked,
        skipped
      )
    )
  else
    io.stderr:write(("\ntutorial tech audit: %d finding(s) in %d tutorial technologies\n"):format(findings, checked))
  end
  return findings
end
