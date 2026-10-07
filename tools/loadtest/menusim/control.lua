-- Plays each Sea Block main menu simulation in an ordinary game, one after
-- another on a fresh surface each, the way the main menu would run it: the
-- init script first, then init_update_count ticks of warm-up, then the scene's
-- length. At the end of each it reports what the scene built, whether every
-- machine in it is actually running, and a character map of the screen.
--
-- The simulation API the scene sees is stood in for by proxies: game.simulation
-- is a table that stores positions the way the real one returns them,
-- game.surfaces.nauvis is the scene's surface, and the script's event handlers
-- are collected here rather than registered, so they stop when the scene does.
-- Every entity a scene places is checked with can_place_entity before it is
-- created, which catches overlaps, pumps that are not on the shore and worms
-- or trees put in the sea.
--
-- Output lines all start with MENUSIM; ci.sh looks for "MENUSIM DONE" and no
-- "MENUSIM FAIL".

local config = prototypes.mod_data["sb-menusim-test"].data
local area = { { -96, -64 }, { 96, 64 } }

-- Machines that should be busy by the end of a scene.
local must_work = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["boiler"] = true,
  ["generator"] = true,
  ["offshore-pump"] = true,
}

local status_names = {}
for name, value in pairs(defines.entity_status) do
  status_names[value] = name
end

-- How often a machine's status is sampled while its scene is on screen.
local sample_every = 10

local names = {}
for name in pairs(config.scenes) do
  names[#names + 1] = name
end
table.sort(names)

local next_scene = 1
local current
local failures = 0
local finished = false

local function fail(scene, message)
  failures = failures + 1
  print("MENUSIM FAIL " .. scene .. ": " .. message)
end

local function where(position)
  return ("(%g, %g)"):format(position.x, position.y)
end

local function surface_proxy(scene, surface)
  return setmetatable({}, {
    __index = function(_, key)
      if key ~= "create_entity" then
        return surface[key]
      end
      return function(definition)
        local placeable = surface.can_place_entity({
          name = definition.name,
          position = definition.position,
          direction = definition.direction,
          force = definition.force or "neutral",
          build_check_type = defines.build_check_type.manual,
        })
        if not placeable then
          fail(scene, definition.name .. " cannot be placed at " .. serpent.line(definition.position))
        end
        local entity = surface.create_entity(definition)
        if not entity then
          fail(scene, "create_entity returned nothing for " .. definition.name)
        end
        return entity
      end
    end,
    __newindex = function(_, key, value)
      surface[key] = value
    end,
  })
end

-- LuaSimulation takes a position in either form and hands back {x =, y =}.
local function camera_stub()
  local values = { camera_position = { x = 0, y = 0 }, camera_zoom = 1 }
  return setmetatable({}, {
    __index = values,
    __newindex = function(_, key, value)
      if key == "camera_position" then
        value = { x = value.x or value[1], y = value.y or value[2] }
      end
      values[key] = value
    end,
  })
end

local function environment(scene, surface, handlers, camera)
  local proxied_surface = surface_proxy(scene, surface)
  local surfaces = setmetatable({}, {
    __index = function(_, key)
      if key == "nauvis" or key == 1 then
        return proxied_surface
      end
      return game.surfaces[key]
    end,
  })
  local fake_game = setmetatable({}, {
    __index = function(_, key)
      if key == "simulation" then
        return camera
      elseif key == "surfaces" then
        return surfaces
      end
      return game[key]
    end,
    __newindex = function(_, key, value)
      if key ~= "tick_paused" then
        game[key] = value
      end
    end,
  })
  local fake_script = setmetatable({
    on_event = function(event, handler)
      handlers.events[event] = handler
    end,
    on_nth_tick = function(tick, handler)
      if tick == nil then
        handlers.nth = {}
      else
        handlers.nth[tick] = handler
      end
    end,
  }, { __index = script })
  return setmetatable({ game = fake_game, script = fake_script }, { __index = _ENV })
end

local function run(scene, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    fail(scene, "script error: " .. tostring(err))
    return false
  end
  return true
end

local tile_chars = { deepwater = "~", water = "-", landfill = "." }
local entity_chars = {
  ["pipe"] = "+",
  ["angels-washing-plant"] = "W",
  ["angels-algae-farm"] = "A",
  ["angels-clarifier"] = "C",
  ["boiler"] = "B",
  ["steam-engine"] = "E",
  ["offshore-pump"] = "P",
  ["angels-seafloor-pump"] = "S",
  ["substation"] = "#",
  ["big-electric-pole"] = "#",
  ["factorio-logo-11tiles"] = "L",
  ["sb-rock-chest"] = "R",
  ["character"] = "@",
}
local type_chars = { tree = "T", turret = "w", fish = "f" }

-- The screen at 1920x1080 and zoom 1 is 60 by 34 tiles.
local function draw(surface, camera)
  local cx, cy = math.floor(camera.camera_position.x), math.floor(camera.camera_position.y)
  local left, top, width, height = cx - 30, cy - 17, 60, 34
  local grid = {}
  for row = 0, height - 1 do
    grid[row] = {}
    for column = 0, width - 1 do
      local tile = surface.get_tile(left + column, top + row).name
      grid[row][column] = tile_chars[tile] or (tile:find("^sand") and "," or "?")
    end
  end
  local window = { { left, top }, { left + width, top + height } }
  for _, entity in pairs(surface.find_entities(window)) do
    local char = entity_chars[entity.name] or type_chars[entity.type] or entity.name:sub(1, 1):upper()
    local box = entity.bounding_box
    for y = math.floor(box.left_top.y), math.ceil(box.right_bottom.y) - 1 do
      for x = math.floor(box.left_top.x), math.ceil(box.right_bottom.x) - 1 do
        local row, column = y - top, x - left
        if grid[row] and grid[row][column] then
          grid[row][column] = char
        end
      end
    end
  end
  print(("MENUSIM MAP x %d..%d, y %d..%d"):format(left, left + width - 1, top, top + height - 1))
  for row = 0, height - 1 do
    print("MENUSIM MAP |" .. table.concat(grid[row], "", 0, width - 1) .. "|")
  end
end

local machine_types = {}
for machine_type in pairs(must_work) do
  machine_types[#machine_types + 1] = machine_type
end

-- Crafts finished by each machine when the warm-up ends and the scene would
-- come on screen.
local function count_crafts(surface)
  local crafts = {}
  for _, entity in pairs(surface.find_entities_filtered({ area = area, type = { "assembling-machine", "furnace" } })) do
    crafts[entity.unit_number] = entity.products_finished
  end
  return crafts
end

-- How many of the on-screen samples found each machine working.
local function sample(surface, samples)
  for _, entity in pairs(surface.find_entities_filtered({ area = area, type = machine_types })) do
    local tally = samples[entity.unit_number] or { taken = 0, working = 0 }
    tally.taken = tally.taken + 1
    if entity.status == defines.entity_status.working then
      tally.working = tally.working + 1
    end
    samples[entity.unit_number] = tally
  end
end

local function report(scene, surface, camera, shown_crafts, samples)
  local counts, lines = {}, {}
  for _, entity in pairs(surface.find_entities(area)) do
    counts[entity.name] = (counts[entity.name] or 0) + 1
    if must_work[entity.type] then
      local status = entity.status
      local text = entity.name .. " " .. where(entity.position) .. " " .. tostring(status_names[status])
      if entity.type == "assembling-machine" or entity.type == "furnace" then
        local recipe = entity.get_recipe()
        text = text .. " [" .. (recipe and recipe.name or "no recipe") .. ", " .. entity.products_finished .. " done]"
      end
      local tally = samples[entity.unit_number]
      if tally and tally.taken > 0 then
        text = text .. (", working %d%% of the time on screen"):format(math.floor(100 * tally.working / tally.taken))
      end
      -- A machine that goes idle between batches, like a clarifier voiding
      -- faster than it is fed, is fine so long as it worked while on screen.
      local crafted = shown_crafts and shown_crafts[entity.unit_number]
      local busy = status == defines.entity_status.working or (crafted and entity.products_finished > crafted)
      if not busy then
        fail(scene, text)
        -- Where the fluids are is nearly always the question when a machine
        -- here is idle. Each line carries the prefix so ci.sh prints it.
        for i = 1, entity.fluids_count do
          local fluid = entity.get_fluid(i)
          local filter = entity.get_fluid_filter(i)
          local targets = {}
          for _, connection in pairs(entity.get_fluid_box_pipe_connections(i) or {}) do
            targets[#targets + 1] = connection.flow_direction
              .. "@"
              .. where(connection.target_position)
              .. (connection.target and "->connected" or "")
          end
          print(
            ("MENUSIM FAIL %s:   box %d filter=%s %s %s"):format(
              scene,
              i,
              tostring(filter and filter.name),
              fluid and (fluid.name .. "=" .. math.floor(fluid.amount)) or "empty",
              table.concat(targets, " ")
            )
          )
        end
      end
      lines[#lines + 1] = text
    elseif entity.type == "character" then
      lines[#lines + 1] = "character ends at " .. where(entity.position)
      -- A scripted walk that never reaches its last waypoint keeps walking,
      -- typically into water the scene forgot to landfill.
      if entity.walking_state.walking then
        fail(scene, "the character is still walking at the end, at " .. where(entity.position))
      end
      local tile = surface.get_tile(entity.position.x, entity.position.y)
      if tile.collides_with("water_tile") then
        fail(scene, "the character ends on " .. tile.name .. " at " .. where(entity.position))
      end
    end
  end
  table.sort(lines)
  local built = {}
  for name, count in pairs(counts) do
    built[#built + 1] = name .. " x" .. count
  end
  table.sort(built)
  print("MENUSIM " .. scene .. " built: " .. table.concat(built, ", "))
  for _, line in ipairs(lines) do
    print("MENUSIM " .. scene .. "   " .. line)
  end
  draw(surface, camera)
end

local function start(scene, tick)
  local definition = config.scenes[scene]
  local surface = game.create_surface("menusim-" .. scene)
  local handlers = { events = {}, nth = {} }
  local camera = camera_stub()
  local env = environment(scene, surface, handlers, camera)

  print("MENUSIM start " .. scene)
  local init, err = load(definition.init, "=" .. scene, "t", env)
  if not init then
    fail(scene, "does not compile: " .. err)
    return nil
  end
  local update
  if definition.update and definition.update ~= "" then
    update, err = load(definition.update, "=" .. scene .. "-update", "t", env)
    if not update then
      fail(scene, "update does not compile: " .. err)
      return nil
    end
  end
  if not run(scene, init) then
    return nil
  end
  return {
    name = scene,
    surface = surface,
    handlers = handlers,
    camera = camera,
    update = update,
    samples = {},
    started = tick,
    shown = tick + definition.init_update_count,
    stop = tick + definition.init_update_count + definition.length,
  }
end

local function step(scene, tick)
  local ok = true
  local on_tick = scene.handlers.events[defines.events.on_tick]
  if on_tick then
    ok = run(scene.name, on_tick, { tick = tick, name = defines.events.on_tick })
  end
  for nth, handler in pairs(scene.handlers.nth) do
    -- The engine fires on_nth_tick on game.tick, not on time since init.
    if ok and tick % nth == 0 then
      ok = run(scene.name, handler, { tick = tick, nth_tick = nth })
    end
  end
  if ok and scene.update then
    ok = run(scene.name, scene.update)
  end
  return ok
end

script.on_event(defines.events.on_tick, function(event)
  if finished then
    return
  end
  if current then
    -- A scene with no warm-up is on screen from its first tick, which is
    -- already past by the time this runs, so take the baseline then.
    if not current.shown_crafts and event.tick >= current.shown then
      current.shown_crafts = count_crafts(current.surface)
    end
    if event.tick >= current.shown and (event.tick - current.shown) % sample_every == 0 then
      sample(current.surface, current.samples)
    end
    if not step(current, event.tick) or event.tick >= current.stop then
      report(current.name, current.surface, current.camera, current.shown_crafts, current.samples)
      current = nil
    end
    return
  end
  if next_scene == 1 then
    local needed = 0
    for _, name in ipairs(names) do
      needed = needed + config.scenes[name].init_update_count + config.scenes[name].length + 2
    end
    print(("MENUSIM needs about %d ticks for %d scenes"):format(needed, #names))
  end
  if names[next_scene] then
    current = start(names[next_scene], event.tick)
    next_scene = next_scene + 1
    return
  end

  -- What is left of the rotation, with the save each scene replays, so a
  -- reviewer can see which save-based scenes Sea Block still shows.
  local others = {}
  for _, other in ipairs(config.others) do
    others[other.name] = true
    print("MENUSIM other simulation " .. other.name .. (other.save and (" (" .. other.save .. ")") or ""))
  end
  if #config.removed == 0 then
    fail("vanilla", "Sea Block reported no removed simulations")
  end
  for _, name in ipairs(config.removed) do
    if others[name] then
      fail("vanilla", name .. " is still in the rotation")
    end
  end
  if #names == 0 then
    fail("all", "no seablock_ simulations are defined")
  end
  print(("MENUSIM DONE %d scenes, %d failures"):format(#names, failures))
  finished = true
end)
