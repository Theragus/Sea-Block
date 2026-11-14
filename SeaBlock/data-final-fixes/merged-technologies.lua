-- Move unlocks that reach a technology after data-updates/petrochem.lua merged it away.
--
-- petrochem.lua moves every effect of angels-chlorine-processing-3 and -4,
-- angels-basic-chemistry-3 and angels-advanced-chemistry-5 to another tier and hides
-- the emptied technology. Angel's OV.add_unlock does not edit a technology when it is
-- called: it queues the change for the next OV.execute(), and the last of those runs in
-- angelssmelting's data-final-fixes, after Sea Block's data-updates. A mod that adds an
-- unlock to one of those tiers through OV in its data-updates therefore lands it on the
-- hidden technology, where nothing can research it. Clowns-Processing does this with
-- hydrochloric-acid-separation on angels-chlorine-processing-3. Move whatever arrived
-- since onto the merge target, as petrochem.lua did with the rest.
--
-- Merged technologies that stay visible keep what they gained; it is still researchable.

local merged = seablock.merged_technologies or {}

local names = {}
for from in pairs(merged) do
  table.insert(names, from)
end
table.sort(names)

for _, from in ipairs(names) do
  local source = data.raw.technology[from]
  local target = data.raw.technology[merged[from]]
  if source and target and source.hidden and source.effects and next(source.effects) then
    target.effects = target.effects or {}
    for _, effect in pairs(source.effects) do
      local duplicate = false
      if effect.type == "unlock-recipe" then
        for _, existing in pairs(target.effects) do
          if existing.type == "unlock-recipe" and existing.recipe == effect.recipe then
            duplicate = true
            break
          end
        end
      end
      if not duplicate then
        table.insert(target.effects, effect)
        log(("Sea Block: moved %s from merged %s to %s"):format(effect.recipe or effect.type, from, target.name))
      end
    end
    source.effects = {}
  end
end
