seablock = seablock or {}

---Work out what the starting rock chest holds.
---@param items table the item prototypes available, keyed by name
function seablock.populate_starting_items(items)
  local starting_items = {
    ["stone"] = 130,
    ["small-electric-pole"] = 50,
    ["small-lamp"] = 12,
    ["iron-plate"] = 1200,
    ["bob-basic-circuit-board"] = 200,
    ["stone-brick"] = 500,
    -- Bob's used to supply stone pipes for the early run and removed them in
    -- 3.0 along with the ceramic and nitinol ones, so their 100 and 50 are
    -- folded into the plain pipes here rather than leaving the player short.
    ["pipe"] = 121,
    ["bob-copper-pipe"] = 5,
    ["iron-gear-wheel"] = 10,
    ["iron-stick"] = 88,
    ["pipe-to-ground"] = 52,
  }

  -- Starting power production
  if items["wind-turbine-2"] then
    starting_items["wind-turbine-2"] = 120
  else
    starting_items["solar-panel"] = 38
    starting_items["accumulator"] = 32
  end

  -- Starting landfill
  local landfill
  local setting = settings.startup["sb-default-landfill"]
  if setting and items[setting.value] then
    landfill = setting.value
  else
    landfill = "landfill"
  end
  starting_items[landfill] = 2000

  -- Inserting an item that no longer exists is a non-recoverable error during
  -- chunk generation, which takes the save with it. Bob's and Angel's drop
  -- items often enough that the list has to tolerate it: leave the player
  -- short of one thing rather than unable to start at all.
  for name in pairs(starting_items) do
    if not items[name] then
      log("Sea Block: starting item " .. name .. " does not exist and has been skipped")
      starting_items[name] = nil
    end
  end

  return starting_items
end
