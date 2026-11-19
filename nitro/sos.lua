-- Nitro SOS (nitro/sos.lua): modo de emergencia.
-- Abre sozinho depois de 3 falhas seguidas no boot (ver init.lua).
-- Confere os arquivos do sistema, mostra o log e so repara depois de perguntar.
local cl, cp = component, computer
local BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/Atualizar_Nitro_OS/main/"
local FAILS, LASTMX, LOGF = "/nitro/falhas.txt", "/nitro/ultimo_mx.txt", "/nitro/sos.log"
local fs = cl.proxy(cp.getBootAddress())
local gpuA, scrA = cl.list("gpu")(), cl.list("screen")()
local g = gpuA and cl.proxy(gpuA)
if g and scrA then g.bind(scrA) end
local W, H = 80, 25
if g then W, H = g.getResolution() end

local logs = {}

local function readFile(p)
  if not fs.exists(p) then return nil end
  local h = fs.open(p)
  if not h then return nil end
  local d = ""
  repeat
    local c = fs.read(h, math.huge)
    d = d .. (c or "")
  until not c
  fs.close(h)
  return d
end

local function rawWrite(p, d)
  local h = fs.open(p, "w")
  if not h then return false end
  fs.write(h, d)
  fs.close(h)
  return true
end

-- guarda a versao antiga em .bak antes de substituir
local function writeFile(p, d)
  local old = readFile(p)
  if old then rawWrite(p .. ".bak", old) end
  return rawWrite(p, d)
end

-- log: fica na memoria e em /nitro/sos.log (ultimas 120 linhas)
local function addLog(t)
  logs[#logs + 1] = t
  while #logs > 200 do table.remove(logs, 1) end
  local old = readFile(LOGF) or ""
  local lines = {}
  for l in old:gmatch("[^\n]+") do lines[#lines + 1] = l end
  lines[#lines + 1] = t
  while #lines > 120 do table.remove(lines, 1) end
  rawWrite(LOGF, table.concat(lines, "\n") .. "\n")
end

local function fetch(u)
  local n = cl.list("internet")()
  if not n then return nil, "sem Internet Card" end
  local r, e = cl.proxy(n).request(u)
  if not r then return nil, tostring(e) end
  local t = cp.uptime() + 15
  while not r.finishConnect() do
    if cp.uptime() > t then
      r.close()
      return nil, "tempo esgotado"
    end
    cp.pullSignal(0)
  end
  local a = {}
  while true do
    local c = r.read(math.huge)
    if not c then break end
    a[#a + 1] = c
  end
  r.close()
  local d = table.concat(a)
  if d:sub(1, 3) == "404" then return nil, "nao encontrado no GitHub" end
  return d
end

local function compiles(d)
  return d and #d > 0 and load(d, "=c") ~= nil
end

local function put(x, y, s, fg, bg)
  if not g then return end
  g.setForeground(fg)
  g.setBackground(bg)
  g.set(x, y, s)
end

local function fill(x, y, w, h, bg)
  if not g then return end
  g.setBackground(bg)
  g.fill(x, y, w, h, " ")
end

local RED, WHITE, BLACK, GRAY, YEL, GREEN = 0xB71C1C, 0xFFFFFF, 0x000000, 0xAAAAAA, 0xFFFF55, 0x55FF55

-- lista de arquivos do sistema (manifesto do GitHub; sem internet, usa os arquivos do disco)
local function listFiles()
  local m = fetch(BASE .. "NitroOS_atualizar.lua")
  local f = m and load(m, "=m")
  local ok, t = false, nil
  if f then ok, t = pcall(f) end
  local out = {}
  if ok and type(t) == "table" and t.files then
    for _, p in ipairs(t.files) do out[#out + 1] = p end
    return out, true
  end
  out[#out + 1] = "nitro/boot.lua"
  local ok2, names = pcall(fs.list, "/nitro/sys")
  if ok2 and type(names) == "table" then
    for _, n in ipairs(names) do
      if n:sub(-4) == ".lua" then out[#out + 1] = "nitro/sys/" .. n end
    end
  end
  return out, false
end

local function check()
  local files, online = listFiles()
  addLog("ARQUIVOS: " .. #files .. " na lista (" .. (online and "GitHub" or "disco, sem internet") .. ")")
  local bad = {}
  for _, p in ipairs(files) do
    local d = readFile("/" .. p)
    if not d or #d == 0 then
      bad[#bad + 1] = { p = p, why = "faltando ou vazio" }
      addLog("FALHA  faltando/vazio  " .. p)
    elseif not compiles(d) then
      bad[#bad + 1] = { p = p, why = "erro de codigo" }
      addLog("FALHA  erro de codigo  " .. p)
    else
      addLog("OK     " .. p)
    end
  end
  addLog("ANALISE: " .. #files .. " arquivos, " .. #bad .. " com problema")
  return bad, #files, online
end

local function repair(bad)
  local ok, fail = 0, 0
  addLog("REPARO: baixando " .. #bad .. " arquivos")
  for _, b in ipairs(bad) do
    local d, e = fetch(BASE .. b.p)
    if not d then
      fail = fail + 1
      addLog("FALHA  download " .. b.p .. ": " .. tostring(e))
    elseif not compiles(d) then
      fail = fail + 1
      addLog("FALHA  codigo baixado invalido  " .. b.p)
    elseif writeFile("/" .. b.p, d) then
      ok = ok + 1
      addLog("BAIXADO " .. b.p)
    else
      fail = fail + 1
      addLog("FALHA  gravacao  " .. b.p)
    end
    cp.pullSignal(0)
  end
  addLog("REPARO FIM: " .. ok .. " ok, " .. fail .. " falhas")
  return ok, fail
end

local function restore(bad)
  local n = 0
  for _, b in ipairs(bad) do
    local bak = readFile("/" .. b.p .. ".bak")
    if compiles(bak) and rawWrite("/" .. b.p, bak) then
      n = n + 1
      addLog("RESTAURADO " .. b.p)
    else
      addLog("SEM BACKUP  " .. b.p)
    end
  end
  return n
end

local function setFails(n)
  rawWrite(FAILS, tostring(n))
end

addLog("--- Nitro SOS aberto ---")
local bad, total, online = check()
local lastMx = (readFile(LASTMX) or "-"):gsub("%s+$", "")
local MENU = {
  { "Reparar arquivos com problema (pede confirmacao)", true },
  { "Restaurar backups (.bak)", true },
  { "Tentar iniciar o sistema agora", true },
  { "Ver log (arquivos, analise e falhas)", true },
  { "Desligar", true },
}
local sel, mode, msg, logTop = 1, "menu", "", 1

local function draw()
  fill(1, 1, W, H, BLACK)
  fill(1, 1, W, 2, RED)
  put(2, 1, "Nitro SOS - Modo de emergencia", WHITE, RED)
  put(2, 2, "Ultimo erro: " .. lastMx, WHITE, RED)
  if mode == "log" then
    put(3, 4, "LOG (setas: rolar   Esc: voltar)", YEL, BLACK)
    local rows = H - 7
    local first = math.max(1, #logs - rows + 1 - (logTop - 1))
    for i = 0, rows - 1 do
      local l = logs[first + i]
      if l then
        local c = WHITE
        if l:find("^FALHA") then c = RED elseif l:find("^OK") then c = GREEN end
        put(3, 5 + i, l:sub(1, W - 4), c, BLACK)
      end
    end
    fill(1, H, W, 1, RED)
    put(2, H, "^ v Rolar   Esc Voltar", WHITE, RED)
    return
  end
  put(3, 4, string.format("Arquivos verificados: %d    com problema: %d    %s",
    total, #bad, online and "(lista do GitHub)" or "(sem internet)"), WHITE, BLACK)
  if #bad == 0 then put(3, 6, "Nenhum arquivo com problema.", GREEN, BLACK) end
  for i = 1, math.min(#bad, H - 16) do
    put(3, 5 + i, bad[i].p .. "  -  " .. bad[i].why, YEL, BLACK)
  end
  for i, m in ipairs(MENU) do
    local label = "  " .. m[1] .. "  "
    local avail = m[2] and not (i == 1 and #bad == 0)
    if i == sel then put(3, H - 9 + i, label, BLACK, WHITE)
    else put(3, H - 9 + i, label, avail and WHITE or GRAY, BLACK) end
  end
  if mode == "confirm" then
    put(3, H - 2, "Baixar e substituir " .. #bad .. " arquivos? Enter = sim   Esc = nao", YEL, BLACK)
  elseif msg ~= "" then
    put(3, H - 2, msg, YEL, BLACK)
  end
  fill(1, H, W, 1, RED)
  put(2, H, "^ v Escolher   Enter Executar   Esc Voltar", WHITE, RED)
end

local function run(opt)
  if opt == 1 then
    if #bad == 0 then return end
    mode = "confirm"
  elseif opt == 2 then
    local n = restore(bad)
    msg = n > 0 and ("Backups restaurados: " .. n .. ".") or "Nenhum backup valido."
    bad, total, online = check()
  elseif opt == 3 then
    setFails(0)
    addLog("Reinicio manual: contador zerado")
    cp.shutdown(true)
  elseif opt == 4 then
    mode, logTop = "log", 1
  elseif opt == 5 then
    cp.shutdown(false)
  end
end

draw()
while true do
  local ev, _, _, code = cp.pullSignal(1)
  if mode == "confirm" then
    if code == 28 then
      mode = "menu"
      msg = "Reparando..."
      draw()
      local ok, fail = repair(bad)
      bad, total, online = check()
      if #bad == 0 then setFails(0) end
      msg = string.format("Reparados: %d. Falhas: %d. %s", ok, fail,
        #bad == 0 and "Pronto para reiniciar." or "Ainda ha arquivos com problema.")
    elseif code == 1 then
      mode = "menu"
      msg = "Reparo cancelado."
      addLog("Reparo cancelado pelo usuario")
    end
  elseif mode == "log" then
    if code == 200 then logTop = math.min(#logs, logTop + 1)
    elseif code == 208 then logTop = math.max(1, logTop - 1)
    elseif code == 1 then mode = "menu"
    end
  elseif ev == "key_down" then
    if code == 200 then sel = math.max(1, sel - 1)
    elseif code == 208 then sel = math.min(#MENU, sel + 1)
    elseif code == 28 then run(sel)
    end
  end
  draw()
end
