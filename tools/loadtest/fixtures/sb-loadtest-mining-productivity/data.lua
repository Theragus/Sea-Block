-- Stands in for a mod such as Seablock Mining that opts in to keeping the
-- mining productivity technologies. It does only what such a mod would do, in
-- the stage it would do it in, so the load test covers Sea Block's side of the
-- interface. It does not depend on load order: every data.lua runs before any
-- data-updates.lua, and Sea Block's data.lua keeps a table that already exists.
seablock = seablock or {}
seablock.trigger = seablock.trigger or {}
seablock.trigger.mining_productivity = true
