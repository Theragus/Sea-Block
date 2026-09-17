-- Repair 2.0 trigger technologies whose trigger Sea Block made impossible.
--
-- Factorio 2.0 lets a technology be unlocked by an action ("mine crude oil",
-- "craft an electronic circuit") instead of by science packs. Sea Block deletes
-- every ore patch and hides a lot of early recipes, so a number of those
-- triggers point at prototypes that no longer exist, or that the player can
-- never obtain. Factorio refuses to load a trigger naming a missing prototype,
-- and a trigger naming an unobtainable one silently walls off the tech tree.
--
-- Rather than patch each technology by hand as Bob's, Angel's and the base game
-- move things around, find the broken triggers and give those technologies an
-- ordinary science pack cost derived from their prerequisites.

local function prototype_exists(categories, name)
  for _, category in pairs(categories) do
    if data.raw[category] and data.raw[category][name] then
      return true
    end
  end
  return false
end

-- Every prototype type that can satisfy a "craft-item" trigger.
local item_types = {
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
}

-- data.raw has no "is this an entity" marker, and names are reused freely
-- across registries: crude-oil is both a fluid and a resource entity, so a
-- naive scan reports the entity as present after Sea Block has deleted it.
-- Listing the registries that are definitely not entities is the reliable way
-- round that.
local non_entity_categories = {}
for _, category in ipairs({
  "recipe",
  "technology",
  "fluid",
  "item-group",
  "item-subgroup",
  "recipe-category",
  "resource-category",
  "fuel-category",
  "ammo-category",
  "module-category",
  "equipment-category",
  "equipment-grid",
  "damage-type",
  "virtual-signal",
  "noise-expression",
  "noise-function",
  "autoplace-control",
  "map-gen-presets",
  "map-settings",
  "utility-constants",
  "utility-sprites",
  "utility-sounds",
  "shortcut",
  "custom-input",
  "collision-layer",
  "airborne-pollutant",
  "surface-property",
  "space-location",
  "space-connection",
  "planet",
  "quality",
  "tips-and-tricks-item",
  "tips-and-tricks-item-category",
  "trigger-target-type",
  "sprite",
  "animation",
  "sound",
  "ambient-sound",
  "font",
  "burner-usage",
  "impact-category",
  "deliver-category",
  "procession",
}) do
  non_entity_categories[category] = true
end
for _, category in ipairs(item_types) do
  non_entity_categories[category] = true
end

local function entity_exists(name)
  for category, prototypes in pairs(data.raw) do
    if prototypes[name] and not non_entity_categories[category] then
      return true
    end
  end
  return false
end

---Prune the unobtainable targets out of a research trigger.
---@return string|nil missing a description of what was dropped, or nil if the
---trigger is still satisfiable
local function prune_trigger(trigger)
  local name_field, plural, exists
  if trigger.type == "mine-entity" or trigger.type == "build-entity" then
    name_field, plural, exists = "entity", "entities", entity_exists
  elseif trigger.type == "craft-item" then
    name_field, plural, exists = "item", "items", function(n)
      return prototype_exists(item_types, n)
    end
  elseif trigger.type == "craft-fluid" then
    name_field, plural, exists = "fluid", "fluids", function(n)
      return prototype_exists({ "fluid" }, n)
    end
  else
    -- capture-spawner, send-item-to-orbit and friends are not Sea Block's to
    -- judge; leave them alone.
    return nil
  end

  -- 2.0 took a single name; 2.1 takes a list. Both shapes are in the wild
  -- because mods target whichever version they were last updated for.
  local list = trigger[plural]
  if type(list) == "table" then
    local kept, dropped = {}, {}
    for _, entry in ipairs(list) do
      local name = type(entry) == "table" and entry.name or entry
      if type(name) == "string" and exists(name) then
        table.insert(kept, entry)
      elseif type(name) == "string" then
        table.insert(dropped, name)
      end
    end
    if #dropped == 0 then
      return nil
    end
    if #kept > 0 then
      trigger[plural] = kept
      return nil
    end
    return table.concat(dropped, ", ")
  end

  local name = trigger[name_field]
  if type(name) == "table" then
    name = name.name
  end
  if type(name) ~= "string" or exists(name) then
    return nil
  end
  return name
end

local repaired, removed = 0, 0
for name, technology in pairs(data.raw.technology) do
  local trigger = technology.research_trigger
  if trigger then
    local missing = prune_trigger(trigger)
    if missing then
      local unit = seablock.lib.inherited_tech_unit(technology)
      if unit then
        technology.research_trigger = nil
        technology.unit = unit
        repaired = repaired + 1
        log(
          ("Sea Block: technology %s was triggered by the missing %q; replaced with a science pack cost"):format(
            name,
            missing
          )
        )
      else
        -- Nothing to inherit from, which means it is a root technology. Leave
        -- it researchable from the start rather than unreachable.
        technology.research_trigger = nil
        technology.unit = { count = 1, ingredients = {}, time = 1 }
        removed = removed + 1
        log(("Sea Block: root technology %s was triggered by the missing %q; made free"):format(name, missing))
      end
    end
  end
end

if repaired > 0 or removed > 0 then
  log(("Sea Block: repaired %d trigger technologies (%d had no prerequisites)"):format(repaired + removed, removed))
end
