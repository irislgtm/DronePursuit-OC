local computer = require("computer")

local M = {}

M.drones = {}
M.maxDrones = 16
M.heartbeatTimeout = 15

function M.init(savedDrones)
  if savedDrones then
    for addr, info in pairs(savedDrones) do
      M.drones[addr] = {
        address = addr,
        modemAddr = info.modemAddr or addr,
        state = "OFFLINE",
        x = info.x,
        y = info.y,
        z = info.z,
        energy = 0,
        maxEnergy = 0,
        energyPct = 0,
        target = nil,
        lastHeartbeat = 0,
        lastUpdate = 0,
        patrol = info.patrol or {},
        name = info.name or ("Drone-" .. M.count()),
      }
    end
  end
end

function M.count()
  local n = 0
  for _ in pairs(M.drones) do n = n + 1 end
  return n
end

function M.activeCount()
  local n = 0
  for _, d in pairs(M.drones) do
    if d.state ~= "OFFLINE" then n = n + 1 end
  end
  return n
end

function M.get(addr)
  return M.drones[addr]
end

function M.getAll()
  return M.drones
end

function M.getSorted()
  local sorted = {}
  for addr, d in pairs(M.drones) do
    d.address = addr
    sorted[#sorted + 1] = d
  end
  table.sort(sorted, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return sorted
end

function M.getByIndex(idx)
  local sorted = M.getSorted()
  return sorted[idx]
end

function M.register(addr, modemAddr)
  if M.drones[addr] then
    M.drones[addr].state = "IDLE"
    M.drones[addr].lastHeartbeat = computer.uptime()
    M.drones[addr].modemAddr = modemAddr or addr
    return M.drones[addr]
  end
  local n = M.count() + 1
  M.drones[addr] = {
    address = addr,
    modemAddr = modemAddr or addr,
    state = "IDLE",
    x = nil,
    y = nil,
    z = nil,
    energy = 0,
    maxEnergy = 0,
    energyPct = 0,
    target = nil,
    lastHeartbeat = computer.uptime(),
    lastUpdate = computer.uptime(),
    patrol = {},
    name = "Drone-" .. string.format("%02d", n),
  }
  return M.drones[addr]
end

function M.unregister(addr)
  M.drones[addr] = nil
end

function M.updatePosition(addr, x, y, z)
  local d = M.drones[addr]
  if d then
    d.x = x
    d.y = y
    d.z = z
    d.lastUpdate = computer.uptime()
  end
end

function M.updateStatus(addr, state, energy, maxEnergy)
  local d = M.drones[addr]
  if d then
    if state then d.state = state end
    if energy then
      d.energy = energy
      d.maxEnergy = maxEnergy or d.maxEnergy
      if d.maxEnergy > 0 then
        d.energyPct = math.floor(d.energy / d.maxEnergy * 100)
      end
    end
    d.lastUpdate = computer.uptime()
  end
end

function M.heartbeat(addr, uptime)
  local d = M.drones[addr]
  if d then
    d.lastHeartbeat = computer.uptime()
  end
end

function M.setTarget(addr, targetName)
  local d = M.drones[addr]
  if d then
    d.target = targetName
  end
end

function M.setState(addr, state)
  local d = M.drones[addr]
  if d then
    d.state = state
  end
end

function M.setPatrol(addr, waypoints)
  local d = M.drones[addr]
  if d then
    d.patrol = waypoints
  end
end

function M.findNearest(x, y, z, stateFilter)
  local best = nil
  local bestDist = math.huge
  for addr, d in pairs(M.drones) do
    if d.state ~= "OFFLINE" then
      local match = true
      if stateFilter and d.state ~= stateFilter then
        match = false
      end
      if match and d.x and d.y and d.z then
        local dx = d.x - x
        local dy = d.y - y
        local dz = d.z - z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist < bestDist then
          bestDist = dist
          best = addr
        end
      end
    end
  end
  return best, bestDist
end

function M.findIdle()
  for addr, d in pairs(M.drones) do
    if d.state == "IDLE" then
      return addr
    end
  end
  for addr, d in pairs(M.drones) do
    if d.state == "PATROL" then
      return addr
    end
  end
  return nil
end

function M.checkHeartbeats()
  local now = computer.uptime()
  local timedOut = {}
  for addr, d in pairs(M.drones) do
    if d.state ~= "OFFLINE" then
      if now - d.lastHeartbeat > M.heartbeatTimeout then
        d.state = "OFFLINE"
        timedOut[#timedOut + 1] = addr
      end
    end
  end
  return timedOut
end

function M.checkLowEnergy(threshold)
  local lowDrones = {}
  for addr, d in pairs(M.drones) do
    if d.state ~= "OFFLINE" and d.state ~= "RETURN" then
      if d.energyPct > 0 and d.energyPct < threshold then
        lowDrones[#lowDrones + 1] = addr
      end
    end
  end
  return lowDrones
end

function M.serialize()
  local out = {}
  for addr, d in pairs(M.drones) do
    out[addr] = {
      modemAddr = d.modemAddr,
      x = d.x,
      y = d.y,
      z = d.z,
      patrol = d.patrol,
      name = d.name,
    }
  end
  return out
end

function M.getFleetStats()
  local stats = {
    total = 0,
    active = 0,
    idle = 0,
    patrol = 0,
    pursuit = 0,
    returning = 0,
    offline = 0,
    avgEnergy = 0,
  }
  local energySum = 0
  local energyCount = 0
  for _, d in pairs(M.drones) do
    stats.total = stats.total + 1
    if d.state == "IDLE" then stats.idle = stats.idle + 1; stats.active = stats.active + 1
    elseif d.state == "PATROL" then stats.patrol = stats.patrol + 1; stats.active = stats.active + 1
    elseif d.state == "PURSUIT" then stats.pursuit = stats.pursuit + 1; stats.active = stats.active + 1
    elseif d.state == "RETURN" then stats.returning = stats.returning + 1; stats.active = stats.active + 1
    else stats.offline = stats.offline + 1 end
    if d.state ~= "OFFLINE" and d.energyPct > 0 then
      energySum = energySum + d.energyPct
      energyCount = energyCount + 1
    end
  end
  if energyCount > 0 then
    stats.avgEnergy = math.floor(energySum / energyCount)
  end
  return stats
end

return M
