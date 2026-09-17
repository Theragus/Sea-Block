-- Audit script: structural validation of recipe ingredients and results.
--
-- Factorio 2.0 dropped the {"name", count} shorthand for both ingredients and
-- results; every entry must be a table carrying type/name/amount. A shorthand
-- entry survives data:extend and only explodes later, inside whichever mod
-- next iterates that recipe -- usually Angel's override functions, far from
-- the mod that actually wrote it.
return function(data)
  local findings = 0

  local function report(fmt, ...)
    io.stderr:write("recipe audit: " .. string.format(fmt, ...) .. "\n")
    findings = findings + 1
  end

  local function check_list(recipe_name, field, list)
    if list == nil then
      return
    end
    if type(list) ~= "table" then
      report("recipe %q has a non-table %s", recipe_name, field)
      return
    end
    for index, entry in pairs(list) do
      if type(entry) ~= "table" then
        report("recipe %q %s[%s] is %s, expected a table", recipe_name, field, tostring(index), type(entry))
      elseif entry.name == nil then
        -- The 2.0-removed shorthand looks exactly like this: entry[1] is the
        -- name and entry[2] the count, with no named fields at all.
        local shorthand = type(entry[1]) == "string" and (" (shorthand for %q)"):format(entry[1]) or ""
        report("recipe %q %s[%s] has no name field%s", recipe_name, field, tostring(index), shorthand)
      elseif entry.type ~= nil and entry.type ~= "item" and entry.type ~= "fluid" then
        report("recipe %q %s[%s] has type %q", recipe_name, field, tostring(index), tostring(entry.type))
      end
    end
  end

  for name, recipe in pairs(data.raw.recipe or {}) do
    check_list(name, "ingredients", recipe.ingredients)
    check_list(name, "results", recipe.results)
    if recipe.normal or recipe.expensive then
      report("recipe %q still uses the 2.0-removed normal/expensive difficulty split", name)
    end
  end

  -- Technology unit ingredients keep the {"name", count} shorthand in 2.x, so
  -- they are checked for existence rather than shape.
  for name, tech in pairs(data.raw.technology or {}) do
    local unit = tech.unit
    if unit and type(unit.ingredients) == "table" then
      for index, entry in pairs(unit.ingredients) do
        local pack = type(entry) == "table" and (entry[1] or entry.name) or nil
        if pack == nil then
          report("technology %q unit.ingredients[%s] is malformed", name, tostring(index))
        elseif not (data.raw.item[pack] or data.raw.tool and data.raw.tool[pack]) then
          report("technology %q needs science pack %q, which is not an item", name, tostring(pack))
        end
      end
    end
  end

  if findings == 0 then
    print("recipe audit: no structural problems")
  end
  return findings
end
