local component = require("component")
local io = require("io")

local FIRMWARE_PATH = "/home/DronePursuit/firmware/drone_fw.lua"

if not component.isAvailable("eeprom") then
  print("ERROR: No EEPROM component found.")
  print("Place a blank EEPROM in an adjacent computer/assembler.")
  return
end

local f = io.open(FIRMWARE_PATH, "r")
if not f then
  print("ERROR: Firmware not found at " .. FIRMWARE_PATH)
  return
end
local code = f:read("*a")
f:close()

if #code > 4096 then
  print("ERROR: Firmware too large (" .. #code .. " bytes, max 4096)")
  return
end

local eeprom = component.eeprom

print("╭─────────────────────────────────────╮")
print("│  DronePursuit Firmware Flasher       │")
print("├─────────────────────────────────────┤")
print("│  Firmware: " .. #code .. " bytes                │")
print("│  EEPROM:   " .. eeprom.getLabel() .. string.rep(" ", 24 - #eeprom.getLabel()) .. "│")
print("╰─────────────────────────────────────╯")
print("")
print("This will overwrite the EEPROM contents.")
io.write("Continue? [y/N] ")
local answer = io.read()
if answer ~= "y" and answer ~= "Y" then
  print("Aborted.")
  return
end

eeprom.set(code)
eeprom.setLabel("DronePursuit FW")

io.write("Set base coordinates for RTB (x,y,z): ")
local coords = io.read()
if coords and #coords > 0 then
  eeprom.setData(coords)
  print("Base coords stored: " .. coords)
else
  eeprom.setData("0,64,0")
  print("Default base coords stored: 0,64,0")
end

print("")
print("Firmware flashed successfully!")
print("Install this EEPROM in a drone to activate.")
