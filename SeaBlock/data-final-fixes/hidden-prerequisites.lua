-- Point prerequisites on hidden technologies at the technology that took over their content.
--
-- A hidden, disabled technology can never be researched, so anything that lists
-- it as a prerequisite can never be researched either. Factorio does not draw
-- hidden technologies in the tree, so the player sees every prerequisite green
-- and is still told one is missing, with no way to find out which.
--
-- Angel's Smelting disables Bob's metal processing technologies and moves their
-- content to its own smelting chains, and its override pass rewrites the
-- prerequisites that exist when it runs. Bob's Warfare loads after it and adds the
-- Bob's names back (artillery on cobalt processing). Angel's 2.1 also disables
-- bob-zinc-processing, which Bob's still requires for military-3; that blocked
-- assembling machine 3, the rocket silo and everything after them.
--
-- Rather than chase each of those by name, find every visible technology with a
-- hidden prerequisite and swap in the successor below. Prerequisites with no
-- known successor are left alone: alien research and Bob's nuclear fuel cells
-- are cut on purpose, and the equipment behind them needs materials Sea Block
-- removed, so unblocking it would only offer a research whose result cannot be
-- crafted. tools/loadtest/audit_hidden_prerequisites.lua lists those.

-- Where a hidden technology's content went. false drops the prerequisite.
local successors = {
  -- data-updates/petrochem.lua hides gas processing and moves its unlocks here;
  -- ScienceCostTweakerM still requires it for production science.
  ["angels-gas-processing"] = "angels-advanced-gas-processing",
  -- Angel's removes this from bob-bodies itself; kept in case Bob's Classes ever
  -- loads after it and adds it back.
  ["bob-wood-processing"] = false,
}

local function usable(name)
  local technology = data.raw.technology[name]
  return technology and not technology.hidden and technology.enabled ~= false
end

local function successor(name)
  local found = successors[name]
  if found == nil then
    local metal = name:match("^bob%-(.+)%-processing$")
    found = metal and ("angels-" .. metal .. "-smelting-1")
  end
  if found == false or (found and usable(found)) then
    return found
  end
  return nil
end

-- Whether technology `from` already requires `target`, directly or indirectly.
local function requires(from, target)
  local seen = {}
  local function visit(name)
    if name == target then
      return true
    end
    if seen[name] then
      return false
    end
    seen[name] = true
    local technology = data.raw.technology[name]
    for _, prerequisite in pairs(technology and technology.prerequisites or {}) do
      if visit(prerequisite) then
        return true
      end
    end
    return false
  end
  return visit(from)
end

local names = {}
for name in pairs(data.raw.technology) do
  table.insert(names, name)
end
table.sort(names)

for _, technology_name in ipairs(names) do
  local technology = data.raw.technology[technology_name]
  if usable(technology_name) and technology.prerequisites then
    -- Copied, because the loop edits the list it walks.
    for _, prerequisite in ipairs({ table.unpack(technology.prerequisites) }) do
      local replacement = nil
      if data.raw.technology[prerequisite] and not usable(prerequisite) then
        replacement = successor(prerequisite)
      end
      if replacement ~= nil then
        bobmods.lib.tech.remove_prerequisite(technology_name, prerequisite)
        if replacement and requires(replacement, technology_name) then
          log(
            ("Sea Block: %s cannot require %s in place of %s, it would close a loop"):format(
              technology_name,
              replacement,
              prerequisite
            )
          )
        elseif replacement and not requires(technology_name, replacement) then
          bobmods.lib.tech.add_prerequisite(technology_name, replacement)
          log(("Sea Block: %s required hidden %s, now requires %s"):format(technology_name, prerequisite, replacement))
        else
          log(("Sea Block: %s no longer requires hidden %s"):format(technology_name, prerequisite))
        end
      end
    end
  end
end
