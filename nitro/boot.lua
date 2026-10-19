-- Nitro OS - /nitro/boot.lua
-- Primeiro boot: idioma, usuario e senha opcional. Depois: preparacao, login e area de trabalho.

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
    prepPreparing = "Estamos preparando tudo para você...",
    prepMinutes = "Isso pode levar alguns minutos.",
    prepWarn = "Aviso: Não desligue o computador",
    loginTitle = "Entrar",
    loginHello = "Olá, %s",
    loginAsk = "Senha:",
    loginWrong = "Senha incorreta",
    loginKeys = "Enter Entrar",
    welcome = "Bem-vindo, %s!",
    ready = "O Nitro OS está pronto.",
    cont = " Enter  Continuar ",
    empty = "Nenhum app instalado ainda",
    hint = "Clique em ◆ Nitro para abrir o Menu",
    soon = "Em breve",
    mFiles = "Arquivos",
    mEditor = "Editor Lua",
    mCalc = "Calculadora",
    mMonitor = "Monitor do Sistema",
    mNotes = "Notas",
    mPrinter = "Impressora 3D",
    mRestart = "Reiniciar",
    mShutdown = "Desligar",
    ram = "RAM",
    energy = "Energia",
    uptime = "Tempo ligado",
    bUp = "↑ Subir",
    bOpen = "Abrir",
    bCreate = "+ Criar",
    bRename = "Renomear",
    bDelete = "Excluir",
    bSave = "Salvar",
    bBack = "Voltar",
    bYes = "Sim",
    bNo = "Não",
    bOk = "OK",
    bCancel = "Cancelar",
    emptyDir = "(pasta vazia)",
    confirmDel = "Excluir %s?  [S/N]",
    sysWarn = "SISTEMA: %s - excluir mesmo assim?  [S/N]",
    sysLocked = "Arquivo do sistema: protegido",
    renamePrompt = "Novo nome:",
    createPrompt = "Nome do novo arquivo:",
    deleted = "Excluído",
    renamed = "Renomeado",
    created = "Criado",
    saved = "Salvo com sucesso!",
    nameExists = "Esse nome já existe",
    nameBad = "Nome inválido",
    binaryFile = "Arquivo binário, não dá para mostrar",
    errPrefix = "Erro: ",
    truncated = "(arquivo cortado)",
    calcErr = "Erro",
    loadSys = "Carregando sistema...",
    loadUser = "Carregando usuário...",
    loadDesk = "Preparando a área de trabalho...",
    loadDone = "Pronto!",
    loaded = "Carregado",
    errTitle = "ERRO FATAL DO SISTEMA",
    errTitleApp = "ERRO NO SISTEMA",
    errContinue = "Enter Continuar",
    errRestart = "Enter Reiniciar",
    e203 = "Sistema corrompido",
    e204 = "Sistema sem RAM",
    e205 = "Falha ao atualizar",
    e206 = "Problema no boot do sistema",
    e207 = "Problema em app ou usuário",
    e208 = "Erro desconhecido",
    wifi = "Rede",
    wifiType = "Tipo",
    wifiStatus = "Status",
    wifiOk = "Conectado",
    wifiWarn = "Placa sem HTTP",
    wifiNone = "Sem placa de rede",
    wifiWireless = "Sem fio ativo, sem Internet Card",
    wifiWired = "Rede local, sem internet",
    wifiTest = "Testar conexão",
    wifiTesting = "Testando...",
    wifiTestOk = "Conexão OK (%s)",
    wifiTestFail = "Falhou: %s",
    wifiRange = "Alcance do sinal",
    wifiNoCard = "Sem Internet Card",
  } },
  { name = "English", t = {
    steps = { "Language", "User", "Password" },
    userTitle = "Create user",
    userAsk = "Username:",
    userEmpty = "Type a name",
    passTitle = "Password (optional)",
    passAsk = "Password (Enter to skip):",
    passConfirm = "Repeat the password:",
    passMismatch = "Passwords do not match",
    keysInput = "Enter OK    Esc Back",
    prepHello = "Hello, %s",
    prepPreparing = "We are getting everything ready for you...",
    prepMinutes = "This might take a few minutes.",
    prepWarn = "Warning: Do not turn off your computer",
    loginTitle = "Sign in",
    loginHello = "Hello, %s",
    loginAsk = "Password:",
    loginWrong = "Wrong password",
    loginKeys = "Enter Sign in",
    welcome = "Welcome, %s!",
    ready = "Nitro OS is ready.",
    cont = " Enter  Continue ",
    empty = "No apps installed yet",
    hint = "Click ◆ Nitro to open the Menu",
    soon = "Coming soon",
    mFiles = "Files",
    mEditor = "Lua Editor",
    mCalc = "Calculator",
    mMonitor = "System Monitor",
    mNotes = "Notes",
    mPrinter = "3D Printer",
    mRestart = "Restart",
    mShutdown = "Shut down",
    ram = "RAM",
    energy = "Energy",
    uptime = "Uptime",
    bUp = "↑ Up",
    bOpen = "Open",
    bCreate = "+ Create",
    bRename = "Rename",
    bDelete = "Delete",
    bSave = "Save",
    bBack = "Back",
    bYes = "Yes",
    bNo = "No",
    bOk = "OK",
    bCancel = "Cancel",
    emptyDir = "(empty folder)",
    confirmDel = "Delete %s?  [Y/N]",
    sysWarn = "SYSTEM: %s - delete anyway?  [Y/N]",
    sysLocked = "System file: protected",
    renamePrompt = "New name:",
    createPrompt = "New file name:",
    deleted = "Deleted",
    renamed = "Renamed",
    created = "Created",
    saved = "Successfully saved!",
    nameExists = "That name already exists",
    nameBad = "Invalid name",
    binaryFile = "Binary file, cannot display",
    errPrefix = "Error: ",
    truncated = "(file truncated)",
    calcErr = "Error",
    loadSys = "Loading system...",
    loadUser = "Loading user...",
    loadDesk = "Preparing the desktop...",
    loadDone = "Done!",
    loaded = "Loaded",
    errTitle = "FATAL SYSTEM ERROR",
    errTitleApp = "SYSTEM ERROR",
    errContinue = "Enter Continue",
    errRestart = "Enter Restart",
    e203 = "System corrupted",
    e204 = "System out of RAM",
    e205 = "Update failed",
    e206 = "System boot problem",
    e207 = "App or user problem",
    e208 = "Unknown error",
    wifi = "Network",
    wifiType = "Type",
    wifiStatus = "Status",
    wifiOk = "Connected",
    wifiWarn = "Card without HTTP",
    wifiNone = "No network card",
    wifiWireless = "Wireless on, no Internet Card",
    wifiWired = "Local network, no internet",
    wifiTest = "Test connection",
    wifiTesting = "Testing...",
    wifiTestOk = "Connection OK (%s)",
    wifiTestFail = "Failed: %s",
    wifiRange = "Signal range",
    wifiNoCard = "No Internet Card",
  } },
}

local T = langs[1].t

local function bootProgress(pct, text)
  local loadedLabel = (T and T.loaded) or "Carregando"
  local label = string.format("[%s %d%%]", loadedLabel, pct)
  rect(1, bootBar.y - 1, w, 1, C.bg)
  put(math.floor((w - ulen(label)) / 2) + 1, bootBar.y - 1, label, C.text, C.bg)
  rect(bootBar.x, bootBar.y, bootBar.w, 1, C.barbg)
  rect(bootBar.x, bootBar.y, math.floor(bootBar.w * pct / 100), 1, C.accent)
end

---------------------------------------------------------------- tela de erro (codigo MX)
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

  local ix = ex + 3
  local icon = { "┏━     ━┓", "┃ ╲   ╱ ┃", "┃   ╳   ┃", "┃ ╱   ╲ ┃", "┗━     ━┛" }
  for i, row in ipairs(icon) do put(ix, ey + 1 + i, row, C.accent, C.bg) end

  local tx, tw = ix + 12, ew - 17
  put(tx, ey + 2, canContinue and T.errTitleApp or T.errTitle, C.accent, C.bg, tw)
  put(tx, ey + 3, string.rep("─", tw), C.accent, C.bg)
  put(tx, ey + 4, string.format("MX-%d  %s", code, T["e" .. code] or T.e208),
    C.text, C.bg, tw)
  local text = tostring(detail or ""):gsub("%s+", " ")
  for n = 0, 2 do
    local part = usub(text, n * tw + 1, (n + 1) * tw)
    if ulen(part) > 0 then put(tx, ey + 5 + n, part, C.dim, C.bg, tw) end
  end
  put(ix, ey + eh - 4, string.rep("▞", ew - 6), C.accent, C.bg)
  put(ix, ey + eh - 2, canContinue and T.errContinue or T.errRestart, C.dim, C.bg)

  while true do
    if key() == 28 then break end
  end
  if not canContinue then cp.shutdown(true) end
end

---------------------------------------------------------------- moldura
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

---------------------------------------------------------------- utilitarios
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
  fs.write(hnd, string.format("return {user=%q,lang=%d,hash=%s}",
    cfg.user, cfg.lang, hashText))
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

---------------------------------------------------------------- primeiro boot
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

  center(py + ph - 3, "⚠️ " .. T.prepWarn, C.warn, C.panel)

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

---------------------------------------------------------------- login
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

---------------------------------------------------------------- area de trabalho
local function clock()
  local ok, text = pcall(os.date, "%H:%M", os.time())
  return ok and text or "--:--"
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
  if title then put(x + 2, y, " " .. title .. " ", C.text, C.panel, bw - 8) end
end

---------------------------------------------------------------- rede (Internet Card / Wireless Network Card)
local NET_TEST = "https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/files.txt"

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
  if s == "ok" then
    return "▂▄▆", " ", C.ok, C.ok
  elseif s == "warn" then
    return "▂▄▆", "!", C.warn, C.warn
  elseif s == "wireless" then
    return "▂▄▆", "▼", C.ok, C.accent
  elseif s == "wired" then
    return "▂▄▆", " ", C.dim, C.dim
  end
  return "▂▄▆", "×", C.dim, C.err
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
  local testY, rangeY = win.y + 6, win.y + 8
  local result, resultColor = "", C.dim

  local function testLabel() return " " .. T.wifiTest .. " " end

  local function strength(info)
    local okS, cur = pcall(info.modem.getStrength)
    return (okS and tonumber(cur)) or 0
  end

  local function adjust(info, delta)
    local new = math.max(0, math.min(400, strength(info) + delta))
    pcall(info.modem.setStrength, new)
  end

  local function doTest()
    result, resultColor = T.wifiTesting, C.dim
    win.body(win)
    local ok, msg = netTest()
    if ok then
      result, resultColor = string.format(T.wifiTestOk, msg), C.ok
    else
      result, resultColor = string.format(T.wifiTestFail, msg), C.err
    end
  end

  win.body = function(self)
    local info = netInfo()
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)

    put(ix, self.y + 2, T.wifiType .. ":", C.dim, C.panel)
    if #info.types == 0 then
      put(ix + 9, self.y + 2, "-", C.text, C.panel)
    end
    for i, name in ipairs(info.types) do
      put(ix + 9, self.y + 1 + i, name, C.text, C.panel, iw - 9)
    end

    local text, color = T.wifiNone, C.err
    if info.state == "ok" then
      text, color = T.wifiOk, C.ok
    elseif info.state == "warn" then
      text, color = T.wifiWarn, C.warn
    elseif info.state == "wireless" then
      text, color = T.wifiWireless, C.ok
    elseif info.state == "wired" then
      text, color = T.wifiWired, C.warn
    end
    put(ix, self.y + 4, T.wifiStatus .. ":", C.dim, C.panel)
    put(ix + 9, self.y + 4, text, color, C.panel, iw - 9)

    if result ~= "" then put(ix, self.y + 5, result, resultColor, C.panel, iw) end
    local label = testLabel()
    rect(ix, testY, ulen(label), 1, C.accent)
    put(ix, testY, label, C.bg, C.accent)

    if info.wireless then
      local cur = strength(info)
      put(ix, rangeY - 1, T.wifiRange .. ": " .. cur .. "/400", C.dim, C.panel, iw)
      local bx, bw = ix + 4, iw - 13
      put(ix, rangeY, "[-]", C.bg, C.accent)
      rect(bx, rangeY, bw, 1, C.barbg)
      rect(bx, rangeY, math.floor(bw * cur / 400), 1, C.accent)
      put(bx + bw + 1, rangeY, "[+]", C.bg, C.accent)
    end
  end

  win.onTouch = function(self, x, y)
    if y == testY and x >= ix and x < ix + ulen(testLabel()) then
      doTest()
      return true
    end
    local info = netInfo()
    if info.wireless and y == rangeY then
      if x >= ix and x < ix + 3 then
        adjust(info, -50)
        return true
      elseif x >= ix + iw - 12 and x < ix + iw - 9 then
        adjust(info, 50)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 28 then
      doTest()
      return true
    end
    local info = netInfo()
    if info.wireless and (char == 43 or char == 61) then
      adjust(info, 50)
      return true
    elseif info.wireless and char == 45 then
      adjust(info, -50)
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- barra de tarefas e menu
local wifiBox = { x = 0, w = 4 }
local MENU_BTN = " ◆ Nitro "
local MENU_W = 26

local function drawTaskbar(cfg, menuOpen)
  rect(1, h, w, 1, C.panel)
  if menuOpen then
    put(1, h, MENU_BTN, C.bg, C.accent)
  else
    put(1, h, MENU_BTN, C.accent, C.panel)
  end
  local right = cfg.user .. "  " .. clock()
  put(w - ulen(right), h, right, C.text, C.panel)

  local bars, suffix, barColor, sufColor = wifiGlyph(netInfo())
  wifiBox.x = w - ulen(right) - 5
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

---------------------------------------------------------------- janelas
local function newWindow(title, body, live)
  local ww = math.min(w - 4, 46)
  local wh = math.min(h - 3, 11)
  return {
    title = title, body = body, live = live, w = ww, h = wh,
    x = math.floor((w - ww) / 2) + 1,
    y = math.floor((h - 1 - wh) / 2) + 1,
  }
end

local function drawWindow(win)
  drawBox(win.x, win.y, win.w, win.h, win.title)
  put(win.x + win.w - 5, win.y, "[X]", C.bg, C.accent)
  win.body(win)
end

local function closeHit(win, x, y)
  return y == win.y and x >= win.x + win.w - 5 and x <= win.x + win.w - 3
end

local function soonBody(win)
  local s = T.soon
  put(win.x + math.floor((win.w - ulen(s)) / 2), win.y + math.floor(win.h / 2),
    s, C.dim, C.panel)
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
  row(win.y + 2, T.ram,
    string.format("%d/%d KB", math.floor((total - free) / 1024), math.floor(total / 1024)),
    usedPct, usedPct > 85 and C.err or C.accent)

  local e, me = cp.energy(), cp.maxEnergy()
  local epct = (me == math.huge or me <= 0) and 100 or math.floor(e * 100 / me)
  row(win.y + 5, T.energy, epct .. "%", epct, epct < 20 and C.err or C.ok)

  rect(x, win.y + 8, bw, 1, C.panel)
  put(x, win.y + 8, T.uptime .. ": " .. fmtTime(cp.uptime()), C.text, C.panel, bw)
end

---------------------------------------------------------------- app Arquivos com Criar Arquivo
local function joinPath(dir, name)
  if dir == "/" then return "/" .. name end
  return dir .. "/" .. name
end

local function parentPath(dir)
  local p = dir:match("^(.*)/[^/]+$")
  if not p or p == "" then return "/" end
  return p
end

local function fmtSize(n)
  if n < 1024 then return n .. "B" end
  return string.format("%.1fK", n / 1024)
end

local function listDir(dir)
  local out = {}
  local ok, names = pcall(fs.list, dir)
  if not ok or type(names) ~= "table" then return out end
  for _, n in ipairs(names) do
    local isDir = n:sub(-1) == "/"
    local name = isDir and n:sub(1, -2) or n
    local path = joinPath(dir, name)
    out[#out + 1] = {
      name = name, dir = isDir, path = path,
      size = isDir and 0 or fs.size(path),
    }
  end
  table.sort(out, function(p, q)
    if p.dir ~= q.dir then return p.dir end
    return p.name:lower() < q.name:lower()
  end)
  return out
end

local function readPreview(path)
  local hnd = fs.open(path)
  if not hnd then return nil end
  local data = fs.read(hnd, 8192) or ""
  fs.close(hnd)
  return data
end

local function filesApp()
  local win = {
    title = T.mFiles,
    w = math.min(w - 2, 60),
    h = math.min(h - 2, 18),
  }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)

  local ix, iw = win.x + 2, win.w - 4
  local btnY, listY = win.y + 2, win.y + 4
  local rows = win.h - 8
  local statusY = win.y + win.h - 3

  local st = {
    dir = "/", items = {}, sel = 1, first = 1, mode = "list",
    msg = "", msgColor = C.warn, input = "", lines = {}, vfirst = 1,
    viewName = "", lastClick = 0,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function selected() return st.items[st.sel] end

  local function keepVisible()
    if st.sel > #st.items then st.sel = #st.items end
    if st.sel < 1 then st.sel = 1 end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function reload(select)
    st.items = listDir(st.dir)
    st.sel, st.first = 1, 1
    if select then
      for i, it in ipairs(st.items) do
        if it.name == select then st.sel = i end
      end
    end
    keepVisible()
  end

  local function backToList()
    st.mode = "list"
    st.msg = ""
  end

  local function goUp()
    if st.dir ~= "/" then
      local old = st.dir:match("([^/]+)$")
      st.dir = parentPath(st.dir)
      reload(old)
      st.msg = ""
    end
  end

  local function openItem()
    local it = selected()
    if not it then return end
    if it.dir then
      st.dir = it.path
      reload()
      st.msg = ""
      return
    end
    local data = readPreview(it.path)
    if not data then
      setMsg(T.errPrefix .. it.name, C.err)
      return
    end
    if data:find("\0", 1, true) then
      setMsg(T.binaryFile, C.warn)
      return
    end
    st.lines = {}
    for line in (data .. "\n"):gmatch("([^\n]*)\n") do
      line = line:gsub("\r", "")
      line = line:gsub("\t", "  ")
      st.lines[#st.lines + 1] = line
    end
    if it.size > 8192 then st.lines[#st.lines + 1] = T.truncated end
    st.vfirst = 1
    st.viewName = it.path
    st.mode = "view"
    st.msg = ""
  end

  local function startCreate()
    st.mode = "create"
    st.input = ""
    st.msg = ""
  end

  local function doCreate()
    local name = st.input:match("^%s*(.-)%s*$")
    if name == "" or name:find("/", 1, true) then
      setMsg(T.nameBad, C.err)
      return
    end
    local target = joinPath(st.dir, name)
    if fs.exists(target) then
      setMsg(T.nameExists, C.err)
      return
    end
    local hnd = fs.open(target, "w")
    if hnd then
      fs.write(hnd, "")
      fs.close(hnd)
      reload(name)
      setMsg(T.created, C.ok)
    else
      setMsg(T.errPrefix .. name, C.err)
    end
    st.mode = "list"
  end

  local function startRename()
    local it = selected()
    if not it then return end
    if it.path:sub(1, 6) == "/nitro" then
      setMsg(T.sysLocked, C.warn)
      return
    end
    st.mode = "rename"
    st.input = it.name
    st.msg = ""
  end

  local function startDelete()
    local it = selected()
    if not it then return end
    st.mode = "confirm"
    if it.path:sub(1, 6) == "/nitro" then
      setMsg(string.format(T.sysWarn, it.name), C.err)
    else
      setMsg(string.format(T.confirmDel, it.name), C.warn)
    end
  end

  local function doDelete()
    local it = selected()
    local keep = st.sel
    st.mode = "list"
    if not it then return end
    local ok, result = pcall(fs.remove, it.path)
    if ok and result then
      reload()
      st.sel = keep
      keepVisible()
      setMsg(T.deleted, C.ok)
    else
      setMsg(T.errPrefix .. it.name, C.err)
    end
  end

  local function doRename()
    local it = selected()
    if not it then
      st.mode = "list"
      return
    end
    local name = st.input:match("^%s*(.-)%s*$")
    if name == "" or name:find("/", 1, true) then
      setMsg(T.nameBad, C.err)
      return
    end
    if name == it.name then
      backToList()
      return
    end
    local target = joinPath(st.dir, name)
    if fs.exists(target) then
      setMsg(T.nameExists, C.err)
      return
    end
    local ok = pcall(fs.rename, it.path, target)
    st.mode = "list"
    if ok then
      reload(name)
      setMsg(T.renamed, C.ok)
    else
      setMsg(T.errPrefix .. it.name, C.err)
    end
  end

  local actions = {
    up = goUp, open = openItem, create = startCreate, rename = startRename, delete = startDelete,
    yes = doDelete, no = backToList, ok = function() if st.mode == "create" then doCreate() else doRename() end end, cancel = backToList,
    back = backToList,
  }

  local function curButtons()
    local defs
    if st.mode == "view" then
      defs = { { "back", T.bBack } }
    elseif st.mode == "confirm" then
      defs = { { "yes", T.bYes }, { "no", T.bNo } }
    elseif st.mode == "rename" or st.mode == "create" then
      defs = { { "ok", T.bOk }, { "cancel", T.bCancel } }
    else
      defs = { { "up", T.bUp }, { "open", T.bOpen }, { "create", T.bCreate },
               { "rename", T.bRename }, { "delete", T.bDelete } }
    end
    local out, x = {}, ix
    for _, d in ipairs(defs) do
      local label = " " .. d[2] .. " "
      out[#out + 1] = { id = d[1], x = x, label = label }
      x = x + ulen(label) + 1
    end
    return out
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local header = (st.mode == "view") and st.viewName or st.dir
    put(ix, self.y + 1, header, C.dim, C.panel, iw)

    for _, b in ipairs(curButtons()) do
      local bg = (b.id == "delete" or b.id == "yes") and C.warn or C.accent
      put(b.x, btnY, b.label, C.bg, bg)
    end

    if st.mode == "view" then
      for n = 0, rows - 1 do
        local line = st.lines[st.vfirst + n]
        if line then put(ix, listY + n, line, C.text, C.panel, iw) end
      end
    else
      if #st.items == 0 then put(ix, listY, T.emptyDir, C.dim, C.panel, iw) end
      for n = 0, rows - 1 do
        local it = st.items[st.first + n]
        if it then
          local y = listY + n
          local isSel = (st.first + n == st.sel)
          local bg = isSel and C.accent or C.panel
          local fg = isSel and C.bg or (it.dir and C.accent or C.text)
          rect(ix - 1, y, iw + 2, 1, bg)
          local label = (it.dir and "▸ " or "  ") .. it.name .. (it.dir and "/" or "")
          local size = it.dir and "" or fmtSize(it.size)
          put(ix, y, label, fg, bg, iw - ulen(size) - 1)
          if size ~= "" then put(ix + iw - ulen(size), y, size, fg, bg) end
        end
      end
      if st.first > 1 then put(self.x + self.w - 3, listY, "▲", C.dim, C.panel) end
      if st.first + rows <= #st.items then
        put(self.x + self.w - 3, listY + rows - 1, "▼", C.dim, C.panel)
      end
    end

    if st.mode == "rename" or st.mode == "create" then
      rect(ix, statusY, iw, 1, C.barbg)
      local promptText = (st.mode == "create") and T.createPrompt or T.renamePrompt
      put(ix + 1, statusY, promptText .. " " .. st.input .. "_", C.text, C.barbg, iw - 2)
      if st.msg ~= "" then put(ix, statusY - 1, st.msg, st.msgColor, C.panel, iw) end
    elseif st.mode == "view" then
      local last = math.min(#st.lines, st.vfirst + rows - 1)
      put(ix, statusY, string.format("%d-%d / %d", st.vfirst, last, #st.lines),
        C.dim, C.panel, iw)
    elseif st.msg ~= "" then
      put(ix, statusY, st.msg, st.msgColor, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      for _, b in ipairs(curButtons()) do
        if x >= b.x and x < b.x + ulen(b.label) then
          actions[b.id]()
          return true
        end
      end
    elseif st.mode == "list" and y >= listY and y < listY + rows
        and x >= self.x + 1 and x < self.x + self.w - 1 then
      local idx = st.first + (y - listY)
      if st.items[idx] then
        local now = cp.uptime()
        if st.sel == idx and now - st.lastClick < 1.5 then
          openItem()
        else
          st.sel = idx
          st.msg = ""
        end
        st.lastClick = now
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "rename" or st.mode == "create" then
      if code == 28 then
        if st.mode == "create" then doCreate() else doRename() end
      elseif code == 1 then
        backToList()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(st.input) < 32 then
        st.input = st.input .. uchar(char)
      end
      return true
    elseif st.mode == "confirm" then
      if code == 31 or code == 21 then
        doDelete()
      elseif code == 49 or code == 1 then
        backToList()
      end
      return true
    elseif st.mode == "view" then
      if code == 200 then
        st.vfirst = math.max(1, st.vfirst - 1)
      elseif code == 208 then
        st.vfirst = math.max(1, math.min(st.vfirst + 1, #st.lines - rows + 1))
      elseif code == 1 or code == 14 or code == 28 then
        backToList()
      end
      return true
    end
    if code == 200 then
      st.sel = st.sel - 1
      keepVisible()
      return true
    elseif code == 208 then
      st.sel = st.sel + 1
      keepVisible()
      return true
    elseif code == 28 then
      openItem()
      return true
    elseif code == 14 then
      goUp()
      return true
    elseif code == 211 then
      startDelete()
      return true
    elseif code == 60 then
      startRename()
      return true
    end
    return false
  end

  win.onScroll = function(self, dir)
    if st.mode == "view" then
      local maxFirst = math.max(1, #st.lines - rows + 1)
      st.vfirst = math.max(1, math.min(st.vfirst - dir * 3, maxFirst))
    elseif st.mode == "list" then
      st.sel = st.sel - dir
      keepVisible()
    end
  end

  reload()
  return win
end

---------------------------------------------------------------- app Editor Lua
local function luaEditorApp()
  local win = {
    title = T.mEditor,
    w = math.min(w - 2, 60),
    h = math.min(h - 2, 18),
  }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)

  local ix, iw = win.x + 2, win.w - 4
  local btnY, listY = win.y + 2, win.y + 4
  local rows = win.h - 8
  local statusY = win.y + win.h - 3

  local st = {
    lines = { "-- Novo script Lua no Nitro OS", "print('Ola, Nitro OS!')" },
    cy = 1, cx = 1, vfirst = 1, msg = "", msgColor = C.warn, filename = "/script.lua"
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function saveFile()
    local hnd = fs.open(st.filename, "w")
    if not hnd then
      setMsg(T.errPrefix .. "Salvar", C.err)
      return
    end
    for _, l in ipairs(st.lines) do
      fs.write(hnd, l .. "\n")
    end
    fs.close(hnd)
    setMsg(T.saved, C.ok)
  end

  local function curButtons()
    local defs = { { "save", T.bSave } }
    local out, x = {}, ix
    for _, d in ipairs(defs) do
      local label = " " .. d[2] .. " "
      out[#out + 1] = { id = d[1], x = x, label = label }
      x = x + ulen(label) + 1
    end
    return out
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, st.filename, C.dim, C.panel, iw)

    for _, b in ipairs(curButtons()) do
      put(b.x, btnY, b.label, C.bg, C.ok)
    end

    for n = 0, rows - 1 do
      local lineIdx = st.vfirst + n
      local line = st.lines[lineIdx]
      local y = listY + n
      if line then
        put(ix, y, string.format("%2d│ %s", lineIdx, line), C.text, C.panel, iw)
      else
        put(ix, y, string.format("%2d│", lineIdx), C.dim, C.panel, iw)
      end
    end

    if st.msg ~= "" then
      put(ix, statusY, st.msg, st.msgColor, C.panel, iw)
    else
      put(ix, statusY, string.format("Ln %d, Col %d", st.cy, st.cx), C.dim, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      for _, b in ipairs(curButtons()) do
        if x >= b.x and x < b.x + ulen(b.label) then
          saveFile()
          return true
        end
      end
    elseif y >= listY and y < listY + rows then
      local clickedRow = st.vfirst + (y - listY)
      if clickedRow <= #st.lines then
        st.cy = clickedRow
        st.cx = math.min(st.cx, ulen(st.lines[st.cy]) + 1)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 200 then -- Seta cima
      st.cy = math.max(1, st.cy - 1)
      if st.cy < st.vfirst then st.vfirst = st.cy end
      st.cx = math.min(st.cx, ulen(st.lines[st.cy]) + 1)
      return true
    elseif code == 208 then -- Seta baixo
      st.cy = math.min(#st.lines, st.cy + 1)
      if st.cy >= st.vfirst + rows then st.vfirst = st.cy - rows + 1 end
      st.cx = math.min(st.cx, ulen(st.lines[st.cy]) + 1)
      return true
    elseif code == 14 then -- Backspace
      local line = st.lines[st.cy]
      if st.cx > 1 then
        st.lines[st.cy] = usub(line, 1, st.cx - 2) .. usub(line, st.cx)
        st.cx = st.cx - 1
      elseif st.cy > 1 then
        local prevLine = st.lines[st.cy - 1]
        st.cx = ulen(prevLine) + 1
        st.lines[st.cy - 1] = prevLine .. line
        table.remove(st.lines, st.cy)
        st.cy = st.cy - 1
        if st.cy < st.vfirst then st.vfirst = st.cy end
      end
      return true
    elseif code == 28 then -- Enter
      local line = st.lines[st.cy]
      local rest = usub(line, st.cx)
      st.lines[st.cy] = usub(line, 1, st.cx - 1)
      table.insert(st.lines, st.cy + 1, rest)
      st.cy = st.cy + 1
      st.cx = 1
      if st.cy >= st.vfirst + rows then st.vfirst = st.cy - rows + 1 end
      return true
    elseif char and char >= 32 and char ~= 127 then
      local line = st.lines[st.cy]
      st.lines[st.cy] = usub(line, 1, st.cx - 1) .. uchar(char) .. usub(line, st.cx)
      st.cx = st.cx + 1
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- app Calculadora
local CALC_LAYOUT = {
  { { "C", "C" }, { "←", "BS" }, { "%", "%" }, { "÷", "/" } },
  { { "7", "7" }, { "8", "8" }, { "9", "9" }, { "×", "*" } },
  { { "4", "4" }, { "5", "5" }, { "6", "6" }, { "−", "-" } },
  { { "1", "1" }, { "2", "2" }, { "3", "3" }, { "+", "+" } },
  { { "0", "0", 2 }, { ".", "." }, { "=", "=" } },
}
local OPSYM = { ["+"] = "+", ["-"] = "−", ["*"] = "×", ["/"] = "÷" }

local function calcFmt(n)
  if n ~= n or n == math.huge or n == -math.huge then return nil end
  return string.format("%.10g", n)
end

local function calcApply(a, b, o)
  if o == "+" then
    return a + b
  elseif o == "-" then
    return a - b
  elseif o == "*" then
    return a * b
  elseif o == "/" then
    if b == 0 then return nil end
    return a / b
  end
  return nil
end

local function calcApp()
  local win = { title = T.mCalc, w = 34, h = 11 }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)

  local BW, GAP = 6, 1
  local gridW = 4 * BW + 3 * GAP

  local cur, prev, op, expr = "0", nil, nil, ""
  local fresh, isErr = true, false

  local function clearAll()
    cur, prev, op, expr = "0", nil, nil, ""
    fresh, isErr = true, false
  end

  local function setError()
    cur, prev, op, expr = T.calcErr, nil, nil, ""
    fresh, isErr = true, true
  end

  local function digit(d)
    if isErr then clearAll() end
    if fresh then
      cur = "0"
      fresh = false
    end
    if cur == "0" then
      cur = d
    elseif #cur < 12 then
      cur = cur .. d
    end
  end

  local function dot()
    if isErr then clearAll() end
    if fresh then
      cur = "0"
      fresh = false
    end
    if not cur:find(".", 1, true) and #cur < 12 then cur = cur .. "." end
  end

  local function backspace()
    if fresh or isErr then return end
    cur = cur:sub(1, -2)
    if cur == "" or cur == "-" then cur = "0" end
  end

  local function percent()
    if isErr then return end
    local v = tonumber(cur)
    if v then
      cur = calcFmt(v / 100) or cur
      fresh = true
    end
  end

  local function operator(o)
    if isErr then return end
    local val = tonumber(cur) or 0
    if op and not fresh then
      local r = calcApply(prev, val, op)
      if r == nil or not calcFmt(r) then
        setError()
        return
      end
      prev = r
      cur = calcFmt(r)
    else
      prev = val
    end
    op = o
    fresh = true
    expr = calcFmt(prev) .. " " .. OPSYM[o]
  end

  local function equals()
    if isErr or not op then return end
    local val = tonumber(cur) or 0
    local r = calcApply(prev, val, op)
    if r == nil or not calcFmt(r) then
      setError()
      return
    end
    expr = calcFmt(prev) .. " " .. OPSYM[op] .. " " .. calcFmt(val) .. " ="
    cur = calcFmt(r)
    prev, op, fresh = nil, nil, true
  end

  local function press(id)
    if id:match("^%d$") then digit(id)
    elseif id == "." then dot()
    elseif id == "C" then clearAll()
    elseif id == "BS" then backspace()
    elseif id == "%" then percent()
    elseif id == "=" then equals()
    else operator(id) end
  end

  local function rects(self)
    local out = {}
    local gx = self.x + math.floor((self.w - gridW) / 2)
    for r, row in ipairs(CALC_LAYOUT) do
      local c = 0
      for _, b in ipairs(row) do
        local span = b[3] or 1
        out[#out + 1] = {
          label = b[1], id = b[2],
          x = gx + c * (BW + GAP), y = self.y + 3 + r,
          w = span * BW + (span - 1) * GAP,
        }
        c = c + span
      end
    end
    return out
  end

  local function colors(id)
    if id:match("^%d$") or id == "." then return 0x333333, C.text end
    if id == "=" then return C.ok, C.bg end
    if id == "C" then return C.warn, C.bg end
    if id == "BS" or id == "%" then return 0x555555, C.text end
    return C.accent, C.bg
  end

  local function drawButton(b, bg, fg)
    rect(b.x, b.y, b.w, 1, bg)
    put(b.x + math.floor((b.w - ulen(b.label)) / 2), b.y, b.label, fg, bg)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local ix, iw = self.x + 2, self.w - 4
    put(ix + iw - ulen(expr), self.y + 1, expr, C.dim, C.panel, iw)
    rect(ix, self.y + 2, iw, 1, C.barbg)
    put(ix + iw - 1 - ulen(cur), self.y + 2, cur, isErr and C.err or C.text, C.barbg, iw - 1)
    for _, b in ipairs(rects(self)) do
      local bg, fg = colors(b.id)
      drawButton(b, bg, fg)
    end
  end

  win.onTouch = function(self, x, y)
    for _, b in ipairs(rects(self)) do
      if y == b.y and x >= b.x and x < b.x + b.w then
        drawButton(b, C.text, C.bg)
        cp.pullSignal(0.1)
        press(b.id)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 28 or code == 156 then
      press("=")
      return true
    elseif code == 14 then
      press("BS")
      return true
    end
    if char and char >= 32 and char < 127 then
      local ch = string.char(char)
      if ch:match("%d") then
        press(ch)
        return true
      elseif ch == "." or ch == "," then
        press(".")
        return true
      elseif ch == "+" or ch == "-" or ch == "*" or ch == "/" then
        press(ch)
        return true
      elseif ch == "=" or ch == "%" then
        press(ch)
        return true
      elseif ch == "c" or ch == "C" then
        press("C")
        return true
      end
    end
    return false
  end

  return win
end

---------------------------------------------------------------- boas-vindas
local function welcome(cfg)
  local bw = math.min(w - 6, 40)
  local bh = 7
  local bx = math.floor((w - bw) / 2) + 1
  local by = math.floor((h - bh) / 2)
  drawBox(bx, by, bw, bh)

  local function mid(y, s, fg, bg)
    put(bx + math.floor((bw - ulen(s)) / 2), y, s, fg, bg)
  end
  mid(by + 2, string.format(T.welcome, cfg.user), C.text, C.panel)
  mid(by + 3, T.ready, C.dim, C.panel)

  local label = T.cont
  local lx = bx + math.floor((bw - ulen(label)) / 2)
  local ly = by + 5
  put(lx, ly, label, C.bg, C.accent)

  while true do
    local ev, _, a, b = cp.pullSignal()
    if ev == "key_down" and b == 28 then return end
    if ev == "touch" and inside(a, b, lx, ly, ulen(label), 1) then return end
  end
end

---------------------------------------------------------------- desktop
local function desktop(cfg)
  local items = {
    { id = "files", label = T.mFiles },
    { id = "editor", label = T.mEditor },
    { id = "calc", label = T.mCalc },
    { id = "monitor", label = T.mMonitor },
    { id = "notes", label = T.mNotes },
    { id = "printer", label = T.mPrinter },
    { sep = true },
    { id = "restart", label = T.mRestart, color = C.warn },
    { id = "shutdown", label = T.mShutdown, color = C.err },
  }
  local menuOpen, win = false, nil
  local guard

  local function render()
    rect(1, 1, w, h - 1, C.bg)
    local size = logoSize()
    local ly = math.floor((h - 1 - (size + 3)) / 2) + 1
    drawLogo(math.floor((w - logoWidth(size)) / 2) + 1, ly, size, C.bg, 0x666666)
    put(math.floor((w - ulen(T.empty)) / 2), ly + size + 1, T.empty, C.dim, C.bg)
    put(math.floor((w - ulen(T.hint)) / 2), ly + size + 2, T.hint, C.dim, C.bg)
    if win then guard(drawWindow, win) end
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

  local function activate(it)
    menuOpen = false
    if it.id == "restart" then
      cp.shutdown(true)
    elseif it.id == "shutdown" then
      cp.shutdown()
    elseif it.id == "monitor" then
      win = newWindow(T.mMonitor, monitorBody, true)
    elseif it.id == "files" then
      win = guard(filesApp)
    elseif it.id == "editor" then
      win = guard(luaEditorApp)
    elseif it.id == "calc" then
      win = guard(calcApp)
    else
      win = newWindow(it.label, soonBody, false)
    end
    render()
  end

  rect(1, 1, w, h, C.bg)
  drawTaskbar(cfg, false)
  welcome(cfg)
  render()

  while true do
    local ev, _, a, b, c = cp.pullSignal(1)
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
          if it and not it.sep then
            put(mx + 1, b, string.rep(" ", mw - 2), C.bg, C.accent)
            put(mx + 2, b, it.label, C.bg, C.accent, mw - 4)
            cp.pullSignal(0.15)
            activate(it)
          end
        else
          menuOpen = false
          render()
        end
      elseif win and closeHit(win, a, b) then
        win = nil
        render()
      elseif win and win.onTouch and inside(a, b, win.x, win.y, win.w, win.h) then
        local handled = guard(win.onTouch, win, a, b)
        if handled and win then guard(drawWindow, win) end
      end
    elseif ev == "scroll" then
      if win and win.onScroll and not menuOpen then
        guard(win.onScroll, win, c)
        if win then guard(drawWindow, win) end
      end
    elseif ev == "key_down" then
      local handled = false
      if win and win.onKey and not menuOpen then
        handled = guard(win.onKey, win, a, b)
        if handled and win then guard(drawWindow, win) end
      end
      if not handled and b == 1 then
        if menuOpen then
          menuOpen = false
          render()
        elseif win then
          win = nil
          render()
        end
      end
    else
      drawTaskbar(cfg, menuOpen)
      if win and win.live and not menuOpen then guard(win.body, win) end
    end
  end
end

---------------------------------------------------------------- inicio
local stage = "boot"

local function main()
  bootBase()
  bootProgress(15, T.loadSys)
  pause(0.4)
  local cfg = loadConfig()
  if cfg then T = (langs[cfg.lang] or langs[1]).t end
  bootProgress(45, T.loadUser)
  pause(0.4)
  bootProgress(75, T.loadDesk)
  pause(0.4)
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
