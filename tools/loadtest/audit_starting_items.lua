-- Audit script: the starting rock chest can actually be filled.
--
-- populate_starting_items runs in the control stage, from on_chunk_generated.
-- Inserting an item that no longer exists is a non-recoverable error there, and
-- it happens during chunk generation, so it takes the save with it. Neither a
-- headless map creation nor a data stage load reaches it: the chest is only
-- built in single player, and the headless server is always multiplayer.
--
-- The function is a pure function of the available items, so it can be called
-- here with the item set the data stage produced.

return function(data, mods, settings, resolve_path)
  local path = resolve_path and resolve_path("__SeaBlock21__/starting-items.lua")
  if not path then
    io.stderr:write("starting items audit: skipped, SeaBlock is not in this manifest\n")
    return 0
  end

  local chunk, err = loadfile(path)
  if not chunk then
    io.stderr:write("starting items audit: could not load " .. path .. ": " .. tostring(err) .. "\n")
    return 1
  end
  chunk()

  -- Every prototype type the game counts as an item, which is what
  -- prototypes.item holds at runtime.
  local items = {}
  for _, category in ipairs({
    "item",
    "ammo",
    "capsule",
    "gun",
    "module",
    "tool",
    "armor",
    "repair-tool",
    "rail-planner",
    "item-with-entity-data",
    "spidertron-remote",
  }) do
    for name, prototype in pairs(data.raw[category] or {}) do
      items[name] = prototype
    end
  end

  local ok, starting_items = pcall(seablock.populate_starting_items, items)
  if not ok then
    io.stderr:write("starting items audit: populate_starting_items errored: " .. tostring(starting_items) .. "\n")
    return 1
  end

  local findings, total = 0, 0
  for name, quantity in pairs(starting_items) do
    total = total + 1
    if not items[name] then
      io.stderr:write(("  starting chest wants %d x %q, which is not an item\n"):format(quantity, name))
      findings = findings + 1
    end
  end

  if findings == 0 then
    print(("starting items audit: all %d stacks exist"):format(total))
  end
  return findings
end
