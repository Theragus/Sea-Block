-- Update catalyst recipes

-- Angel's 2.1 returns the catalyst as a result (90%, else an empty carrier), so swap it on both sides
local function replace_catalyst(recipe, from, to)
  seablock.lib.substingredient(recipe, from, to)
  seablock.lib.substresult(recipe, from, to)
end

bobmods.lib.tech.remove_recipe_unlock("angels-basic-chemistry-3", "angels-catalyst-metal-red")
seablock.lib.hide("item", "angels-catalyst-metal-red")
bobmods.lib.recipe.hide("angels-catalyst-metal-red")

-- Angel's 2.1 makes 1 catalyst from 1 carrier (was 10 from 10)
bobmods.lib.recipe.set_ingredients("angels-catalyst-metal-green", {
  { type = "item", name = "angels-catalyst-metal-carrier", amount = 1, ignored_by_stats = 1 },
  { type = "item", name = "copper-ore", amount = 1 },
  { type = "item", name = "iron-ore", amount = 1 },
})
bobmods.lib.recipe.set_ingredients("angels-catalyst-metal-blue", {
  { type = "item", name = "angels-catalyst-metal-carrier", amount = 1, ignored_by_stats = 1 },
  { type = "item", name = "bob-bauxite-ore", amount = 1 },
  { type = "item", name = "bob-silver-ore", amount = 1 },
})
bobmods.lib.tech.add_recipe_unlock("angels-advanced-chemistry-4", "sb-catalyst-metal-purple")

replace_catalyst("angels-liquid-acetic-acid-catalyst", "angels-catalyst-metal-red", "angels-catalyst-metal-green")
replace_catalyst("angels-gas-ammonia", "angels-catalyst-metal-red", "angels-catalyst-metal-green")
replace_catalyst("angels-catalyst-steam-cracking-naphtha", "angels-catalyst-metal-red", "angels-catalyst-metal-green")

replace_catalyst("angels-gas-synthesis-methanol", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")
replace_catalyst("angels-gas-acid-catalyst", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")
replace_catalyst("angels-liquid-styrene", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")
replace_catalyst("angels-gas-benzene", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")
replace_catalyst("angels-liquid-propionic-acid", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")
replace_catalyst("angels-gas-butadiene", "angels-catalyst-metal-green", "angels-catalyst-metal-blue")

replace_catalyst("angels-liquid-naphtha-catalyst", "angels-catalyst-metal-red", "sb-catalyst-metal-purple")
replace_catalyst("angels-solid-sodium-cyanide", "angels-catalyst-metal-green", "sb-catalyst-metal-purple")
replace_catalyst("angels-gas-synthesis-methanation", "angels-catalyst-metal-blue", "sb-catalyst-metal-purple")
replace_catalyst("angels-gas-hydrazine", "angels-catalyst-metal-blue", "sb-catalyst-metal-purple")
replace_catalyst("angels-gas-synthesis-methanol", "angels-catalyst-metal-blue", "sb-catalyst-metal-purple")

replace_catalyst("angels-cumene-process", "angels-catalyst-metal-blue", "angels-catalyst-metal-yellow")

table.insert(
  data.raw.recipe["angels-liquid-mineral-oil-catalyst"].ingredients,
  { type = "item", name = "sb-catalyst-metal-purple", amount = 1, ignored_by_stats = 1 }
)
seablock.lib.addresult("angels-liquid-mineral-oil-catalyst", {
  type = "item",
  name = "sb-catalyst-metal-purple",
  amount = 1,
  ignored_by_productivity = 1,
  ignored_by_stats = 1,
  shared_probability = { min = 0.0, max = 0.9 },
})
seablock.lib.addresult("angels-liquid-mineral-oil-catalyst", {
  type = "item",
  name = "angels-catalyst-metal-carrier",
  amount = 1,
  ignored_by_productivity = 1,
  shared_probability = { min = 0.9, max = 1.0 },
})

bobmods.lib.tech.add_prerequisite("angels-bio-plastic-2", "angels-advanced-chemistry-2")
bobmods.lib.tech.add_prerequisite("angels-sodium-processing-2", "angels-advanced-chemistry-4")
bobmods.lib.tech.add_prerequisite("angels-advanced-chemistry-1", "angels-basic-chemistry-3")
bobmods.lib.tech.add_prerequisite("angels-advanced-chemistry-3", "angels-thermal-water-extraction-2")
bobmods.lib.tech.remove_prerequisite("angels-advanced-chemistry-1", "angels-ore-floatation")

bobmods.lib.tech.add_new_science_pack("angels-nitrogen-processing-3", "production-science-pack", 1)
bobmods.lib.tech.add_prerequisite("angels-nitrogen-processing-3", "angels-advanced-chemistry-4")
bobmods.lib.tech.replace_prerequisite("angels-resin-2", "angels-nitrogen-processing-3", "angels-advanced-chemistry-2")
seablock.lib.moveeffect("angels-air-filter-3", "angels-nitrogen-processing-3", "angels-advanced-chemistry-2", 4)
seablock.lib.moveeffect("angels-gas-melamine", "angels-nitrogen-processing-3", "angels-advanced-chemistry-2")

bobmods.lib.tech.add_new_science_pack("angels-gas-synthesis", "production-science-pack", 1)
bobmods.lib.tech.add_prerequisite("angels-gas-synthesis", "angels-advanced-chemistry-4")

seablock.lib.moveeffect(
  "angels-liquid-mineral-oil-catalyst",
  "angels-advanced-chemistry-3",
  "angels-advanced-chemistry-4"
)
seablock.lib.moveeffect("angels-catalyst-metal-carrier", "angels-basic-chemistry-3", "angels-advanced-chemistry-1", 5)
seablock.lib.moveeffect("angels-catalyst-metal-green", "angels-advanced-chemistry-1", "angels-advanced-chemistry-1", 6)
seablock.lib.moveeffect("angels-catalyst-metal-blue", "angels-advanced-chemistry-3", "angels-advanced-chemistry-2", 8)
seablock.lib.moveeffect("angels-catalyst-metal-yellow", "angels-advanced-chemistry-5", "angels-advanced-chemistry-5", 6)
