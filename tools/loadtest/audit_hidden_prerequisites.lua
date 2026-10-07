-- No visible technology may require a hidden or disabled one.
--
-- A hidden technology can never be researched, so neither can anything that
-- requires it, and Factorio does not draw hidden technologies in the tree: the
-- player sees every prerequisite green and is still told one is missing. That is
-- how Angel's 2.1 disabling bob-zinc-processing walled off assembling machine 3,
-- the environment farms and everything after blue science without any error.
--
-- data-final-fixes/hidden-prerequisites.lua repairs the cases it knows a
-- successor for. The prerequisites below are left in place on purpose: their
-- content is cut from Sea Block, and the equipment that requires them is made
-- from materials Sea Block removed, so it stays out of reach. They are counted
-- and reported rather than hidden, so a new technology walled off behind one of
-- them still shows up here.

return function(data, mods, settings)
  local cut = {
    -- data-updates/military.lua: no alien artifacts without biter nests
    ["bob-alien-research"] = true,
    ["bob-alien-blue-research"] = true,
    ["bob-alien-green-research"] = true,
    ["bob-alien-orange-research"] = true,
    ["bob-alien-purple-research"] = true,
    ["bob-alien-red-research"] = true,
    ["bob-alien-yellow-research"] = true,
    -- data-updates/military.lua: the explosives chain past nitroglycerin is hidden,
    -- and Angel's Explosives 3 unlocks only hidden recipes
    ["angels-explosives-2"] = true,
    -- Bob's nuclear fuels beyond uranium and its heavy water are not in the pack
    ["bob-heavy-water-processing"] = true,
    ["bob-nuclear-power-2"] = true,
    ["bob-plutonium-fuel-cell"] = true,
    ["bob-thorium-plutonium-fuel-cell"] = true,
  }

  local function usable(technology)
    return not technology.hidden and technology.enabled ~= false
  end

  local findings, behind_cut = {}, 0
  for name, technology in pairs(data.raw.technology) do
    if usable(technology) then
      for _, prerequisite in pairs(technology.prerequisites or {}) do
        local required = data.raw.technology[prerequisite]
        if required and not usable(required) then
          if cut[prerequisite] then
            behind_cut = behind_cut + 1
          else
            table.insert(findings, { name = name, on = prerequisite })
          end
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
    print(
      ("hidden prerequisite audit: no visible technology requires a hidden one (%d behind cut content, left alone)"):format(
        behind_cut
      )
    )
  else
    io.stderr:write(
      ("\nhidden prerequisite audit: %d visible technologies require a hidden one\n"):format(#findings)
    )
  end
  return #findings
end
