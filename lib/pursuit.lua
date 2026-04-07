local computer = require("computer")

local M = {}

M.detections = {}
M.maxDetections = 64
M.trackTimeout = 60
M.pursuitTimeout = 120
M.pursuitAssignments = {}
M.onAlert = nil
M.onDispatch = nil

function M.init(cfg)
  M.pursuitTimeout = cfg.pursuitTimeout or 120
end

function M.addDetection(name, x, y, z)
  local now = computer.uptime()
  local found = false
  for i, det in ipairs(M.detections) do
    if det.name == name then
      det.x = x
      det.y = y
      det.z = z
      det.lastSeen = now
      det.count = det.count + 1
      found = true
      break
    end
  end
  if not found then
    if #M.detections >= M.maxDetections then
      table.remove(M.detections, 1)
    end
    M.detections[#M.detections + 1] = {
      name = name,
      x = x,
      y = y,
      z = z,
      firstSeen = now,
      lastSeen = now,
      count = 1,
    }
  end
  return not found
end

function M.getDetection(name)
  for _, det in ipairs(M.detections) do
    if det.name == name then
      return det
    end
  end
  return nil
end

function M.getRecentDetections(maxAge)
  maxAge = maxAge or M.trackTimeout
  local now = computer.uptime()
  local recent = {}
  for _, det in ipairs(M.detections) do
    if now - det.lastSeen <= maxAge then
      recent[#recent + 1] = det
    end
  end
  return recent
end

function M.assignPursuit(droneAddr, playerName, x, y, z)
  M.pursuitAssignments[droneAddr] = {
    target = playerName,
    x = x,
    y = y,
    z = z,
    assignedAt = computer.uptime(),
  }
end

function M.clearPursuit(droneAddr)
  M.pursuitAssignments[droneAddr] = nil
end

function M.getPursuit(droneAddr)
  return M.pursuitAssignments[droneAddr]
end

function M.getActivePursuits()
  return M.pursuitAssignments
end

function M.isPursued(playerName)
  for _, p in pairs(M.pursuitAssignments) do
    if p.target == playerName then
      return true
    end
  end
  return false
end

function M.checkPursuitTimeouts()
  local now = computer.uptime()
  local expired = {}
  for addr, p in pairs(M.pursuitAssignments) do
    if now - p.assignedAt > M.pursuitTimeout then
      expired[#expired + 1] = addr
    end
  end
  for _, addr in ipairs(expired) do
    M.pursuitAssignments[addr] = nil
  end
  return expired
end

function M.updatePursuitTarget(playerName, x, y, z)
  for addr, p in pairs(M.pursuitAssignments) do
    if p.target == playerName then
      p.x = x
      p.y = y
      p.z = z
      return addr
    end
  end
  return nil
end

function M.cleanOldDetections()
  local now = computer.uptime()
  local kept = {}
  for _, det in ipairs(M.detections) do
    if now - det.lastSeen <= M.trackTimeout * 3 then
      kept[#kept + 1] = det
    end
  end
  M.detections = kept
end

function M.calculateIntercept(targetX, targetZ, prevX, prevZ, droneX, droneZ, droneSpeed)
  if not prevX or not prevZ then
    return targetX, targetZ
  end
  local vx = targetX - prevX
  local vz = targetZ - prevZ
  return targetX + vx * 2, targetZ + vz * 2
end

return M
