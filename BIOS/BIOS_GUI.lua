-- Nitro BIOS - layout de configuracao (estilo PhoenixBIOS)
-- Baixado do GitHub pela EEPROM quando F9 e apertado. Roda so na RAM.
-- Recebe a api da EEPROM (gpu, w, h, cp, version, verified, bootAddr, hasInternet,
-- boot, repair, installer, reboot, shutdown).
return function(api)
  local g, W, H = api.gpu, api.w, api.h
  local cp = api.cp
  local BLUE, WHITE, BLACK, CYAN, YEL = 0x0000AA, 0xFFFFFF, 0x000000, 0x55FFFF, 0xFFFF55
  local TABS = { "Principal", "Recuperacao", "Avancado", "Sair" }
  local MENU = {
    { { "Iniciar Nitro OS", "Carrega o sistema instalado no disco.", "boot" } },
    { { "Reparar Nitro OS", "Baixa init.lua e boot.lua do GitHub e grava no disco. Tambem pela tecla F10.", "repair" },
      { "Reinstalar", "Abre o instalador do Nitro OS, baixado para a memoria RAM.", "installer" } },
    { { "Reiniciar", "Reinicia o computador.", "reboot" },
      { "Desligar", "Desliga o computador.", "shutdown" } },
    { { "Iniciar Nitro OS", "Sai do Setup e inicia o sistema.", "boot" } },
  }
  local tab, sel, msg = 1, 1, ""

  local function put(x, y, s, fg, bg)
    g.setForeground(fg)
    g.setBackground(bg)
    g.set(x, y, s)
  end

  local function fill(x, y, w, h, bg)
    g.setBackground(bg)
    g.fill(x, y, w, h, " ")
  end

  local function kb(n)
    return math.floor(n / 1024) .. " KB"
  end

  local function uptime()
    local s = math.floor(cp.uptime())
    return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
  end

  -- quebra o texto da ajuda em linhas curtas
  local function wrap(s, width)
    local out, line = {}, ""
    for word in s:gmatch("%S+") do
      if #line + #word + 1 > width and line ~= "" then
        out[#out + 1] = line
        line = word
      else
        line = (line == "") and word or (line .. " " .. word)
      end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
  end

  local function draw()
    fill(1, 1, W, H, BLACK)
    fill(1, 1, W, 2, BLUE)
    put(2, 1, "Nitro BIOS - Setup Utility", WHITE, BLUE)
    local x = 2
    for i, t in ipairs(TABS) do
      local label = " " .. t .. " "
      if i == tab then put(x, 2, label, BLUE, WHITE) else put(x, 2, label, WHITE, BLUE) end
      x = x + #label + 1
    end

    -- informacoes (esquerda)
    local a = api.bootAddr()
    put(3, 4, "Versao da BIOS:  " .. api.version, WHITE, BLACK)
    put(3, 5, "Memoria total:   " .. kb(cp.totalMemory()), WHITE, BLACK)
    put(3, 6, "Memoria livre:   " .. kb(cp.freeMemory()), WHITE, BLACK)
    put(3, 7, "Disco de boot:   " .. (a and a:sub(1, 8) or "-"), WHITE, BLACK)
    put(3, 8, "Internet:        " .. (api.hasInternet() and "Sim" or "Nao"), WHITE, BLACK)
    put(3, 9, "Tempo ligado:    " .. uptime(), WHITE, BLACK)
    if api.verified then
      put(3, 10, "Layout:          verificado", CYAN, BLACK)
    else
      put(3, 10, "Layout:          NAO verificado", YEL, BLACK)
    end

    -- opcoes da aba atual
    for i, it in ipairs(MENU[tab]) do
      local label = " " .. it[1] .. string.rep(" ", 30 - #it[1])
      if i == sel then put(3, 12 + i - 1, label, BLACK, WHITE)
      else put(3, 12 + i - 1, label, WHITE, BLACK) end
    end

    -- ajuda (direita)
    fill(46, 3, W - 45, H - 5, BLUE)
    put(48, 4, "Item Specific Help", WHITE, BLUE)
    local item = MENU[tab][sel]
    if item then
      for i, l in ipairs(wrap(item[2], W - 50)) do put(48, 5 + i, l, WHITE, BLUE) end
    end

    if msg ~= "" then put(3, H - 4, msg, YEL, BLACK) end

    -- rodape com as teclas
    fill(1, H, W, 1, BLUE)
    put(2, H, "F9 Recuperacao  F10 Reparar  <- -> Aba  ^ v Opcao  Enter Selecionar  Esc Sair", WHITE, BLUE)
  end

  local function run(action)
    if action == "boot" then
      local r = api.boot()
      if r then msg = r end
    elseif action == "repair" then
      msg = api.repair()
    elseif action == "installer" then
      msg = api.installer()
    elseif action == "reboot" then
      api.reboot()
    elseif action == "shutdown" then
      api.shutdown()
    end
  end

  draw()
  while true do
    local ev, _, _, code = cp.pullSignal(1)
    if ev == "key_down" then
      if code == 203 then
        tab = (tab - 2) % #TABS + 1
        sel = 1
      elseif code == 205 then
        tab = tab % #TABS + 1
        sel = 1
      elseif code == 200 then
        sel = math.max(1, sel - 1)
      elseif code == 208 then
        sel = math.min(#MENU[tab], sel + 1)
      elseif code == 28 then
        run(MENU[tab][sel][3])
      elseif code == 67 then
        tab, sel = 2, 1
      elseif code == 68 then
        msg = api.repair()
      elseif code == 1 then
        run("boot")
      end
      draw()
    else
      draw()
    end
  end
end
