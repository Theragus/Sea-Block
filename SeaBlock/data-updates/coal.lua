-- Coal removal
seablock.lib.substingredient("firearm-magazine", "coal", "angels-wood-charcoal")
seablock.lib.substingredient("grenade", "coal", "angels-wood-charcoal")
seablock.lib.substingredient("explosives", "coal", "angels-wood-charcoal")
seablock.lib.substingredient("bob-solid-fuel-from-hydrogen", "coal", "angels-wood-charcoal")
if mods["bobenemies"] then
  seablock.lib.substingredient("bob-alien-poison", "coal", "angels-wood-charcoal")
  seablock.lib.substingredient("bob-alien-explosive", "coal", "angels-wood-charcoal")
end
seablock.lib.substingredient("angels-filter-coal", "coal", "angels-wood-charcoal")
seablock.lib.substingredient("carbon", "coal", "angels-wood-charcoal")
if mods["Transport_Drones"] then
  seablock.lib.substingredient("road", "coal", "angels-wood-charcoal")
end
seablock.lib.substingredient("angels-gas-carbon-dioxide", "coal", "angels-wood-charcoal", 1)
if mods["angelsaddons-storage"] and data.raw.recipe["angels-silo-coal"] then
  seablock.lib.substingredient("angels-silo-coal", "angels-coal-crushed", "angels-wood-charcoal", 10)
end

-- Disable coal cracking technology
seablock.lib.hide_technology("angels-coal-cracking")
seablock.lib.moveeffect("angels-pellet-coke", "angels-coal-cracking", "angels-coal-processing-2")
angelsmods.functions.move_item("angels-pellet-coke", "angels-bio-processing-wood", "f[pellet-coke]")
angelsmods.functions.move_item("angels-pellet-coke", "angels-bio-processing-wood", "f[pellet-coke]", "recipe")

-- Clear fuel value so these don't appear in Helmod's fuel picker. The fuel
-- categories go too, or coal is left a fuel worth nothing.
for _, name in pairs({ "carbon", "coal", "angels-coal-crushed" }) do
  local item = data.raw.item[name]
  item.fuel_emissions_multiplier = nil
  item.fuel_value = nil
  item.fuel_categories = nil
end

-- Angel's 2.x unlocks only pellet coke with charcoal processing 3, and the
-- moveeffect above follows it down to tier 2, which leaves tier 3 empty.
bobmods.lib.tech.remove_prerequisite("angels-sodium-processing-2", "angels-coal-processing-3")
seablock.lib.hide_technology("angels-coal-processing-3")

data.raw.recipe["angels-filter-coal"].localised_name = { "item-name.angels-filter-charcoal" }
