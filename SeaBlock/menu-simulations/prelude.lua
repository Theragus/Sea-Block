-- Shared set-up for Sea Block's main menu simulations.
--
-- The vanilla simulations replay save files made with ore patches under them,
-- and Sea Block deletes every resource prototype, so those scenes load with
-- their drills standing on bare ground. These scenes carry no save at all:
-- each one paints its own tiles and builds its own entities from script, which
-- keeps them in step with whatever Bob's and Angel's currently call things.
--
-- The code runs as a console command inside the simulation, so it cannot
-- require anything; every scene is this prelude concatenated with its own
-- script. It clears the scene area of whatever map generation left there,
-- fixes the time of day at noon, calls a cease-fire with the worms, and
-- defines:
--   surface        the simulation surface
--   paint(fn)      sets every tile in the scene area to fn(x, y)
--   place(name, x, y, extra)
--                  create_entity on the player force, extra merged into the
--                  definition
--   sign(n)        -1, 0 or 1
--   place_logo()   puts the Factorio logo at {0, -10} and the camera on it the
--                  way the vanilla scenes do, 9.75 tiles below it
--   place_fish(count, seed)
--                  scatters fish over whatever water is near the camera
--
-- tools/loadtest/menusim plays these scenes in the headless game and fails the
-- load test on a script error, on anything placed where it cannot go, and on a
-- machine that does no work while the scene is on screen.
return [[
local surface = game.surfaces.nauvis
local area = { { -96, -64 }, { 96, 64 } }

-- Radius 3 is the 7x7 chunks that cover the area; no more is ever seen.
surface.request_to_generate_chunks({ 0, 0 }, 3)
surface.force_generate_chunk_requests()
for _, entity in pairs(surface.find_entities(area)) do
  if entity.valid then
    entity.destroy()
  end
end
surface.destroy_decoratives({ area = area })
surface.daytime = 0
surface.freeze_daytime = true
-- Worms generated outside the cleared area, and any a scene places, pose
-- rather than spit.
game.forces.enemy.set_cease_fire("player", true)
game.forces.player.set_cease_fire("enemy", true)

local function paint(tile_at)
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do
      tiles[#tiles + 1] = { name = tile_at(x, y), position = { x, y } }
    end
  end
  surface.set_tiles(tiles, true, true, true)
end

local function place(name, x, y, extra)
  local definition = { name = name, position = { x, y }, force = "player" }
  for k, v in pairs(extra or {}) do
    definition[k] = v
  end
  return surface.create_entity(definition)
end

local function sign(n)
  return n > 0 and 1 or (n < 0 and -1 or 0)
end

local function place_logo()
  local logo = place("factorio-logo-11tiles", 0, -10, { force = "neutral" })
  logo.destructible = false
  game.simulation.camera_position = { logo.position.x, logo.position.y + 9.75 }
  game.simulation.camera_zoom = 1
  game.tick_paused = false
end

local function place_fish(count, seed)
  local rng = game.create_random_generator(seed)
  for _ = 1, count do
    local x, y = rng(-45, 45), rng(-22, 22)
    local tile = surface.get_tile(x, y).name
    if tile == "deepwater" or tile == "water" then
      surface.create_entity({ name = "fish", position = { x + 0.5, y + 0.5 } })
    end
  end
end
]]
