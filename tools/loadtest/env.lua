-- Emulation of the globals Factorio's C++ side injects into the data stage.
-- Everything else (dataloader, util, math2d, ...) comes from the real
-- core/lualib shipped in wube/factorio-data, so only the engine boundary is
-- faked here.

local env = {}

---------------------------------------------------------------------------
-- serpent (Factorio embeds it; only used for error formatting here)
---------------------------------------------------------------------------
local function serialize(value, indent, level, maxlevel, seen)
  level = level or 0
  maxlevel = maxlevel or 4
  seen = seen or {}
  local t = type(value)
  if t == "string" then
    return string.format("%q", value)
  elseif t ~= "table" then
    return tostring(value)
  elseif seen[value] then
    return "<cycle>"
  elseif level >= maxlevel then
    return "{...}"
  end
  seen[value] = true
  local pad = indent and string.rep("  ", level + 1) or ""
  local close = indent and string.rep("  ", level) or ""
  local sep = indent and "\n" or " "
  local parts = {}
  for k, v in pairs(value) do
    local key
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      key = k .. " = "
    else
      key = "[" .. serialize(k, nil, level + 1, maxlevel, seen) .. "] = "
    end
    parts[#parts + 1] = pad .. key .. serialize(v, indent, level + 1, maxlevel, seen)
  end
  seen[value] = nil
  if #parts == 0 then
    return "{}"
  end
  return "{" .. sep .. table.concat(parts, "," .. sep) .. sep .. close .. "}"
end

env.serpent = {
  block = function(v, opts)
    return serialize(v, true, 0, opts and opts.maxlevel or 4)
  end,
  line = function(v, opts)
    return serialize(v, false, 0, opts and opts.maxlevel or 4)
  end,
  dump = function(v)
    return serialize(v, false, 0, 16)
  end,
}

---------------------------------------------------------------------------
-- defines
--
-- The data stage only ever reads a handful of these as prototype values
-- (directions, inventories, ...). Those are given their real numeric values.
-- Anything else auto-vivifies so that control-stage-only lookups parsed at
-- file scope do not explode; reading such a leaf yields 0.
---------------------------------------------------------------------------
local real_defines = {
  direction = {
    north = 0,
    northnortheast = 1,
    northeast = 2,
    eastnortheast = 3,
    east = 4,
    eastsoutheast = 5,
    southeast = 6,
    southsoutheast = 7,
    south = 8,
    southsouthwest = 9,
    southwest = 10,
    westsouthwest = 11,
    west = 12,
    westnorthwest = 13,
    northwest = 14,
    northnorthwest = 15,
  },
  inventory = {
    fuel = 1,
    burnt_result = 2,
    chest = 1,
    furnace_source = 2,
    furnace_result = 3,
    furnace_modules = 4,
    character_main = 1,
    character_guns = 2,
    character_ammo = 3,
    character_armor = 4,
    character_vehicle = 5,
    character_trash = 6,
    assembling_machine_input = 2,
    assembling_machine_output = 3,
    assembling_machine_modules = 4,
    lab_input = 1,
    lab_modules = 2,
    rocket_silo_rocket = 6,
    rocket_silo_result = 7,
    rocket_silo_input = 8,
    rocket_silo_output = 9,
    rocket_silo_modules = 10,
  },
  controllers = { ghost = 0, character = 1, god = 2, editor = 3, cutscene = 4, spectator = 5, remote = 6 },
  chain_signal_state = { none = 0, all_open = 1, partially_open = 2, none_open = 3 },
  rail_direction = { front = 0, back = 1 },
  riding = {
    acceleration = { nothing = 0, accelerating = 1, braking = 2, reversing = 3 },
    direction = { left = 0, straight = 1, right = 2 },
  },
  wire_type = { red = 2, green = 3, copper = 1 },
  wire_connector_id = { circuit_red = 1, circuit_green = 2, pole_copper = 3 },
  circuit_connector_id = { accumulator = 1, constant_combinator = 1, container = 1, programmable_speaker = 1 },
  transport_line = { left_line = 1, right_line = 2 },
  logistic_mode = { none = 0, active_provider = 1, storage = 2, requester = 3, passive_provider = 4, buffer = 5 },
  relative_gui_type = {},
  relative_gui_position = { top = 0, bottom = 1, left = 2, right = 3 },
  -- Read by util.combine_icons, which Bob's and Angel's lean on heavily.
  constant = { default_icon_size = 64 },
}

-- defines.prototypes groups every prototype type under its base type. The base
-- game's recycler mod walks defines.prototypes.item to generate a recycling
-- recipe per item, so an empty table here means no recycling recipes at all --
-- and then Bob's, which expects them, indexes a nil.
local function name_set(names)
  local set = {}
  for index, name in ipairs(names) do
    set[name] = index
  end
  return set
end

real_defines.prototypes = {
  item = name_set({
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
    "item-with-label",
    "item-with-inventory",
    "item-with-tags",
    "blueprint",
    "blueprint-book",
    "deconstruction-item",
    "upgrade-item",
    "selection-tool",
    "copy-paste-tool",
    "spidertron-remote",
    "mining-tool",
    "space-platform-starter-pack",
  }),
  equipment = name_set({
    "active-defense-equipment",
    "battery-equipment",
    "belt-immunity-equipment",
    "energy-shield-equipment",
    "generator-equipment",
    "movement-bonus-equipment",
    "night-vision-equipment",
    "roboport-equipment",
    "solar-panel-equipment",
    "equipment-ghost",
    "inventory-bonus-equipment",
  }),
  entity = name_set({
    "accumulator",
    "agricultural-tower",
    "ammo-turret",
    "arithmetic-combinator",
    "artillery-turret",
    "artillery-wagon",
    "assembling-machine",
    "asteroid-collector",
    "beacon",
    "boiler",
    "burner-generator",
    "car",
    "cargo-landing-pad",
    "cargo-wagon",
    "character",
    "cliff",
    "constant-combinator",
    "container",
    "corpse",
    "curved-rail-a",
    "curved-rail-b",
    "decider-combinator",
    "display-panel",
    "electric-energy-interface",
    "electric-pole",
    "electric-turret",
    "fish",
    "fluid-turret",
    "fluid-wagon",
    "furnace",
    "fusion-generator",
    "fusion-reactor",
    "gate",
    "generator",
    "half-diagonal-rail",
    "heat-interface",
    "heat-pipe",
    "infinity-container",
    "infinity-pipe",
    "inserter",
    "lab",
    "lamp",
    "land-mine",
    "lightning-attractor",
    "linked-belt",
    "linked-container",
    "loader",
    "loader-1x1",
    "locomotive",
    "logistic-container",
    "market",
    "mining-drill",
    "offshore-pump",
    "pipe",
    "pipe-to-ground",
    "plant",
    "power-switch",
    "programmable-speaker",
    "pump",
    "radar",
    "rail-chain-signal",
    "rail-ramp",
    "rail-signal",
    "rail-support",
    "reactor",
    "roboport",
    "rocket-silo",
    "selector-combinator",
    "simple-entity",
    "simple-entity-with-force",
    "simple-entity-with-owner",
    "solar-panel",
    "space-platform-hub",
    "spider-vehicle",
    "splitter",
    "storage-tank",
    "straight-rail",
    "thruster",
    "train-stop",
    "transport-belt",
    "tree",
    "turret",
    "underground-belt",
    "unit",
    "unit-spawner",
    "valve",
    "wall",
  }),
}

-- Leaf placeholder: usable as a number, a string key and a table lookup.
local placeholder_mt = {
  __index = function(t, k)
    local v = setmetatable({}, getmetatable(t))
    rawset(t, k, v)
    return v
  end,
  __tostring = function()
    return "0"
  end,
  __eq = function()
    return false
  end,
  __concat = function(a, b)
    return tostring(a) .. tostring(b)
  end,
}

local function autovivify(tbl)
  return setmetatable(tbl, placeholder_mt)
end

env.defines = autovivify(real_defines)
for _, k in ipairs({ "events", "command", "compound_command", "distraction", "behavior_result", "control_behavior" }) do
  real_defines[k] = autovivify({})
end

---------------------------------------------------------------------------
-- misc engine globals
---------------------------------------------------------------------------
function env.table_size(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

env.feature_flags = {
  quality = false,
  rail_bridges = false,
  space_travel = false,
  freezing = false,
  segmented_units = false,
  expansion_shaders = false,
}

---------------------------------------------------------------------------
-- table.insert
--
-- Lua 5.1 accepted any position for table.insert; 5.2 added the "position out
-- of bounds" check. Factorio's Lua does not enforce it, and mods rely on that:
-- Bob's inserts its science pack at index 5 of a lab input list that another
-- mod may have shortened to one entry. Clamp instead of erroring, so the
-- harness follows the same path the game does.
---------------------------------------------------------------------------
local raw_insert = table.insert
function env.install_permissive_table_insert()
  table.insert = function(list, a, b)
    if b == nil then
      return raw_insert(list, a)
    end
    local position = a
    if type(position) ~= "number" then
      return raw_insert(list, position, b)
    end
    local limit = #list + 1
    if position < 1 then
      position = 1
    elseif position > limit then
      position = limit
    end
    return raw_insert(list, position, b)
  end
end

---------------------------------------------------------------------------
-- deterministic pairs
--
-- Lua randomises its string hash seed per process, so pairs() order changes
-- between runs and any mod whose behaviour depends on it becomes a coin flip.
-- Factorio pins its seed for multiplayer determinism and so always takes the
-- same branch. Sorting keys gives the harness a stable order too -- not the
-- game's order, but a reproducible one, which is what CI needs.
---------------------------------------------------------------------------
local raw_pairs = pairs
function env.install_deterministic_pairs()
  pairs = function(t)
    local keys, strings_only = {}, true
    for k in raw_pairs(t) do
      keys[#keys + 1] = k
      if type(k) ~= "string" then
        strings_only = false
      end
    end
    if not strings_only then
      return raw_pairs(t)
    end
    table.sort(keys)
    local i = 0
    return function()
      i = i + 1
      local k = keys[i]
      if k ~= nil then
        return k, t[k]
      end
    end
  end
end

return env
