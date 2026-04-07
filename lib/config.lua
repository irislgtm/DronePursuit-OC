local filesystem = require("filesystem")
local serialization = require("serialization")

local M = {}

M.defaults = {
  port = 7331,
  signalStrength = 400,
  heartbeatInterval = 5,
  autoDispatch = true,
  lowEnergyRecall = 15,
  pursuitTimeout = 120,
  patrolRadius = 32,
  refreshRate = 1,
  mapScale = 4,
  baseX = 0,
  baseY = 64,
  baseZ = 0,
  drones = {},
  patrols = {},
  watchlist = {},
}

M.path = "/home/DronePursuit/config.dat"
M.data = {}

function M.load()
  M.data = {}
  for k, v in pairs(M.defaults) do
    if type(v) == "table" then
      M.data[k] = {}
      for kk, vv in pairs(v) do
        M.data[k][kk] = vv
      end
    else
      M.data[k] = v
    end
  end
  if filesystem.exists(M.path) then
    local f = io.open(M.path, "r")
    if f then
      local raw = f:read("*a")
      f:close()
      local ok, loaded = pcall(serialization.unserialize, raw)
      if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do
          M.data[k] = v
        end
      end
    end
  end
  return M.data
end

function M.save()
  local dir = filesystem.path(M.path)
  if not filesystem.isDirectory(dir) then
    filesystem.makeDirectory(dir)
  end
  local f = io.open(M.path, "w")
  if f then
    f:write(serialization.serialize(M.data))
    f:close()
  end
end

function M.get(key)
  return M.data[key]
end

function M.set(key, value)
  M.data[key] = value
  M.save()
end

return M
