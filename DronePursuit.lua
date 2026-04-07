package.path = "/home/DronePursuit/lib/?.lua;" .. package.path

local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local keyboard = require("keyboard")

package.loaded["lib/config"] = nil
package.loaded["lib/ui"] = nil
package.loaded["lib/net"] = nil
package.loaded["lib/fleet"] = nil
package.loaded["lib/pursuit"] = nil

local config = require("lib/config")
local ui = require("lib/ui")
local net = require("lib/net")
local fleet = require("lib/fleet")
local pursuit = require("lib/pursuit")

local running = true
local alerts = {}
local activityLog = {}
local dialogMode = nil
local dialogBuffer = ""
local dialogCallback = nil
local settingsField = 1
local settingsEdit = false
local settingsBuffer = ""
local settingsFieldCount = 13
local confirmCallback = nil

local function addAlert(severity, message)
  alerts[#alerts + 1] = {
    severity = severity,
    message = message,
    time = computer.uptime(),
    dismissed = false,
  }
  if #alerts > 200 then
    table.remove(alerts, 1)
  end
end

local function addActivity(kind, message)
  activityLog[#activityLog + 1] = {
    kind = kind,
    message = message,
    time = computer.uptime(),
  }
  if #activityLog > 200 then
    table.remove(activityLog, 1)
  end
end

local function dispatchDrone(targetName, x, y, z)
  local addr = fleet.findIdle()
  if not addr then
    addr = fleet.findNearest(x, y, z, "PATROL")
  end
  if not addr then
    addAlert("WARNING", "No available drones for dispatch")
    return false
  end
  local d = fleet.get(addr)
  net.sendGoto(d.modemAddr or addr, x, y, z)
  net.sendAssign(d.modemAddr or addr, targetName)
  net.sendColor(d.modemAddr or addr, 0xBF5AF2)
  fleet.setState(addr, "PURSUIT")
  fleet.setTarget(addr, targetName)
  pursuit.assignPursuit(addr, targetName, x, y, z)
  addActivity("dispatch", d.name .. " dispatched to pursue " .. targetName)
  addAlert("DETECT", "Pursuing " .. targetName .. " at " .. ui.formatPos(x, y, z))
  return true
end

local function recallDrone(addr)
  local d = fleet.get(addr)
  if not d then return end
  local cfg = config.data
  net.sendGoto(d.modemAddr or addr, cfg.baseX, cfg.baseY, cfg.baseZ)
  net.sendColor(d.modemAddr or addr, 0xFFD60A)
  fleet.setState(addr, "RETURN")
  fleet.setTarget(addr, nil)
  pursuit.clearPursuit(addr)
  addActivity("info", (d.name or "Drone") .. " recalled to base")
end

local function recallAll()
  for addr, d in pairs(fleet.getAll()) do
    if d.state ~= "OFFLINE" then
      recallDrone(addr)
    end
  end
end

local function handleDroneMessage(remoteAddr, cmd, payload, distance)
  if cmd == "BOOT" then
    local parts = {}
    if payload then
      for p in payload:gmatch("[^;]+") do
        parts[#parts + 1] = p
      end
    end
    local droneAddr = parts[1] or remoteAddr
    local modemAddr = parts[2] or remoteAddr
    local d = fleet.register(droneAddr, modemAddr)
    net.registerDrone(remoteAddr)
    addActivity("info", d.name .. " online (dist: " .. math.floor(distance or 0) .. ")")
    addAlert("INFO", d.name .. " connected")
    net.sendPing(modemAddr)

  elseif cmd == "POS" then
    local x, y, z = net.parsePos(payload)
    if x then
      local d = fleet.get(remoteAddr)
      if not d then
        for addr, dd in pairs(fleet.getAll()) do
          if dd.modemAddr == remoteAddr then
            d = dd
            remoteAddr = addr
            break
          end
        end
      end
      if d then
        fleet.updatePosition(remoteAddr, x, y, z)
      end
    end

  elseif cmd == "STATUS" then
    local status = net.parseStatus(payload)
    if status then
      local d = fleet.get(remoteAddr)
      if not d then
        for addr, dd in pairs(fleet.getAll()) do
          if dd.modemAddr == remoteAddr then
            d = dd
            remoteAddr = addr
            break
          end
        end
      end
      if d then
        fleet.updateStatus(remoteAddr, status.state, status.energy, status.maxEnergy)
      end
    end

  elseif cmd == "HEARTBEAT" then
    local d = fleet.get(remoteAddr)
    if not d then
      for addr, dd in pairs(fleet.getAll()) do
        if dd.modemAddr == remoteAddr then
          d = dd
          remoteAddr = addr
          break
        end
      end
    end
    if d then
      fleet.heartbeat(remoteAddr)
      if d.state == "OFFLINE" then
        fleet.setState(remoteAddr, "IDLE")
        addActivity("info", (d.name or "Drone") .. " reconnected")
      end
    end

  elseif cmd == "ALERT" then
    local parts = {}
    if payload then
      for p in payload:gmatch("[^;]+") do
        parts[#parts + 1] = p
      end
    end
    local alertType = parts[1] or "INFO"
    local alertMsg = parts[2] or payload or "Unknown alert"
    local d = fleet.get(remoteAddr)
    local droneName = d and d.name or "Unknown"
    addAlert(alertType, droneName .. ": " .. alertMsg)
    addActivity("alert", droneName .. " - " .. alertMsg)

  elseif cmd == "ACK" then
    local d = fleet.get(remoteAddr)
    if not d then
      for addr, dd in pairs(fleet.getAll()) do
        if dd.modemAddr == remoteAddr then
          d = dd
          break
        end
      end
    end
  end
end

local function handleMotion(_, addr, rx, ry, rz, entityName)
  if not entityName or entityName == "" then return end

  local cfg = config.data
  local absX = cfg.baseX + rx
  local absY = cfg.baseY + ry
  local absZ = cfg.baseZ + rz

  local isNew = pursuit.addDetection(entityName, absX, absY, absZ)

  if isNew then
    addActivity("detect", entityName .. " detected at " .. ui.formatPos(absX, absY, absZ))
    addAlert("DETECT", "Player \"" .. entityName .. "\" detected at " .. ui.formatPos(absX, absY, absZ))
  end

  if cfg.autoDispatch and not pursuit.isPursued(entityName) then
    dispatchDrone(entityName, absX, absY, absZ)
  end

  local updatedAddr = pursuit.updatePursuitTarget(entityName, absX, absY, absZ)
  if updatedAddr then
    local d = fleet.get(updatedAddr)
    if d and d.state == "PURSUIT" then
      net.sendGoto(d.modemAddr or updatedAddr, absX, absY, absZ)
    end
  end
end

local function periodicTick()
  local cfg = config.data

  local timedOut = fleet.checkHeartbeats()
  for _, addr in ipairs(timedOut) do
    local d = fleet.get(addr)
    addAlert("CRITICAL", (d and d.name or "Drone") .. " lost connection")
    addActivity("alert", (d and d.name or "Drone") .. " went offline")
    pursuit.clearPursuit(addr)
  end

  local lowDrones = fleet.checkLowEnergy(cfg.lowEnergyRecall)
  for _, addr in ipairs(lowDrones) do
    local d = fleet.get(addr)
    addAlert("WARNING", (d and d.name or "Drone") .. " low energy (" .. (d and d.energyPct or 0) .. "%)")
    recallDrone(addr)
  end

  local expired = pursuit.checkPursuitTimeouts()
  for _, addr in ipairs(expired) do
    local d = fleet.get(addr)
    if d and d.state == "PURSUIT" then
      fleet.setState(addr, "IDLE")
      fleet.setTarget(addr, nil)
      net.sendColor(d.modemAddr or addr, 0x30D158)
      addActivity("info", (d.name or "Drone") .. " pursuit timed out, now idle")
    end
  end

  pursuit.cleanOldDetections()

  config.set("drones", fleet.serialize())
end

local function renderUI()
  local uptime = computer.uptime()
  local fleetData = fleet.getAll()

  ui.fill(1, 4, ui.w, ui.h - 4, " ", nil, ui.colors.BG_PRIMARY)

  if ui.currentView == 1 then
    local hints = "Q: Quit  D: Deploy  R: Recall All  Space: Refresh  1-5: Views"
    ui.renderChrome(fleetData, uptime, hints)
    ui.renderDashboard(fleetData, alerts, activityLog, uptime)

  elseif ui.currentView == 2 then
    local hints = "D: Deploy  R: Recall  G: Goto  P: Patrol  Up/Down: Select  Q: Quit"
    ui.renderChrome(fleetData, uptime, hints)
    ui.renderFleet(fleetData, ui.selectedRow[2])

  elseif ui.currentView == 3 then
    local hints = "+/-: Zoom  Space: Refresh  Q: Quit"
    ui.renderChrome(fleetData, uptime, hints)
    ui.renderMap(fleetData, pursuit.getRecentDetections(), config.data)

  elseif ui.currentView == 4 then
    local hints = "Up/Down: Scroll  X: Dismiss  Space: Refresh  Q: Quit"
    ui.renderChrome(fleetData, uptime, hints)
    ui.renderAlerts(alerts, ui.scrollPos[4], ui.selectedRow[4])

  elseif ui.currentView == 5 then
    local hints = "Up/Down: Navigate  Enter: Edit  Tab: Toggle  Q: Quit"
    ui.renderChrome(fleetData, uptime, hints)
    ui.renderSettings(config.data, settingsField, settingsEdit, settingsBuffer)
  end

  if dialogMode == "input" then
    ui.renderInputDialog("Input", dialogBuffer, dialogBuffer)
  elseif dialogMode == "confirm" then
    ui.renderConfirmDialog("Confirm", dialogBuffer)
  end
end

local function getSettingsKeyByIndex(idx)
  local fields = {
    "port", "signalStrength", "heartbeatInterval",
    "autoDispatch", "lowEnergyRecall", "pursuitTimeout", "patrolRadius",
    "baseX", "baseY", "baseZ",
    "refreshRate", "mapScale",
  }
  return fields[idx]
end

local function getSettingsTypeByIndex(idx)
  local types = {
    "number", "number", "number",
    "bool", "number", "number", "number",
    "number", "number", "number",
    "number", "number",
  }
  return types[idx]
end

local function handleKeyDown(_, _, char, code, player)
  if dialogMode == "input" then
    if code == 28 then
      if dialogCallback then
        dialogCallback(dialogBuffer)
      end
      dialogMode = nil
      dialogBuffer = ""
      dialogCallback = nil
    elseif code == 1 then
      dialogMode = nil
      dialogBuffer = ""
      dialogCallback = nil
    elseif code == 14 then
      dialogBuffer = dialogBuffer:sub(1, -2)
    elseif char >= 32 and char < 127 then
      dialogBuffer = dialogBuffer .. string.char(char)
    end
    return
  end

  if dialogMode == "confirm" then
    if char == 121 or char == 89 then
      if confirmCallback then confirmCallback(true) end
      dialogMode = nil
      confirmCallback = nil
    elseif char == 110 or char == 78 or code == 1 then
      if confirmCallback then confirmCallback(false) end
      dialogMode = nil
      confirmCallback = nil
    end
    return
  end

  if settingsEdit and ui.currentView == 5 then
    if code == 28 then
      local key = getSettingsKeyByIndex(settingsField)
      local ftype = getSettingsTypeByIndex(settingsField)
      if key then
        if ftype == "number" then
          local val = tonumber(settingsBuffer)
          if val then
            config.set(key, val)
            if key == "signalStrength" then
              net.setStrength(val)
            end
          end
        elseif ftype == "bool" then
          config.set(key, settingsBuffer == "ON" or settingsBuffer == "true")
        end
      end
      settingsEdit = false
      settingsBuffer = ""
    elseif code == 1 then
      settingsEdit = false
      settingsBuffer = ""
    elseif code == 14 then
      settingsBuffer = settingsBuffer:sub(1, -2)
    elseif char >= 32 and char < 127 then
      settingsBuffer = settingsBuffer .. string.char(char)
    end
    return
  end

  if char == 113 or char == 81 then
    dialogMode = "confirm"
    dialogBuffer = "Shut down DronePursuit?"
    confirmCallback = function(yes)
      if yes then running = false end
    end
    return
  end

  if code >= 2 and code <= 6 then
    ui.currentView = code - 1
    return
  end

  if code == 15 then
    ui.currentView = (ui.currentView % 5) + 1
    return
  end

  if ui.currentView == 2 then
    local sorted = fleet.getSorted()
    local maxRow = #sorted

    if code == 200 then
      ui.selectedRow[2] = math.max(1, (ui.selectedRow[2] or 1) - 1)
    elseif code == 208 then
      ui.selectedRow[2] = math.min(maxRow, (ui.selectedRow[2] or 1) + 1)
    elseif char == 100 or char == 68 then
      net.broadcast("PING")
      addActivity("info", "Discovery ping broadcast sent")
    elseif char == 114 or char == 82 then
      local d = fleet.getByIndex(ui.selectedRow[2])
      if d then
        recallDrone(d.address)
      end
    elseif char == 103 or char == 71 then
      local d = fleet.getByIndex(ui.selectedRow[2])
      if d then
        dialogMode = "input"
        dialogBuffer = ""
        dialogCallback = function(input)
          local x, y, z = input:match("([%-]?%d+)[%s,]+([%-]?%d+)[%s,]+([%-]?%d+)")
          if x then
            net.sendGoto(d.modemAddr or d.address, tonumber(x), tonumber(y), tonumber(z))
            fleet.setState(d.address, "PATROL")
            addActivity("dispatch", d.name .. " sent to " .. ui.formatPos(tonumber(x), tonumber(y), tonumber(z)))
          end
        end
      end
    elseif char == 112 or char == 80 then
      local d = fleet.getByIndex(ui.selectedRow[2])
      if d then
        dialogMode = "input"
        dialogBuffer = ""
        dialogCallback = function(input)
          local waypoints = net.parsePatrolWaypoints(input)
          if #waypoints > 0 then
            net.sendPatrol(d.modemAddr or d.address, waypoints)
            fleet.setPatrol(d.address, waypoints)
            fleet.setState(d.address, "PATROL")
            net.sendColor(d.modemAddr or d.address, 0x0A84FF)
            addActivity("info", d.name .. " patrol route set (" .. #waypoints .. " waypoints)")
          end
        end
      end
    end

  elseif ui.currentView == 3 then
    if char == 43 or char == 61 then
      local s = config.get("mapScale")
      if s > 1 then config.set("mapScale", s - 1) end
    elseif char == 45 then
      local s = config.get("mapScale")
      config.set("mapScale", s + 1)
    end

  elseif ui.currentView == 4 then
    if code == 200 then
      ui.scrollPos[4] = math.min(#alerts - 1, (ui.scrollPos[4] or 0) + 1)
    elseif code == 208 then
      ui.scrollPos[4] = math.max(0, (ui.scrollPos[4] or 0) - 1)
    elseif char == 120 or char == 88 then
      if #alerts > 0 then
        local idx = #alerts - (ui.scrollPos[4] or 0)
        if idx >= 1 and idx <= #alerts then
          alerts[idx].dismissed = true
        end
      end
    end

  elseif ui.currentView == 5 then
    if code == 200 then
      settingsField = math.max(1, settingsField - 1)
    elseif code == 208 then
      settingsField = math.min(settingsFieldCount - 1, settingsField + 1)
    elseif code == 28 then
      local key = getSettingsKeyByIndex(settingsField)
      local ftype = getSettingsTypeByIndex(settingsField)
      if ftype == "bool" then
        local cur = config.get(key)
        config.set(key, not cur)
      else
        settingsEdit = true
        settingsBuffer = tostring(config.get(key) or "")
      end
    elseif code == 15 then
      local key = getSettingsKeyByIndex(settingsField)
      local ftype = getSettingsTypeByIndex(settingsField)
      if ftype == "bool" then
        local cur = config.get(key)
        config.set(key, not cur)
      end
    end
  end

  if char == 32 then
    for addr, d in pairs(fleet.getAll()) do
      if d.state ~= "OFFLINE" then
        net.sendPing(d.modemAddr or addr)
      end
    end
  end
end

local function main()
  config.load()
  local cfg = config.data

  ui.init()
  ui.renderSplash()
  os.sleep(1.5)

  local modemOk = net.init(cfg.port)
  if not modemOk then
    ui.clear()
    ui.text(3, 3, "ERROR: No modem component found!", ui.colors.RED)
    ui.text(3, 5, "Install a wireless network card and restart.", ui.colors.FG_SECONDARY)
    os.sleep(5)
    return
  end

  if cfg.signalStrength then
    net.setStrength(cfg.signalStrength)
  end

  fleet.init(cfg.drones)
  fleet.heartbeatTimeout = (cfg.heartbeatInterval or 5) * 3
  pursuit.init(cfg)

  net.onMessage = handleDroneMessage
  net.startListening()

  if component.isAvailable("motion_sensor") then
    event.listen("motion", handleMotion)
  end

  addActivity("info", "DronePursuit initialized")
  addAlert("INFO", "System online - " .. fleet.count() .. " drone(s) registered")

  net.broadcast("PING")
  addActivity("info", "Discovery ping broadcast sent")

  local lastTick = computer.uptime()
  local lastRender = 0

  ui.clear()

  while running do
    local now = computer.uptime()

    if now - lastTick >= (cfg.heartbeatInterval or 5) then
      periodicTick()
      lastTick = now
    end

    if now - lastRender >= (cfg.refreshRate or 1) then
      renderUI()
      lastRender = now
    end

    local sig = {event.pull(0.5)}
    if sig[1] == "key_down" then
      handleKeyDown(table.unpack(sig))
      renderUI()
      lastRender = computer.uptime()
    elseif sig[1] == "touch" then
      local sx, sy = sig[3], sig[4]
      if sy == 2 then
        local x = 2
        for i = 1, 5 do
          local label = "[" .. i .. "] " .. ui.viewNames[i]
          local w = #label + 3
          if sx >= x and sx < x + w then
            ui.currentView = i
            break
          end
          x = x + w
        end
      end
    elseif sig[1] == "interrupted" then
      running = false
    end
  end

  net.shutdown()
  if component.isAvailable("motion_sensor") then
    event.ignore("motion", handleMotion)
  end
  config.set("drones", fleet.serialize())

  ui.clear()
  ui.text(3, 3, "DronePursuit shut down.", ui.colors.FG_SECONDARY)
  term.setCursor(1, 5)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  term.clear()
  io.stderr:write("DronePursuit Error: " .. tostring(err) .. "\n")
end
