local P,H,L=7331,5,10
local d,m,n
for a,t in component.list()do
if t=="drone"then d=component.proxy(a)
elseif t=="modem"then m=component.proxy(a)
elseif t=="navigation"then n=component.proxy(a)end
end
if not d or not m then computer.beep(1000,.5)computer.shutdown()end
m.open(P)
if m.setStrength then m.setStrength(400)end
d.setLightColor(0x30D158)
d.setStatusText("BOOT")
local s,w,wi,tg="IDLE",{},1
m.broadcast(P,"BOOT:"..d.address..";"..m.address)
local function gp()
if n then local o,x,y,z=pcall(n.getPosition)if o and x then return x,y,z end end
end
local function sr(c,p)m.broadcast(P,p and c..":"..p or c)end
local function ss()sr("STATUS",s..";"..math.floor(computer.energy())..";"..math.floor(computer.maxEnergy()))end
local function sp()local x,y,z=gp()if x then sr("POS",math.floor(x)..","..math.floor(y)..","..math.floor(z))end end
local function mv(a,b,c)local x,y,z=gp()if not x then return end local e,f,g=a-x,b-y,c-z local q=math.sqrt(e*e+f*f+g*g)if q<2 then return true end local r=math.min(q,16)/q d.move(e*r,f*r,g*r)end
local function pp(r)if not r then return end local x,y,z=r:match("(%-?%d+),(%-?%d+),(%-?%d+)")if x then return tonumber(x),tonumber(y),tonumber(z)end end
local function pw(r)if not r then return{}end local t={}for v in r:gmatch("[^;]+")do local x,y,z=v:match("(%-?%d+),(%-?%d+),(%-?%d+)")if x then t[#t+1]={tonumber(x),tonumber(y),tonumber(z)}end end return t end
local function rb()local e=component.proxy(component.list("eeprom")())local b=e and e.getData()or""local x,y,z=b:match("(%-?%d+),(%-?%d+),(%-?%d+)")if x then return{tonumber(x),tonumber(y),tonumber(z)}end return{0,64,0}end
local lt,lh=computer.uptime(),computer.uptime()
while true do
local si={computer.pullSignal(1)}
local now=computer.uptime()
if si[1]=="modem_message"then
local r=si[6]
if type(r)=="string"then
local p=r:find(":")
local c,v
if p then c,v=r:sub(1,p-1),r:sub(p+1)else c=r end
if c=="GOTO"then local x,y,z=pp(v)if x then tg={x,y,z}s="PATROL"d.setStatusText("GOTO")d.setLightColor(0x0A84FF)sr("ACK","GOTO")end
elseif c=="PATROL"then w=pw(v)wi=1 if#w>0 then s="PATROL"tg={w[1][1],w[1][2],w[1][3]}d.setStatusText("PTR")d.setLightColor(0x0A84FF)sr("ACK","PATROL")end
elseif c=="RTB"then tg=rb()s="RETURN"w={}d.setStatusText("RTB")d.setLightColor(0xFFD60A)sr("ACK","RTB")
elseif c=="HALT"then s="IDLE"tg=nil w={}d.setStatusText("IDLE")d.setLightColor(0x30D158)d.move(0,0,0)sr("ACK","HALT")
elseif c=="COLOR"then local x=tonumber(v)if x then d.setLightColor(x)end
elseif c=="PING"then ss()sp()
elseif c=="ASSIGN"then tg=tg or{0,64,0}s="PURSUIT"d.setStatusText(">"..(v or"?"))d.setLightColor(0xBF5AF2)sr("ACK","ASSIGN")
elseif c=="REBOOT"then computer.shutdown(true)
end end end
if(s=="PATROL"or s=="PURSUIT"or s=="RETURN")and tg then
local ok=mv(tg[1],tg[2],tg[3])
if ok then
if s=="PATROL"and#w>0 then wi=wi%#w+1 tg={w[wi][1],w[wi][2],w[wi][3]}
elseif s=="RETURN"then s="IDLE"tg=nil d.setStatusText("IDLE")d.setLightColor(0x30D158)
elseif s=="PURSUIT"then d.setStatusText("HOLD")end
end end
if now-lh>=H then sr("HEARTBEAT",tostring(math.floor(now)))sp()lh=now end
if now-lt>=H*2 then ss()lt=now end
local me=computer.maxEnergy()
if me>0 and computer.energy()/me*100<L and s~="RETURN"then
sr("ALERT","WARNING;Low energy")tg=rb()s="RETURN"w={}d.setStatusText("RTB!")d.setLightColor(0xFF453A)
end end
