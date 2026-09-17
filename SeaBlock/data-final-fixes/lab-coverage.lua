-- Keep every technology researchable by some lab.
--
-- Factorio 2.1 refuses to load if a technology's science pack set is not
-- accepted in full by at least one lab, and it checks hidden and disabled
-- technologies too. Sea Block trips that in two ways: it empties the alien
-- lab's input list (so YAFC stops reporting alien science as producible), and
-- it hides whole branches of Bob's military tree whose costs Bob's still sets
-- in alien science. The technologies are unreachable by design, but their
-- costs still have to name packs a lab will take.
--
-- Anything that fails this check while still visible is a real progression
-- bug rather than deliberate pruning, so that case is logged loudly instead
-- of being quietly rewritten.

local function pack_names(unit)
  local names = {}
  for _, ingredient in pairs((unit or {}).ingredients or {}) do
    local name = ingredient[1] or ingredient.name
    if type(name) == "string" then
      table.insert(names, name)
    end
  end
  return names
end

-- name -> set of packs it takes, for every lab that takes anything
local lab_inputs = {}
for name, lab in pairs(data.raw.lab or {}) do
  if lab.inputs and #lab.inputs > 0 then
    local accepted = {}
    for _, input in pairs(lab.inputs) do
      accepted[input] = true
    end
    lab_inputs[name] = accepted
  end
end

---@return boolean covered, table|nil best the most permissive lab's pack set
local function coverage(packs)
  local best, best_score = nil, -1
  for _, accepted in pairs(lab_inputs) do
    local score, missing = 0, false
    for _, pack in pairs(packs) do
      if accepted[pack] then
        score = score + 1
      else
        missing = true
      end
    end
    if not missing then
      return true, accepted
    end
    if score > best_score then
      best, best_score = accepted, score
    end
  end
  return false, best
end

local fallback_pack
for _, candidate in ipairs({ "automation-science-pack", "logistic-science-pack" }) do
  for _, accepted in pairs(lab_inputs) do
    if accepted[candidate] then
      fallback_pack = candidate
      break
    end
  end
  if fallback_pack then
    break
  end
end

local rewritten, expected = 0, 0
for name, technology in pairs(data.raw.technology) do
  local packs = pack_names(technology.unit)
  if #packs > 0 then
    local covered, best = coverage(packs)
    if not covered then
      -- Sea Block's tutorial technologies are completed from control.lua the
      -- moment the player obtains the matching item, so their cost is only
      -- ever a tech tree label. They are expected here, not a symptom.
      local scripted = (seablock.scripted_techs or {})[name] == true
      local hidden = technology.hidden == true or technology.enabled == false

      local kept = {}
      for _, ingredient in pairs(technology.unit.ingredients) do
        local pack = ingredient[1] or ingredient.name
        if best and best[pack] then
          table.insert(kept, ingredient)
        end
      end

      if #kept > 0 then
        technology.unit.ingredients = kept
      elseif scripted then
        technology.unit = { count = 1, ingredients = { { fallback_pack, 1 } }, time = 1 }
      else
        -- Nothing of the original cost survives, so take the prerequisites'
        -- cost rather than dropping an endgame technology to red science.
        technology.unit = seablock.lib.inherited_tech_unit(technology)
          or { count = 1, ingredients = { { fallback_pack, 1 } }, time = 1 }
      end

      if scripted then
        expected = expected + 1
      else
        rewritten = rewritten + 1
        local note = hidden and "hidden" or "VISIBLE, so its branch may have been pruned by mistake"
        log(
          ("Sea Block: technology %s (%s) required %s, which no lab accepts; rewritten as %s"):format(
            name,
            note,
            table.concat(packs, " + "),
            table.concat(pack_names(technology.unit), " + ")
          )
        )
      end
    end
  end
end

if rewritten > 0 or expected > 0 then
  log(
    ("Sea Block: rewrote %d technology costs with no matching lab (%d scripted tutorial technologies)"):format(
      rewritten + expected,
      expected
    )
  )
end
