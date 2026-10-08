-- No visible technology may require a hidden or disabled one.
--
-- A hidden technology can never be researched, so neither can anything that
-- requires it, and Factorio does not draw hidden technologies in the tree: the
-- player sees every prerequisite green and is still told one is missing. That is
-- how Angel's 2.1 disabling bob-zinc-processing walled off assembling machine 3,
-- the environment farms and everything after blue science without any error.
--
-- data-final-fixes/hidden-prerequisites.lua repairs the cases it knows a
-- successor for. There are no exceptions: a technology behind content Sea Block
-- cuts on purpose (the equipment made from alien alloys) is hidden along with it
-- in data-updates/military.lua, so anything reported here is either missing a
-- successor or missing from that list.

return function(data, mods, settings)
  local function usable(technology)
    return not technology.hidden and technology.enabled ~= false
  end

  local findings = {}
  for name, technology in pairs(data.raw.technology) do
    if usable(technology) then
      for _, prerequisite in pairs(technology.prerequisites or {}) do
        local required = data.raw.technology[prerequisite]
        if required and not usable(required) then
          table.insert(findings, { name = name, on = prerequisite })
        end
      end
    end
  end

  table.sort(findings, function(a, b)
    return a.name < b.name or (a.name == b.name and a.on < b.on)
  end)

  for _, finding in ipairs(findings) do
    io.stderr:write(
      ("  technology %q requires hidden %q, so it can never be researched\n"):format(finding.name, finding.on)
    )
  end

  if #findings == 0 then
    print("hidden prerequisite audit: no visible technology requires a hidden one")
  else
    io.stderr:write(
      ("\nhidden prerequisite audit: %d visible technologies require a hidden one\n"):format(#findings)
    )
  end
  return #findings
end
