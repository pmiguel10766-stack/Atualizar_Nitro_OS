-- Atualizar Nitro OS (nitro/sys/atualizar.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local VERSION = A.VERSION
  local cp = A.cp
  local drawButtons = A.drawButtons
  local fs = A.fs
  local hitButton = A.hitButton
  local httpGet = A.httpGet
  local makeButtons = A.makeButtons
  local put = A.put
  local rect = A.rect
  local setWinGeom = A.setWinGeom
local UPDATE_BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/Atualizar_Nitro_OS/main/"
local UPDATE_MANIFEST = "NitroOS_atualizar.lua"

local function parseManifest(data)
  local f = load(data, "=update", "t", {})
  if not f then return nil end
  local ok, m = pcall(f)
  if not ok or type(m) ~= "table" then return nil end
  if type(m.version) ~= "string" or type(m.files) ~= "table" then return nil end
  if #m.files == 0 or #m.files > 40 then return nil end
  for _, path in ipairs(m.files) do
    if type(path) ~= "string" or path:find("..", 1, true) or path:sub(1, 1) == "/"
        or not path:match("^[%w_%-%./]+$") then
      return nil
    end
  end
  return m
end

local function updateApp()
  local win = { title = T.uTitle }
  setWinGeom(win, 54, 13)
  local ix, iw = win.x + 2, win.w - 4
  local btnY = win.y + 9
  local st = { phase = "idle", manifest = nil, msg = "", msgColor = C.dim, pct = 0 }

  local function setStatus(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function failWith(text)
    st.phase = "fail"
    setStatus(string.format(T.uFail, text), C.err)
  end

  local function doCheck()
    st.phase = "working"
    st.pct = 0
    setStatus(T.uChecking, C.dim)
    win.body(win)
    local data, err = httpGet(UPDATE_BASE .. UPDATE_MANIFEST, 15)
    if not data then
      failWith(tostring(err))
      return
    end
    local m = parseManifest(data)
    if not m then
      st.phase = "fail"
      setStatus(T.uBadManifest, C.err)
      return
    end
    st.manifest = m
    if m.version == VERSION then
      st.phase = "uptodate"
      setStatus(T.uUpToDate, C.ok)
    else
      st.phase = "ready"
      setStatus(T.uAvailable, C.warn)
    end
  end

  local function removeNew(files)
    for _, path in ipairs(files) do pcall(fs.remove, "/" .. path .. ".new") end
  end

  local function rollback(swapped)
    for _, path in ipairs(swapped) do
      local target = "/" .. path
      if fs.exists(target .. ".bak") then
        pcall(fs.remove, target)
        pcall(fs.rename, target .. ".bak", target)
      end
    end
  end

  local function checkFile(path, data)
    if #data == 0 or data:sub(1, 3) == "404" then return "vazio/404" end
    if path:sub(-4) == ".lua" and not load(data, "=" .. path) then return "codigo invalido" end
    return nil
  end

  local function doUpdate()
    local m = st.manifest
    if not m then return end
    if cp.freeMemory() < 40000 then
      st.phase = "fail"
      setStatus(T.uLowRam, C.err)
      return
    end
    st.phase = "working"
    local files = m.files
    local total = #files

    -- fase 1: baixa e confere tudo em arquivos .new (o sistema atual nao e tocado)
    for i, path in ipairs(files) do
      st.pct = math.floor((i - 1) * 80 / total)
      setStatus(string.format(T.uDownloading, i, total, path), C.dim)
      win.body(win)
      local data, err = httpGet(UPDATE_BASE .. path, 25)
      if not data then
        removeNew(files)
        failWith(path .. ": " .. tostring(err))
        return
      end
      local bad = checkFile(path, data)
      if bad then
        removeNew(files)
        failWith(path .. ": " .. bad)
        return
      end
      local dir = path:match("^(.*)/[^/]+$")
      if dir then fs.makeDirectory("/" .. dir) end
      local hnd = fs.open("/" .. path .. ".new", "w")
      if not hnd then
        removeNew(files)
        failWith(path .. ": gravar")
        return
      end
      fs.write(hnd, data)
      fs.close(hnd)
    end

    -- fase 2: troca os arquivos (guarda .bak e desfaz tudo se algo falhar)
    setStatus(T.uApplying, C.dim)
    local swapped = {}
    for i, path in ipairs(files) do
      st.pct = 80 + math.floor(i * 20 / total)
      win.body(win)
      local target = "/" .. path
      if fs.exists(target) then
        pcall(fs.remove, target .. ".bak")
        pcall(fs.rename, target, target .. ".bak")
      end
      pcall(fs.rename, target .. ".new", target)
      if not fs.exists(target) then
        if fs.exists(target .. ".bak") then pcall(fs.rename, target .. ".bak", target) end
        rollback(swapped)
        removeNew(files)
        failWith(path .. ": trocar")
        return
      end
      swapped[#swapped + 1] = path
    end
    st.pct = 100
    st.phase = "done"
    setStatus(T.uDone, C.ok)
  end

  local function curButtons()
    if st.phase == "working" then return {} end
    if st.phase == "ready" then
      return makeButtons(ix, {
        { "update", T.uNow, C.ok }, { "check", T.uCheck },
      })
    elseif st.phase == "done" then
      return makeButtons(ix, { { "restart", T.uRestart, C.ok } })
    end
    return makeButtons(ix, { { "check", T.uCheck } })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 2, T.uInstalled .. ": " .. VERSION, C.text, C.panel, iw)
    local online = st.manifest and st.manifest.version or "-"
    put(ix, self.y + 3, T.uOnline .. ": " .. online, C.text, C.panel, iw)
    if st.msg ~= "" then put(ix, self.y + 5, st.msg, st.msgColor, C.panel, iw) end
    if st.phase == "working" or st.phase == "done" then
      rect(ix, self.y + 7, iw, 1, C.barbg)
      rect(ix, self.y + 7, math.floor(iw * st.pct / 100), 1, C.accent)
    end
    drawButtons(curButtons(), btnY)
  end

  local function act(id)
    if id == "check" then
      doCheck()
    elseif id == "update" then
      doUpdate()
    elseif id == "restart" then
      cp.shutdown(true)
    end
  end

  win.onTouch = function(self, x, y)
    if y ~= btnY then return false end
    local id = hitButton(curButtons(), x)
    if not id then return false end
    act(id)
    return true
  end

  win.onKey = function(self, char, code)
    if code == 28 then
      local list = curButtons()
      if list[1] then act(list[1].id) end
      return true
    end
    return false
  end

  win.canClose = function(self)
    return st.phase ~= "working"
  end

  return win
end

---------------------------------------------------------------- fundos (imagens e video em quadros)
  return updateApp(...)
end
