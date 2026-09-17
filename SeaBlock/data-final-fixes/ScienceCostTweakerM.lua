if not mods["ScienceCostTweakerM"] then
  return
end

-- ScienceCostTweakerM replaces the base game's science pack technologies with
-- its own: sctm.tech_replace folds sct-automation-science-pack into
-- automation-science-pack, keeping the sct- technology's contents under the
-- base game's name and deleting the sct- key.
--
-- It does that in its data-final-fixes, which is after Sea Block's data-updates
-- has already written sct-automation-science-pack into the prerequisites of
-- every startup technology, because that is the name the technology still has
-- at that point. Those prerequisites are then left pointing at a technology
-- that no longer exists, and Factorio refuses to load.
--
-- Sea Block loads after ScienceCostTweakerM in every stage, so the folding has
-- happened by the time this runs. Rewriting sct-<name> to <name> matches what
-- tech_replace does, and the "only if <name> exists" check leaves alone the
-- sct- technologies it does not touch, such as sct-lab-t1.

local function folded_name(name)
  if data.raw.technology[name] then
    return nil
  end
  local base_name = name:match("^sct%-(.+)$")
  if base_name and data.raw.technology[base_name] then
    return base_name
  end
  return nil
end

local repaired = 0
for technology_name, technology in pairs(data.raw.technology) do
  local prerequisites = technology.prerequisites
  if prerequisites then
    local seen, rebuilt = {}, {}
    for _, prerequisite in ipairs(prerequisites) do
      local resolved = folded_name(prerequisite) or prerequisite
      -- Folding can collide with a prerequisite the technology already had.
      if not seen[resolved] then
        seen[resolved] = true
        table.insert(rebuilt, resolved)
      end
      if resolved ~= prerequisite then
        repaired = repaired + 1
        log(
          ("Sea Block: technology %s required %s, which ScienceCostTweakerM folded into %s"):format(
            technology_name,
            prerequisite,
            resolved
          )
        )
      end
    end
    technology.prerequisites = rebuilt
  end
end

if repaired > 0 then
  log(("Sea Block: repaired %d prerequisites left behind by ScienceCostTweakerM"):format(repaired))
end

-- S.C.T.'s Lab 3 gates blue science and waits on Oil Processing. In Sea Block
-- oil comes from blue algae rather than a pumpjack, so Oil Processing itself
-- sits behind blue science and the pair close a loop. S.C.T. declares this as
-- the base game's oil-processing and Angel's renames it afterwards, so the
-- removal has to happen here, once the name has settled. Lab 3's other
-- prerequisites -- advanced chemistry, the smelting chains, nitrogen, sulfur --
-- still gate it.
for _, name in ipairs({ "angels-oil-processing", "oil-processing" }) do
  bobmods.lib.tech.remove_prerequisite("sct-lab-t3", name)
end
