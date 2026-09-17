-- Sea Block must not gate a trigger technology that unlocks nothing behind its
-- own startup chain.
--
-- Factorio holds a satisfied research trigger at 99% with a full progress bar
-- while a prerequisite is unresearched, and still labels the technology
-- available. That is indistinguishable from a broken research. It is what
-- electronics did: "craft 10 copper plate" is satisfied in the first minute,
-- but Sea Block had gated it behind angels-slag-processing-1, so it sat at 99%
-- for hours with no way to tell why.
--
-- The check is deliberately limited to gates Sea Block itself adds to
-- technologies that unlock nothing, because that is the only case where the
-- gate is both Sea Block's doing and free to remove: it grants nothing early,
-- and its successors carry their own prerequisites.
--
-- The cases left alone, and why, since they look identical from here:
--
--   * upstream's own gates. Vanilla gives automation-science-pack both a
--     "craft a lab" trigger and prerequisites of steam-power and electronics.
--     It stalls the same way in Sea Block, but removing those prerequisites
--     would release four technologies that name it as their only prerequisite
--     into the startup tutorial. The wait is load-bearing.
--
--   * triggers that cannot be met early anyway. space-science-pack is
--     triggered by sending a satellite to orbit, which needs the rocket silo
--     it is gated behind, so it never sits at 99% in the first place.
--
-- Both are counted and reported rather than hidden, so a change in either
-- shows up here instead of in someone's game.

return function(data, mods, settings)
  local gates = {
    ["angels-slag-processing-1"] = true, -- seablock.final_startup_tech
    ["sb-startup4"] = true, -- seablock.final_scripted_tech, without SCT
    ["sct-automation-science-pack"] = true, -- ... and with it
  }

  local stalled, total, upstream_gated = {}, 0, 0

  for name, technology in pairs(data.raw.technology) do
    local visible = not technology.hidden and (technology.enabled == nil or technology.enabled == true)
    if visible and technology.research_trigger then
      total = total + 1
      local prerequisites = technology.prerequisites or {}
      if #prerequisites > 0 and #(technology.effects or {}) == 0 then
        if #prerequisites == 1 and gates[prerequisites[1]] then
          table.insert(stalled, { name = name, on = prerequisites[1] })
        else
          upstream_gated = upstream_gated + 1
        end
      end
    end
  end

  table.sort(stalled, function(a, b)
    return a.name < b.name
  end)

  for _, tech in ipairs(stalled) do
    io.stderr:write(
      ("  technology %q unlocks nothing but Sea Block gates it behind %s, so it will sit at 99%%\n"):format(
        tech.name,
        tech.on
      )
    )
  end

  if #stalled == 0 then
    print(
      ("trigger tech audit: none of %d trigger technologies stall on a Sea Block gate (%d gated upstream, left alone)"):format(
        total,
        upstream_gated
      )
    )
  else
    io.stderr:write(("\ntrigger tech audit: %d of %d trigger technologies will stall at 99%%\n"):format(#stalled, total))
  end
  return #stalled
end
