-- Audit script: referential integrity across recipes and technologies.
--
-- Factorio rejects most of these at load, but one at a time: it reports the
-- first bad prerequisite and stops, so a pack with thirty stale names takes
-- thirty startup attempts to clean up. This reports all of them at once.

return function(data)
  local findings = 0
  local by_kind = {}

  local function report(kind, fmt, ...)
    io.stderr:write(("  [%s] "):format(kind) .. string.format(fmt, ...) .. "\n")
    by_kind[kind] = (by_kind[kind] or 0) + 1
    findings = findings + 1
  end

  -- Item-like prototype types, as a name -> true set.
  local items, fluids = {}, {}
  for _, category in ipairs({
    "item",
    "ammo",
    "capsule",
    "gun",
    "module",
    "tool",
    "armor",
    "repair-tool",
    "rail-planner",
    "item-with-entity-data",
    "spidertron-remote",
    "selection-tool",
    "blueprint",
    "blueprint-book",
    "deconstruction-item",
    "upgrade-item",
    "copy-paste-tool",
    "space-platform-starter-pack",
  }) do
    for name in pairs(data.raw[category] or {}) do
      items[name] = true
    end
  end
  for name in pairs(data.raw.fluid or {}) do
    fluids[name] = true
  end

  ------------------------------------------------------------------ recipes
  for name, recipe in pairs(data.raw.recipe or {}) do
    local categories = recipe.categories or (recipe.category and { recipe.category })
    for _, category in pairs(categories or { "crafting" }) do
      if not (data.raw["recipe-category"] or {})[category] then
        report("recipe-category", "recipe %q uses missing category %q", name, category)
      end
    end
    for _, field in ipairs({ "ingredients", "results" }) do
      for _, entry in pairs(recipe[field] or {}) do
        if type(entry) == "table" and type(entry.name) == "string" then
          local pool = entry.type == "fluid" and fluids or items
          if not pool[entry.name] then
            report(
              "recipe-" .. field,
              "recipe %q %s references missing %s %q",
              name,
              field,
              entry.type or "item",
              entry.name
            )
          end
        end
      end
    end
  end

  ------------------------------------------------------------- technologies
  for name, tech in pairs(data.raw.technology or {}) do
    for _, prerequisite in pairs(tech.prerequisites or {}) do
      if not data.raw.technology[prerequisite] then
        report("tech-prerequisite", "technology %q requires missing technology %q", name, prerequisite)
      end
    end

    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and not data.raw.recipe[effect.recipe] then
        report("tech-unlock", "technology %q unlocks missing recipe %q", name, tostring(effect.recipe))
      end
      if effect.type == "give-item" and not items[effect.item] then
        report("tech-give-item", "technology %q gives missing item %q", name, tostring(effect.item))
      end
    end

    local unit = tech.unit
    if unit and type(unit.ingredients) == "table" then
      for _, entry in pairs(unit.ingredients) do
        local pack = type(entry) == "table" and (entry[1] or entry.name) or nil
        if type(pack) == "string" and not items[pack] then
          report("tech-science-pack", "technology %q costs missing science pack %q", name, pack)
        end
      end
    end
  end

  ------------------------------------------------------------------ summary
  if findings == 0 then
    print("integrity audit: clean")
  else
    io.stderr:write("\nintegrity audit summary:\n")
    local kinds = {}
    for kind in pairs(by_kind) do
      kinds[#kinds + 1] = kind
    end
    table.sort(kinds)
    for _, kind in ipairs(kinds) do
      io.stderr:write(("  %-20s %d\n"):format(kind, by_kind[kind]))
    end
  end
  return findings
end
