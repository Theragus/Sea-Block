-- Audit script: every ingredient of a recipe the player can use has a source.
--
-- The reachability audit checks that a visible recipe can be unlocked. It does
-- not check that the recipe can then be crafted. When Sea Block hides an item or
-- fluid (gunmetal, nickel plate, sour gas, alien artifacts), Bob's and Angel's
-- recipes that ask for it stay visible and keep their unlocks, and nothing
-- errors: the recipe shows up in the tree, the player researches it, and the
-- crafting window says an ingredient is missing that no recipe makes.
--
-- A recipe is checked when it is visible and either enabled from the start or
-- unlocked by a researchable technology. Each ingredient must then come from
-- somewhere other than that recipe itself:
--
--   - another recipe that is usable in the same sense, and visible or crafted
--     by a furnace (furnaces pick hidden recipes by their ingredients), but
--     not recycling, which only returns what was put in,
--   - mining an entity the map generates (trees, Angel's gardens, fish) or a
--     resource that survived Sea Block's removal (the sea pump resource), and
--     the loot those entities drop,
--   - an offshore pump's filter (Angel's seafloor pump makes viscous mud
--     water) or the fluid of a tile the map generates,
--   - a boiler's output,
--   - the burnt, spoil or rocket launch result of an item,
--   - a give-item effect of a researchable technology,
--   - the starting chest.
--
-- One level deep on purpose: a producer whose own ingredients are missing is
-- found when that producer is checked.

return function(data, mods, settings, resolve_path)
  local raw = data.raw

  local sources = {}
  local function add(name, why)
    if name and not sources[name] then
      sources[name] = why
    end
  end

  local function add_product(product, why)
    if type(product) ~= "table" then
      return
    end
    local amount = product.amount or product.amount_max or 1
    if amount > 0 and (product.probability or 1) > 0 then
      add(product.name or product[1], why)
    end
  end

  local function add_minable(minable, why)
    if not minable then
      return
    end
    add(minable.result, why)
    for _, result in pairs(minable.results or {}) do
      add_product(result, why)
    end
  end

  -- Recipes the player can get at.
  local unlocked = {}
  for _, technology in pairs(raw.technology or {}) do
    if technology.hidden ~= true and technology.enabled ~= false then
      for _, effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe then
          unlocked[effect.recipe] = true
        elseif effect.type == "give-item" and effect.item then
          add(effect.item, "technology")
        end
      end
    end
  end

  local function usable(name, recipe)
    return recipe.enabled ~= false or unlocked[name] == true
  end

  local furnace_categories = {}
  for _, furnace in pairs(raw.furnace or {}) do
    for _, category in pairs(furnace.crafting_categories or {}) do
      furnace_categories[category] = true
    end
  end

  local function categories(recipe)
    return recipe.categories or { recipe.category or "crafting" }
  end

  local function has_category(recipe, wanted)
    for _, category in pairs(categories(recipe)) do
      if wanted[category] then
        return true
      end
    end
    return false
  end

  -- Recycling hands back a quarter of what went into the item, so it is never
  -- the first source of anything: the gunmetal in a sniper rifle's recycling
  -- results had to be in the rifle already.
  local recycling = { recycling = true }

  -- producers[item] = { recipe = true, ... }
  local producers = {}
  for name, recipe in pairs(raw.recipe or {}) do
    if
      usable(name, recipe)
      and (recipe.hidden ~= true or has_category(recipe, furnace_categories))
      and not has_category(recipe, recycling)
    then
      for _, result in pairs(recipe.results or {}) do
        local amount = result.amount or result.amount_max or 1
        if result.name and amount > 0 and (result.probability or 1) > 0 then
          producers[result.name] = producers[result.name] or {}
          producers[result.name][name] = true
        end
      end
    end
  end

  -- Entities and tiles the map generates. A planet that lists autoplace
  -- settings places only those; Sea Block restricts Nauvis this way.
  local placed_entities, placed_tiles, restricted = {}, {}, false
  for _, planet in pairs(raw.planet or {}) do
    local autoplace = (planet.map_gen_settings or {}).autoplace_settings
    if autoplace then
      restricted = true
      for name in pairs((autoplace.entity or {}).settings or {}) do
        placed_entities[name] = true
      end
      for name in pairs((autoplace.tile or {}).settings or {}) do
        placed_tiles[name] = true
      end
    end
  end

  -- Item types are not entities; everything else in data.raw with a minable or
  -- loot field is.
  local item_types = {
    item = true,
    ammo = true,
    capsule = true,
    gun = true,
    module = true,
    tool = true,
    armor = true,
    ["repair-tool"] = true,
    ["rail-planner"] = true,
    ["item-with-entity-data"] = true,
    ["spidertron-remote"] = true,
    ["selection-tool"] = true,
  }

  for type_name, prototypes in pairs(raw) do
    if item_types[type_name] then
      for _, item in pairs(prototypes) do
        add(item.burnt_result, "burnt result")
        add(item.spoil_result, "spoil result")
        for _, product in pairs(item.rocket_launch_products or {}) do
          add_product(product, "rocket launch")
        end
      end
    elseif type_name == "resource" then
      -- Sea Block deletes every resource it does not need, so what is left is
      -- mined on purpose (the sea pump resource).
      for _, resource in pairs(prototypes) do
        add_minable(resource.minable, "resource")
      end
    elseif type_name == "tile" then
      for name, tile in pairs(prototypes) do
        if tile.fluid and (placed_tiles[name] or (not restricted and tile.autoplace)) then
          add(tile.fluid, "tile")
        end
      end
    elseif type_name ~= "recipe" and type_name ~= "technology" then
      for name, entity in pairs(prototypes) do
        if type(entity) == "table" and (placed_entities[name] or (not restricted and entity.autoplace)) then
          add_minable(entity.minable, "map")
          for _, loot in pairs(entity.loot or {}) do
            add(loot.item, "loot")
          end
        end
      end
    end
  end

  for _, pump in pairs(raw["offshore-pump"] or {}) do
    add((pump.fluid_box or {}).filter, "offshore pump")
  end
  for _, boiler in pairs(raw.boiler or {}) do
    add((boiler.output_fluid_box or {}).filter, "boiler")
  end

  -- The starting chest, read the same way the starting items audit does.
  local path = resolve_path and resolve_path("__SeaBlock21__/starting-items.lua")
  local chunk = path and loadfile(path)
  if chunk then
    chunk()
    local items = {}
    for type_name in pairs(item_types) do
      for name, prototype in pairs(raw[type_name] or {}) do
        items[name] = prototype
      end
    end
    local ok, starting_items = pcall(seablock.populate_starting_items, items)
    if ok then
      for name in pairs(starting_items) do
        add(name, "starting chest")
      end
    end
  end

  local findings, checked = 0, 0
  for name, recipe in pairs(raw.recipe or {}) do
    if recipe.hidden ~= true and usable(name, recipe) then
      checked = checked + 1
      for _, ingredient in pairs(recipe.ingredients or {}) do
        local wanted = ingredient.name
        local made = false
        for producer in pairs(producers[wanted] or {}) do
          if producer ~= name then
            made = true
            break
          end
        end
        if wanted and not made and not sources[wanted] then
          io.stderr:write(
            ("  recipe %q needs %s %q, which no usable recipe or other source produces\n"):format(
              name,
              ingredient.type or "item",
              wanted
            )
          )
          findings = findings + 1
        end
      end
    end
  end

  if findings == 0 then
    print(("ingredient source audit: every ingredient of %d usable recipes has a source"):format(checked))
  else
    io.stderr:write(
      ("\ningredient source audit: %d ingredient(s) with no source, in %d usable recipes\n"):format(findings, checked)
    )
  end
  return findings
end
