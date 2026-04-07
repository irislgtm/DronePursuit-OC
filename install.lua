local component = require("component")
local filesystem = require("filesystem")
local internet   = require("internet")
local io         = require("io")

local RAW  = "https://raw.githubusercontent.com/irislgtm/DronePursuit-OC/main"
local DEST = "/home/DronePursuit"

local C = {
  ACCENT = 0x0A84FF,
  GREEN  = 0x30D158,
  RED    = 0xFF453A,
  YELLOW = 0xFFD60A,
  FG     = 0xFFFFFF,
  DIM    = 0x8E8E93,
}

local gpu = component.isAvailable("gpu") and component.gpu or nil

local function col(c) if gpu then gpu.setForeground(c) end end
local function rst() if gpu then gpu.setForeground(C.FG) end end

local function print2(msg, color)
  col(color or C.FG)
  print(msg)
  rst()
end

local function heading(title)
  print2("")
  print2("  " .. title, C.ACCENT)
  print2("  " .. string.rep("─", #title), C.DIM)
end

local function ok(label)   print2("  \xe2\x9c\x93  " .. label, C.GREEN) end
local function fail(label) print2("  \xe2\x9c\x97  " .. label, C.RED)   end
local function info(label) print2("  \xc2\xb7  " .. label, C.DIM)       end

local function fetch(path)
  local url = RAW .. "/" .. path
  local ok2, handle = pcall(internet.request, url)
  if not ok2 then return nil, "request error" end
  local chunks = {}
  local success, err = pcall(function()
    for chunk in handle do
      chunks[#chunks + 1] = chunk
    end
  end)
  if not success then return nil, tostring(err) end
  local data = table.concat(chunks)
  if #data == 0 then return nil, "empty response" end
  return data
end

local function ensureDir(path)
  if not filesystem.isDirectory(path) then
    local res, err = filesystem.makeDirectory(path)
    if not res then return false, err end
  end
  return true
end

local function writeFile(dst, data)
  local f = io.open(dst, "wb")
  if not f then return false, "cannot open " .. dst end
  f:write(data)
  f:close()
  return true
end

local FILES = {
  { path = "DronePursuit.lua",      dst = DEST .. "/DronePursuit.lua"         },
  { path = "flash.lua",             dst = DEST .. "/flash.lua"                },
  { path = "lib/config.lua",        dst = DEST .. "/lib/config.lua"           },
  { path = "lib/ui.lua",            dst = DEST .. "/lib/ui.lua"               },
  { path = "lib/net.lua",           dst = DEST .. "/lib/net.lua"              },
  { path = "lib/fleet.lua",         dst = DEST .. "/lib/fleet.lua"            },
  { path = "lib/pursuit.lua",       dst = DEST .. "/lib/pursuit.lua"          },
  { path = "firmware/drone_fw.lua", dst = DEST .. "/firmware/drone_fw.lua"    },
}

local DIRS = {
  DEST,
  DEST .. "/lib",
  DEST .. "/firmware",
}

local function writeLauncher()
  local f = io.open("/usr/bin/dronepursuit", "w")
  if not f then return false end
  f:write('require("shell").execute("/home/DronePursuit/DronePursuit.lua")\n')
  f:close()
  return true
end

local function main()
  print("")
  print2("  \xe2\x95\xad\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x95\xae", C.DIM)
  print2("  \xe2\x94\x82      DronePursuit  Network Installer      \xe2\x94\x82", C.FG)
  print2("  \xe2\x95\xb0\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x95\xaf", C.DIM)
  info("Source: " .. RAW)

  heading("Creating directories")
  for _, dir in ipairs(DIRS) do
    local res, err = ensureDir(dir)
    if res then ok(dir)
    else fail(dir .. " -- " .. tostring(err)) return false end
  end

  heading("Downloading files")
  local errors = 0
  for _, entry in ipairs(FILES) do
    io.write("  \xe2\x80\xa6  " .. entry.path .. " ")
    local data, err = fetch(entry.path)
    if data then
      local res2, err2 = writeFile(entry.dst, data)
      if res2 then
        print2("[ok]", C.GREEN)
      else
        print2("[write error: " .. tostring(err2) .. "]", C.RED)
        errors = errors + 1
      end
    else
      print2("[fetch error: " .. tostring(err) .. "]", C.RED)
      errors = errors + 1
    end
  end

  heading("Creating launcher")
  if writeLauncher() then
    ok("/usr/bin/dronepursuit  (run anywhere with: dronepursuit)")
  else
    info("Could not write launcher -- run manually: " .. DEST .. "/DronePursuit.lua")
  end

  heading("Configuring firmware")
  io.write("  Enter base station coordinates for drone RTB (x,y,z): ")
  local coords = io.read()
  if coords and coords:match("%-?%d+[%s,]+%-?%d+[%s,]+%-?%d+") then
    local f = io.open(DEST .. "/basecoords.dat", "w")
    if f then f:write(coords) f:close() end
    ok("Base coords saved: " .. coords)
    info("Run flash.lua to burn firmware to each drone EEPROM.")
  else
    info("Skipped -- set base coords later in Settings (View 5).")
  end

  print2("")
  if errors == 0 then
    print2("  \xe2\x95\xad\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x95\xae", C.GREEN)
    print2("  \xe2\x94\x82        Installation complete!              \xe2\x94\x82", C.GREEN)
    print2("  \xe2\x95\xb0\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x95\xaf", C.GREEN)
    print2("")
    print2("  Start now:    dronepursuit", C.FG)
    print2("  Flash drone:  " .. DEST .. "/flash.lua", C.DIM)
  else
    print2("  Finished with " .. errors .. " error(s). Check output above.", C.YELLOW)
  end
  print2("")
  return errors == 0
end

main()
