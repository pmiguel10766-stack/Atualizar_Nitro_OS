-- Nitro OS - /nitro/boot.lua
-- Sistema Operacional para OpenComputers com AppStore estilizada, Logotipo, Desktop limpo e Gestor de Arquivos.

local cl, cp = component, computer
local gpu = cl.proxy(cl.list("gpu")())
local screenAddr = cl.list("screen")()
if screenAddr and not gpu.getScreen() then gpu.bind(screenAddr) end
local w, h = gpu.getResolution()

local ulen = (unicode and unicode.len) or string.len
local usub = (unicode and unicode.sub) or string.sub
local uchar = (unicode and unicode.char) or string.char

local fs = cl.proxy(cp.getBootAddress())
local CONFIG = "/nitro/config.lua"

---------------------------------------------------------------- cores e desenho
local C = {
  bg = 0x050505, panel = 0x1A1A1A, accent = 0xFF2D2D, text = 0xFFFFFF,
  dim = 0xA0A0A0, ok = 0x3DDC84, warn = 0xFFB300, err = 0xFF8A8A,
  barbg = 0x3A3A3A,
}

local function rect(x, y, rw, rh, bg)
  gpu.setBackground(bg)
  gpu.fill(x, y, rw, rh, " ")
end

local function put(x, y, s, fg, bg, maxw)
  s = tostring(s)
  if maxw and ulen(s) > maxw then s = usub(s, 1, maxw) end
  gpu.setBackground(bg)
  gpu.setForeground(fg)
  gpu.set(x, y, s)
end

local function key()
  while true do
    local ev, _, _, code = cp.pullSignal()
    if ev == "key_down" then return code end
  end
end

local pw = math.min(w - 4, 64)
local px = math.floor((w - pw) / 2) + 1
local py = 4
local ph = math.max(9, math.min(h - 5, 22))
local cx = px + 3
local cw = pw - 6

local function center(y, s, fg, bg)
  put(px + math.floor((pw - ulen(s)) / 2), y, s, fg, bg)
end

local function footer(text)
  rect(1, h, w, 1, C.panel)
  put(2, h, text, C.dim, C.panel, w - 2)
end

---------------------------------------------------------------- logo Nitro OS
local function logoSize()
  return (h >= 24) and 14 or 8
end

local function logoWidth(size)
  return math.floor(size * 1.75 + 0.5)
end

local function drawLogo(x, y, size, bg, stripe)
  local R = size
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

local function pause(t)
  local deadline = cp.uptime() + t
  repeat
    cp.pullSignal(deadline - cp.uptime())
  until cp.uptime() >= deadline
end

local bootBar = { x = 1, y = 1, w = 1 }

local function bootBase()
  rect(1, 1, w, h, C.bg)
  local size = logoSize()
  local ly = math.floor((h - (size + 6)) / 2) + 1
  drawLogo(math.floor((w - logoWidth(size)) / 2) + 1, ly, size, C.bg, 0xE6E6E6)
  local name = "NITRO OS"
  put(math.floor((w - ulen(name)) / 2) + 1, ly + size + 1, name, C.text, C.bg)
  bootBar.w = math.min(w - 10, 40)
  bootBar.x = math.floor((w - bootBar.w) / 2) + 1
  bootBar.y = ly + size + 4
end

---------------------------------------------------------------- idiomas
local langs = {
  { name = "Português", t = {
    steps = { "Idioma", "Usuário", "Senha" },
    userTitle = "Criar usuário",
    userAsk = "Nome de usuário:",
    userEmpty = "Digite um nome",
    passTitle = "Senha (opcional)",
    passAsk = "Senha (Enter para pular):",
    passConfirm = "Repita a senha:",
    passMismatch = "As senhas não são iguais",
    keysInput = "Enter OK    Esc Voltar",
    prepHello = "Olá, %s",
    prepPreparing = "Preparando o sistema...",
    prepMinutes = "Aguarde um momento.",
    prepWarn = "Aviso: Não desligue o computador",
    loginTitle = "Entrar",
    loginHello = "Olá, %s",
    loginAsk = "Senha:",
    loginWrong = "Senha incorreta",
    loginKeys = "Enter Entrar",
    welcome = "Bem-vindo, %s!",
    ready = "O Nitro OS está pronto.",
    cont = " Enter  Continuar ",
    mFiles = "Arquivos",
    mEditor = "Editor Lua",
    mFloppy = "Disquetes",
    mCalc = "Calc",
    mMonitor = "Monitor",
    mSettings = "Ajustes",
    mCmd = "Terminal",
    mWebMin = "WebMin",
    mStore = "AppStore",
    mNotes = "Notas",
    mPrinter = "Impressora",
    mRestart = "Reiniciar",
    mShutdown = "Desligar",
    ram = "RAM",
    energy = "Energia",
    uptime = "Tempo ligado",
    bUp = "Subir",
    bOpen = "Abrir",
    bCreate = "Criar",
    bRename = "Renomear",
    bDelete = "Excluir",
    bSave = "Salvar",
    bRun = "Executar",
    bBack = "Voltar",
    bYes = "Sim",
    bNo = "Não",
    bOk = "OK",
    bCancel = "Cancelar",
    emptyDir = "(pasta vazia)",
    noFloppy = "Nenhum disco removível",
    floppyTitle = "Gestor de Discos",
    confirmDel = "Excluir %s? [S/N]",
    renamePrompt = "Novo nome:",
    createPrompt = "Criar arquivo:",
    deleted = "Excluído",
    renamed = "Renomeado",
    created = "Criado",
    saved = "Salvo!",
    executed = "Executado!",
    nameExists = "Já existe",
    nameBad = "Nome inválido",
    binaryFile = "Arquivo binário",
    errPrefix = "Erro: ",
    loadSys = "Carregando sistema...",
    loadUser = "Carregando usuário...",
    loadDesk = "Preparando ambiente...",
    loadDone = "Pronto!",
    loaded = "Carregado",
    errTitle = "ERRO FATAL",
    errTitleApp = "ERRO NO APLICATIVO",
    errContinue = "Enter Continuar",
    errRestart = "Enter Reiniciar",
    e203 = "Sistema corrompido",
    e204 = "Sem memória RAM",
    e205 = "Falha na atualização",
    e206 = "Erro de boot",
    e207 = "Erro em aplicativo",
    e208 = "Erro desconhecido",
    wifi = "Rede",
    wifiType = "Tipo",
    wifiStatus = "Status",
    wifiOk = "Conectado",
    wifiWarn = "Sem HTTP",
    wifiNone = "Sem placa",
    wifiTest = "Testar",
    wifiTesting = "Testando...",
    wifiTestOk = "OK (%s)",
    wifiTestFail = "Falhou: %s",
    wifiNoCard = "Sem Internet Card",
  } },
}

local T = langs[1].t

local function bootProgress(pct, text)
  local loadedLabel = (T and T.loaded) or "Loading"
  local label = string.format("[%s %d%%]", loadedLabel, pct)
  rect(1, bootBar.y - 1, w, 1, C.bg)
  put(math.floor((w - ulen(label)) / 2) + 1, bootBar.y - 1, label, C.text, C.bg)
  rect(bootBar.x, bootBar.y, bootBar.w, 1, C.barbg)
  rect(bootBar.x, bootBar.y, math.floor(bootBar.w * pct / 100), 1, C.accent)
end

local function classify(err, default)
  local s = tostring(err):lower()
  if s:find("not enough memory", 1, true) or s:find("out of memory", 1, true) then
    return 204
  end
  return default
end

local function errorScreen(code, detail, canContinue)
  local ew = math.min(w - 4, 60)
  local eh = math.min(h - 4, 12)
  local ex = math.floor((w - ew) / 2) + 1
  local ey = math.floor((h - eh) / 2) + 1
  rect(1, 1, w, h, C.bg)
  local line = string.rep("─", ew - 2)
  put(ex, ey, "╭" .. line .. "╮", C.accent, C.bg)
  for r = 1, eh - 2 do
    put(ex, ey + r, "│", C.accent, C.bg)
    put(ex + ew - 1, ey + r, "│", C.accent, C.bg)
  end
  put(ex, ey + eh - 1, "╰" .. line .. "╯", C.accent, C.bg)

  local tx, tw = ex + 4, ew - 8
  put(tx, ey + 2, canContinue and T.errTitleApp or T.errTitle, C.accent, C.bg, tw)
  put(tx, ey + 3, string.rep("─", tw), C.accent, C.bg)
  put(tx, ey + 4, string.format("MX-%d  %s", code, T["e" .. code] or T.e208), C.text, C.bg, tw)
  local text = tostring(detail or ""):gsub("%s+", " ")
  for n = 0, 2 do
    local part = usub(text, n * tw + 1, (n + 1) * tw)
    if ulen(part) > 0 then put(tx, ey + 5 + n, part, C.dim, C.bg, tw) end
  end
  put(tx, ey + eh - 2, canContinue and T.errContinue or T.errRestart, C.dim, C.bg)

  while true do
    if key() == 28 then break end
  end
  if not canContinue then cp.shutdown(true) end
end

local function frame(step, title)
  rect(1, 1, w, h, C.bg)
  rect(1, 1, w, 1, C.panel)
  put(2, 1, "◆ NITRO OS", C.accent, C.panel)

  if step then
    local x = px
    for i, name in ipairs(T.steps) do
      local label = " " .. i .. " " .. name .. " "
      if i == step then
        put(x, 2, label, C.bg, C.accent)
      elseif i < step then
        put(x, 2, label, C.ok, C.bg)
      else
        put(x, 2, label, C.dim, C.bg)
      end
      x = x + ulen(label) + 1
    end
  end

  rect(px, py, pw, ph, C.panel)
  local line = string.rep("─", pw - 2)
  put(px, py, "╭" .. line .. "╮", C.accent, C.panel)
  for r = 1, ph - 2 do
    put(px, py + r, "│", C.accent, C.panel)
    put(px + pw - 1, py + r, "│", C.accent, C.panel)
  end
  put(px, py + ph - 1, "╰" .. line .. "╯", C.accent, C.panel)
  if title then put(px + 2, py, " " .. title .. " ", C.text, C.panel, pw - 6) end
end

local function message(text, color)
  rect(px + 1, py + ph - 3, pw - 2, 1, C.panel)
  if text and text ~= "" then put(cx, py + ph - 3, text, color or C.warn, C.panel, cw) end
end

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

local function hash(s)
  s = "nitro:" .. s
  local x = 5381
  for i = 1, #s do x = (x * 33 + s:byte(i)) % 4294967296 end
  return string.format("%08x", x)
end

local configBad = false

local function loadConfig()
  if not fs.exists(CONFIG) then return nil end
  local data = readFile(CONFIG)
  local f = data and load(data, "=config", "t", {})
  if f then
    local ok, cfg = pcall(f)
    if ok and type(cfg) == "table" and cfg.user then return cfg end
  end
  configBad = true
  return nil
end

local function saveConfig(cfg)
  fs.makeDirectory("/nitro")
  local hnd = fs.open(CONFIG, "w")
  local hashText = cfg.hash and string.format("%q", cfg.hash) or "nil"
  fs.write(hnd, string.format("return {user=%q,lang=%d,hash=%s}", cfg.user, cfg.lang, hashText))
  fs.close(hnd)
end

local function input(y, masked, maxLen)
  local text = ""
  local function draw()
    rect(cx, y, cw, 1, C.barbg)
    local shown = masked and string.rep("*", ulen(text)) or text
    put(cx + 1, y, shown .. "_", C.text, C.barbg, cw - 2)
  end
  draw()
  while true do
    local ev, _, char, code = cp.pullSignal()
    if ev == "key_down" then
      if code == 28 then
        return text, "enter"
      elseif code == 1 then
        return text, "back"
      elseif code == 14 then
        if ulen(text) > 0 then text = usub(text, 1, ulen(text) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(text) < maxLen then
        text = text .. uchar(char)
      end
      draw()
    end
  end
end

local function chooseLanguage()
  local sel = 1
  local function draw()
    frame(1, "Language / Idioma")
    put(cx, py + 2, "Escolha o idioma / Choose your language", C.dim, C.panel, cw)
    for i, l in ipairs(langs) do
      local y = py + 4 + (i - 1) * 2
      if i == sel then
        rect(cx - 1, y, cw + 2, 1, C.accent)
        put(cx, y, "▶ " .. l.name, C.bg, C.accent, cw)
      else
        put(cx, y, "  " .. l.name, C.text, C.panel, cw)
      end
    end
    footer("↑↓ Select / Escolher    Enter OK")
  end
  draw()
  while true do
    local code = key()
    if code == 200 and sel > 1 then
      sel = sel - 1
      draw()
    elseif code == 208 and sel < #langs then
      sel = sel + 1
      draw()
    elseif code == 28 then
      T = langs[sel].t
      return sel
    end
  end
end

local function prepareUserScreen(cfg)
  rect(1, 1, w, h, C.bg)
  rect(1, 1, w, 1, C.panel)
  put(2, 1, "◆ NITRO OS", C.accent, C.panel)

  rect(px, py, pw, ph, C.panel)
  local line = string.rep("─", pw - 2)
  put(px, py, "╭" .. line .. "╮", C.accent, C.panel)
  for r = 1, ph - 2 do
    put(px, py + r, "│", C.accent, C.panel)
    put(px + pw - 1, py + r, "│", C.accent, C.panel)
  end
  put(px, py + ph - 1, "╰" .. line .. "╯", C.accent, C.panel)

  center(py + 3, string.format(T.prepHello, cfg.user), C.text, C.panel)
  center(py + 5, T.prepPreparing, C.dim, C.panel)
  center(py + 6, T.prepMinutes, C.dim, C.panel)

  local barW = math.min(cw, 36)
  local barX = math.floor((w - barW) / 2) + 1
  local barY = py + 9

  center(py + ph - 3, "[!] " .. T.prepWarn, C.warn, C.panel)

  for pct = 0, 100, 4 do
    rect(barX, barY, barW, 1, C.barbg)
    rect(barX, barY, math.floor(barW * pct / 100), 1, C.accent)
    local pctText = string.format("%d%%", pct)
    center(barY + 1, pctText, C.text, C.panel)
    pause(0.08)
  end
  pause(0.4)
end

local function setup()
  local cfg = {}
  local step, pending = 1, nil
  while true do
    if step == 1 then
      cfg.lang = chooseLanguage()
      step = 2
    elseif step == 2 then
      frame(2, T.userTitle)
      put(cx, py + 2, T.userAsk, C.dim, C.panel, cw)
      footer(T.keysInput)
      local name, how = input(py + 4, false, 16)
      name = name:match("^%s*(.-)%s*$")
      if how == "back" then
        step = 1
      elseif #name == 0 then
        message(T.userEmpty, C.warn)
        cp.pullSignal(1)
      else
        cfg.user = name
        step = 3
      end
    elseif step == 3 then
      frame(3, T.passTitle)
      put(cx, py + 2, T.passAsk, C.dim, C.panel, cw)
      footer(T.keysInput)
      local pass, how = input(py + 4, true, 32)
      if how == "back" then
        step = 2
      elseif pass == "" then
        cfg.hash = nil
        prepareUserScreen(cfg)
        return cfg
      else
        pending = pass
        step = 4
      end
    elseif step == 4 then
      frame(3, T.passTitle)
      put(cx, py + 2, T.passConfirm, C.dim, C.panel, cw)
      footer(T.keysInput)
      local again, how = input(py + 4, true, 32)
      if how == "back" then
        step = 3
      elseif again == pending then
        cfg.hash = hash(pending)
        prepareUserScreen(cfg)
        return cfg
      else
        message(T.passMismatch, C.err)
        cp.pullSignal(1)
        step = 3
      end
    end
  end
end

local function login(cfg)
  local wrong = false
  while true do
    frame(nil, T.loginTitle)
    center(py + 2, string.format(T.loginHello, cfg.user), C.text, C.panel)
    put(cx, py + 4, T.loginAsk, C.dim, C.panel, cw)
    footer(T.loginKeys)
    if wrong then message(T.loginWrong, C.err) end
    local pass = input(py + 6, true, 32)
    if hash(pass) == cfg.hash then return end
    wrong = true
  end
end

local function getClock()
  local ok, text = pcall(os.date, "%H:%M", os.time())
  return ok and text or "19:41"
end

local function getDate()
  local ok, text = pcall(os.date, "%d/%m/%Y", os.time())
  return ok and text or "20/10/2026"
end

local function fmtTime(s)
  s = math.floor(s)
  local hh, mm, ss = math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60
  if hh > 0 then return string.format("%dh %02dm", hh, mm) end
  return string.format("%dm %02ds", mm, ss)
end

local function inside(x, y, bx, by, bw, bh)
  return x >= bx and x < bx + bw and y >= by and y < by + bh
end

local function drawBox(x, y, bw, bh, title)
  rect(x, y, bw, bh, C.panel)
  local line = string.rep("─", bw - 2)
  put(x, y, "╭" .. line .. "╮", C.accent, C.panel)
  for r = 1, bh - 2 do
    put(x, y + r, "│", C.accent, C.panel)
    put(x + bw - 1, y + r, "│", C.accent, C.panel)
  end
  put(x, y + bh - 1, "╰" .. line .. "╯", C.accent, C.panel)
  if title then put(x + 2, y, " " .. title .. " ", C.text, C.panel, bw - 12) end
end

---------------------------------------------------------------- rede / WebMin
local NET_TEST = "https://raw.githubusercontent.com/pmiguel10766-stack/nitro-appstore/main/files.txt"

local function netInfo()
  local info = { types = {}, state = "none", modem = nil, wireless = false }
  local netAddr = cl.list("internet")()
  local modemAddr = cl.list("modem")()
  if netAddr then
    info.types[#info.types + 1] = "Internet Card"
    local okH, http = pcall(cl.invoke, netAddr, "isHttpEnabled")
    info.state = (okH and http) and "ok" or "warn"
  end
  if modemAddr then
    local m = cl.proxy(modemAddr)
    local okW, isW = pcall(m.isWireless)
    if okW and isW then
      info.wireless = true
      info.modem = m
      info.types[#info.types + 1] = "Wireless Network Card"
      if not netAddr then info.state = "wireless" end
    else
      info.types[#info.types + 1] = "Network Card"
      if not netAddr then info.state = "wired" end
    end
  end
  return info
end

local function wifiGlyph(info)
  local s = info.state
  if s == "ok" then return "▂▄▆", " ", C.ok, C.ok
  elseif s == "warn" then return "▂▄▆", "!", C.warn, C.warn
  elseif s == "wireless" then return "▂▄▆", "v", C.ok, C.accent
  elseif s == "wired" then return "▂▄▆", " ", C.dim, C.dim end
  return "▂▄▆", "x", C.dim, C.err
end

local function netTest()
  local addr = cl.list("internet")()
  if not addr then return false, T.wifiNoCard end
  local net = cl.proxy(addr)
  local t0 = cp.uptime()
  local req, err = net.request(NET_TEST)
  if not req then return false, tostring(err) end
  local limit = t0 + 8
  local ok, e = pcall(function()
    while not req.finishConnect() do
      if cp.uptime() > limit then error("timeout") end
      cp.pullSignal(0)
    end
    local code = req.response()
    if code and code >= 400 then error("HTTP " .. code) end
  end)
  pcall(req.close)
  if not ok then return false, tostring(e) end
  return true, string.format("%d ms", math.floor((cp.uptime() - t0) * 1000))
end

local function wifiApp()
  local win = { title = T.wifi, w = 40, h = 10 }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)
  local ix, iw = win.x + 2, win.w - 4
  local testY = win.y + 6
  local result, resultColor = "", C.dim

  win.body = function(self)
    local info = netInfo()
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 2, T.wifiType .. ":", C.dim, C.panel)
    for i, name in ipairs(info.types) do
      put(ix + 9, self.y + 1 + i, name, C.text, C.panel, iw - 9)
    end
    put(ix, self.y + 4, T.wifiStatus .. ":", C.dim, C.panel)
    put(ix + 9, self.y + 4, info.state == "ok" and T.wifiOk or T.wifiWarn, C.ok, C.panel)
    if result ~= "" then put(ix, self.y + 5, result, resultColor, C.panel, iw) end
    rect(ix, testY, ulen(T.wifiTest) + 2, 1, C.accent)
    put(ix + 1, testY, T.wifiTest, C.bg, C.accent)
  end

  win.onTouch = function(self, x, y)
    if y == testY and x >= ix and x < ix + ulen(T.wifiTest) + 2 then
      result, resultColor = T.wifiTesting, C.dim
      win.body(win)
      local ok, msg = netTest()
      if ok then result, resultColor = string.format(T.wifiTestOk, msg), C.ok
      else result, resultColor = string.format(T.wifiTestFail, msg), C.err end
      return true
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 28 then return true end
    return false
  end

  return win
end

---------------------------------------------------------------- janelas e tarefas
local wifiBox = { x = 0, w = 4 }
local MENU_BTN = " ◆ Nitro "
local MENU_W = 28

local function drawTaskbar(cfg, menuOpen)
  rect(1, h, w, 1, C.panel)
  if menuOpen then
    put(1, h, MENU_BTN, C.bg, C.accent)
  else
    put(1, h, MENU_BTN, C.accent, C.panel)
  end
  
  local timeStr = getClock()
  local dateStr = getDate()
  local infoRight = cfg.user .. "  " .. timeStr .. " " .. dateStr
  put(w - ulen(infoRight), h, infoRight, C.text, C.panel)

  local bars, suffix, barColor, sufColor = wifiGlyph(netInfo())
  wifiBox.x = w - ulen(infoRight) - 5
  put(wifiBox.x, h, bars, barColor, C.panel)
  put(wifiBox.x + 3, h, suffix, sufColor, C.panel)
end

local function menuGeometry(items)
  local mh = #items + 2
  return 1, h - mh, MENU_W, mh
end

local function drawMenu(items)
  local mx, my, mw, mh = menuGeometry(items)
  drawBox(mx, my, mw, mh)
  for i, it in ipairs(items) do
    local y = my + i
    if it.sep then
      put(mx + 1, y, string.rep("─", mw - 2), C.dim, C.panel)
    else
      put(mx + 2, y, it.label, it.color or C.text, C.panel, mw - 4)
    end
  end
end

local function newWindow(title, body, live)
  local ww = math.min(w - 4, 52)
  local wh = math.min(h - 3, 16)
  return {
    title = title, body = body, live = live, w = ww, h = wh,
    x = math.floor((w - ww) / 2) + 1,
    y = math.max(2, math.floor((h - 1 - wh) / 2) + 1),
    origW = ww, origH = wh, origX = math.floor((w - ww) / 2) + 1, origY = math.max(2, math.floor((h - 1 - wh) / 2) + 1),
    maximized = false, minimized = false
  }
end

local function drawWindow(win)
  if win.minimized then return end
  drawBox(win.x, win.y, win.w, win.h, win.title)
  put(win.x + win.w - 10, win.y, "[_][o][X]", C.text, C.panel)
  win.body(win)
end

local function handleWindowControls(win, x, y)
  if y == win.y then
    if x >= win.x + win.w - 10 and x <= win.x + win.w - 8 then
      win.minimized = true
      return "minimize"
    elseif x >= win.x + win.w - 7 and x <= win.x + win.w - 5 then
      if win.maximized then
        win.x, win.y, win.w, win.h = win.origX, win.origY, win.origW, win.origH
        win.maximized = false
      else
        win.origX, win.origY, win.origW, win.origH = win.x, win.y, win.w, win.h
        win.x, win.y, win.w, win.h = 1, 1, w, h - 1
        win.maximized = true
      end
      return "maximize"
    elseif x >= win.x + win.w - 4 and x <= win.x + win.w - 2 then
      return "close"
    end
  end
  return nil
end

local function monitorBody(win)
  local x, bw = win.x + 3, win.w - 6
  local function row(y, label, value, pct, color)
    rect(x, y, bw, 1, C.panel)
    put(x, y, label, C.text, C.panel, bw - ulen(value) - 1)
    put(x + bw - ulen(value), y, value, C.dim, C.panel)
    rect(x, y + 1, bw, 1, C.barbg)
    rect(x, y + 1, math.floor(bw * pct / 100), 1, color)
  end
  local total, free = cp.totalMemory(), cp.freeMemory()
  local usedPct = math.floor((total - free) * 100 / total)
  row(win.y + 2, T.ram, string.format("%d/%d KB", math.floor((total - free) / 1024), math.floor(total / 1024)), usedPct, usedPct > 85 and C.err or C.accent)
  local e, me = cp.energy(), cp.maxEnergy()
  local epct = (me == math.huge or me <= 0) and 100 or math.floor(e * 100 / me)
  row(win.y + 5, T.energy, epct .. "%", epct, epct < 20 and C.err or C.ok)
  rect(x, win.y + 8, bw, 1, C.panel)
  put(x, win.y + 8, T.uptime .. ": " .. fmtTime(cp.uptime()), C.text, C.panel, bw)
end

---------------------------------------------------------------- Apps do Sistema
local function settingsApp(cfg)
  local win = newWindow(T.mSettings, nil, false)
  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 2, "PAINEL DE CONFIGURAÇÕES", C.accent, C.panel)
    put(ix, self.y + 4, "Usuário: " .. cfg.user, C.text, C.panel)
    put(ix, self.y + 6, "Idioma: " .. langs[cfg.lang].name, C.text, C.panel)
    put(ix, self.y + self.h - 3, "Pressione Esc para fechar", C.dim, C.panel)
  end
  win.onKey = function(self, char, code) if code == 1 or code == 28 then return true end return false end
  return win
end

local function cmdApp(closeCallback)
  local win = newWindow(T.mCmd, nil, false)
  local history = { "Nitro OS Terminal v1.1", "Digite 'help' ou 'exit'." }
  local inputLine = ""

  local function addHist(s)
    history[#history + 1] = s
    if #history > 15 then table.remove(history, 1) end
  end

  local function runCmd(cmd)
    addHist("> " .. cmd)
    cmd = cmd:match("^%s*(.-)%s*$")
    if cmd == "help" then addHist("Cmds: cls, ver, uptime, exit")
    elseif cmd == "cls" then history = {}
    elseif cmd == "ver" then addHist("Nitro OS 1.1 - OpenComputers")
    elseif cmd == "uptime" then addHist("Uptime: " .. fmtTime(cp.uptime()))
    elseif cmd == "exit" then if closeCallback then closeCallback() end
    else addHist("Comando desconhecido.") end
  end

  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    local rows = self.h - 5
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    for i = 0, rows - 1 do
      local line = history[i + 1]
      if line then put(ix, self.y + 2 + i, line, C.text, C.panel, iw) end
    end
    rect(ix, self.y + self.h - 3, iw, 1, C.barbg)
    put(ix + 1, self.y + self.h - 3, "> " .. inputLine .. "_", C.text, C.barbg, iw - 2)
  end

  win.onKey = function(self, char, code)
    if code == 28 then
      if inputLine ~= "" then local cmd = inputLine; inputLine = ""; runCmd(cmd) end
      return true
    elseif code == 14 then
      if ulen(inputLine) > 0 then inputLine = usub(inputLine, 1, ulen(inputLine) - 1) end
      return true
    elseif char and char >= 32 and char ~= 127 then
      inputLine = inputLine .. uchar(char)
      return true
    end
    return false
  end
  return win
end

local function webminApp()
  local win = newWindow(T.mWebMin, nil, false)
  local url = "https://api.github.com"
  local statusText = "Pronto para teste HTTPS."

  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 2, "WEBMIN - HTTPS SEGURO", C.accent, C.panel)
    put(ix, self.y + 4, "URL: " .. url, C.dim, C.panel, iw)
    put(ix, self.y + 6, statusText, C.text, C.panel, iw)
    put(ix, self.y + self.h - 3, "[Pressione Enter para testar]", C.ok, C.panel)
  end

  win.onKey = function(self, char, code)
    if code == 28 then
      statusText = "A contactar via HTTPS..."
      win.body(win)
      local internet = cl.list("internet")()
      if not internet then
        statusText = "Erro: Sem Internet Card"
      else
        local handle, err = cl.invoke(internet, "request", url)
        if handle then
          local codeHttp = nil
          local limit = cp.uptime() + 5
          repeat
            local success = pcall(function() codeHttp = handle.response() end)
            if success and codeHttp then break end
            cp.pullSignal(0.1)
          until cp.uptime() > limit
          pcall(cl.invoke, handle, "close")
          if codeHttp and codeHttp < 400 then statusText = "Sucesso HTTPS! Código: " .. codeHttp
          else statusText = "Falha HTTP: " .. tostring(codeHttp or err) end
        else statusText = "Falha de conexão: " .. tostring(err) end
      end
      return true
    end
    return false
  end
  return win
end

local function appStoreApp()
  local win = newWindow(T.mStore, nil, false)
  local apps = {
    { name = "SCADA Reactor", folder = "ScadaApp.APP", script = "app.lua" },
    { name = "Nitro Utils", folder = "NitroUtils.APP", script = "app.lua" },
  }
  local sel = 1
  local msg = "Repositório: nitro-appstore (GitHub)"

  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    
    -- Logotipo gráfico da AppStore
    put(ix, self.y + 2, "  [◆] NITRO APPSTORE  ", C.bg, C.accent, iw)
    put(ix, self.y + 3, string.rep("─", iw), C.dim, C.panel)

    for i, app in ipairs(apps) do
      local y = self.y + 5 + (i - 1) * 2
      if i == sel then
        rect(ix - 1, y, iw + 2, 1, C.accent)
        put(ix, y, "▶ " .. app.name .. " (" .. app.folder .. ")", C.bg, C.accent, iw)
      else
        put(ix, y, "  " .. app.name, C.text, C.panel, iw)
      end
    end
    put(ix, self.y + self.h - 4, msg, C.warn, C.panel, iw)
    put(ix, self.y + self.h - 3, "Enter Instalar da pasta .APP", C.dim, C.panel)
  end

  win.onKey = function(self, char, code)
    if code == 200 and sel > 1 then sel = sel - 1; return true
    elseif code == 208 and sel < #apps then sel = sel + 1; return true
    elseif code == 28 then
      local targetApp = apps[sel]
      msg = "A baixar " .. targetApp.folder .. "/" .. targetApp.script .. "..."
      win.body(win)
      local internet = cl.list("internet")()
      if not internet then
        msg = "Erro: Sem Internet Card"
      else
        local rawUrl = string.format("https://raw.githubusercontent.com/pmiguel10766-stack/nitro-appstore/main/%s/%s", targetApp.folder, targetApp.script)
        local handle, err = cl.invoke(internet, "request", rawUrl)
        if handle then
          local data = ""
          local limit = cp.uptime() + 5
          repeat
            local chunk = handle.read()
            if chunk then data = data .. chunk else cp.pullSignal(0.1) end
          until not chunk or cp.uptime() > limit
          pcall(cl.invoke, handle, "close")
          if #data > 0 then
            fs.makeDirectory("/apps/" .. targetApp.folder)
            local hnd = fs.open("/apps/" .. targetApp.folder .. "/" .. targetApp.script, "w")
            if hnd then fs.write(hnd, data); fs.close(hnd); msg = "Instalado em /apps/!"
            else msg = "Erro ao gravar." end
          else msg = "Erro: Conteúdo vazio." end
        else msg = "Falha: " .. tostring(err) end
      end
      return true
    end
    return false
  end
  return win
end

local function notesApp()
  local win = newWindow(T.mNotes, nil, false)
  local text = "Escreva as suas notas aqui..."
  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(self.x + 2, self.y + 2, "BLOCO DE NOTAS", C.accent, C.panel)
    put(self.x + 2, self.y + 4, text, C.text, C.panel, self.w - 4)
  end
  win.onKey = function(self, char, code)
    if code == 1 then return true end
    if char and char >= 32 then text = text .. uchar(char); return true end
    return false
  end
  return win
end

local function printerApp()
  local win = newWindow(T.mPrinter, nil, false)
  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(self.x + 2, self.y + 2, "IMPRESSORA 3D (OpenComputers)", C.accent, C.panel)
    put(self.x + 2, self.y + 5, "Estado: Pronta para fabricar peças", C.ok, C.panel)
    put(self.x + 2, self.y + self.h - 3, "Pressione Esc para fechar", C.dim, C.panel)
  end
  win.onKey = function(self, code) if code == 1 then return true end return false end
  return win
end

---------------------------------------------------------------- app Arquivos
local function joinPath(dir, name)
  if dir == "/" then return "/" .. name end
  return dir .. "/" .. name
end

local function parentPath(dir)
  local p = dir:match("^(.*)/[^/]+$")
  if not p or p == "" then return "/" end
  return p
end

local function listDir(dir)
  local out = {}
  local ok, names = pcall(fs.list, dir)
  if not ok or type(names) ~= "table" then return out end
  for _, n in ipairs(names) do
    local isDir = n:sub(-1) == "/"
    local name = isDir and n:sub(1, -2) or n
    out[#out + 1] = { name = name, dir = isDir, path = joinPath(dir, name) }
  end
  table.sort(out, function(p, q) if p.dir ~= q.dir then return p.dir end return p.name:lower() < q.name:lower() end)
  return out
end

local function filesApp()
  local win = newWindow(T.mFiles, nil, false)
  win.w, win.h = 56, 17
  local st = { dir = "/", items = {}, sel = 1, first = 1 }

  local function reload()
    st.items = listDir(st.dir)
    st.sel = math.max(1, math.min(st.sel, #st.items))
  end

  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, st.dir, C.dim, C.panel, iw)

    local btnY = self.y + 2
    put(ix, btnY, "[ " .. T.bUp .. " ]", C.bg, C.accent)
    put(ix + 10, btnY, "[ " .. T.bOpen .. " ]", C.bg, C.accent)

    local rows = self.h - 8
    local listY = self.y + 4
    for i = 0, rows - 1 do
      local it = st.items[st.first + i]
      local y = listY + i
      if it then
        local isSel = (st.first + i == st.sel)
        local bg = isSel and C.accent or C.panel
        local fg = isSel and C.bg or (it.dir and C.accent or C.text)
        rect(ix - 1, y, iw + 2, 1, bg)
        put(ix, y, (it.dir and "▸ " or "  ") .. it.name, fg, bg, iw)
      else
        rect(ix - 1, y, iw + 2, 1, C.panel)
      end
    end
    put(ix, self.y + self.h - 3, "Enter Abrir    Backspace Subir", C.dim, C.panel, iw)
  end

  win.onTouch = function(self, x, y)
    local ix = self.x + 2
    local btnY = self.y + 2
    if y == btnY then
      if x >= ix and x < ix + 8 then
        if st.dir ~= "" then st.dir = parentPath(st.dir); reload() end
        return true
      elseif x >= ix + 10 and x < ix + 20 then
        local it = st.items[st.sel]
        if it and it.dir then st.dir = it.path; reload() end
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 200 and st.sel > 1 then st.sel = st.sel - 1; return true
    elseif code == 208 and st.sel < #st.items then st.sel = st.sel + 1; return true
    elseif code == 28 then
      local it = st.items[st.sel]
      if it and it.dir then st.dir = it.path; reload() end
      return true
    elseif code == 14 then
      if st.dir ~= "/" then st.dir = parentPath(st.dir); reload() end
      return true
    end
    return false
  end

  reload()
  return win
end

local function luaEditorApp()
  local win = newWindow(T.mEditor, nil, false)
  win.w, win.h = 56, 16
  local st = { lines = { "-- Editor Lua Nitro OS", "print('Ola Mundo!')" }, cy = 1, cx = 1, vfirst = 1 }
  win.body = function(self)
    local ix, iw = self.x + 2, self.w - 4
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, "/script.lua", C.dim, C.panel, iw)
    for n = 0, self.h - 7 do
      local line = st.lines[st.vfirst + n]
      if line then put(ix, self.y + 3 + n, string.format("%2d│ %s", st.vfirst + n, line), C.text, C.panel, iw) end
    end
    put(ix, self.y + self.h - 3, string.format("Ln %d, Col %d", st.cy, st.cx), C.dim, C.panel, iw)
  end
  win.onKey = function(self, char, code)
    if code == 200 then st.cy = math.max(1, st.cy - 1); return true
    elseif code == 208 then st.cy = math.min(#st.lines, st.cy + 1); return true
    elseif code == 203 then st.cx = math.max(1, st.cx - 1); return true
    elseif code == 205 then st.cx = math.min(ulen(st.lines[st.cy]) + 1, st.cx + 1); return true
    elseif char and char >= 32 then
      local line = st.lines[st.cy]
      st.lines[st.cy] = usub(line, 1, st.cx - 1) .. uchar(char) .. usub(line, st.cx)
      st.cx = st.cx + 1
      return true
    end
    return false
  end
  return win
end

local function floppyApp()
  local win = newWindow(T.mFloppy, nil, false)
  win.w, win.h = 50, 12
  win.body = function(self)
    local ix = self.x + 2
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 2, "GESTOR DE DISCOS (ACRONIS STYLE)", C.accent, C.panel)
    put(ix, self.y + 4, "[Disk 0] Sistema Principal (Boot)", C.text, C.panel)
    put(ix, self.y + 6, "[Disk 1] Disquete / Armazenamento Removível", C.dim, C.panel)
  end
  win.onKey = function(self, code) if code == 1 or code == 28 then return true end return false end
  return win
end

---------------------------------------------------------------- desktop (Ícones limpos sem texto extra)
local function desktop(cfg)
  local items = {
    { id = "files", label = T.mFiles },
    { id = "editor", label = T.mEditor },
    { id = "floppy", label = T.mFloppy },
    { id = "settings", label = T.mSettings },
    { id = "cmd", label = T.mCmd },
    { id = "webmin", label = T.mWebMin },
    { id = "store", label = T.mStore },
    { id = "notes", label = T.mNotes },
    { id = "printer", label = T.mPrinter },
    { sep = true },
    { id = "restart", label = T.mRestart, color = C.warn },
    { id = "shutdown", label = T.mShutdown, color = C.err },
  }

  local deskIcons = {
    { id = "files", label = "[F]", x = 4, y = 3 },
    { id = "editor", label = "[E]", x = 4, y = 5 },
    { id = "floppy", label = "[D]", x = 4, y = 7 },
    { id = "settings", label = "[S]", x = 4, y = 9 },
    { id = "cmd", label = "[CMD]", x = 4, y = 11 },
    { id = "webmin", label = "[WEB]", x = 4, y = 13 },
    { id = "store", label = "[APP]", x = 4, y = 15 },
    { id = "notes", label = "[N]", x = 4, y = 17 },
  }

  local menuOpen, win = false, nil
  local guard

  local function render()
    rect(1, 1, w, h - 1, C.bg)
    for _, icon in ipairs(deskIcons) do
      put(icon.x, icon.y, icon.label, C.text, C.panel)
    end
    if win and not win.minimized then guard(drawWindow, win) end
    drawTaskbar(cfg, menuOpen)
    if menuOpen then drawMenu(items) end
  end

  guard = function(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    win = nil
    menuOpen = false
    errorScreen(classify(res, 207), res, true)
    render()
    return nil
  end

  local function activateById(id)
    menuOpen = false
    if id == "restart" then cp.shutdown(true)
    elseif id == "shutdown" then cp.shutdown()
    elseif id == "monitor" then win = newWindow(T.mMonitor, monitorBody, true)
    elseif id == "settings" then win = guard(settingsApp, cfg)
    elseif id == "cmd" then win = guard(function() return cmdApp(function() win = nil; render() end) end)
    elseif id == "webmin" then win = guard(webminApp)
    elseif id == "store" then win = guard(appStoreApp)
    elseif id == "notes" then win = guard(notesApp)
    elseif id == "printer" then win = guard(printerApp)
    elseif id == "files" then win = guard(filesApp)
    elseif id == "editor" then win = guard(luaEditorApp)
    elseif id == "floppy" then win = guard(floppyApp)
    else win = newWindow(id, function(s) put(s.x+2, s.y+2, T.soon, C.dim, C.panel) end, false) end
    render()
  end

  rect(1, 1, w, h, C.bg)
  drawTaskbar(cfg, false)
  render()

  while true do
    local ev, _, a, b, c = cp.pullSignal(0.8)
    if ev == "touch" then
      if b == h and a <= ulen(MENU_BTN) then
        menuOpen = not menuOpen
        render()
      elseif b == h and a >= wifiBox.x and a < wifiBox.x + wifiBox.w then
        menuOpen = false
        win = guard(wifiApp)
        render()
      elseif menuOpen then
        local mx, my, mw, mh = menuGeometry(items)
        if inside(a, b, mx, my, mw, mh) then
          local it = items[b - my]
          if it and not it.sep then activateById(it.id) end
        else
          menuOpen = false
          render()
        end
      else
        local clickedIcon = nil
        for _, icon in ipairs(deskIcons) do
          if b == icon.y and a >= icon.x and a < icon.x + ulen(icon.label) then
            clickedIcon = icon.id
            break
          end
        end
        if clickedIcon then
          activateById(clickedIcon)
        elseif win and not win.minimized then
          local action = handleWindowControls(win, a, b)
          if action == "close" then win = nil; render()
          elseif action == "minimize" or action == "maximize" then render()
          elseif win.onTouch and inside(a, b, win.x, win.y, win.w, win.h) then
            local handled = guard(win.onTouch, win, a, b)
            if handled and win then guard(drawWindow, win) end
          end
        end
      end
    elseif ev == "key_down" then
      local handled = false
      if win and win.onKey and not menuOpen and not win.minimized then
        handled = guard(win.onKey, win, a, b)
        if handled and win then guard(drawWindow, win) end
      end
      if not handled and b == 1 then
        if menuOpen then menuOpen = false; render()
        elseif win then win = nil; render() end
      end
    else
      render()
    end
  end
end

---------------------------------------------------------------- boot
local stage = "boot"
local function main()
  bootBase()
  bootProgress(20, T.loadSys)
  pause(0.3)
  local cfg = loadConfig()
  if cfg then T = (langs[cfg.lang] or langs[1]).t end
  bootProgress(60, T.loadUser)
  pause(0.3)
  bootProgress(100, T.loadDone)
  pause(0.3)
  if not cfg then
    if configBad then errorScreen(207, CONFIG, true) end
    cfg = setup()
    saveConfig(cfg)
  end
  if cfg.hash then login(cfg) end
  stage = "desktop"
  desktop(cfg)
end

local ok, err = pcall(main)
if not ok then
  errorScreen(classify(err, stage == "boot" and 206 or 208), err, false)
end
