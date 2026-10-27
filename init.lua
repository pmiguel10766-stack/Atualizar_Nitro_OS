-- Nitro OS - /init.lua (launcher)
-- Se /nitro/boot.lua existe, inicia o Nitro OS.
-- Se nao existe, baixa o instalador do GitHub e abre ele.
-- Funciona com a BIOS padrao do OpenComputers (nao precisa de EEPROM propria).
-- Erros aparecem em tela preta e vermelha com codigo MX-xxx.
local BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/"
local INSTALLER = BASE .. "installer.lua"
local BOOT = "/nitro/boot.lua"

local cl, cp = component, computer
local function first(t) return cl.list(t)() end

local gpu = first("gpu")
local scr = first("screen")
if gpu and scr then
  gpu = cl.proxy(gpu)
  gpu.bind(scr)
else
  gpu = nil
end

local ulen = (unicode and unicode.len) or string.len
local usub = (unicode and unicode.sub) or string.sub

-- logo Nitro OS (C listrado + rosto vermelho), igual ao do sistema
local function drawLogo(x, y, R, bg, stripe)
  local r = math.floor(R * 0.64 + 0.5)
  local arm = math.floor(R * 0.65 + 0.5)
  gpu.setBackground(bg)
  gpu.setForeground(stripe)
  for ry = 0, R - 1 do
    local dy = (ry + 0.5) * 2 - R
    local left = math.floor(R - math.sqrt(R * R - dy * dy) + 0.5)
    local right
    if math.abs(dy) >= r then
      right = R + arm
    else
      right = math.floor(R - math.sqrt(r * r - dy * dy) + 0.5)
    end
    if right > left then
      gpu.set(x + left, y + ry, string.rep("▀", right - left))
    end
  end
  local Rf = math.floor(R * 0.43 + 0.5)
  local fcx = R + math.floor(R * 0.28 + 0.5)
  local red, black = 0xD01818, 0x000000
  local frows = {}
  gpu.setBackground(red)
  for ry = 0, R - 1 do
    local dy = (ry + 0.5) * 2 - R
    if math.abs(dy) < Rf then
      local hw = math.floor(math.sqrt(Rf * Rf - dy * dy) + 0.5)
      if hw > 0 then
        gpu.fill(x + fcx - hw, y + ry, hw * 2, 1, " ")
        frows[#frows + 1] = ry
      end
    end
  end
  local nF = #frows
  if nF >= 2 then
    local eyeRow = frows[nF >= 5 and 2 or 1]
    gpu.setBackground(red)
    gpu.setForeground(black)
    gpu.set(x + fcx - 3, y + eyeRow, ">")
    gpu.set(x + fcx + 2, y + eyeRow, "<")
    gpu.setBackground(black)
    if nF >= 5 then
      gpu.fill(x + fcx - 3, y + frows[4], 7, 1, " ")
      gpu.fill(x + fcx - 2, y + frows[5], 5, 1, " ")
    else
      gpu.fill(x + fcx - 1, y + frows[nF], 3, 1, " ")
    end
  end
end

-- tela com logo e uma mensagem embaixo
local function logoScreen(status)
  if not gpu then return end
  local w, h = gpu.getResolution()
  gpu.setBackground(0x050505)
  gpu.fill(1, 1, w, h, " ")
  local size = (h >= 24) and 14 or 8
  local lw = math.floor(size * 1.75 + 0.5)
  local ly = math.floor((h - (size + 5)) / 2) + 1
  drawLogo(math.floor((w - lw) / 2) + 1, ly, size, 0x050505, 0xE6E6E6)
  gpu.setBackground(0x050505)
  gpu.setForeground(0xFFFFFF)
  local name = "NITRO OS"
  gpu.set(math.floor((w - #name) / 2) + 1, ly + size + 1, name)
  gpu.setForeground(0xA0A0A0)
  gpu.set(math.floor((w - #status) / 2) + 1, ly + size + 3, status)
end

-- codigos de erro
local MXMSG = {
  [203] = "Sistema corrompido",
  [204] = "Sistema sem RAM",
  [205] = "Falha ao atualizar",
  [206] = "Problema no boot do sistema",
  [207] = "Problema em app ou usuário",
  [208] = "Erro desconhecido",
}

local function classify(err, default)
  local s = tostring(err):lower()
  if s:find("not enough memory", 1, true) or s:find("out of memory", 1, true) then
    return 204
  end
  return default
end

-- tela de erro: fundo preto, moldura vermelha, icone [X], codigo MX e detalhe.
-- Enter reinicia o computador.
local function errorScreen(code, detail)
  if gpu then
    local w, h = gpu.getResolution()
    local RED, BG = 0xFF2D2D, 0x050505
    local function put(x, y, s, fg, maxw)
      s = tostring(s)
      if maxw and ulen(s) > maxw then s = usub(s, 1, maxw) end
      gpu.setBackground(BG)
      gpu.setForeground(fg)
      gpu.set(x, y, s)
    end
    local ew = math.min(w - 4, 60)
    local eh = math.min(h - 4, 12)
    local ex = math.floor((w - ew) / 2) + 1
    local ey = math.floor((h - eh) / 2) + 1
    gpu.setBackground(BG)
    gpu.fill(1, 1, w, h, " ")
    local line = string.rep("─", ew - 2)
    put(ex, ey, "╭" .. line .. "╮", RED)
    for r = 1, eh - 2 do
      put(ex, ey + r, "│", RED)
      put(ex + ew - 1, ey + r, "│", RED)
    end
    put(ex, ey + eh - 1, "╰" .. line .. "╯", RED)

    local ix = ex + 3
    local icon = { "┏━     ━┓", "┃ ╲   ╱ ┃", "┃   ╳   ┃", "┃ ╱   ╲ ┃", "┗━     ━┛" }
    for i, row in ipairs(icon) do put(ix, ey + 1 + i, row, RED) end

    local tx, tw = ix + 12, ew - 17
    put(tx, ey + 2, "ERRO FATAL DO SISTEMA", RED, tw)
    put(tx, ey + 3, string.rep("─", tw), RED)
    put(tx, ey + 4, string.format("MX-%d  %s", code, MXMSG[code] or MXMSG[208]), 0xFFFFFF, tw)
    local text = tostring(detail or ""):gsub("%s+", " ")
    for n = 0, 2 do
      local part = usub(text, n * tw + 1, (n + 1) * tw)
      if ulen(part) > 0 then put(tx, ey + 5 + n, part, 0xA0A0A0, tw) end
    end
    put(ix, ey + eh - 4, string.rep("▞", ew - 6), RED)
    put(ix, ey + eh - 2, "Enter Reiniciar", 0xA0A0A0)
  end
  while true do
    local ev, _, _, c = cp.pullSignal()
    if ev == "key_down" and c == 28 then cp.shutdown(true) end
  end
end

local bootAddr = cp.getBootAddress()
local fs = bootAddr and cl.proxy(bootAddr) or nil

local function readFile(path)
  local hnd = fs.open(path)
  if not hnd then return nil end
  local data = ""
  repeat
    local c = fs.read(hnd, math.huge)
    data = data .. (c or "")
  until not c
  fs.close(hnd)
  return data
end

-- runCode = codigo usado se o programa travar durante a execucao
local function run(code, name, runCode)
  local fn, err = load(code, "=" .. name)
  if not fn then errorScreen(203, err) end
  local ok, e = pcall(fn)
  if not ok then errorScreen(classify(e, runCode), e) end
end

local function downloadOnce(url, timeout)
  local net = first("internet")
  if not net then return nil, "Sem Internet Card" end
  net = cl.proxy(net)
  local req, err = net.request(url)
  if not req then return nil, tostring(err) end
  local limit = cp.uptime() + timeout
  local parts = {}
  local ok, e = pcall(function()
    while not req.finishConnect() do
      if cp.uptime() > limit then error("Tempo esgotado", 0) end
      cp.pullSignal(0.05)
    end
    local code = req.response()
    if code and code >= 400 then error("HTTP " .. code, 0) end
    while true do
      local c = req.read(math.huge)
      if not c then break end
      parts[#parts + 1] = c
    end
  end)
  pcall(req.close)
  if not ok then return nil, tostring(e) end
  return table.concat(parts)
end

local function download(url)
  local data, err
  for attempt = 1, 2 do
    data, err = downloadOnce(url, 30)
    if data then return data end
    if tostring(err):find("HTTP 4", 1, true) then break end
  end
  return nil, tostring(err) .. " (" .. url .. ")"
end

logoScreen("Carregando sistema...")
if fs and fs.exists(BOOT) then
  local data = readFile(BOOT)
  if not data then errorScreen(206, BOOT) end
  run(data, "nitro", 206)
  errorScreen(206, "O sistema foi encerrado")
end

if cp.freeMemory() < 20000 then
  errorScreen(204, string.format("RAM livre: %d KB", math.floor(cp.freeMemory() / 1024)))
end

logoScreen("Baixando instalador...")
local code, err = download(INSTALLER)
if not code or #code == 0 then
  errorScreen(205, err or "installer.lua")
end
run(code, "installer", 208)
errorScreen(208, "Instalador encerrado")
