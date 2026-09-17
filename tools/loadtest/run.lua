-- Runs Factorio's data stage outside the game.
--
-- Loads core/lualib and every enabled mod's settings.lua, data.lua,
-- data-updates.lua and data-final-fixes.lua in dependency order, using the
-- real dataloader from wube/factorio-data. Anything that would crash Factorio
-- on startup (nil prototype access, bad data:extend, missing require) crashes
-- here with the same message.
--
-- Usage: lua5.2 run.lua <manifest.lua> [audit.lua ...]

local manifest_path = arg[1]
if not manifest_path then
  io.stderr:write("usage: run.lua <manifest.lua> [audit script ...]\n")
  os.exit(2)
end

local here = manifest_path:match("^(.*)/[^/]*$") or "."
local script_dir = arg[0]:match("^(.*)/[^/]*$") or "."

local mods_list = dofile(manifest_path)

local mod_path = {}
for _, m in ipairs(mods_list) do
  mod_path[m.name] = m.path
end

local core_path = assert(mod_path["core"], "the core mod must be present in the manifest")
local lualib = core_path .. "/lualib"

---------------------------------------------------------------------------
-- engine globals
---------------------------------------------------------------------------
local env = dofile(script_dir .. "/env.lua")
serpent = env.serpent
defines = env.defines
table_size = env.table_size
feature_flags = env.feature_flags
env.install_permissive_table_insert()
if os.getenv("LOADTEST_DETERMINISTIC") then
  env.install_deterministic_pairs()
end

mods = {}
for _, m in ipairs(mods_list) do
  if m.name ~= "core" then
    mods[m.name] = m.version
  end
end

local log_lines = {}
local echo_log = os.getenv("LOADTEST_ECHO_LOG")
function log(msg)
  log_lines[#log_lines + 1] = tostring(msg)
  if echo_log and tostring(msg):find(echo_log, 1, true) then
    io.stderr:write(tostring(msg) .. "\n")
  end
end

---------------------------------------------------------------------------
-- Factorio's require
--
--   require("foo.bar")            -> <current mod>/foo/bar.lua, else core/lualib
--   require("__other__/foo/bar")  -> <other mod>/foo/bar.lua
--
-- Dots and slashes are interchangeable. The module cache is keyed by resolved
-- absolute path, which gives each mod its own namespace for same-named files
-- exactly as the game does.
---------------------------------------------------------------------------
local mod_stack = {}
local dir_stack = {}
local module_cache = {}

local function current_mod()
  return mod_stack[#mod_stack]
end

local function current_dir()
  return dir_stack[#dir_stack]
end

local function file_exists(path)
  local fh = io.open(path, "r")
  if fh then
    fh:close()
    return true
  end
  return false
end

local function resolve(name)
  local normalised = name:gsub("%.", "/")
  -- strip a trailing .lua the caller may have included
  normalised = normalised:gsub("%.lua$", "")

  local explicit_mod, rest = normalised:match("^__([^_]+[^/]*)__/?(.*)$")
  if explicit_mod then
    local root = mod_path[explicit_mod]
    if not root then
      return nil, "no such mod: " .. explicit_mod
    end
    local path = root .. "/" .. rest .. ".lua"
    if file_exists(path) then
      return path
    end
    return nil, "not found: " .. path
  end

  local tried = {}

  local dir = current_dir()
  if dir then
    local path = dir .. "/" .. normalised .. ".lua"
    if file_exists(path) then
      return path
    end
    tried[#tried + 1] = path
  end

  local mod = current_mod()
  if mod then
    local path = mod_path[mod] .. "/" .. normalised .. ".lua"
    if file_exists(path) then
      return path
    end
    tried[#tried + 1] = path
  end

  local path = lualib .. "/" .. normalised .. ".lua"
  if file_exists(path) then
    return path
  end
  tried[#tried + 1] = path

  return nil, "not found in any of:\n    " .. table.concat(tried, "\n    ")
end

local function owning_mod(path)
  for name, root in pairs(mod_path) do
    if path:sub(1, #root + 1) == root .. "/" then
      return name
    end
  end
  return current_mod()
end

-- wube/factorio-data ships no graphics, so the per-sprite metadata files that
-- util.sprite_load requires are absent. Nothing in a recipe/technology audit
-- depends on sprite geometry, so hand back plausible defaults instead.
local sprite_stub_cache = {}
local function sprite_stub(name)
  if not sprite_stub_cache[name] then
    sprite_stub_cache[name] = {
      width = 64,
      height = 64,
      shift = { 0, 0 },
      line_length = 1,
      frames = 1,
      scale = 0.5,
      filename = name .. ".png",
    }
  end
  return sprite_stub_cache[name]
end

local function is_graphics_path(name)
  local normalised = "/" .. name:gsub("%.", "/")
  return normalised:find("/graphics/", 1, true) ~= nil
end

-- Other content wube strips from the public data repo. Indexing these yields
-- nil, which is what the base mod's optional lookups already tolerate.
local stripped_assets = {
  ["menu%-simulations"] = true,
  ["tutorials"] = true,
}

local function is_stripped_asset(name)
  local normalised = "/" .. name:gsub("%.", "/")
  for pattern in pairs(stripped_assets) do
    if normalised:find("/" .. pattern .. "/") then
      return true
    end
  end
  return false
end

function require(name)
  local path, err = resolve(name)
  if not path then
    if is_graphics_path(name) then
      return sprite_stub(name)
    end
    if is_stripped_asset(name) then
      return {}
    end
    error("module '" .. name .. "' " .. err, 2)
  end
  if module_cache[path] ~= nil then
    return module_cache[path]
  end
  -- Mark before running so a self-referential require does not recurse.
  module_cache[path] = true
  local chunk, load_err = loadfile(path)
  if not chunk then
    error("could not load " .. path .. ": " .. tostring(load_err), 2)
  end
  mod_stack[#mod_stack + 1] = owning_mod(path)
  dir_stack[#dir_stack + 1] = path:match("^(.*)/[^/]*$")
  local ok, result = xpcall(chunk, function(e)
    -- Capture the traceback here, at the point of failure: re-raising through
    -- nested requires would otherwise discard every frame below this one.
    if type(e) == "string" and e:find("\nstack traceback:", 1, true) then
      return e
    end
    return tostring(e) .. "\nstack traceback:\n" .. debug.traceback("", 2)
  end, name)
  mod_stack[#mod_stack] = nil
  dir_stack[#dir_stack] = nil
  if not ok then
    module_cache[path] = nil
    error(result, 0)
  end
  if result ~= nil then
    module_cache[path] = result
  end
  return module_cache[path]
end

---------------------------------------------------------------------------
-- stage running
---------------------------------------------------------------------------
local failures = {}

local function run_stage(stage)
  for _, m in ipairs(mods_list) do
    local path = m.path .. "/" .. stage .. ".lua"
    if file_exists(path) then
      mod_stack[#mod_stack + 1] = m.name
      dir_stack[#dir_stack + 1] = m.path
      local chunk, load_err = loadfile(path)
      if not chunk then
        failures[#failures + 1] = { mod = m.name, stage = stage, err = tostring(load_err) }
      else
        local ok, err = xpcall(chunk, function(e)
          return tostring(e) .. "\n" .. debug.traceback("", 2)
        end)
        if not ok then
          failures[#failures + 1] = { mod = m.name, stage = stage, err = err }
        end
      end
      mod_stack[#mod_stack] = nil
      dir_stack[#dir_stack] = nil
      if #failures > 0 then
        -- A failed stage leaves data.raw inconsistent; stop like the game does.
        return false
      end
    end
  end
  return true
end

local function report_and_exit()
  for _, f in ipairs(failures) do
    io.stderr:write(("\n=== %s :: %s.lua ===\n%s\n"):format(f.mod, f.stage, f.err))
  end
  io.stderr:write(("\n%d stage failure(s)\n"):format(#failures))
  os.exit(1)
end

-- Settings stage ----------------------------------------------------------
require("dataloader")

for _, stage in ipairs({ "settings", "settings-updates", "settings-final-fixes" }) do
  if not run_stage(stage) then
    report_and_exit()
  end
end

settings = { startup = {}, global = {}, player = {} }
local setting_types = {
  ["bool-setting"] = true,
  ["int-setting"] = true,
  ["double-setting"] = true,
  ["string-setting"] = true,
  ["color-setting"] = true,
}
local startup_count = 0
for proto_type in pairs(setting_types) do
  for name, proto in pairs(data.raw[proto_type] or {}) do
    local bucket = proto.setting_type == "runtime-global" and settings.global
      or proto.setting_type == "runtime-per-user" and settings.player
      or settings.startup
    -- forced_value wins over default_value: a mod that sets it is pinning the
    -- setting regardless of what the player chose, which is how Sea Block
    -- locks down Bob's and Angel's options.
    local value = proto.default_value
    if proto.forced_value ~= nil then
      value = proto.forced_value
    end
    bucket[name] = { value = value }
    if bucket == settings.startup then
      startup_count = startup_count + 1
    end
  end
end

-- Data stage --------------------------------------------------------------
-- Settings prototypes live in a separate data.raw from the data stage.
data.raw = {}
module_cache = {}
require("dataloader")

-- LOADTEST_STOP_AFTER lets an audit inspect data.raw part-way through the
-- data stage, which is how you find which mod introduced malformed data when
-- a later mod is the one that crashes on it.
local stop_after = os.getenv("LOADTEST_STOP_AFTER")
for _, stage in ipairs({ "data", "data-updates", "data-final-fixes" }) do
  if not run_stage(stage) then
    report_and_exit()
  end
  if stop_after == stage then
    io.stderr:write("stopping after " .. stage .. " stage as requested\n")
    break
  end
end

local prototype_count = 0
local type_count = 0
for _, protos in pairs(data.raw) do
  type_count = type_count + 1
  for _ in pairs(protos) do
    prototype_count = prototype_count + 1
  end
end

print(
  ("data stage OK: %d mods, %d startup settings, %d prototypes across %d types"):format(
    #mods_list,
    startup_count,
    prototype_count,
    type_count
  )
)

---------------------------------------------------------------------------
-- audits
---------------------------------------------------------------------------
local audit_failures = 0
-- Resolve a "__mod__/path" reference to a real file, for audits that need to
-- look at an asset rather than a prototype.
local function resolve_asset(reference)
  local mod, rest = reference:match("^__([^_]+[^/]*)__/(.*)$")
  if not mod or not mod_path[mod] then
    return nil
  end
  return mod_path[mod] .. "/" .. rest
end

-- An audit script returns a function(data, mods, settings, resolve_asset) ->
-- number of findings. Returning a bare number from the chunk also works.
for i = 2, #arg do
  local chunk = assert(loadfile(arg[i]))
  local result = chunk(data, mods, settings, resolve_asset)
  if type(result) == "function" then
    result = result(data, mods, settings, resolve_asset)
  end
  audit_failures = audit_failures + (tonumber(result) or 0)
end

if audit_failures > 0 then
  io.stderr:write(("\n%d audit finding(s)\n"):format(audit_failures))
  os.exit(1)
end
