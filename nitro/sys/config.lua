-- Configuracoes do Nitro OS (nitro/sys/config.lua): menu lateral com categorias e cartoes.
-- Cada cartao mostra um estado e, quando faz sentido, uma acao ao clicar.
-- Recebe A (API do Nitro OS), cfg (usuario) e shared (estado do desktop).
return function(A, cfg, shared, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub = A.ulen, A.usub
  local makeButtons, drawButtons, hitButton = A.makeButtons, A.drawButtons, A.hitButton
  local C, T, cp = A.C, A.T, A.cp
  local langs, THEMES, themeIndex, applyTheme = A.langs, A.THEMES, A.themeIndex, A.applyTheme
  local saveConfig, hash, setLang = A.saveConfig, A.hash, A.setLang
  local netInfo, netTest, fmtTime = A.netInfo, A.netTest, A.fmtTime
  local listInstalledApps = A.listInstalledApps
  local VERSION, GO = A.VERSION, A.GO

  local win = { title = T.mSettings }
  setWinGeom(win, 64, 18)
  local ix, iw = win.x + 2, win.w - 4
  local sideW = 18
  local cardX = ix + sideW + 2
  local cardW = iw - sideW - 2
  local btnY, msgY = win.y + 15, win.y + 16

  local CATS = {
    { id = "sys", key = "cSys" }, { id = "net", key = "cNet" },
    { id = "look", key = "cLook" }, { id = "apps", key = "cApps" },
    { id = "acc", key = "cAcc" }, { id = "time", key = "cTime" },
    { id = "priv", key = "cPriv" }, { id = "upd", key = "cUpd" },
  }
  local PROMPT_TXT = { user = "sNewUser", pass1 = "sCurPass", pass2 = "sNewPass", pass3 = "sRepeat" }

  local st = {
    cat = 1, flow = nil, input = "", masked = false, tmp = nil,
    msg = "", msgColor = C.dim, netResult = nil, netColor = C.dim,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function clockText()
    local ok, t = pcall(os.date, "%d/%m/%Y %H:%M")
    return ok and t or fmtTime(cp.uptime())
  end

  local function themeName()
    return T[THEMES[themeIndex(cfg.theme)].key]
  end

  -- cada cartao: titulo, estado, cor e acao (nil = so mostra a informacao)
  local function cardsFor(id)
    local out = {}
    local function add(title, status, color, action)
      out[#out + 1] = { title = title, status = status, color = color or C.dim, action = action }
    end

    if id == "sys" then
      add(T.sVersion, VERSION, C.text)
      add(T.sEdition, GO and "Go" or "Pro", C.text)
      add(T.ram, string.format(T.svRam, math.floor(cp.freeMemory() / 1024)), C.text, "mem")
      add(T.uptime, fmtTime(cp.uptime()), C.text)

    elseif id == "net" then
      local ni = netInfo().state
      local nStatus, nColor = T.svNetWarn, C.warn
      if ni == "ok" then
        nStatus, nColor = T.svNetOk, C.ok
      elseif ni == "none" then
        nStatus, nColor = T.svNetNone, C.err
      end
      add(T.sNet, nStatus, nColor)
      add(T.sTestNet, st.netResult or T.svTestNet, st.netColor, "nettest")
      add(T.cLocal, T.cLocalHint, C.dim, "open:redelocal")

    elseif id == "look" then
      add(T.sTheme, themeName(), C.text, "theme")
      add(T.sWallpaper, cfg.wallpaper or "default", C.text, "open:wallpaper")

    elseif id == "apps" then
      add(T.mStore, T.bOpen, C.dim, "open:store")
      add(T.mMyApps, string.format(T.svAppsCount, #listInstalledApps()), C.text, "open:myapps")
      add(T.mAntivirus, T.bOpen, C.dim, "open:antivirus")

    elseif id == "acc" then
      add(T.sUser, cfg.user or "", C.text, "user")
      local hasPass = cfg.hash
      add(T.sPass, hasPass and T.sPassOn or T.sPassNone, hasPass and C.ok or C.warn, "pass")
      local lm = cfg.lockMin or 0
      add(T.lkAuto, (lm > 0) and string.format(T.lkMin, lm) or T.lkNever, C.text, "lock")

    elseif id == "time" then
      add(T.sLang, langs[cfg.lang].name, C.text, "lang")
      add(T.cClock, clockText(), C.text)

    elseif id == "priv" then
      local hidden = 0
      for _ in pairs(cfg.hidden or {}) do hidden = hidden + 1 end
      add(T.cHidden, string.format(T.cHiddenStatus, hidden), C.text, "showhidden")
      add(T.cSecLog, T.bOpen, C.dim, "open:antivirus")

    elseif id == "upd" then
      add(T.sVersion, VERSION, C.text)
      add(T.sUpdate, T.bOpen, C.dim, "open:update")
    end
    return out
  end

  local function startPrompt(flow)
    st.flow = flow
    st.masked = (flow ~= "user")
    st.input = (flow == "user") and (cfg.user or "") or ""
    setMsg("", C.dim)
  end

  local function cancelPrompt()
    st.flow = nil
    setMsg("", C.dim)
  end

  local function submit()
    local text = st.input
    if st.flow == "user" then
      text = text:match("^%s*(.-)%s*$")
      if text == "" then
        setMsg(T.userEmpty, C.err)
        return
      end
      cfg.user = text
      saveConfig(cfg)
      shared.refresh = true
      st.flow = nil
      setMsg(T.sUserSet, C.ok)
    elseif st.flow == "pass1" then
      if hash(text) ~= cfg.hash then
        setMsg(T.sWrongPass, C.err)
        st.input = ""
        return
      end
      startPrompt("pass2")
    elseif st.flow == "pass2" then
      if text == "" then
        cfg.hash = nil
        saveConfig(cfg)
        st.flow = nil
        setMsg(T.sPassOff, C.ok)
      else
        st.tmp = text
        startPrompt("pass3")
      end
    elseif st.flow == "pass3" then
      if text ~= st.tmp then
        startPrompt("pass2")
        setMsg(T.passMismatch, C.err)
        return
      end
      cfg.hash = hash(text)
      saveConfig(cfg)
      st.tmp = nil
      st.flow = nil
      setMsg(T.sPassSet, C.ok)
    end
  end

  local function runAction(action)
    if not action then return end
    if action == "mem" then
      setMsg(string.format(T.svRam, math.floor(cp.freeMemory() / 1024)), C.dim)
    elseif action == "nettest" then
      st.netResult, st.netColor = T.sTesting, C.dim
      local ok, msg = netTest()
      if ok then
        st.netResult, st.netColor = T.svNetOk .. " (" .. msg .. ")", C.ok
      else
        st.netResult, st.netColor = tostring(msg), C.err
      end
    elseif action == "theme" then
      local idx = (themeIndex(cfg.theme) % #THEMES) + 1
      cfg.theme = THEMES[idx].id
      applyTheme(cfg.theme)
      saveConfig(cfg)
      shared.refresh = true
      setMsg(T.sTheme .. ": " .. themeName(), C.ok)
    elseif action == "lang" then
      cfg.lang = (cfg.lang % #langs) + 1
      setLang(cfg.lang)
      T = langs[cfg.lang].t
      saveConfig(cfg)
      shared.refresh = true
      setMsg(langs[cfg.lang].name, C.ok)
    elseif action == "user" then
      startPrompt("user")
    elseif action == "pass" then
      startPrompt(cfg.hash and "pass1" or "pass2")
    elseif action == "lock" then
      local opts = { 0, 2, 5, 10 }
      local cur = cfg.lockMin or 0
      local nxt = opts[1]
      for i, v in ipairs(opts) do
        if v == cur then nxt = opts[(i % #opts) + 1] end
      end
      cfg.lockMin = nxt
      saveConfig(cfg)
      shared.refresh = true
      setMsg(T.lkAuto .. ": " .. ((nxt > 0) and string.format(T.lkMin, nxt) or T.lkNever), C.ok)
    elseif action == "showhidden" then
      cfg.hidden = {}
      saveConfig(cfg)
      shared.refresh = true
      setMsg(T.cShownOk, C.ok)
    elseif action:sub(1, 5) == "open:" then
      shared.open = action:sub(6)
      shared.openArg = nil
    end
  end

  local function promptButtons()
    return makeButtons(cardX, { { "ok", T.bOk }, { "cancel", T.bCancel } })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.sTitle, C.accent, C.panel, iw)

    for i, cat in ipairs(CATS) do
      local y = self.y + 1 + i
      local isSel = (i == st.cat)
      local bg = isSel and C.accent or C.barbg
      rect(ix, y, sideW, 1, bg)
      put(ix + 1, y, T[cat.key], isSel and C.bg or C.text, bg, sideW - 2)
    end

    for n, card in ipairs(cardsFor(CATS[st.cat].id)) do
      local y = self.y + 2 + (n - 1) * 3
      rect(cardX, y, cardW, 2, C.bg)
      put(cardX + 1, y, card.title, C.text, C.bg, cardW - 2)
      put(cardX + 1, y + 1, card.status, card.color, C.bg, cardW - 2)
    end

    if st.flow then
      put(cardX, self.y + 13, T[PROMPT_TXT[st.flow]], C.dim, C.panel, cardW)
      rect(cardX, self.y + 14, cardW, 1, C.barbg)
      local shown = st.masked and string.rep("*", ulen(st.input)) or st.input
      put(cardX + 1, self.y + 14, shown .. "_", C.text, C.barbg, cardW - 2)
      drawButtons(promptButtons(), btnY)
    else
      put(ix, btnY, T.keysInput, C.dim, C.panel, iw)
    end

    if st.msg ~= "" then put(ix, msgY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if st.flow then
      if y == btnY then
        local id = hitButton(promptButtons(), x)
        if id == "ok" then submit()
        elseif id == "cancel" then cancelPrompt()
        else return false end
        return true
      end
      return false
    end
    if x >= ix and x < ix + sideW and y >= self.y + 2 and y < self.y + 2 + #CATS then
      st.cat = y - (self.y + 2) + 1
      return true
    end
    for n, card in ipairs(cardsFor(CATS[st.cat].id)) do
      local cy = self.y + 2 + (n - 1) * 3
      if x >= cardX and x < cardX + cardW and y >= cy and y < cy + 2 then
        runAction(card.action)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.flow then
      if code == 28 then
        submit()
      elseif code == 1 then
        cancelPrompt()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char < 127 and ulen(st.input) < 32 then
        st.input = st.input .. string.char(char)
      end
      return true
    end
    if code == 200 and st.cat > 1 then
      st.cat = st.cat - 1
      return true
    elseif code == 208 and st.cat < #CATS then
      st.cat = st.cat + 1
      return true
    end
    return false
  end

  return win
end
