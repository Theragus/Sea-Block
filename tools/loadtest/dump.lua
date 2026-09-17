-- Audit script: writes every loaded prototype name to LOADTEST_DUMP as
-- "<type>\t<name>" lines, for cross-referencing against source literals.
return function(data)
  local out_path = os.getenv("LOADTEST_DUMP") or "/tmp/prototypes.tsv"
  local fh = assert(io.open(out_path, "w"))
  local types = {}
  for proto_type in pairs(data.raw) do
    types[#types + 1] = proto_type
  end
  table.sort(types)
  local n = 0
  for _, proto_type in ipairs(types) do
    local names = {}
    for name in pairs(data.raw[proto_type]) do
      names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
      fh:write(proto_type, "\t", name, "\n")
      n = n + 1
    end
  end
  fh:close()
  print(("dumped %d prototype names to %s"):format(n, out_path))
  return 0
end
