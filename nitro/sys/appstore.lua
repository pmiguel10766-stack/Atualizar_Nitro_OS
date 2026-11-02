-- AppStore (nitro/sys/appstore.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local avScan = A.avScan
  local drawButtons = A.drawButtons
  local fs = A.fs
  local hitButton = A.hitButton
  local httpGet = A.httpGet
  local makeButtons = A.makeButtons
  local put = A.put
  local rect = A.rect
  local setWinGeom = A.setWinGeom
local STORE_BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/nitro-appstore/main/app/"
local STORE_INDEX = "apps.lua"
local APPS_DIR = "/apps"

-- o indice e so dados: lista de { name = "...", file = "...", desc = "..." }
local function parseStoreIndex(data)
  local f = load(data, "=apps", "t", {})
  if not f then return nil end
  local ok, list = pcall(f)
  if not ok or type(list) ~= "table" then return nil end
  local out = {}
  for _, a in ipairs(list) do
    if type(a) == "table" and type(a.name) == "string" and type(a.file) == "string"
        and a.file:match("^[%w_%-]+%.lua$") and #out < 60 then
      out[#out + 1] = { name = a.name, file = a.file, desc = tostring(a.desc or "") }
    end
  end
  if #out == 0 then return nil end
  return out
end

local function appStoreApp(shared)
  local win = { title = T.mStore }
  setWinGeom(win, 60, 17)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, listY = win.y + 2, win.y + 4
  local rows = win.h - 9
  local statusY = win.y + win.h - 3
  local st = {
    apps = nil, sel = 1, first = 1, busy = false,
    msg = T.stLoading, msgColor = C.dim, pending = nil,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function keepVisible()
    if st.apps then
      if st.sel > #st.apps then st.sel = #st.apps end
      if st.sel < 1 then st.sel = 1 end
    end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function loadIndex(isRefresh)
    if isRefresh then
      setMsg(T.stRefreshing, C.dim)
      win.body(win)
    end
    local data, err = httpGet(STORE_BASE .. STORE_INDEX, 15)
    if not data then
      setMsg(string.format(T.stFail, tostring(err)), C.err)
      return
    end
    local list = parseStoreIndex(data)
    if not list then
      setMsg(T.stBad, C.err)
      return
    end
    local keepFile = st.apps and st.apps[st.sel] and st.apps[st.sel].file
    st.apps = list
    st.sel, st.first = 1, 1
    if keepFile then
      for i, a in ipairs(list) do
        if a.file == keepFile then st.sel = i end
      end
    end
    keepVisible()
    if isRefresh then
      setMsg(string.format(T.stRefreshed, #list), C.ok)
    else
      setMsg(T.stRepo, C.dim)
    end
  end

  -- baixa, confere sintaxe e analisa; so grava se o usuario aceitar (ou se estiver limpo)
  local function installSelected(confirmed)
    local app = st.apps and st.apps[st.sel]
    if not app then return end
    if not confirmed then
      setMsg(string.format(T.stScan, app.file), C.dim)
      win.body(win)
      local data, err = httpGet(STORE_BASE .. app.file, 25)
      if not data then
        setMsg(string.format(T.stFail, tostring(err)), C.err)
        return
      end
      if #data == 0 or data:sub(1, 3) == "404" or not load(data, "=" .. app.file) then
        setMsg(T.stSyntax, C.err)
        return
      end
      local report = avScan(data)
      if report.verdict == "danger" then
        setMsg(string.format(T.stDanger, report.score), C.err)
        st.pending = nil
        return
      elseif report.verdict == "warn" then
        st.pending = { app = app, data = data }
        setMsg(string.format(T.stWarn, report.score), C.warn)
        return
      end
      st.pending = { app = app, data = data }
      st.pending.save = true
    end
    local p = st.pending
    if not p then return end
    fs.makeDirectory(APPS_DIR)
    local hnd = fs.open(APPS_DIR .. "/" .. p.app.file, "w")
    if not hnd then
      setMsg(string.format(T.stFail, "gravar"), C.err)
      return
    end
    fs.write(hnd, p.data)
    fs.close(hnd)
    st.pending = nil
    if shared then shared.refresh = true end
    setMsg(string.format(T.stSaved, p.app.file), C.ok)
  end

  local function curButtons()
    if st.pending then
      return makeButtons(ix, { { "yes", T.stYes, C.warn }, { "no", T.stNo } })
    end
    return makeButtons(ix, { { "install", T.stInstall, C.ok }, { "refresh", T.stRefresh } })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.stTitle, C.accent, C.panel, iw)
    drawButtons(curButtons(), btnY)
    if not st.apps then
      put(ix, listY, st.msg, st.msgColor, C.panel, iw)
    else
      if #st.apps == 0 then put(ix, listY, T.stEmpty, C.dim, C.panel, iw) end
      for n = 0, rows - 1 do
        local app = st.apps[st.first + n]
        if app then
          local y = listY + n
          local isSel = (st.first + n == st.sel)
          local bg = isSel and C.accent or C.panel
          rect(ix - 1, y, iw + 2, 1, bg)
          put(ix, y, "  " .. app.name, isSel and C.bg or C.text, bg, iw)
        end
      end
    end
    if st.apps then
      local app = st.apps[st.sel]
      if app and not st.pending then
        put(ix, statusY - 1, app.desc, C.dim, C.panel, iw)
      end
    end
    if st.msg ~= "" then put(ix, statusY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "install" then
        installSelected(false)
      elseif id == "refresh" then
        loadIndex(true)
      elseif id == "yes" then
        installSelected(true)
      elseif id == "no" then
        st.pending = nil
        setMsg("", C.dim)
      else
        return false
      end
      return true
    end
    if st.apps and y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if st.apps[idx] then
        st.sel = idx
        st.pending = nil
        setMsg(T.stRepo, C.dim)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.pending then
      if code == 31 or code == 21 then
        installSelected(true)
      elseif code == 49 or code == 1 then
        st.pending = nil
        setMsg("", C.dim)
      end
      return true
    end
    if code == 28 then
      if st.apps then installSelected(false) end
      return true
    elseif code == 63 then
      loadIndex(true)
      return true
    elseif code == 200 and st.apps then
      st.sel = st.sel - 1
      keepVisible()
      return true
    elseif code == 208 and st.apps then
      st.sel = st.sel + 1
      keepVisible()
      return true
    end
    return false
  end

  win.canClose = function(self)
    return not st.busy
  end

  loadIndex()
  return win
end

---------------------------------------------------------------- apps instalados (/apps) no Menu
  return appStoreApp(...)
end
