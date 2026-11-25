-- Merge basic chemistry 2 into basic chemistry
-- Recorded so data-final-fixes/merged-technologies.lua can move unlocks that other mods
-- add to a merged technology after this runs.
seablock.merged_technologies = seablock.merged_technologies or {}
local function movealleffects(from, to)
  seablock.merged_technologies[from] = to
  for _, v in pairs(data.raw.technology[from].effects) do
    table.insert(data.raw.technology[to].effects, v)
  end
  for _, v in pairs(data.raw.technology) do
    for k, prerequisite in pairs(v.prerequisites or {}) do
      if prerequisite == from then
        v.prerequisites[k] = to
      end
    end
  end
  data.raw.technology[from].effects = {}
end
movealleffects("angels-basic-chemistry-2", "angels-basic-chemistry")
movealleffects("angels-basic-chemistry-3", "angels-basic-chemistry-2")
movealleffects("angels-advanced-chemistry-3", "angels-advanced-chemistry-2")
movealleffects("angels-advanced-chemistry-4", "angels-advanced-chemistry-3")
movealleffects("angels-advanced-chemistry-5", "angels-advanced-chemistry-4")
movealleffects("angels-chlorine-processing-3", "angels-chlorine-processing-2")
movealleffects("angels-chlorine-processing-4", "angels-chlorine-processing-2")
bobmods.lib.tech.add_new_science_pack("angels-basic-chemistry-2", "logistic-science-pack", 1)
bobmods.lib.tech.add_new_science_pack("angels-advanced-chemistry-3", "production-science-pack", 1)
bobmods.lib.tech.add_new_science_pack("angels-advanced-chemistry-4", "utility-science-pack", 1)
bobmods.lib.tech.add_new_science_pack("angels-chlorine-processing-2", "chemical-science-pack", 1)
bobmods.lib.tech.add_prerequisite("angels-advanced-chemistry-4", "angels-advanced-chemistry-3")
bobmods.lib.tech.add_prerequisite("angels-advanced-chemistry-4", "utility-science-pack")
bobmods.lib.tech.add_prerequisite("angels-chlorine-processing-2", "angels-sodium-processing-1")
bobmods.lib.tech.add_prerequisite("angels-chlorine-processing-2", "angels-advanced-chemistry-2")
seablock.lib.hide_technology("angels-basic-chemistry-3")
seablock.lib.hide_technology("angels-advanced-chemistry-5")
seablock.lib.hide_technology("angels-chlorine-processing-3")
seablock.lib.hide_technology("angels-chlorine-processing-4")

-- Move recipes back
seablock.lib.moveeffect("angels-water-gas-shift-1", "angels-basic-chemistry", "angels-basic-chemistry-2")
seablock.lib.moveeffect("angels-water-gas-shift-2", "angels-basic-chemistry", "angels-basic-chemistry-2")
bobmods.lib.tech.add_prerequisite("angels-nickel-smelting-1", "angels-basic-chemistry-2")

-- Bob's Plates gives the chemical plant a technology of its own, but Angel's
-- already unlocks the plant with Basic chemistry, which is cheaper and comes first.
-- That left Chemical plant with nothing to give. Lubricant, the only visible
-- technology that requires it, is pointed at Basic chemistry by
-- data-final-fixes/hidden-prerequisites.lua.
seablock.lib.hide_technology("bob-chemical-plant")

-- Make Basic Chemistry depend on Wood Processing 2
bobmods.lib.tech.add_prerequisite("angels-basic-chemistry", "angels-bio-wood-processing-2")

-- Move Methane to Blue Science
bobmods.lib.tech.remove_recipe_unlock("angels-advanced-chemistry-2", "angels-gas-refinery-small-2")
bobmods.lib.tech.remove_recipe_unlock("flammables", "angels-solid-fuel-methane")
bobmods.lib.tech.remove_recipe_unlock("angels-gas-processing", "angels-gas-fractioning")
bobmods.lib.tech.remove_recipe_unlock("angels-gas-processing", "angels-gas-refining")
bobmods.lib.tech.remove_recipe_unlock("angels-steam-cracking-1", "angels-gas-butadiene")
bobmods.lib.tech.remove_recipe_unlock("angels-steam-cracking-1", "angels-steam-cracking-butane")
bobmods.lib.tech.remove_recipe_unlock("angels-steam-cracking-1", "angels-gas-ethylene")
bobmods.lib.tech.remove_recipe_unlock("angels-steam-cracking-1", "angels-steam-cracking-methane")
bobmods.lib.tech.remove_recipe_unlock("angels-steam-cracking-2", "angels-steam-cracking-oil-residual")

bobmods.lib.tech.add_recipe_unlock("angels-advanced-chemistry-2", "angels-gas-butadiene")
bobmods.lib.tech.add_recipe_unlock("angels-advanced-gas-processing", "angels-gas-refinery-small-2")
bobmods.lib.tech.add_recipe_unlock("angels-advanced-gas-processing", "angels-gas-refining")
bobmods.lib.tech.add_recipe_unlock("angels-advanced-gas-processing", "angels-gas-fractioning")
bobmods.lib.tech.add_recipe_unlock("angels-advanced-gas-processing", "angels-solid-fuel-methane")
bobmods.lib.tech.add_recipe_unlock("fluid-handling", "angels-storage-tank-1")
bobmods.lib.tech.add_recipe_unlock("angels-steam-cracking-1", "angels-steam-cracking-oil-residual")
bobmods.lib.tech.add_recipe_unlock("angels-steam-cracking-2", "angels-steam-cracking-butane")
bobmods.lib.tech.add_recipe_unlock("angels-steam-cracking-2", "angels-gas-ethylene")
bobmods.lib.tech.add_recipe_unlock("angels-steam-cracking-2", "angels-steam-cracking-methane")
seablock.lib.add_recipe_unlock("angels-bio-nutrient-paste", "angels-gas-refinery-small", 2)

bobmods.lib.tech.remove_prerequisite("advanced-material-processing-2", "angels-gas-processing")
bobmods.lib.tech.remove_prerequisite("angels-advanced-gas-processing", "angels-steam-cracking-2")
bobmods.lib.tech.remove_prerequisite("angels-oil-processing", "oil-gathering")
bobmods.lib.tech.remove_prerequisite("angels-sulfur-processing-3", "angels-gas-processing")
bobmods.lib.tech.remove_prerequisite("angels-bio-nutrient-paste", "angels-gas-processing")
bobmods.lib.tech.remove_prerequisite("angels-bio-processing-paste", "angels-chlorine-processing-2")
bobmods.lib.tech.remove_prerequisite("angels-gas-processing", "oil-gathering")
bobmods.lib.tech.remove_prerequisite("angels-steam-cracking-1", "angels-gas-processing")
bobmods.lib.tech.remove_prerequisite("angels-steam-cracking-2", "angels-advanced-chemistry-2")

bobmods.lib.tech.add_prerequisite("angels-advanced-chemistry-2", "angels-steam-cracking-2")
bobmods.lib.tech.add_prerequisite("angels-advanced-gas-processing", "angels-bio-nutrient-paste")
bobmods.lib.tech.add_prerequisite("angels-advanced-gas-processing", "angels-bio-refugium-puffer-1")
bobmods.lib.tech.add_prerequisite("angels-oil-processing", "fluid-handling")
bobmods.lib.tech.add_prerequisite("angels-bio-processing-paste", "angels-chlorine-processing-1")
bobmods.lib.tech.add_prerequisite("angels-steam-cracking-2", "angels-advanced-gas-processing")

bobmods.lib.tech.hide("angels-gas-processing")
