-- Audit script: check every declared icon against the file on disk.
--
-- The headless build never loads sprites, so an icon whose declared icon_size
-- does not match the image sails through it and then kills the graphical
-- client with "the given sprite rectangle is outside the actual sprite size".
-- That is the one class of breakage the rest of this rig cannot see, and it
-- needs no renderer to catch: the answer is in the PNG header.
--
-- An icon file is either icon_size square or a horizontal mipmap strip of it
-- -- 64 + 32 + 16 + 8 = 120 wide for a 64px icon. What Factorio actually
-- rejects is a declared square that does not fit inside the image, so that is
-- what is checked: a file larger than declared is legal and left alone.

return function(data, mods, settings, resolve_path)
  if not resolve_path then
    io.stderr:write("icon audit: skipped, the harness did not provide a path resolver\n")
    return 0
  end

  local findings, checked = 0, 0
  local size_cache = {}
  -- wube/factorio-data ships no graphics, and a source checkout of any mod may
  -- be missing them too. Rather than guess, record per mod whether any icon
  -- resolved: a mod with graphics present that is still missing one file has a
  -- genuinely wrong path, which is exactly the bug worth catching.
  local mod_has_graphics = {}
  local deferred_missing = {}

  local function png_size(path)
    if size_cache[path] ~= nil then
      return size_cache[path]
    end
    local fh = io.open(path, "rb")
    if not fh then
      size_cache[path] = false
      return false
    end
    local header = fh:read(24)
    fh:close()
    if not header or #header < 24 or header:sub(1, 8) ~= "\137PNG\r\n\26\n" then
      size_cache[path] = false
      return false
    end
    local function be32(offset)
      local a, b, c, d = header:byte(offset, offset + 3)
      return ((a * 256 + b) * 256 + c) * 256 + d
    end
    local size = { width = be32(17), height = be32(21) }
    size_cache[path] = size
    return size
  end

  local function report(fmt, ...)
    io.stderr:write("  " .. string.format(fmt, ...) .. "\n")
    findings = findings + 1
  end

  local function check(owner, icon, icon_size)
    if type(icon) ~= "string" or not icon_size then
      return
    end
    local source_mod = icon:match("^__([^_]+[^/]*)__/")
    local path = resolve_path(icon)
    if not path then
      -- Unresolvable usually means the mod is not in this manifest, which the
      -- reference audits already cover; an icon audit should not double-report.
      return
    end
    local size = png_size(path)
    if not size then
      deferred_missing[#deferred_missing + 1] = { owner = owner, icon = icon, mod = source_mod }
      return
    end
    if source_mod then
      mod_has_graphics[source_mod] = true
    end
    checked = checked + 1
    -- Factorio only rejects an icon whose declared square does not fit inside
    -- the image: "the given sprite rectangle is outside the actual sprite
    -- size". A larger file is accepted, so it is not reported here.
    if icon_size > size.height or icon_size > size.width then
      report("%s: declares icon_size %d but %s is only %dx%d", owner, icon_size, icon, size.width, size.height)
    end
  end

  for category, prototypes in pairs(data.raw) do
    for name, prototype in pairs(prototypes) do
      if type(prototype) == "table" then
        local owner = ("%s %q"):format(category, name)
        check(owner, prototype.icon, prototype.icon_size)
        if type(prototype.icons) == "table" then
          for index, layer in ipairs(prototype.icons) do
            if type(layer) == "table" then
              check(("%s icons[%d]"):format(owner, index), layer.icon, layer.icon_size or prototype.icon_size)
            end
          end
        end
      end
    end
  end

  local absent_mods = 0
  for _, entry in ipairs(deferred_missing) do
    if entry.mod and mod_has_graphics[entry.mod] then
      report("%s: icon file does not exist: %s", entry.owner, entry.icon)
    else
      absent_mods = absent_mods + 1
    end
  end

  if absent_mods > 0 then
    print(("icon audit: skipped %d icons from mods whose graphics are not in this checkout"):format(absent_mods))
  end

  if findings == 0 then
    print(("icon audit: %d icons check out"):format(checked))
  else
    io.stderr:write(("\nicon audit: %d problem(s) across %d icons\n"):format(findings, checked))
  end
  return findings
end
