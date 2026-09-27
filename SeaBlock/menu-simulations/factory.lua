-- A few hours in: a landfill shelf on the coast, steam power burning wood
-- pellets, algae farms, and the mud washing line that is Sea Block's ore
-- supply. Everything here is connected for real and runs on its own; the
-- simulation's warm-up gives the fluids time to fill the pipes first.
return [[
local shore = 6

-- The original sand island, landfilled around long ago.
local function island(x, y)
  local dx, dy = x + 0.5 + 16, y + 0.5 + 13
  local angle = math.atan2(dy, dx)
  local r = 4.5 + 0.8 * math.sin(3 * angle) + 0.4 * math.cos(5 * angle)
  return dx * dx + dy * dy <= r * r
end

paint(function(x, y)
  if y < shore then
    return island(x, y) and "sand-1" or "landfill"
  end
  local deep = shore + 3 + math.floor(1.5 * math.sin(x * 0.35) + 0.5)
  return y < deep and "water" or "deepwater"
end)

place_logo()

for _, tree in pairs({ { "tree-02", -18, -14 }, { "tree-03", -15, -12 }, { "tree-05", -17, -10.5 } }) do
  surface.create_entity({ name = tree[1], position = { tree[2], tree[3] } })
end

local function pipes(x1, y1, x2, y2)
  local sx, sy = sign(x2 - x1), sign(y2 - y1)
  local x, y = x1, y1
  while true do
    place("pipe", x, y)
    if x == x2 and y == y2 then
      break
    end
    x, y = x + sx, y + sy
  end
end

local function machine(name, x, y, recipe, extra)
  local entity = place(name, x, y, extra)
  game.forces.player.recipes[recipe].enabled = true
  entity.set_recipe(recipe)
  return entity
end

local south = { direction = defines.direction.south }

-- Mud washing, one column from the shore up: the seafloor pump's viscous
-- mud enters the bottom plant, each plant passes its mud straight up into the
-- next, and the clarifier on top voids the thin mud. Fresh water runs up the
-- east side.
place("angels-seafloor-pump", 20.5, 4.5, south)
pipes(20.5, 3.5, 20.5, 3.5)
local stages = {
  "angels-water-heavy-mud",
  "angels-water-concentrated-mud",
  "angels-water-light-mud",
  "angels-water-thin-mud",
}
for i, recipe in ipairs(stages) do
  local y = 5.5 - 5 * i
  machine("angels-washing-plant", 20.5, y, recipe)
  -- Solid mud is what all this is for. It goes down a belt to be pressed
  -- into landfill.
  place("inserter", 17.5, y, { direction = defines.direction.east })
end
place("angels-clarifier", 20.5, -19.5)

place("offshore-pump", 23.5, 5.5, south)
pipes(23.5, 4.5, 23.5, -14.5)

for y = -15.5, 0.5 do
  place("transport-belt", 16.5, y, south)
end
place("inserter", 16.5, 1.5, { direction = defines.direction.north })
machine("assembling-machine-1", 16.5, 3.5, "angels-solid-mud-landfill")
place("inserter", 14.5, 3.5, { direction = defines.direction.east })
place("wooden-chest", 13.5, 3.5)

-- Steam power and algae on the other side of the logo.
place("offshore-pump", -19.5, 5.5, south)
pipes(-19.5, 4.5, -19.5, 4.5)
pipes(-24.5, 3.5, -12.5, 3.5)
machine("angels-algae-farm", -20.5, -0.5, "angels-algae-green-simple", south)
machine("angels-algae-farm", -12.5, -0.5, "angels-algae-green-simple", south)

local boiler = place("boiler", -26.5, 3)
boiler.insert({ name = "angels-wood-pellets", count = 50 })
place("steam-engine", -26.5, -0.5)
place("steam-engine", -26.5, -5.5)

place("substation", -24, 5)
place("big-electric-pole", -12, 5)
place("big-electric-pole", 8, 5)
place("substation", 13, 1)
place("substation", 13, -10)

place_fish(25, 11)
]]
