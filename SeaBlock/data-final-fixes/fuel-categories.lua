-- Factorio 2.1.20 replaced ItemPrototype::fuel_category with fuel_categories,
-- and refuses to start while any item still carries the old field. Bob's 3.0.1
-- and Angel's 2.1.2 predate that and set it on 22 items, charcoal among them;
-- the game names only the first it trips over, bob-enriched-fuel. Sea Block
-- loads after both, so it can carry the value across until they fix it.
--
-- The old field replaces rather than merges: before 2.1.20 it was an item's
-- whole fuel category, and where these mods set it twice it is to reassign one,
-- as Bob's does to move its thorium and deuterium fuel cells off "nuclear".
--
-- Only from 2.1.20: 2.1.19 still reads fuel_category and ignores the new field,
-- so converting there leaves every fuel without a category and fails the load.
--
-- Remove once Bob's and Angel's have 2.1.20 releases. Loads that still hit this
-- on something loaded after Sea Block are that mod's to fix, not reachable here.
local version = {}
for part in mods["base"]:gmatch("%d+") do
  table.insert(version, tonumber(part))
end
local major, minor, patch = version[1], version[2], version[3]
local renamed = major > 2 or (major == 2 and (minor > 1 or (minor == 1 and patch >= 20)))

if renamed then
  for item_type in pairs(defines.prototypes.item) do
    for _, item in pairs(data.raw[item_type] or {}) do
      if item.fuel_category then
        item.fuel_categories = { item.fuel_category }
        item.fuel_category = nil
      end
    end
  end
end
