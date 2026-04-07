local component = require("component")
local filesystem = require("filesystem")
local io = require("io")
local shell = require("shell")

local DEST = "/home/DronePursuit"

local C = {
  ACCENT   = 0x0A84FF,
  GREEN    = 0x30D158,
  RED      = 0xFF453A,
  YELLOW   = 0xFFD60A,
  FG       = 0xFFFFFF,
  DIM      = 0x8E8E93,
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

local function ok(label)   print2("  ✓  " .. label, C.GREEN) end
local function fail(label) print2("  ✗  " .. label, C.RED) end
local function info(label) print2("  ·  " .. label, C.DIM) end

local function findSource()
  local args = shell.parse(...)
  if args[1] and filesystem.isDirectory(args[1]) then
    return args[1]
  end
  local cwd = shell.getWorkingDirectory()
  if filesystem.exists(cwd .. "/DronePursuit.lua") then
    return cwd
  end
  for addr in component.list("filesystem") do
    local mnt = "/mnt/" .. addr:sub(1, 8)
    if filesystem.isDirectory(mnt) and filesystem.exists(mnt .. "/DronePursuit.lua") then
      return mnt
    end
  end
  return nil
end

local function ensureDir(path)
  if not filesystem.isDirectory(path) then
    local ok2, err = filesystem.makeDirectory(path)
    if not ok2 then return false, err end
  end
  return true
end

local function copyFile(src, dst)
  local f = io.open(src, "rb")
  if not f then return false, "cannot open source" end
  local data = f:read("*a")
  f:close()
  local g = io.open(dst, "wb")
  if not g then return false, "cannot open dest" end
  g:write(data)
  g:close()
  return true
end

local FILES = {
  { src = "DronePursuit.lua",    dst = DEST .. "/DronePursuit.lua" },
  { src = "flash.lua",           dst = DEST .. "/flash.lua"        },
  { src = "lib/config.lua",      dst = DEST .. "/lib/config.lua"   },
  { src = "lib/ui.lua",          dst = DEST .. "/lib/ui.lua"       },
  { src = "lib/net.lua",         dst = DEST .. "/lib/net.lua"      },
  { src = "lib/fleet.lua",       dst = DEST .. "/lib/fleet.lua"    },
  { src = "lib/pursuit.lua",     dst = DEST .. "/lib/pursuit.lua"  },
  { src = "firmware/drone_fw.lua", dst = DEST .. "/firmware/drone_fw.lua" },
}

local DIRS = {
  DEST,
  DEST .. "/lib",
  DEST .. "/firmware",
}

local function writeLauncher()
  local path = "/usr/bin/dronepursuit"
  local f = io.open(path, "w")
  if not f then return false end
  f:write('require("shell").execute("/home/DronePursuit/DronePursuit.lua")\n')
  f:close()
  return true
end

local function main()
  print("")
  print2("  ╭───────────────────────────────────────╮", C.DIM)
  print2("  │      DronePursuit  Installer          │", C.FG)
  print2("  ╰───────────────────────────────────────╯", C.DIM)

  heading("Locating source files")
  local src = findSource()
  if not src then
    fail("Source not found. Usage:")
    info("  install.lua [/path/to/DronePursuit-OC]")
    info("  Or place this script in the same folder as DronePursuit.lua")
    info("  Or insert the floppy disk containing the files")
    return false
  end
  ok("Source: " .. src)

  heading("Creating directories")
  for _, dir in ipairs(DIRS) do
    local success, err = ensureDir(dir)
    if success then ok(dir)
    else fail(dir .. " — " .. tostring(err)) return false end
  end

  heading("Copying files")
  local copied = 0
  local errors = 0
  for _, entry in ipairs(FILES) do
    local srcPath = src .. "/" .. entry.src
    if filesystem.exists(srcPath) then
      local success, err = copyFile(srcPath, entry.dst)
      if success then
        ok(entry.dst)
        copied = copied + 1
      else
        fail(entry.dst .. " — " .. tostring(err))
        errors = errors + 1
      end
    else
      fail("Missing: " .. entry.src)
      errors = errors + 1
    end
  end

  heading("Creating launcher")
  if writeLauncher() then
    ok("/usr/bin/dronepursuit  (run anywhere with: dronepursuit)")
  else
    info("Could not write /usr/bin/dronepursuit  (run manually instead)")
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
    info("Skipped — you can set base coords later in Settings (View 5).")
  end

  print2("")
  if errors == 0 then
    print2("  ╭───────────────────────────────────────╮", C.GREEN)
    print2("  │        Installation complete!          │", C.GREEN)
    print2("  ╰───────────────────────────────────────╯", C.GREEN)
    print2("")
    print2("  Start now:    dronepursuit", C.FG)
    print2("  Flash drone:  " .. DEST .. "/flash.lua", C.DIM)
  else
    print2("  Installation finished with " .. errors .. " error(s).", C.YELLOW)
    print2("  Check missing files above and retry.", C.DIM)
  end
  print2("")
  return errors == 0
end

main()
