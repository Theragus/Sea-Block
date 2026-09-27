-- The opening of every Sea Block game: a sand island, a few trees, the rock
-- chest, and nothing else but sea. The engineer walks off towards the logo,
-- landfilling the way a tile or two ahead of their feet.
return [[
local islands = {
  { x = -20, y = 4, r = 5.5, seed = 1 },
  { x = -35, y = -9, r = 3, seed = 2 },
  { x = 27, y = -9, r = 3.5, seed = 3 },
  { x = 34, y = 9, r = 2.5, seed = 4 },
  { x = 13, y = -16, r = 2, seed = 5 },
  { x = -9, y = 14, r = 3, seed = 6 },
}

-- Positive inside an island, by roughly how far in; negative outside.
local function island_depth(x, y)
  local best = -math.huge
  for _, island in pairs(islands) do
    local dx, dy = x + 0.5 - island.x, y + 0.5 - island.y
    local angle = math.atan2(dy, dx)
    local r = island.r + 0.8 * math.sin(3 * angle + island.seed) + 0.4 * math.cos(5 * angle + 2 * island.seed)
    local depth = r - math.sqrt(dx * dx + dy * dy)
    if depth > best then
      best = depth
    end
  end
  return best
end

-- The landfill pad the logo sits on, as inclusive tile bounds.
local pad = { left = -8, right = 7, top = -13, bottom = -8 }

-- The causeway, as the line the engineer walks. Every corner is on whole
-- coordinates, so a two-tile-wide strip centred on it is always exactly the
-- tiles {x - 1, x} by {y - 1, y}.
local path = { { -17, 3 }, { -11, 3 }, { -11, -10 }, { -7, -10 } }
local walked = { 0 }
for i = 2, #path do
  walked[i] = walked[i - 1] + math.abs(path[i][1] - path[i - 1][1]) + math.abs(path[i][2] - path[i - 1][2])
end

local cells, causeway = {}, {}
for i = 1, #path - 1 do
  local a, b = path[i], path[i + 1]
  local sx, sy = sign(b[1] - a[1]), sign(b[2] - a[2])
  for step = 0, walked[i + 1] - walked[i] do
    local px, py = a[1] + sx * step, a[2] + sy * step
    for cx = px - 1, px do
      for cy = py - 1, py do
        local key = cx .. "," .. cy
        if not causeway[key] then
          causeway[key] = true
          cells[#cells + 1] = { x = cx, y = cy, along = walked[i] + step }
        end
      end
    end
  end
end

-- Shallow water hugs the land, and the line the causeway will take.
local function near_land(x, y)
  if island_depth(x, y) > -3 then
    return true
  end
  local px = math.max(pad.left - x, 0, x - pad.right)
  local py = math.max(pad.top - y, 0, y - pad.bottom)
  if math.max(px, py) <= 2 then
    return true
  end
  for dx = -2, 2 do
    for dy = -2, 2 do
      if causeway[(x + dx) .. "," .. (y + dy)] then
        return true
      end
    end
  end
  return false
end

paint(function(x, y)
  if x >= pad.left and x <= pad.right and y >= pad.top and y <= pad.bottom then
    return "landfill"
  end
  local depth = island_depth(x, y)
  if depth > 1 then
    return "sand-1"
  elseif depth > 0 then
    return "sand-2"
  elseif near_land(x, y) then
    return "water"
  end
  return "deepwater"
end)

place_logo()

for _, tree in pairs({
  { "tree-02", -23, 1.5 },
  { "tree-03", -24.5, 4 },
  { "tree-02", -22, 7 },
  { "tree-05", -19, 7.5 },
  { "tree-03", -36, -10 },
  { "tree-02", -34, -8 },
  { "tree-05", 35, 9 },
  { "tree-02", -9, 14 },
}) do
  surface.create_entity({ name = tree[1], position = { tree[2], tree[3] } })
end
place("sb-rock-chest", -20.5, 4.5, { force = "neutral" })

-- Sea Block's only natives, on an islet of their own. The prelude's
-- cease-fire keeps them from spitting at the engineer on the way past.
place("medium-worm-turret", 27, -9.5, { force = "enemy" })
place("small-worm-turret", 25, -7.5, { force = "enemy" })

place_fish(30, 7)

local character = place("character", path[1][1], path[1][2])
character.character_running_speed_modifier = -0.7

local leg, next_cell = 1, 1
local start_walking = game.tick + 60

script.on_event(defines.events.on_tick, function()
  if not character.valid then
    return
  end

  local position = character.position
  local from = path[leg]
  local reach = walked[leg] + math.abs(position.x - from[1]) + math.abs(position.y - from[2]) + 2.5
  local tiles = {}
  while cells[next_cell] and cells[next_cell].along <= reach do
    local cell = cells[next_cell]
    local tile = surface.get_tile(cell.x, cell.y).name
    if tile == "water" or tile == "deepwater" then
      tiles[#tiles + 1] = { name = "landfill", position = { cell.x, cell.y } }
    end
    next_cell = next_cell + 1
  end
  if #tiles > 0 then
    surface.set_tiles(tiles)
  end

  if game.tick < start_walking then
    return
  end
  local target = path[leg + 1]
  if not target then
    character.walking_state = { walking = false, direction = defines.direction.north }
    return
  end
  local dx, dy = target[1] - position.x, target[2] - position.y
  if math.abs(dx) + math.abs(dy) < 0.1 then
    leg = leg + 1
    return
  end
  local direction
  if math.abs(dx) > math.abs(dy) then
    direction = dx > 0 and defines.direction.east or defines.direction.west
  else
    direction = dy > 0 and defines.direction.south or defines.direction.north
  end
  character.walking_state = { walking = true, direction = direction }
end)
]]
