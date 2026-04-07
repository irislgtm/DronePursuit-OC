local component = require("component")
local gpu = component.gpu

local M = {}

M.colors = {
  BG_PRIMARY    = 0x1C1C1E,
  BG_SECONDARY  = 0x2C2C2E,
  BG_TERTIARY   = 0x3A3A3C,
  BG_ELEVATED   = 0x48484A,
  ACCENT        = 0x0A84FF,
  GREEN         = 0x30D158,
  YELLOW        = 0xFFD60A,
  RED           = 0xFF453A,
  ORANGE        = 0xFF9F0A,
  PURPLE        = 0xBF5AF2,
  FG_PRIMARY    = 0xFFFFFF,
  FG_SECONDARY  = 0x8E8E93,
  FG_TERTIARY   = 0x636366,
  SEPARATOR     = 0x48484A,
}

M.w = 1
M.h = 1
M.compact = false
M.currentView = 1
M.viewNames = {"Dashboard", "Fleet", "Map", "Alerts", "Settings"}
M.scrollPos = {}
M.selectedRow = {}

for i = 1, 5 do
  M.scrollPos[i] = 0
  M.selectedRow[i] = 1
end

function M.init()
  M.w, M.h = gpu.maxResolution()
  gpu.setResolution(M.w, M.h)
  M.compact = (M.w < 100)
  gpu.setDepth(gpu.maxDepth())
  M.clear()
end

function M.clear()
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.setForeground(M.colors.FG_PRIMARY)
  gpu.fill(1, 1, M.w, M.h, " ")
end

function M.setFg(color)
  gpu.setForeground(color)
end

function M.setBg(color)
  gpu.setBackground(color)
end

function M.text(x, y, str, fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) end
  gpu.set(x, y, str)
end

function M.hline(x, y, len, char, fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) end
  gpu.fill(x, y, len, 1, char or "─")
end

function M.vline(x, y, len, char, fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) end
  gpu.fill(x, y, 1, len, char or "│")
end

function M.fill(x, y, w, h, char, fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) end
  gpu.fill(x, y, w, h, char or " ")
end

function M.box(x, y, w, h, title, fg, bg)
  fg = fg or M.colors.SEPARATOR
  bg = bg or M.colors.BG_SECONDARY
  gpu.setForeground(fg)
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.set(x, y, "╭")
  gpu.fill(x + 1, y, w - 2, 1, "─")
  gpu.set(x + w - 1, y, "╮")
  if title then
    gpu.setForeground(M.colors.FG_SECONDARY)
    gpu.set(x + 2, y, " " .. title .. " ")
    gpu.setForeground(fg)
  end
  gpu.setBackground(bg)
  for row = 1, h - 2 do
    gpu.setBackground(M.colors.BG_PRIMARY)
    gpu.set(x, y + row, "│")
    gpu.set(x + w - 1, y + row, "│")
    gpu.setBackground(bg)
    gpu.fill(x + 1, y + row, w - 2, 1, " ")
  end
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.setForeground(fg)
  gpu.set(x, y + h - 1, "╰")
  gpu.fill(x + 1, y + h - 1, w - 2, 1, "─")
  gpu.set(x + w - 1, y + h - 1, "╯")
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.card(x, y, w, h, bg)
  bg = bg or M.colors.BG_SECONDARY
  gpu.setForeground(M.colors.SEPARATOR)
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.set(x, y, "╭")
  gpu.fill(x + 1, y, w - 2, 1, "─")
  gpu.set(x + w - 1, y, "╮")
  for row = 1, h - 2 do
    gpu.setBackground(M.colors.BG_PRIMARY)
    gpu.set(x, y + row, "│")
    gpu.set(x + w - 1, y + row, "│")
    gpu.setBackground(bg)
    gpu.fill(x + 1, y + row, w - 2, 1, " ")
  end
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.setForeground(M.colors.SEPARATOR)
  gpu.set(x, y + h - 1, "╰")
  gpu.fill(x + 1, y + h - 1, w - 2, 1, "─")
  gpu.set(x + w - 1, y + h - 1, "╯")
end

function M.progressBar(x, y, w, pct, fg, bg)
  fg = fg or M.colors.ACCENT
  bg = bg or M.colors.BG_TERTIARY
  local filled = math.floor(w * math.min(1, math.max(0, pct / 100)))
  gpu.setBackground(fg)
  gpu.setForeground(fg)
  if filled > 0 then
    gpu.fill(x, y, filled, 1, "█")
  end
  if filled < w then
    gpu.setBackground(bg)
    gpu.fill(x + filled, y, w - filled, 1, "░")
  end
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.badge(x, y, label, fg, bg)
  gpu.setBackground(bg or M.colors.BG_TERTIARY)
  gpu.setForeground(fg or M.colors.FG_PRIMARY)
  gpu.set(x, y, " " .. label .. " ")
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.statusDot(x, y, color)
  gpu.setForeground(color)
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.set(x, y, "■")
end

function M.heading(x, y, title)
  gpu.setForeground(M.colors.FG_PRIMARY)
  gpu.setBackground(M.colors.BG_PRIMARY)
  gpu.set(x, y, title)
  gpu.setForeground(M.colors.SEPARATOR)
  gpu.fill(x, y + 1, #title + 4, 1, "═")
end

function M.pad(str, len, align)
  if not str then str = "" end
  str = tostring(str)
  if #str >= len then return str:sub(1, len) end
  local diff = len - #str
  if align == "right" then
    return string.rep(" ", diff) .. str
  elseif align == "center" then
    local left = math.floor(diff / 2)
    return string.rep(" ", left) .. str .. string.rep(" ", diff - left)
  end
  return str .. string.rep(" ", diff)
end

function M.truncate(str, maxLen)
  if not str then return "" end
  str = tostring(str)
  if #str <= maxLen then return str end
  return str:sub(1, maxLen - 2) .. ".."
end

function M.shortAddr(addr)
  if not addr then return "----..----" end
  return addr:sub(1, 4) .. ".." .. addr:sub(-4)
end

function M.formatPos(x, y, z)
  if not x then return "—" end
  return string.format("(%d, %d, %d)", math.floor(x), math.floor(y), math.floor(z))
end

function M.formatTime(uptime)
  local h = math.floor(uptime / 3600) % 24
  local m = math.floor(uptime / 60) % 60
  local s = math.floor(uptime) % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

function M.formatShortTime(uptime)
  local m = math.floor(uptime / 60) % 60
  local s = math.floor(uptime) % 60
  return string.format("%02d:%02d", m, s)
end

function M.energyColor(pct)
  if pct > 60 then return M.colors.GREEN end
  if pct > 30 then return M.colors.YELLOW end
  if pct > 15 then return M.colors.ORANGE end
  return M.colors.RED
end

function M.stateColor(state)
  if state == "PATROL" then return M.colors.ACCENT end
  if state == "PURSUIT" then return M.colors.PURPLE end
  if state == "IDLE" then return M.colors.GREEN end
  if state == "RETURN" then return M.colors.YELLOW end
  if state == "OFFLINE" then return M.colors.RED end
  return M.colors.FG_SECONDARY
end

function M.renderNavBar(fleetData, uptime)
  gpu.setBackground(M.colors.BG_SECONDARY)
  gpu.fill(1, 1, M.w, 1, " ")
  gpu.setForeground(M.colors.ACCENT)
  gpu.set(2, 1, "▓▓")
  gpu.setForeground(M.colors.FG_PRIMARY)
  gpu.set(5, 1, " DronePursuit")

  local activeCount = 0
  local totalCount = 0
  local totalEnergy = 0
  local energyDrones = 0
  for _, d in pairs(fleetData) do
    totalCount = totalCount + 1
    if d.state ~= "OFFLINE" then
      activeCount = activeCount + 1
      totalEnergy = totalEnergy + (d.energyPct or 0)
      energyDrones = energyDrones + 1
    end
  end
  local avgEnergy = energyDrones > 0 and math.floor(totalEnergy / energyDrones) or 0

  local info = string.format("Fleet: %d/%d    Energy: %d%%    %s",
    activeCount, totalCount, avgEnergy, M.formatTime(uptime))
  gpu.setForeground(M.colors.FG_SECONDARY)
  gpu.set(M.w - #info - 1, 1, info)
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.renderTabBar()
  gpu.setBackground(M.colors.BG_TERTIARY)
  gpu.fill(1, 2, M.w, 1, " ")
  local x = 2
  for i, name in ipairs(M.viewNames) do
    local label = "[" .. i .. "] " .. name
    if i == M.currentView then
      gpu.setBackground(M.colors.ACCENT)
      gpu.setForeground(M.colors.FG_PRIMARY)
    else
      gpu.setBackground(M.colors.BG_TERTIARY)
      gpu.setForeground(M.colors.FG_SECONDARY)
    end
    gpu.set(x, 2, " " .. label .. " ")
    x = x + #label + 3
  end
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.renderStatusBar(hints)
  gpu.setBackground(M.colors.BG_SECONDARY)
  gpu.fill(1, M.h, M.w, 1, " ")
  gpu.setForeground(M.colors.FG_TERTIARY)
  gpu.set(2, M.h, hints or "Q: Quit  D: Deploy  R: Recall  Space: Refresh  1-5: Views")
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.renderChrome(fleetData, uptime, hints)
  M.renderNavBar(fleetData, uptime)
  M.renderTabBar()
  gpu.setForeground(M.colors.SEPARATOR)
  gpu.fill(1, 3, M.w, 1, "─")
  M.renderStatusBar(hints)
end

function M.renderDashboard(fleetData, alerts, activityLog, uptime)
  local cy = 5
  local leftW, rightX, rightW

  if M.compact then
    leftW = M.w - 4
    rightX = 3
    rightW = leftW
  else
    leftW = math.floor(M.w * 0.55)
    rightX = leftW + 4
    rightW = M.w - rightX - 1
  end

  M.heading(3, cy, "Fleet Overview")
  cy = cy + 2

  local counts = {IDLE = 0, PATROL = 0, PURSUIT = 0, RETURN = 0, OFFLINE = 0}
  local total = 0
  for _, d in pairs(fleetData) do
    total = total + 1
    local st = d.state or "OFFLINE"
    counts[st] = (counts[st] or 0) + 1
  end
  if total == 0 then total = 1 end

  local cardW = math.floor((leftW - 5) / 2)
  local pairs_data = {
    {"Active", counts.IDLE + counts.PATROL + counts.PURSUIT + counts.RETURN, M.colors.GREEN},
    {"Patrol", counts.PATROL, M.colors.ACCENT},
    {"Pursuit", counts.PURSUIT, M.colors.PURPLE},
    {"Offline", counts.OFFLINE, M.colors.RED},
  }

  for i, pd in ipairs(pairs_data) do
    local col = ((i - 1) % 2 == 0) and 3 or (cardW + 5)
    local row = cy + math.floor((i - 1) / 2) * 5
    M.card(col, row, cardW, 4)
    M.text(col + 2, row + 1, M.pad(pd[1], cardW - 8), M.colors.FG_SECONDARY, M.colors.BG_SECONDARY)
    M.text(col + cardW - 5, row + 1, M.pad(tostring(pd[2]), 3, "right"), pd[3], M.colors.BG_SECONDARY)
    gpu.setBackground(M.colors.BG_SECONDARY)
    M.progressBar(col + 2, row + 2, cardW - 4, total > 0 and (pd[2] / total * 100) or 0, pd[3])
  end

  cy = cy + 11
  M.heading(3, cy, "Alert Summary")
  cy = cy + 2

  local activeAlerts = {}
  for _, a in ipairs(alerts) do
    if not a.dismissed then
      activeAlerts[#activeAlerts + 1] = a
    end
  end

  local alertH = math.min(#activeAlerts + 2, 6)
  M.card(3, cy, leftW - 2, alertH)
  if #activeAlerts == 0 then
    M.text(5, cy + 1, "No active alerts", M.colors.FG_TERTIARY, M.colors.BG_SECONDARY)
  else
    M.text(5, cy + 1, "■ " .. #activeAlerts .. " active alert" .. (#activeAlerts > 1 and "s" or ""), M.colors.YELLOW, M.colors.BG_SECONDARY)
    for j = 1, math.min(#activeAlerts, alertH - 2) do
      local a = activeAlerts[j]
      local sev = a.severity or "INFO"
      local col = M.colors.FG_SECONDARY
      if sev == "CRITICAL" then col = M.colors.RED
      elseif sev == "WARNING" then col = M.colors.ORANGE
      elseif sev == "DETECT" then col = M.colors.YELLOW end
      M.text(7, cy + 1 + j, M.truncate(a.message or "", leftW - 10), col, M.colors.BG_SECONDARY)
    end
  end

  if not M.compact then
    local ry = 5
    M.heading(rightX, ry, "Recent Activity")
    ry = ry + 2
    local maxLines = M.h - ry - 3
    local start = math.max(1, #activityLog - maxLines + 1)
    for i = start, #activityLog do
      local entry = activityLog[i]
      local timeStr = M.formatShortTime(entry.time or 0)
      local icon = "□"
      local iconColor = M.colors.FG_TERTIARY
      if entry.kind == "detect" then icon = "■"; iconColor = M.colors.YELLOW
      elseif entry.kind == "dispatch" then icon = "▸"; iconColor = M.colors.ACCENT
      elseif entry.kind == "alert" then icon = "■"; iconColor = M.colors.RED
      elseif entry.kind == "arrive" then icon = "■"; iconColor = M.colors.GREEN end
      local line = timeStr .. "  " .. icon .. " " .. M.truncate(entry.message or "", rightW - 12)
      M.text(rightX, ry, timeStr, M.colors.FG_TERTIARY)
      M.text(rightX + 7, ry, icon, iconColor)
      M.text(rightX + 9, ry, M.truncate(entry.message or "", rightW - 12), M.colors.FG_SECONDARY)
      ry = ry + 1
      if ry >= M.h - 2 then break end
    end
  end
end

function M.renderFleet(fleetData, selected)
  local cy = 5
  M.heading(3, cy, "Drone Fleet")
  cy = cy + 2

  local drones = {}
  for id, d in pairs(fleetData) do
    d._id = id
    drones[#drones + 1] = d
  end
  table.sort(drones, function(a, b) return (a._id or "") < (b._id or "") end)

  local colID, colAddr, colState, colPos, colEnergy, colTarget
  if M.compact then
    colID = 3; colAddr = 7; colState = 20; colPos = 30; colEnergy = 52; colTarget = 63
    local tw = M.w - 4
    M.card(2, cy, tw, #drones + 4)
    cy = cy + 1
    gpu.setBackground(M.colors.BG_SECONDARY)
    M.text(colID, cy, M.pad("ID", 4), M.colors.ACCENT)
    M.text(colAddr, cy, M.pad("Address", 12), M.colors.ACCENT)
    M.text(colState, cy, M.pad("Status", 9), M.colors.ACCENT)
    M.text(colPos, cy, M.pad("Position", 20), M.colors.ACCENT)
    M.text(colEnergy, cy, M.pad("Energy", 10), M.colors.ACCENT)
    M.text(colTarget, cy, M.pad("Target", 12), M.colors.ACCENT)
  else
    colID = 4; colAddr = 10; colState = 28; colPos = 42; colEnergy = 68; colTarget = 86
    local tw = M.w - 4
    M.card(2, cy, tw, #drones + 4)
    cy = cy + 1
    gpu.setBackground(M.colors.BG_SECONDARY)
    M.text(colID, cy, M.pad("ID", 5), M.colors.ACCENT)
    M.text(colAddr, cy, M.pad("Address", 16), M.colors.ACCENT)
    M.text(colState, cy, M.pad("Status", 12), M.colors.ACCENT)
    M.text(colPos, cy, M.pad("Position", 24), M.colors.ACCENT)
    M.text(colEnergy, cy, M.pad("Energy", 16), M.colors.ACCENT)
    M.text(colTarget, cy, M.pad("Target", 20), M.colors.ACCENT)
  end

  cy = cy + 1
  gpu.setForeground(M.colors.SEPARATOR)
  gpu.fill(3, cy, M.w - 5, 1, "─")
  cy = cy + 1

  for idx, d in ipairs(drones) do
    local isSelected = (idx == selected)
    local rowBg = isSelected and M.colors.BG_ELEVATED or M.colors.BG_SECONDARY
    gpu.setBackground(rowBg)
    gpu.fill(3, cy, M.w - 5, 1, " ")

    local idStr = string.format("%02d", idx)
    M.text(colID, cy, idStr, M.colors.FG_PRIMARY, rowBg)
    M.text(colAddr, cy, M.shortAddr(d.address), M.colors.FG_SECONDARY, rowBg)

    local stColor = M.stateColor(d.state)
    M.badge(colState, cy, M.pad(d.state or "OFFLINE", 8), M.colors.FG_PRIMARY, stColor)
    gpu.setBackground(rowBg)

    M.text(colPos, cy, M.formatPos(d.x, d.y, d.z), M.colors.FG_SECONDARY, rowBg)

    local ePct = d.energyPct or 0
    local eColor = M.energyColor(ePct)
    local barW = M.compact and 6 or 8
    M.progressBar(colEnergy, cy, barW, ePct, eColor)
    gpu.setBackground(rowBg)
    M.text(colEnergy + barW + 1, cy, string.format("%d%%", ePct), eColor, rowBg)

    M.text(colTarget, cy, M.truncate(d.target or "", 18), M.colors.FG_SECONDARY, rowBg)

    cy = cy + 1
  end

  gpu.setBackground(M.colors.BG_PRIMARY)
  cy = cy + 2
  M.text(3, cy, "[D] Deploy  [R] Recall  [P] Patrol  [G] Goto  [Enter] Details", M.colors.FG_TERTIARY)
end

function M.renderMap(fleetData, detections, cfg)
  local cy = 5
  M.heading(3, cy, "Tactical Map")
  cy = cy + 2

  local scale = cfg.mapScale or 4
  local mapW = M.compact and (M.w - 6) or (M.w - 8)
  local mapH = M.h - cy - 4
  local baseX = cfg.baseX or 0
  local baseZ = cfg.baseZ or 0

  M.card(3, cy, mapW + 2, mapH + 2)

  local halfW = math.floor(mapW / 2)
  local halfH = math.floor(mapH / 2)
  local centerX = 4 + halfW
  local centerY = cy + 1 + halfH

  gpu.setBackground(M.colors.BG_SECONDARY)
  gpu.setForeground(M.colors.BG_TERTIARY)
  gpu.fill(4, cy + 1, mapW, mapH, " ")

  gpu.setForeground(M.colors.BG_TERTIARY)
  for gx = 4, 4 + mapW - 1, 8 do
    gpu.fill(gx, cy + 1, 1, mapH, "·")
  end
  for gy = cy + 1, cy + mapH, 4 do
    gpu.fill(4, gy, mapW, 1, "·")
  end

  gpu.setForeground(M.colors.SEPARATOR)
  if centerY >= cy + 1 and centerY <= cy + mapH then
    gpu.fill(4, centerY, mapW, 1, "─")
  end
  if centerX >= 4 and centerX <= 4 + mapW - 1 then
    gpu.fill(centerX, cy + 1, 1, mapH, "│")
  end

  if centerX >= 4 and centerX <= 4 + mapW - 1 and centerY >= cy + 1 and centerY <= cy + mapH then
    gpu.setForeground(M.colors.ACCENT)
    gpu.set(centerX, centerY, "◆")
  end

  for _, d in pairs(fleetData) do
    if d.x and d.state ~= "OFFLINE" then
      local dx = math.floor((d.x - baseX) / scale)
      local dz = math.floor((d.z - baseZ) / scale)
      local px = centerX + dx
      local py = centerY + dz
      if px >= 4 and px < 4 + mapW and py >= cy + 1 and py < cy + 1 + mapH then
        local dColor = M.stateColor(d.state)
        gpu.setForeground(dColor)
        gpu.setBackground(M.colors.BG_SECONDARY)
        local label = "D"
        if d._id then
          local num = tostring(d._id):match("(%d+)$")
          if num then label = "D" .. num end
        end
        gpu.set(px, py, label:sub(1, 2))
      end
    end
  end

  for _, det in ipairs(detections) do
    if det.x then
      local dx = math.floor((det.x - baseX) / scale)
      local dz = math.floor((det.z - baseZ) / scale)
      local px = centerX + dx
      local py = centerY + dz
      if px >= 4 and px < 4 + mapW and py >= cy + 1 and py < cy + 1 + mapH then
        gpu.setForeground(M.colors.RED)
        gpu.setBackground(M.colors.BG_SECONDARY)
        local initial = (det.name or "?"):sub(1, 1):upper()
        gpu.set(px, py, initial)
      end
    end
  end

  gpu.setBackground(M.colors.BG_PRIMARY)
  local legendY = cy + mapH + 3
  M.text(3, legendY, "◆", M.colors.ACCENT)
  M.text(5, legendY, "Base  ", M.colors.FG_TERTIARY)
  M.text(11, legendY, "D#", M.colors.GREEN)
  M.text(14, legendY, "Drone  ", M.colors.FG_TERTIARY)
  M.text(21, legendY, "A-Z", M.colors.RED)
  M.text(25, legendY, "Player  ", M.colors.FG_TERTIARY)
  M.text(33, legendY, string.format("Scale: %d blk/char", scale), M.colors.FG_TERTIARY)

  gpu.setForeground(M.colors.FG_TERTIARY)
  local nLabel = "N"
  if centerX >= 4 and centerX <= 4 + mapW - 1 then
    gpu.set(centerX, cy, nLabel)
  end
end

function M.renderAlerts(alerts, scrollPos, selected)
  local cy = 5
  M.heading(3, cy, "Alerts & Events")
  cy = cy + 2

  local maxLines = M.h - cy - 4
  local totalAlerts = #alerts

  if totalAlerts == 0 then
    M.text(3, cy, "No alerts recorded.", M.colors.FG_TERTIARY)
    return
  end

  local startIdx = math.max(1, totalAlerts - maxLines - scrollPos + 1)
  local endIdx = math.min(totalAlerts, startIdx + maxLines - 1)

  local tw = M.w - 6
  for i = startIdx, endIdx do
    local a = alerts[totalAlerts - (i - startIdx)]
    if a then
      local row = cy + (i - startIdx)
      local isSelected = ((i - startIdx + 1) == selected)
      local rowBg = isSelected and M.colors.BG_ELEVATED or M.colors.BG_PRIMARY

      gpu.setBackground(rowBg)
      gpu.fill(2, row, M.w - 2, 1, " ")

      local sev = a.severity or "INFO"
      local sevColor = M.colors.FG_TERTIARY
      local icon = "□"
      if sev == "CRITICAL" then sevColor = M.colors.RED; icon = "■"
      elseif sev == "WARNING" then sevColor = M.colors.ORANGE; icon = "■"
      elseif sev == "DETECT" then sevColor = M.colors.YELLOW; icon = "■" end

      M.text(3, row, icon, sevColor, rowBg)
      M.text(5, row, M.formatShortTime(a.time or 0), M.colors.FG_TERTIARY, rowBg)
      M.badge(12, row, M.pad(sev, 8), M.colors.FG_PRIMARY, sevColor)
      gpu.setBackground(rowBg)
      M.text(23, row, M.truncate(a.message or "", tw - 22), M.colors.FG_SECONDARY, rowBg)
    end
  end

  gpu.setBackground(M.colors.BG_PRIMARY)
  local scrollInfo = string.format("Showing %d-%d of %d", startIdx, endIdx, totalAlerts)
  M.text(3, M.h - 2, scrollInfo, M.colors.FG_TERTIARY)
end

function M.renderSettings(cfg, selectedField, editMode, editBuffer)
  local cy = 5
  M.heading(3, cy, "Settings")
  cy = cy + 2

  local sections = {
    {title = "Network", fields = {
      {key = "port", label = "Port", type = "number"},
      {key = "signalStrength", label = "Signal Strength", type = "number"},
      {key = "heartbeatInterval", label = "Heartbeat Interval", type = "number", suffix = "s"},
    }},
    {title = "Pursuit", fields = {
      {key = "autoDispatch", label = "Auto-dispatch", type = "bool"},
      {key = "lowEnergyRecall", label = "Low Energy Recall", type = "number", suffix = "%"},
      {key = "pursuitTimeout", label = "Pursuit Timeout", type = "number", suffix = "s"},
      {key = "patrolRadius", label = "Patrol Radius", type = "number"},
    }},
    {title = "Base Position", fields = {
      {key = "baseX", label = "Base X", type = "number"},
      {key = "baseY", label = "Base Y", type = "number"},
      {key = "baseZ", label = "Base Z", type = "number"},
    }},
    {title = "Display", fields = {
      {key = "refreshRate", label = "Refresh Rate", type = "number", suffix = "s"},
      {key = "mapScale", label = "Map Scale", type = "number", suffix = " blk/char"},
    }},
  }

  local fieldIdx = 0
  for _, section in ipairs(sections) do
    local boxH = #section.fields + 3
    local boxW = M.compact and (M.w - 4) or math.floor(M.w * 0.7)
    M.box(3, cy, boxW, boxH, section.title)
    local fy = cy + 1
    for _, field in ipairs(section.fields) do
      fieldIdx = fieldIdx + 1
      local isSelected = (fieldIdx == selectedField)
      local labelX = 5
      local valueX = 30
      local valW = 16

      if isSelected then
        gpu.setBackground(M.colors.BG_ELEVATED)
        gpu.fill(4, fy, boxW - 3, 1, " ")
      else
        gpu.setBackground(M.colors.BG_SECONDARY)
      end

      M.text(labelX, fy, field.label .. ":", M.colors.FG_SECONDARY)

      local val = cfg[field.key]
      local displayVal
      if field.type == "bool" then
        displayVal = val and "ON" or "OFF"
      else
        displayVal = tostring(val or "")
      end

      if isSelected and editMode then
        displayVal = editBuffer or displayVal
        gpu.setBackground(M.colors.BG_TERTIARY)
        M.text(valueX, fy, "[ " .. M.pad(displayVal, valW - 4) .. " ]", M.colors.ACCENT)
      else
        local bracket = isSelected and M.colors.ACCENT or M.colors.SEPARATOR
        gpu.setBackground(isSelected and M.colors.BG_ELEVATED or M.colors.BG_SECONDARY)
        gpu.setForeground(bracket)
        gpu.set(valueX, fy, "[ ")
        gpu.setForeground(M.colors.FG_PRIMARY)
        gpu.set(valueX + 2, fy, M.pad(displayVal .. (field.suffix or ""), valW - 4))
        gpu.setForeground(bracket)
        gpu.set(valueX + valW - 2, fy, " ]")
      end

      fy = fy + 1
    end
    cy = cy + boxH + 1
  end

  gpu.setBackground(M.colors.BG_PRIMARY)
  M.text(3, cy + 1, "[Up/Down] Navigate  [Enter] Edit  [Esc] Cancel  [Tab] Toggle Bool", M.colors.FG_TERTIARY)
end

function M.renderSplash()
  M.clear()
  local cx = math.floor(M.w / 2)
  local cy = math.floor(M.h / 2) - 6

  local logo = {
    "  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ",
    "  ▓▓                            ▓▓  ",
    "  ▓▓   ╭────────────────────╮   ▓▓  ",
    "  ▓▓   │   DronePursuit     │   ▓▓  ",
    "  ▓▓   │   ────────────     │   ▓▓  ",
    "  ▓▓   │                    │   ▓▓  ",
    "  ▓▓   │   Surveillance     │   ▓▓  ",
    "  ▓▓   │   Control System   │   ▓▓  ",
    "  ▓▓   │                    │   ▓▓  ",
    "  ▓▓   ╰────────────────────╯   ▓▓  ",
    "  ▓▓                            ▓▓  ",
    "  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ",
  }

  for i, line in ipairs(logo) do
    local lx = cx - math.floor(#line / 2)
    M.text(lx, cy + i, line, M.colors.ACCENT, M.colors.BG_PRIMARY)
  end

  local tagline = "Intelligent Drone Surveillance for OpenComputers"
  M.text(cx - math.floor(#tagline / 2), cy + #logo + 2, tagline, M.colors.FG_SECONDARY)

  local prompt = "Initializing..."
  M.text(cx - math.floor(#prompt / 2), cy + #logo + 4, prompt, M.colors.FG_TERTIARY)
end

function M.renderInputDialog(title, prompt, buffer)
  local dw = M.compact and (M.w - 8) or 50
  local dh = 7
  local dx = math.floor((M.w - dw) / 2)
  local dy = math.floor((M.h - dh) / 2)

  M.box(dx, dy, dw, dh, title)
  gpu.setBackground(M.colors.BG_SECONDARY)
  M.text(dx + 2, dy + 2, prompt, M.colors.FG_SECONDARY)
  gpu.setBackground(M.colors.BG_TERTIARY)
  gpu.fill(dx + 2, dy + 4, dw - 4, 1, " ")
  M.text(dx + 3, dy + 4, buffer or "", M.colors.FG_PRIMARY, M.colors.BG_TERTIARY)
  gpu.setBackground(M.colors.BG_PRIMARY)
end

function M.renderConfirmDialog(title, message)
  local dw = M.compact and (M.w - 8) or 50
  local dh = 7
  local dx = math.floor((M.w - dw) / 2)
  local dy = math.floor((M.h - dh) / 2)

  M.box(dx, dy, dw, dh, title)
  gpu.setBackground(M.colors.BG_SECONDARY)
  M.text(dx + 2, dy + 2, message, M.colors.FG_SECONDARY)
  M.text(dx + 2, dy + 4, "[Y] Confirm    [N] Cancel", M.colors.FG_TERTIARY)
  gpu.setBackground(M.colors.BG_PRIMARY)
end

return M
