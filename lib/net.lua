local component = require("component")
local event = require("event")
local serialization = require("serialization")

local M = {}

M.PORT = 7331
M.modem = nil
M.registered = {}
M.onMessage = nil
M.messageLog = {}

function M.init(port)
  M.PORT = port or M.PORT
  if component.isAvailable("modem") then
    M.modem = component.modem
    M.modem.open(M.PORT)
    if M.modem.isWireless() then
      M.modem.setStrength(400)
    end
    return true
  end
  return false
end

function M.setStrength(val)
  if M.modem and M.modem.isWireless() then
    M.modem.setStrength(val)
  end
end

function M.registerDrone(addr)
  M.registered[addr] = true
end

function M.unregisterDrone(addr)
  M.registered[addr] = nil
end

function M.isRegistered(addr)
  return M.registered[addr] == true
end

function M.encode(cmd, payload)
  if payload then
    return cmd .. ":" .. payload
  end
  return cmd
end

function M.decode(raw)
  if not raw or type(raw) ~= "string" then return nil, nil end
  local sep = raw:find(":")
  if sep then
    return raw:sub(1, sep - 1), raw:sub(sep + 1)
  end
  return raw, nil
end

function M.send(addr, cmd, payload)
  if not M.modem then return false end
  local msg = M.encode(cmd, payload)
  M.modem.send(addr, M.PORT, msg)
  M.messageLog[#M.messageLog + 1] = {
    time = require("computer").uptime(),
    dir = "OUT",
    addr = addr,
    cmd = cmd,
    payload = payload,
  }
  return true
end

function M.broadcast(cmd, payload)
  if not M.modem then return false end
  local msg = M.encode(cmd, payload)
  M.modem.broadcast(M.PORT, msg)
  return true
end

function M.sendGoto(addr, x, y, z)
  return M.send(addr, "GOTO", string.format("%d,%d,%d", math.floor(x), math.floor(y), math.floor(z)))
end

function M.sendPatrol(addr, waypoints)
  local parts = {}
  for _, wp in ipairs(waypoints) do
    parts[#parts + 1] = string.format("%d,%d,%d", math.floor(wp[1]), math.floor(wp[2]), math.floor(wp[3]))
  end
  return M.send(addr, "PATROL", table.concat(parts, ";"))
end

function M.sendRTB(addr)
  return M.send(addr, "RTB")
end

function M.sendHalt(addr)
  return M.send(addr, "HALT")
end

function M.sendColor(addr, rgb)
  return M.send(addr, "COLOR", tostring(rgb))
end

function M.sendPing(addr)
  return M.send(addr, "PING")
end

function M.sendAssign(addr, playerName)
  return M.send(addr, "ASSIGN", playerName)
end

function M.sendReboot(addr)
  return M.send(addr, "REBOOT")
end

function M.parsePos(payload)
  if not payload then return nil, nil, nil end
  local x, y, z = payload:match("([%-]?%d+),([%-]?%d+),([%-]?%d+)")
  if x then return tonumber(x), tonumber(y), tonumber(z) end
  return nil, nil, nil
end

function M.parseStatus(payload)
  if not payload then return nil end
  local parts = {}
  for p in payload:gmatch("[^;]+") do
    parts[#parts + 1] = p
  end
  return {
    state = parts[1],
    energy = tonumber(parts[2]),
    maxEnergy = tonumber(parts[3]),
  }
end

function M.parsePatrolWaypoints(payload)
  if not payload then return {} end
  local waypoints = {}
  for wp in payload:gmatch("[^;]+") do
    local x, y, z = wp:match("([%-]?%d+),([%-]?%d+),([%-]?%d+)")
    if x then
      waypoints[#waypoints + 1] = {tonumber(x), tonumber(y), tonumber(z)}
    end
  end
  return waypoints
end

function M.handleModemMessage(_, localAddr, remoteAddr, port, distance, raw)
  if port ~= M.PORT then return end

  local cmd, payload = M.decode(raw)
  if not cmd then return end

  M.messageLog[#M.messageLog + 1] = {
    time = require("computer").uptime(),
    dir = "IN",
    addr = remoteAddr,
    cmd = cmd,
    payload = payload,
    distance = distance,
  }

  local trusted = M.isRegistered(remoteAddr)

  if cmd == "BOOT" and not trusted then
    M.registerDrone(remoteAddr)
    trusted = true
  end

  if not trusted then
    return
  end

  if M.onMessage then
    M.onMessage(remoteAddr, cmd, payload, distance)
  end
end

function M.startListening()
  event.listen("modem_message", M.handleModemMessage)
end

function M.stopListening()
  event.ignore("modem_message", M.handleModemMessage)
end

function M.shutdown()
  M.stopListening()
  if M.modem then
    M.modem.close(M.PORT)
  end
end

return M
