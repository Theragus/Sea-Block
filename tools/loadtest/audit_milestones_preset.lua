-- Audit script: the Milestones preset Sea Block serves names real prototypes.
--
-- Sea Block provides the "Sea Block" preset through its own remote interface,
-- so a name that Bob's or Angel's has since changed is Sea Block's to fix.
-- Milestones drops invalid entries rather than erroring, so the only symptom is
-- a milestone quietly missing and one red line in the console -- which is
-- exactly the kind of thing nobody chases down.
--
-- remote.lua is control stage, but milestones_presets only reads
-- script.active_mods and settings.startup, so it can be called here with the
-- prototype set the data stage produced.

return function(data, mods, settings, resolve_path)
  local path = resolve_path and resolve_path("__SeaBlock21__/remote.lua")
  if not path then
    io.stderr:write("milestones preset audit: skipped, SeaBlock is not in this manifest\n")
    return 0
  end

  local captured
  local previous = { script = script, storage = storage, remote = remote }
  script = { active_mods = mods }
  storage = { unlocks = {}, starting_items = {} }
  remote = {
    add_interface = function(_, functions)
      captured = functions
    end,
  }

  local chunk, err = loadfile(path)
  if not chunk then
    io.stderr:write("milestones preset audit: could not load remote.lua: " .. tostring(err) .. "\n")
    return 1
  end
  local ok, load_err = pcall(chunk)
  script, storage, remote = previous.script, previous.storage, previous.remote
  if not ok then
    io.stderr:write("milestones preset audit: remote.lua errored: " .. tostring(load_err) .. "\n")
    return 1
  end
  if not captured or not captured.milestones_presets then
    io.stderr:write("milestones preset audit: remote.lua did not register milestones_presets\n")
    return 1
  end

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
    "selection-tool",
    "blueprint",
    "blueprint-book",
    "deconstruction-item",
    "upgrade-item",
    "copy-paste-tool",
    "space-platform-starter-pack",
  }) do
    for name in pairs(data.raw[category] or {}) do
      items[name] = true
    end
  end

  local function entity_exists(name)
    for category, prototypes in pairs(data.raw) do
      if prototypes[name] and category ~= "recipe" and category ~= "technology" and not items[name] then
        return true
      end
    end
    return items[name] ~= nil
  end

  local findings, checked = 0, 0
  local function report(fmt, ...)
    io.stderr:write("  " .. string.format(fmt, ...) .. "\n")
    findings = findings + 1
  end

  script = { active_mods = mods }
  local got, presets = pcall(captured.milestones_presets)
  script = previous.script
  if not got then
    io.stderr:write("milestones preset audit: milestones_presets errored: " .. tostring(presets) .. "\n")
    return 1
  end

  for preset_name, preset in pairs(presets or {}) do
    for _, milestone in pairs(preset.milestones or {}) do
      local kind, name = milestone.type, milestone.name
      if type(name) == "string" then
        if kind == "item" then
          checked = checked + 1
          if not items[name] then
            report("%s: item %q does not exist", preset_name, name)
          end
        elseif kind == "fluid" then
          checked = checked + 1
          if not (data.raw.fluid or {})[name] then
            report("%s: fluid %q does not exist", preset_name, name)
          end
        elseif kind == "technology" then
          checked = checked + 1
          if not (data.raw.technology or {})[name] then
            report("%s: technology %q does not exist", preset_name, name)
          end
        elseif kind == "kill" then
          checked = checked + 1
          if not entity_exists(name) then
            report("%s: kill target %q does not exist", preset_name, name)
          end
        end
      end
    end
  end

  if findings == 0 then
    print(("milestones preset audit: all %d entries exist"):format(checked))
  end
  return findings
end
