# DronePursuit -Setup & Operations Guide

## Hardware Requirements

### Base Station

| Component | Tier | Notes |
|-----------|------|-------|
| Computer Case | Tier 3 | Needed for full RAM and component slots |
| CPU | Tier 3 | Required for event throughput |
| RAM | 2× Tier 3.5 | Heavy Lua state for fleet + UI |
| GPU | Tier 3 | Full-color 160×50 terminal |
| Screen | Tier 2+ | 80×25 minimum; Tier 3 for full layout |
| Hard Disk Drive | Tier 2+ | Stores all program files and config |
| Wireless Network Card | Tier 2 | Signal strength up to 400 blocks |
| Motion Sensor | Any | Detects player movement within 8 blocks |
| Internet Card | Optional | Not required after install |

Connect the screen and motion sensor directly to the computer or via an adapter. The network card can be internal or in an expansion card slot.

---

### Each Drone

| Upgrade | Tier | Notes |
|---------|------|-------|
| Drone Case | Tier 2+ | Tier 3 gives more energy capacity |
| Wireless Network Card | Tier 1+ | Must share the same channel as base |
| Navigation Upgrade | Tier 2 | Required for `getPosition()` to work |
| EEPROM | Any | Will be flashed with `drone_fw.lua` |
| Angel Upgrade | Optional | Lets drone fly through solid blocks |
| Leash Upgrade | Optional | Prevents drones leaving loaded chunks |

The navigation upgrade requires a navigation map item crafted at a cartography table centered on your base. Without it, `getPosition()` returns nil and the drone cannot report coordinates.

---

## Step 1 — Copy Files to OC Computer (Windows)

1. Open File Explorer and navigate to your world's OpenComputers computer folder:

   ```
   %appdata%\PrismLauncher\instances\NotPack - Performance\minecraft\saves\<WorldName>\opencomputers\<ComputerUUID>\
   ```

   The UUID is a long hex string. Open each one and look for a `home/` folder — that is your base station computer.

2. Inside that folder, create:

   ```
   home/
   ```

3. Copy these files from the `DronePursuit-OC` workspace folder into the computer's `home/` folder:

   ```
   install.lua
   DronePursuit.lua
   flash.lua
   lib/
   firmware/
   agentic/    (optional — research docs only)
   ```

   The final layout should be:

   ```
   home/
   ├── install.lua
   ├── DronePursuit.lua
   ├── flash.lua
   ├── lib/
   │   ├── config.lua
   │   ├── ui.lua
   │   ├── net.lua
   │   ├── fleet.lua
   │   └── pursuit.lua
   └── firmware/
       └── drone_fw.lua
   ```

---

## Step 2 — Run the Installer In-Game

Boot the base station computer. At the OpenOS shell:

```
cd /home
install.lua
```

The installer will:
- Create `/home/DronePursuit/` and sub-directories
- Copy all program files to the correct paths
- Create a `/usr/bin/dronepursuit` launcher so you can run it with just `dronepursuit`
- Prompt for your base station coordinates (used for drone Return-to-Base)

To find your exact coordinates, stand at the base computer and press `F3` in Minecraft. Enter them as `x,y,z` when prompted, e.g. `120,65,-340`.

---

## Step 3 — Flash Each Drone's EEPROM

**In the OC computer:**

1. Build a drone and place it in the assembler with the required upgrades.
2. Before assembling, insert a blank EEPROM into the drone case.
3. Assemble the drone.
4. Hold the assembled drone and use an EEPROM programmer (or the OC computer's disk drive) to access the EEPROM.
5. Connect the drone (via item frame or drone dock) to the base station.
6. In the base station shell:

   ```
   /home/DronePursuit/flash.lua
   ```

   The flasher reads `firmware/drone_fw.lua`, verifies it is under 4096 bytes, writes it to the connected EEPROM component, and stores the base coordinates in the EEPROM data slot.

   Repeat for every drone you want to enroll.

**What the firmware does on a drone:**
- Boots and broadcasts a `BOOT` message to the base station on port 7331
- Waits for commands: `GOTO`, `PATROL`, `RTB`, `HALT`, `ASSIGN`, `PING`, `COLOR`, `REBOOT`
- Sends heartbeat + position every 5 seconds
- Auto-returns to base when energy drops below 10%

---

## Step 4 — Launch DronePursuit

```
dronepursuit
```

On first launch a splash screen appears, then the Dashboard view loads. Any drone that has been flashed will appear in the Fleet view (View 2) within seconds of being activated, once it broadcasts its `BOOT` signal.

---

## Controls Reference

| Key | Action |
|-----|--------|
| `1` | Dashboard view |
| `2` | Fleet view |
| `3` | Map view |
| `4` | Alerts view |
| `5` | Settings view |
| `Tab` | Cycle views forward |
| `D` | Deploy nearest idle drone to selected coordinates |
| `R` | Recall (RTB) selected drone |
| `G` | Go-to: prompt for coordinates, dispatch a drone there |
| `P` | Toggle patrol mode on selected drone |
| `Space` | Ping all registered drones (requests status update) |
| `Q` | Quit (confirmation dialog) |
| `↑` `↓` | Scroll lists / select drone |

---

## Drone States

| State | Color | Meaning |
|-------|-------|---------|
| `IDLE` | Green | Hovering, awaiting orders |
| `PATROL` | Blue | Flying the patrol route autonomously |
| `PURSUIT` | Purple | Chasing a detected player |
| `RETURN` | Yellow | Returning to base coordinates |
| `OFFLINE` | Red | Heartbeat timed out (> 15 s) |

---

## Communication Protocol

All messages are sent on **port 7331** using the format `CMD:payload`.

Base → Drone commands: `GOTO`, `PATROL`, `RTB`, `HALT`, `ASSIGN`, `PING`, `COLOR`, `REBOOT`

Drone → Base reports: `BOOT`, `HEARTBEAT`, `POS`, `STATUS`, `ALERT`

Payload formats:
- Coordinates: `x,y,z` (e.g. `120,65,-340`)
- Patrol waypoints: `x1,y1,z1;x2,y2,z2;...`
- Status: `state,energy` (e.g. `PURSUIT,73`)

---

## Troubleshooting

**Drone does not appear in Fleet view**
- Verify the EEPROM was flashed and the drone is powered on.
- Confirm both the base station and drone have wireless cards on the same frequency range.
- Open Fleet view and press `Space` to broadcast a ping.

**`getPosition()` returns nil in firmware**
- The navigation upgrade needs a navigation map centered on the base. Craft one and insert it into the upgrade.

**EEPROM write fails in flash.lua**
- Ensure the drone's EEPROM is accessible as a component (drone docked and connected, or EEPROM in programmer).
- If the firmware has grown past 4096 bytes (e.g. after edits), it will refuse to flash and show the exact size.

**Motion sensor fires for mobs, not players**
- This is normal. The firmware and base station filter by entity name at the pursuit layer; no pursuit is assigned to non-player names unless `autoDispatch` is on and the name matches a player pattern.

**Program crashes with "not enough memory"**
- Upgrade RAM to 2× Tier 3.5.
- Reduce `refreshRate` in Settings (View 5) to lower rendering frequency.
