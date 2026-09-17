if mods["ScienceCostTweakerM"] then
  if data.raw.item["bob-lab-2"] then
    -- Update lab energy usage
    data.raw.lab["bob-lab-2"].energy_usage = "10MW"
    -- Only two module slots for lab-2 if s.c.t. is installed (other labs have no module slots)
    data.raw.lab["bob-lab-2"].module_slots = 2
  end

  -- Change tech to use lab icon from SCT. sb-startup4 declares icon_size 128,
  -- so it needs the 128px file: pointing at icon-64.png leaves a 128 square
  -- declared over a 64x64 image, which the graphical client rejects even
  -- though a headless server never loads the sprite at all.
  data.raw["technology"]["sb-startup4"].icon = "__ScienceCostTweakerM__/graphics/sct-lab-t1/icon-128.png"

  -- Reduce processing unit cost of S.C.T. high-tech science
  seablock.lib.substingredient("sct-htech-injector", "processing-unit", nil, 3)

  -- S.C.T. gates each science pack behind a lab tier, and those tiers carry
  -- prerequisites written for a tree where ore and oil come out of the ground.
  -- Sea Block inverts both, so two of them close loops in the early game.

  -- Lab 1 is part of the Sea Block tutorial chain, reached from Basic Circuit
  -- Board before anything else exists. S.C.T. has it wait on Electronics and
  -- Steam Power, which in Sea Block come after Slag Processing 1 -- which in
  -- turn waits on red science, which waits on Lab 1. Clear them and let
  -- data-updates/startup.lua put it back on sb-startup3, the way the other
  -- tutorial technologies are handled.
  if data.raw.technology["sct-lab-t1"] then
    data.raw.technology["sct-lab-t1"].prerequisites = {}
  end

  -- Hide empty tech (Lab 2 will have been moved to it's own tech sct-lab-lab2
  seablock.lib.hide_technology("bob-advanced-research")

  -- Yellow science now requires Purple science
  -- Adjust any techs that needed Yellow but not Purple

  bobmods.lib.tech.replace_science_pack("fission-reactor-equipment", "utility-science-pack", "production-science-pack")
  bobmods.lib.tech.replace_prerequisite("fission-reactor-equipment", "utility-science-pack", "production-science-pack")
  bobmods.lib.tech.add_prerequisite("fission-reactor-equipment", "low-density-structure")
  if mods["bobequipment"] then
    bobmods.lib.tech.add_prerequisite("bob-fission-reactor-equipment-3", "utility-science-pack")
  end

  if mods["bobvehicleequipment"] then
    bobmods.lib.tech.replace_science_pack(
      "bob-vehicle-fission-reactor-equipment-2",
      "utility-science-pack",
      "production-science-pack"
    )
    bobmods.lib.tech.replace_prerequisite(
      "bob-vehicle-fission-reactor-equipment-2",
      "utility-science-pack",
      "production-science-pack"
    )
    bobmods.lib.tech.add_prerequisite("bob-vehicle-fission-reactor-equipment-3", "utility-science-pack")
  end

  -- Move intermediates from Advanced Material Processing to Purple Science
  bobmods.lib.tech.remove_recipe_unlock("advanced-material-processing-2", "sct-prod-baked-biopaste")
  bobmods.lib.tech.remove_recipe_unlock("advanced-material-processing-2", "sct-prod-biosilicate")
  bobmods.lib.tech.add_recipe_unlock("production-science-pack", "sct-prod-baked-biopaste")
  bobmods.lib.tech.add_recipe_unlock("production-science-pack", "sct-prod-biosilicate")
  bobmods.lib.tech.add_prerequisite("sct-production-science-pack", "angels-advanced-gas-processing")
end
