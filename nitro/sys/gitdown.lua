-- GitDown (nitro/sys/gitdown.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local avAnalyzeFile = A.avAnalyzeFile
  local avFormat = A.avFormat
  local avVerdictColor = A.avVerdictColor
  local avVerdictName = A.avVerdictName
  local cl = A.cl
  local cp = A.cp
  local drawButtons = A.drawButtons
  local fmtSize = A.fmtSize
  local fs = A.fs
  local hitButton = A.hitButton
  local makeButtons = A.makeButtons
  local makeEnv = A.makeEnv
  local put = A.put
  local readFile = A.readFile
  local rect = A.rect
  local setWinGeom = A.setWinGeom
  local ulen = A.ulen
local DOWNLOAD_DIR = "/Download"
local GIT_MAX = 131072

-- troca links normais do GitHub (blob) pelo link "raw" que entrega o arquivo puro
local function normalizeGithubUrl(u)
  u = u:match("^%s*(.-)%s*$")
  local host, rest = u:match("^https?://([^/]+)/(.+)$")
  if not host then return nil end
  host = host:lower()
  rest = rest:gsub("[?#].*$", "")
  if host == "raw.githubusercontent.com" then
    return "https://" .. host .. "/" .. rest
  end
  if host == "github.com" or host == "www.github.com" then
    local user, repo, kind, tail = rest:match("^([^/]+)/([^/]+)/(%a+)/(.+)$")
    if user and (kind == "blob" or kind == "raw") then
      tail = tail:gsub("^refs/heads/", "")
      return "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. tail
    end
  end
  return nil
end

local function httpDownload(url, timeout, onProgress)
  local addr = cl.list("internet")()
  if not addr then return nil, T.wifiNoCard end
  local net = cl.proxy(addr)
  local req, err = net.request(url)
  if not req then return nil, tostring(err) end
  local limit = cp.uptime() + (timeout or 20)
  local parts, size = {}, 0
  local ok, e = pcall(function()
    while not req.finishConnect() do
      if cp.uptime() > limit then error("timeout", 0) end
      cp.pullSignal(0)
    end
    local code = req.response()
    if code and code >= 400 then error("HTTP " .. code, 0) end
    while true do
      local chunk = req.read(math.huge)
      if not chunk then break end
      parts[#parts + 1] = chunk
      size = size + #chunk
      if size > GIT_MAX then error("TOOBIG", 0) end
      if onProgress then onProgress(size) end
    end
  end)
  pcall(req.close)
  if not ok then
    if tostring(e) == "TOOBIG" then return nil, T.gTooBig end
    return nil, tostring(e)
  end
  return table.concat(parts)
end

local function runLuaFile(path, restricted)
  local out = {}
  local data = readFile(path)
  if not data then return out, "nao foi possivel ler o arquivo" end
  local chunkName = path:match("([^/]+)$") or "arquivo"
  local fn, err = load(data, "=" .. chunkName, "t", makeEnv(restricted, out))
  if not fn then return out, tostring(err) end
  local deadline = cp.uptime() + 5
  local hooked = false
  if restricted and debug and debug.sethook then
    debug.sethook(function()
      if cp.uptime() > deadline then error("tempo esgotado (5 s)", 0) end
    end, "", 100000)
    hooked = true
  end
  local ok, e = pcall(fn)
  if hooked then debug.sethook() end
  if not ok then return out, tostring(e) end
  return out, nil
end

local function gitdownApp(shared)
  local win = { title = T.mGitDown }
  setWinGeom(win, 60, 16)
  local ix, iw = win.x + 2, win.w - 4
  local urlY, btnA, btnB, listY = win.y + 2, win.y + 3, win.y + 4, win.y + 6
  local rows = win.h - 11
  local statusY = win.y + win.h - 3
  local st = {
    mode = "main", url = "", files = {}, sel = 1, first = 1,
    msg = "", msgColor = C.dim, outLines = {}, outErr = nil, outTitle = "", vfirst = 1,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function keepVisible()
    if st.sel > #st.files then st.sel = #st.files end
    if st.sel < 1 then st.sel = 1 end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function reload(select)
    st.files = {}
    local ok, names = pcall(fs.list, DOWNLOAD_DIR)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-1) ~= "/" then
          local path = DOWNLOAD_DIR .. "/" .. n
          st.files[#st.files + 1] = { name = n, path = path, size = fs.size(path) }
        end
      end
    end
    table.sort(st.files, function(p, q) return p.name:lower() < q.name:lower() end)
    st.sel, st.first = 1, 1
    if select then
      for i, f in ipairs(st.files) do
        if f.name == select then st.sel = i end
      end
    end
    keepVisible()
  end

  local function selected() return st.files[st.sel] end

  local function uniqueName(name)
    if not fs.exists(DOWNLOAD_DIR .. "/" .. name) then return name end
    local base, ext = name:match("^(.*)(%.[^.]*)$")
    if not base then base, ext = name, "" end
    local n = 2
    while fs.exists(DOWNLOAD_DIR .. "/" .. base .. "-" .. n .. ext) do n = n + 1 end
    return base .. "-" .. n .. ext
  end

  local function doDownload()
    local raw = normalizeGithubUrl(st.url)
    if not raw then
      setMsg(T.gBadUrl, C.err)
      return
    end
    setMsg(string.format(T.gDownloading, 0), C.dim)
    win.body(win)
    local data, err = httpDownload(raw, 20, function(n)
      setMsg(string.format(T.gDownloading, math.floor(n / 1024)), C.dim)
      win.body(win)
    end)
    if not data then
      setMsg(string.format(T.gFail, tostring(err)), C.err)
      return
    end
    local name = (raw:match("([^/]+)$") or ""):gsub("[^%w_%-%.]", "_")
    if name == "" then name = "arquivo.lua" end
    if #data == 0 or data:sub(1, 3) == "404" then
      setMsg(string.format(T.gFail, "vazio/404"), C.err)
      return
    end
    if name:sub(-4) == ".lua" and not load(data, "=" .. name) then
      setMsg(string.format(T.gFail, "codigo Lua invalido"), C.err)
      return
    end
    fs.makeDirectory(DOWNLOAD_DIR)
    name = uniqueName(name)
    local hnd = fs.open(DOWNLOAD_DIR .. "/" .. name, "w")
    if not hnd then
      setMsg(string.format(T.gFail, "gravar"), C.err)
      return
    end
    fs.write(hnd, data)
    fs.close(hnd)
    st.url = ""
    reload(name)
    setMsg(string.format(T.gSaved, DOWNLOAD_DIR .. "/" .. name), C.ok)
  end

  local function needLua()
    local f = selected()
    if not f or f.name:sub(-4) ~= ".lua" then
      setMsg(T.gNeedLua, C.warn)
      return nil
    end
    return f
  end

  local function runFile(restricted)
    local f = selected()
    if not f then return end
    local out, err = runLuaFile(f.path, restricted)
    st.outLines = out
    st.outColors = nil
    st.outErr = nil
    if err then
      st.outLines[#st.outLines + 1] = string.format(T.gRunErr, err)
      st.outErr = #st.outLines
    elseif #st.outLines == 0 then
      st.outLines[1] = T.gNoOutput
    end
    st.outTitle = string.format(T.gOutput, f.name) .. (restricted and "  [" .. T.gRunSafe .. "]" or "")
    st.vfirst = 1
    st.mode = "output"
  end

  local function scanSelected()
    local f = selected()
    if not f then return end
    local report, err = avAnalyzeFile(f.path)
    if not report then
      setMsg(tostring(err), C.err)
      return
    end
    st.outLines, st.outColors = avFormat(report)
    st.outErr = nil
    st.outTitle = string.format(T.avScanned, f.name)
    st.vfirst = 1
    st.mode = "output"
  end

  local function backToMain()
    st.mode = "main"
    setMsg("", C.dim)
  end

  local function startDelete()
    local f = selected()
    if not f then return end
    st.mode = "confirm"
    setMsg(string.format(T.gDelAsk, f.name), C.warn)
  end

  local function doDelete()
    local f = selected()
    local keep = st.sel
    st.mode = "main"
    if not f then return end
    local ok, result = pcall(fs.remove, f.path)
    if ok and result then
      reload()
      st.sel = keep
      keepVisible()
      setMsg(T.deleted, C.ok)
    else
      setMsg(T.errPrefix .. f.name, C.err)
    end
  end

  local function startRun()
    local f = needLua()
    if f then
      st.scan = avAnalyzeFile(f.path)
      st.mode = "warn"
      setMsg("", C.dim)
    end
  end

  local function buttonsA()
    if st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    elseif st.mode == "warn" then
      return makeButtons(ix, { { "go", T.gRunAnyway, C.warn }, { "cancel", T.bCancel } })
    elseif st.mode == "output" then
      return makeButtons(ix, { { "back", T.gBack } })
    end
    return makeButtons(ix, {
      { "dl", T.gDownload, C.ok }, { "folder", T.gOpenFolder }, { "del", T.bDelete, C.warn },
    })
  end

  local function buttonsB()
    return makeButtons(ix, {
      { "run", T.gRun, C.warn }, { "safe", T.gRunSafe }, { "scan", T.avScan, C.ok },
    })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.gUrl, C.dim, C.panel, iw)
    rect(ix, urlY, iw, 1, C.barbg)
    local shown = st.url
    if #shown > iw - 3 then shown = shown:sub(#shown - iw + 4) end
    put(ix + 1, urlY, shown .. (st.mode == "main" and "_" or ""), C.text, C.barbg, iw - 2)

    drawButtons(buttonsA(), btnA)
    if st.mode == "main" then drawButtons(buttonsB(), btnB) end

    if st.mode == "output" then
      put(ix, listY - 1, st.outTitle, C.accent, C.panel, iw)
      for n = 0, rows - 1 do
        local line = st.outLines[st.vfirst + n]
        if line then
          local idx = st.vfirst + n
          local color = (st.outColors and st.outColors[idx])
            or ((idx == st.outErr) and C.err or C.text)
          put(ix, listY + n, line, color, C.panel, iw)
        end
      end
    elseif st.mode == "warn" then
      local f = selected()
      put(ix, listY, T.gWarn1, C.warn, C.panel, iw)
      put(ix, listY + 1, T.gWarn2, C.warn, C.panel, iw)
      if f then put(ix, listY + 3, f.name, C.text, C.panel, iw) end
      if st.scan then
        put(ix, listY + 4, string.format(T.avWarnLine, avVerdictName(st.scan), st.scan.score),
          avVerdictColor(st.scan), C.panel, iw)
      end
    else
      if #st.files == 0 then put(ix, listY, T.gEmpty, C.dim, C.panel, iw) end
      for n = 0, rows - 1 do
        local f = st.files[st.first + n]
        if f then
          local y = listY + n
          local isSel = (st.first + n == st.sel)
          local bg = isSel and C.accent or C.panel
          rect(ix - 1, y, iw + 2, 1, bg)
          local size = fmtSize(f.size)
          put(ix, y, "  " .. f.name, isSel and C.bg or C.text, bg, iw - ulen(size) - 1)
          put(ix + iw - ulen(size), y, size, isSel and C.bg or C.dim, bg)
        end
      end
    end

    if st.msg ~= "" then
      put(ix, statusY, st.msg, st.msgColor, C.panel, iw)
    elseif st.mode == "main" then
      put(ix, statusY, T.gSafeNote, C.dim, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y == btnA or (y == btnB and st.mode == "main") then
      local id = hitButton(y == btnA and buttonsA() or buttonsB(), x)
      if id == "dl" then
        doDownload()
      elseif id == "folder" then
        shared.open = "files"
        shared.openArg = DOWNLOAD_DIR
      elseif id == "del" then
        startDelete()
      elseif id == "run" then
        startRun()
      elseif id == "safe" then
        if needLua() then runFile(true) end
      elseif id == "scan" then
        scanSelected()
      elseif id == "yes" then
        doDelete()
      elseif id == "no" or id == "cancel" or id == "back" then
        backToMain()
      elseif id == "go" then
        runFile(false)
      else
        return false
      end
      return true
    end
    if st.mode == "main" and y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if st.files[idx] then
        st.sel = idx
        setMsg("", C.dim)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "confirm" then
      if code == 31 or code == 21 then
        doDelete()
      elseif code == 49 or code == 1 then
        backToMain()
      end
      return true
    elseif st.mode == "warn" then
      if code == 31 or code == 21 then
        runFile(false)
      elseif code == 49 or code == 1 then
        backToMain()
      end
      return true
    elseif st.mode == "output" then
      if code == 200 then
        st.vfirst = math.max(1, st.vfirst - 1)
      elseif code == 208 then
        st.vfirst = math.max(1, math.min(st.vfirst + 1, #st.outLines - rows + 1))
      elseif code == 1 or code == 28 then
        backToMain()
      end
      return true
    end
    if code == 28 then
      doDownload()
      return true
    elseif code == 14 then
      if #st.url > 0 then st.url = st.url:sub(1, -2) end
      return true
    elseif code == 200 then
      st.sel = st.sel - 1
      keepVisible()
      return true
    elseif code == 208 then
      st.sel = st.sel + 1
      keepVisible()
      return true
    elseif char and char >= 32 and char < 127 and #st.url < 300 then
      st.url = st.url .. string.char(char)
      return true
    end
    return false
  end

  win.onPaste = function(self, text)
    if st.mode ~= "main" then return false end
    text = tostring(text):gsub("%c", "")
    st.url = (st.url .. text):sub(1, 300)
    return true
  end

  reload()
  return win
end

---------------------------------------------------------------- AppStore (repositorio nitro-appstore)
  return gitdownApp(...)
end
