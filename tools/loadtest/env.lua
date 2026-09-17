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

return env
