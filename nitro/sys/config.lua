-- Configuracoes (nitro/sys/config.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local GO = A.GO
  local THEMES = A.THEMES
  local VERSION = A.VERSION
  local applyTheme = A.applyTheme
  local cp = A.cp
  local drawButtons = A.drawButtons
  local fmtTime = A.fmtTime
  local hash = A.hash
  local hitButton = A.hitButton
  local input = A.input
  local langs = A.langs
  local makeButtons = A.makeButtons
  local netInfo = A.netInfo
  local netTest = A.netTest
  local put = A.put
  local rect = A.rect
  local saveConfig = A.saveConfig
  local setWinGeom = A.setWinGeom
  local themeIndex = A.themeIndex
  local uchar = A.uchar
  local ulen = A.ulen
  local usub = A.usub
local function settingsApp(cfg, shared)
  local win = { title = T.mSettings, live = true }
  setWinGeom(win, 58, 16)
  local ix, iw = win.x + 2, win.w - 4
  local bottomY = win.y + 11
  local st = {
    mode = "menu", sel = 1, flow = nil, input = "", masked = false,
    tmp = nil, msg = "", msgColor = C.warn, result = "", resultColor = C.dim,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function entries()
    local all = {
      { id = "lang", label = T.sLang, value = langs[cfg.lang].name },
      { id = "theme", label = T.sTheme, value = T[THEMES[themeIndex(cfg.theme)].key] },
      { id = "user", label = T.sUser, value = cfg.user },
      { id = "pass", label = T.sPass, value = cfg.hash and T.sPassOn or T.sPassNone },
      { id = "status", label = T.sStatus, value = "" },
      { id = "update", label = T.sUpdate, value = VERSION },
      { id = "wallpaper", label = T.sWallpaper, value = "" },
      { id = "about", label = T.sAbout, value = "" },
    }
    if not GO then return all end
    local out = {}
    for _, e in ipairs(all) do
      if e.id ~= "wallpaper" then out[#out + 1] = e end
    end
    return out
  end

  local function startPrompt(flow)
    st.mode = "prompt"
    st.flow = flow
    st.masked = (flow ~= "user")
    st.input = (flow == "user") and cfg.user or ""
    setMsg("", C.dim)
  end

  local PROMPTS = {
    user = "sNewUser", pass1 = "sCurPass", pass2 = "sNewPass", pass3 = "sRepeat",
  }

  local function backToMenu()
    st.mode = "menu"
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
      st.mode = "menu"
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
        st.mode = "menu"
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
      st.mode = "menu"
      setMsg(T.sPassSet, C.ok)
    end
  end

  local function runNetTest()
    st.result, st.resultColor = T.sTesting, C.dim
    win.body(win)
    local ok, msg = netTest()
    if ok then
      st.result, st.resultColor = string.format(T.wifiTestOk, msg), C.ok
    else
      st.result, st.resultColor = string.format(T.wifiTestFail, msg), C.err
    end
  end

  local function activate(id)
    if id == "lang" then
      cfg.lang = (cfg.lang % #langs) + 1
      A.setLang(cfg.lang)
      saveConfig(cfg)
      shared.refresh = true
      setMsg("", C.dim)
    elseif id == "theme" then
      local idx = (themeIndex(cfg.theme) % #THEMES) + 1
      cfg.theme = THEMES[idx].id
      applyTheme(cfg.theme)
      saveConfig(cfg)
      shared.refresh = true
      setMsg("", C.dim)
    elseif id == "user" then
      startPrompt("user")
    elseif id == "pass" then
      if cfg.hash then startPrompt("pass1") else startPrompt("pass2") end
    elseif id == "status" then
      st.mode = "status"
      st.result = ""
    elseif id == "update" then
      shared.open = "update"
    elseif id == "wallpaper" then
      shared.open = "wallpaper"
    elseif id == "about" then
      st.mode = "about"
    end
  end

  local function curButtons()
    if st.mode == "prompt" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    elseif st.mode == "status" then
      return makeButtons(ix, { { "test", T.sTestNet }, { "back", T.bBack } })
    elseif st.mode == "about" then
      return makeButtons(ix, { { "back", T.bBack } })
    end
    return {}
  end

  local function statusRow(y, label, value, pct, color)
    rect(ix, y, iw, 1, C.panel)
    put(ix, y, label, C.text, C.panel, iw - ulen(value) - 1)
    put(ix + iw - ulen(value), y, value, C.dim, C.panel)
    rect(ix, y + 1, iw, 1, C.barbg)
    rect(ix, y + 1, math.floor(iw * pct / 100), 1, color)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.sTitle, C.accent, C.panel, iw)

    if st.mode == "menu" then
      for i, e in ipairs(entries()) do
        local y = self.y + 3 + (i - 1)
        local isSel = (i == st.sel)
        local bg = isSel and C.accent or C.panel
        local fg = isSel and C.bg or C.text
        rect(ix - 1, y, iw + 2, 1, bg)
        put(ix, y, (isSel and "▶ " or "  ") .. e.label, fg, bg, iw - 2)
        if e.value ~= "" then
          put(ix + iw - ulen(e.value), y, e.value, isSel and C.bg or C.dim, bg)
        end
      end
      if st.msg ~= "" then put(ix, bottomY, st.msg, st.msgColor, C.panel, iw) end

    elseif st.mode == "prompt" then
      put(ix, self.y + 3, T[PROMPTS[st.flow]], C.dim, C.panel, iw)
      rect(ix, self.y + 5, iw, 1, C.barbg)
      local shown = st.masked and string.rep("*", ulen(st.input)) or st.input
      put(ix + 1, self.y + 5, shown .. "_", C.text, C.barbg, iw - 2)
      if st.msg ~= "" then put(ix, self.y + 7, st.msg, st.msgColor, C.panel, iw) end
      drawButtons(curButtons(), bottomY)

    elseif st.mode == "status" then
      local total, free = cp.totalMemory(), cp.freeMemory()
      local usedPct = math.floor((total - free) * 100 / total)
      statusRow(self.y + 3, T.sFree,
        string.format("%d/%d KB", math.floor(free / 1024), math.floor(total / 1024)),
        100 - usedPct, usedPct > 85 and C.err or C.accent)
      local e, me = cp.energy(), cp.maxEnergy()
      local epct = (me == math.huge or me <= 0) and 100 or math.floor(e * 100 / me)
      statusRow(self.y + 6, T.energy, epct .. "%", epct, epct < 20 and C.err or C.ok)
      put(ix, self.y + 9, T.uptime .. ": " .. fmtTime(cp.uptime()), C.text, C.panel, iw)
      local info = netInfo()
      local online = (info.state == "ok")
      put(ix, self.y + 10, T.sNet .. ": " .. (online and T.wifiOk or T.wifiNone), online and C.ok or C.warn, C.panel, iw)
      drawButtons(curButtons(), bottomY)
      if st.result ~= "" then put(ix + 36, bottomY, st.result, st.resultColor, C.panel, iw - 36) end

    elseif st.mode == "about" then
      put(ix, self.y + 4, "Nitro OS", C.text, C.panel, iw)
      put(ix, self.y + 6, string.format(T.sVersion, VERSION), C.dim, C.panel, iw)
      put(ix, self.y + 7, T.sFor, C.dim, C.panel, iw)
      put(ix, self.y + 8, T.sEdition .. ": " .. (GO and "Go" or "Pro"), C.dim, C.panel, iw)
      drawButtons(curButtons(), bottomY)
    end
  end

  win.onTouch = function(self, x, y)
    if st.mode == "menu" then
      local list = entries()
      local i = y - (self.y + 3) + 1
      if i >= 1 and i <= #list and x >= self.x + 1 and x < self.x + self.w - 1 then
        st.sel = i
        activate(list[i].id)
        return true
      end
      return false
    end
    if y == bottomY then
      local id = hitButton(curButtons(), x)
      if id == "ok" then
        submit()
      elseif id == "cancel" or id == "back" then
        backToMenu()
      elseif id == "test" then
        runNetTest()
      else
        return false
      end
      return true
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "prompt" then
      if code == 28 then
        submit()
      elseif code == 1 then
        backToMenu()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(st.input) < 32 then
        st.input = st.input .. uchar(char)
      end
      return true
    elseif st.mode == "status" then
      if code == 28 then
        runNetTest()
      elseif code == 1 then
        backToMenu()
      end
      return true
    elseif st.mode == "about" then
      if code == 1 or code == 28 then backToMenu() end
      return true
    end
    local count = #entries()
    if code == 200 and st.sel > 1 then
      st.sel = st.sel - 1
      return true
    elseif code == 208 and st.sel < count then
      st.sel = st.sel + 1
      return true
    elseif code == 28 then
      activate(entries()[st.sel].id)
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- download HTTP e app Atualizar
  return settingsApp(...)
end
