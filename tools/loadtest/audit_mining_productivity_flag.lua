-- seablock.trigger.mining_productivity is a public interface: another mod sets
-- it in data.lua and Sea Block then leaves the mining productivity
-- technologies visible, effects included (data-updates/misc.lua). Seablock
-- Mining relies on it to put mining productivity on Angel's crystallizers.
--
-- Upstream dropped the flag in a cleanup because nothing inside Sea Block set
-- it, which is the risk with any interface only outside mods use. So this
-- audit checks both directions, and ci.sh runs a configuration with
-- fixtures/sb-loadtest-mining-productivity, which sets the flag:
--
--   * flag set: every mining-productivity-N that exists must be visible and
--     keep its effects. A later pass hiding one again counts too.
--   * flag unset: they must stay hidden, as Sea Block intends without the
--     opt-in, so the flag cannot become a silent no-op the other way round.
return function(data)
  local flag = seablock and seablock.trigger and seablock.trigger.mining_productivity
  local findings, checked = 0, 0

  for i = 1, 4 do
    local name = "mining-productivity-" .. i
    local technology = data.raw.technology[name]
    if technology then
      checked = checked + 1
      local hidden = technology.hidden or technology.enabled == false
      if flag and hidden then
        io.stderr:write(("  %s is hidden although seablock.trigger.mining_productivity is set\n"):format(name))
        findings = findings + 1
      elseif flag and #(technology.effects or {}) == 0 then
        io.stderr:write(("  %s lost its effects although seablock.trigger.mining_productivity is set\n"):format(name))
        findings = findings + 1
      elseif not flag and not hidden then
        io.stderr:write(("  %s is visible although no mod set seablock.trigger.mining_productivity\n"):format(name))
        findings = findings + 1
      end
    end
  end

  if checked == 0 then
    io.stderr:write("  no mining-productivity technologies exist; the flag audit has nothing to check\n")
    findings = findings + 1
  end

  if findings == 0 then
    print(
      ("mining productivity flag audit: %d technologies %s, as the flag says"):format(
        checked,
        flag and "visible with their effects" or "hidden"
      )
    )
  else
    io.stderr:write(("\nmining productivity flag audit: %d finding(s)\n"):format(findings))
  end
  return findings
end
