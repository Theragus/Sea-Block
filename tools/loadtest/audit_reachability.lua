-- Audit script: a recipe the player can see must be obtainable.
--
-- Sea Block disables a lot of recipes and hands the unlocks to its own
-- technologies, then hides or retires those technologies as the configuration
-- changes. When an unlock is stranded on a technology that has been hidden,
-- nothing errors: the recipe is simply never granted, and the run walks into a
-- wall some hours later. That is how the automation science pack became
-- uncraftable with ScienceCostTweakerM.
--
-- A recipe that is disabled, not hidden, and unlocked by no technology the
-- player can research is unobtainable by definition. Deliberately removed
-- content is hidden, so it does not show up here.

return function(data)
  local unlocked_by = {}
  for name, technology in pairs(data.raw.technology or {}) do
    -- A hidden or disabled technology cannot be researched, so an unlock
    -- sitting on it grants nothing.
    local researchable = technology.hidden ~= true and technology.enabled ~= false
    if researchable then
      for _, effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe then
          unlocked_by[effect.recipe] = name
        end
      end
    end
  end

  local findings, checked = 0, 0
  for name, recipe in pairs(data.raw.recipe or {}) do
    if recipe.enabled == false and recipe.hidden ~= true then
      checked = checked + 1
      if not unlocked_by[name] then
        io.stderr:write(
          ("  recipe %q is disabled and visible, but no researchable technology unlocks it\n"):format(name)
        )
        findings = findings + 1
      end
    end
  end

  if findings == 0 then
    print(("reachability audit: all %d disabled recipes have a way in"):format(checked))
  else
    io.stderr:write(("\nreachability audit: %d unobtainable recipe(s) of %d checked\n"):format(findings, checked))
  end
  return findings
end
