-- Terminal seguro do Nitro OS (nitro/sys/terminal.lua)
-- So comandos fixos. Nunca executa codigo digitado nem arquivos .lua.
-- O sistema chama esta funcao passando A (a API do Nitro OS) e recebe a janela.
return function(A, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub, uchar = A.ulen, A.usub, A.uchar
  local joinPath, parentPath = A.joinPath, A.parentPath
  local readFile, fmtSize, fmtTime = A.readFile, A.fmtSize, A.fmtTime
  local C, fs, cp, VERSION, T = A.C, A.fs, A.cp, A.VERSION, A.T
  local httpGet, avScan = A.httpGet, A.avScan
  local netInfo, netTest, listInstalledApps = A.netInfo, A.netTest, A.listInstalledApps

  local STORE_BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/nitro-appstore/main/app/"
  local APPS_DIR = "/apps"
  local MAX_COPY = 300

  local win = { title = T.mTerm }
  setWinGeom(win, 60, 18)
  local ix, iw = win.x + 2, win.w - 4
  local rows = win.h - 5
  local st = { cwd = "/", lines = {}, colors = {}, input = "", hist = {}, hpos = 1, exit = false }

  local function out(text, color)
    st.lines[#st.lines + 1] = text
    st.colors[#st.lines] = color or C.text
    while #st.lines > 300 do
      table.remove(st.lines, 1)
      table.remove(st.colors, 1)
    end
  end

  local function resolve(arg)
    if not arg or arg == "" then return st.cwd end
    if arg:sub(1, 1) == "/" then return arg end
    if arg == ".." then return parentPath(st.cwd) end
    if arg == "." then return st.cwd end
    return joinPath(st.cwd, arg)
  end

  local function isProt(path)
    return path:sub(1, 6) == "/nitro" or path == "/init.lua"
  end

  -- copia arquivo ou pasta inteira (limite de itens para nao travar)
  local function copyTree(src, dst, counter)
    counter.n = counter.n + 1
    if counter.n > MAX_COPY then return false end
    if fs.isDirectory(src) then
      fs.makeDirectory(dst)
      local ok, names = pcall(fs.list, src)
      if not ok or type(names) ~= "table" then return false end
      for _, n in ipairs(names) do
        local name = (n:gsub("/$", ""))
        if not copyTree(joinPath(src, name), joinPath(dst, name), counter) then return false end
      end
      return true
    end
    local rh = fs.open(src)
    if not rh then return false end
    local wh = fs.open(dst, "w")
    if not wh then
      fs.close(rh)
      return false
    end
    while true do
      local chunk = fs.read(rh, 4096)
      if not chunk then break end
      fs.write(wh, chunk)
    end
    fs.close(rh)
    fs.close(wh)
    return true
  end

  local HELP = {
    ls = "ls [pasta]", cd = "cd <pasta>", pwd = "pwd", cat = "cat <arquivo>",
    mkdir = "mkdir <nome>", rm = "rm <nome>", cp = "cp <origem> <destino>",
    mv = "mv <origem> <destino>", touch = "touch <nome>",
    echo = "echo <texto> > <arquivo>   (use >> para acrescentar)",
    tail = "tail <arquivo> [linhas]", date = "date", net = "net", ping = "ping",
    apps = "apps", history = "history", install = "install <nome>   (instala um app da AppStore)",
    mem = "mem", uptime = "uptime", ver = "ver", clear = "clear", exit = "exit", help = "help [comando]",
  }

  local cmds = {}

  cmds.help = function(arg)
    if arg and HELP[arg] then out(HELP[arg], C.text) return end
    if arg then out(string.format(T.tmNoCmd, arg), C.err) return end
    out(T.tmHelp, C.dim)
  end
  cmds.ver = function() out(string.format(T.tmVer, VERSION), C.dim) end
  cmds.pwd = function() out(st.cwd, C.text) end
  cmds.clear = function() st.lines, st.colors = {}, {} end
  cmds.exit = function() st.exit = true end
  cmds.uptime = function() out(fmtTime(cp.uptime()), C.text) end
  cmds.date = function()
    local ok, t = pcall(os.date, "%d/%m/%Y %H:%M:%S")
    out(ok and t or fmtTime(cp.uptime()), C.text)
  end

  cmds.mem = function()
    local total, free = cp.totalMemory(), cp.freeMemory()
    out(string.format("RAM: %d KB livres de %d KB", math.floor(free / 1024), math.floor(total / 1024)), C.text)
  end

  cmds.net = function()
    local info = netInfo()
    local names = (#info.types > 0) and table.concat(info.types, ", ") or "-"
    out("Placas: " .. names, C.text)
    out(string.format(T.tmNetState, info.state), C.text)
  end

  cmds.ping = function()
    local ok, msg = netTest()
    if ok then out(string.format(T.tmPingOk, msg), C.ok) else out(tostring(msg), C.err) end
  end

  cmds.apps = function()
    local list = listInstalledApps()
    if #list == 0 then out(T.maEmpty, C.dim) return end
    for _, app in ipairs(list) do
      out(app.name .. "  (" .. fmtSize(app.size or 0) .. ")", C.text)
    end
  end

  cmds.history = function()
    if #st.hist == 0 then out(T.tmHistEmpty, C.dim) return end
    for i = math.max(1, #st.hist - 9), #st.hist do
      out(i .. "  " .. st.hist[i], C.text)
    end
  end

  cmds.ls = function(arg)
    local dir = resolve(arg)
    local ok, names = pcall(fs.list, dir)
    if not ok or type(names) ~= "table" then
      out(string.format(T.tmNoDir, dir), C.err)
      return
    end
    local items = {}
    for _, n in ipairs(names) do
      local isDir = n:sub(-1) == "/"
      local name = isDir and n:sub(1, -2) or n
      items[#items + 1] = { name = name, dir = isDir, size = isDir and 0 or fs.size(joinPath(dir, name)) }
    end
    table.sort(items, function(a, b)
      if a.dir ~= b.dir then return a.dir end
      return a.name:lower() < b.name:lower()
    end)
    if #items == 0 then out(T.emptyDir, C.dim) end
    for _, it in ipairs(items) do
      local label = (it.dir and "▸ " or "  ") .. it.name .. (it.dir and "/" or "")
      local right = it.dir and "" or ("   " .. fmtSize(it.size))
      out(label .. right, it.dir and C.accent or C.text)
    end
  end
  cmds.dir = cmds.ls

  cmds.cd = function(arg)
    local target = resolve(arg)
    if not fs.exists(target) or not fs.isDirectory(target) then
      out(string.format(T.tmNoDir, target), C.err)
    else
      st.cwd = target
    end
  end

  cmds.cat = function(arg)
    if not arg or arg == "" then
      out(string.format(T.tmUsage, "cat"), C.warn)
      return
    end
    local path = resolve(arg)
    if not fs.exists(path) then
      out(string.format(T.tmNoFile, path), C.err)
      return
    end
    if fs.isDirectory(path) then
      out(string.format(T.tmIsDir, path), C.err)
      return
    end
    local data = readFile(path) or ""
    if data:find("\0", 1, true) then
      out(T.tmBin, C.warn)
      return
    end
    if #data > 2048 then
      data = data:sub(1, 2048)
      out(T.tmCatBig, C.dim)
    end
    for line in (data .. "\n"):gmatch("([^\n]*)\n") do
      out((line:gsub("\r", ""):gsub("\t", "  ")), C.text)
    end
  end

  cmds.tail = function(_, rest)
    local file, n = (rest or ""):match("^(%S+)%s*(%d*)$")
    if not file then
      out(string.format(T.tmUsage, "tail <arquivo> [linhas]"), C.warn)
      return
    end
    local data = readFile(resolve(file))
    if not data then
      out(string.format(T.tmNoFile, resolve(file)), C.err)
      return
    end
    local lines = {}
    for line in data:gmatch("[^\n]+") do lines[#lines + 1] = line end
    local count = tonumber(n) or 10
    for i = math.max(1, #lines - count + 1), #lines do out(lines[i], C.text) end
  end

  cmds.mkdir = function(arg)
    if not arg or arg == "" then
      out(string.format(T.tmUsage, "mkdir"), C.warn)
      return
    end
    local path = resolve(arg)
    if fs.exists(path) then
      out(T.nameExists, C.err)
      return
    end
    if fs.makeDirectory(path) then out(T.tmDone, C.ok) else out(T.tmBadName, C.err) end
  end

  cmds.touch = function(arg)
    if not arg or arg == "" then
      out(string.format(T.tmUsage, "touch <nome>"), C.warn)
      return
    end
    local path = resolve(arg)
    if fs.exists(path) then
      out(T.tmDone, C.ok)
      return
    end
    local h = fs.open(path, "w")
    if h then
      fs.close(h)
      out(T.tmDone, C.ok)
    else
      out(T.tmBadName, C.err)
    end
  end

  cmds.echo = function(_, rest)
    local text, file, mode = (rest or ""):match("^(.-)%s*>>%s*(%S+)%s*$")
    if text then
      mode = "a"
    else
      text, file = (rest or ""):match("^(.-)%s*>%s*(%S+)%s*$")
      mode = "w"
    end
    if not file then
      out(string.format(T.tmUsage, "echo <texto> > <arquivo>"), C.warn)
      return
    end
    local path = resolve(file)
    if isProt(path) then
      out(string.format(T.tmProt, path), C.err)
      return
    end
    local h = fs.open(path, mode)
    if not h then
      out(T.errPrefix .. file, C.err)
      return
    end
    fs.write(h, text .. "\n")
    fs.close(h)
    out(T.tmWritten, C.ok)
  end

  cmds.rm = function(arg)
    if not arg or arg == "" then
      out(string.format(T.tmUsage, "rm"), C.warn)
      return
    end
    local path = resolve(arg)
    if isProt(path) then
      out(string.format(T.tmProt, path), C.err)
      return
    end
    if not fs.exists(path) then
      out(string.format(T.tmNoFile, path), C.err)
      return
    end
    local ok, res = pcall(fs.remove, path)
    if ok and res then out(T.tmDone, C.ok) else out(T.errPrefix .. path, C.err) end
  end

  cmds.cp = function(_, rest)
    local a, b = (rest or ""):match("^(%S+)%s+(%S+)$")
    if not a then
      out(string.format(T.tmUsage, "cp <origem> <destino>"), C.warn)
      return
    end
    local src, dst = resolve(a), resolve(b)
    if not fs.exists(src) then
      out(string.format(T.tmNoFile, src), C.err)
      return
    end
    if fs.isDirectory(dst) then dst = joinPath(dst, src:match("([^/]+)$")) end
    if fs.exists(dst) then
      out(T.nameExists, C.err)
      return
    end
    if copyTree(src, dst, { n = 0 }) then out(T.tmCopied, C.ok) else out(T.errPrefix .. src, C.err) end
  end

  cmds.mv = function(_, rest)
    local a, b = (rest or ""):match("^(%S+)%s+(%S+)$")
    if not a then
      out(string.format(T.tmUsage, "mv <origem> <destino>"), C.warn)
      return
    end
    local src, dst = resolve(a), resolve(b)
    if isProt(src) or isProt(dst) then
      out(string.format(T.tmProt, src), C.err)
      return
    end
    if not fs.exists(src) then
      out(string.format(T.tmNoFile, src), C.err)
      return
    end
    if fs.isDirectory(dst) then dst = joinPath(dst, src:match("([^/]+)$")) end
    if fs.exists(dst) then
      out(T.nameExists, C.err)
      return
    end
    local ok, res = pcall(fs.rename, src, dst)
    if ok and res then out(T.tmMoved, C.ok) else out(T.errPrefix .. src, C.err) end
  end

  -- instala um app da AppStore pelo nome (mesma analise do Antivirus)
  cmds.install = function(_, rest)
    local wanted = (rest or ""):match("^%s*(.-)%s*$")
    if wanted == "" then
      out(string.format(T.tmUsage, "install <nome>"), C.warn)
      return
    end
    local data, err = httpGet(STORE_BASE .. "apps.lua", 15)
    if not data then
      out(tostring(err), C.err)
      return
    end
    local f = load(data, "=apps", "t", {})
    local okL, list = false, nil
    if f then okL, list = pcall(f) end
    if not okL or type(list) ~= "table" then
      out(T.stBad, C.err)
      return
    end
    local low = wanted:lower()
    local found
    for _, a in ipairs(list) do
      if type(a) == "table" and type(a.name) == "string" and type(a.file) == "string" then
        local file = a.file:lower()
        if a.name:lower() == low or file == low or file == low .. ".lua" then
          found = a
          break
        end
      end
    end
    if not found then
      out(string.format(T.tmNoApp, wanted), C.err)
      return
    end
    out(string.format(T.tmInstalling, found.name), C.dim)
    local code = httpGet(STORE_BASE .. found.file, 25)
    if not code or #code == 0 or code:sub(1, 3) == "404" or not load(code, "=" .. found.file) then
      out(T.stSyntax, C.err)
      return
    end
    local report = avScan(code)
    if report.verdict == "danger" then
      out(string.format(T.tmBlocked, report.score), C.err)
      return
    end
    if report.verdict == "warn" then
      out(string.format(T.tmSuspect, report.score), C.warn)
      return
    end
    fs.makeDirectory(APPS_DIR)
    local h = fs.open(APPS_DIR .. "/" .. found.file, "w")
    if not h then
      out(T.errPrefix .. found.file, C.err)
      return
    end
    fs.write(h, code)
    fs.close(h)
    local vh = fs.open(APPS_DIR .. "/" .. found.file .. ".ver", "w")
    if vh then
      fs.write(vh, found.ver or "1")
      fs.close(vh)
    end
    out(string.format(T.tmInstalled, found.name), C.ok)
  end

  local function runLine(line)
    st.hist[#st.hist + 1] = line
    st.hpos = #st.hist + 1
    out(st.cwd .. "> " .. line, C.accent)
    local name, rest = line:match("^%s*(%S+)%s*(.-)%s*$")
    name = (name or ""):lower()
    if name == "" then return end
    local arg = (rest or ""):match("^(%S+)")
    local fn = cmds[name]
    if fn then
      local ok, err = pcall(fn, arg, rest)
      if not ok then out(T.errPrefix .. tostring(err), C.err) end
    else
      out(string.format(T.tmNoCmd, name), C.err)
    end
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local first = math.max(1, #st.lines - rows + 1)
    for n = 0, rows - 1 do
      local idx = first + n
      if st.lines[idx] then
        put(ix, self.y + 1 + n, st.lines[idx], st.colors[idx] or C.text, C.panel, iw)
      end
    end
    rect(ix, self.y + self.h - 3, iw, 1, C.barbg)
    local prompt = st.cwd .. "> " .. st.input .. "_"
    if ulen(prompt) > iw - 2 then prompt = usub(prompt, ulen(prompt) - iw + 3) end
    put(ix + 1, self.y + self.h - 3, prompt, C.text, C.barbg, iw - 2)
  end

  -- devolve "close" quando o comando exit e digitado: o desktop fecha a janela
  win.onKey = function(self, char, code)
    if code == 28 or char == 13 then
      local line = st.input
      st.input = ""
      if line:match("%S") then runLine(line) end
      if st.exit then return "close" end
      return true
    elseif code == 14 then
      if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      return true
    elseif code == 200 and st.hpos > 1 then
      st.hpos = st.hpos - 1
      st.input = st.hist[st.hpos] or ""
      return true
    elseif code == 208 then
      st.hpos = math.min(#st.hist + 1, st.hpos + 1)
      st.input = st.hist[st.hpos] or ""
      return true
    elseif char and char >= 32 and char < 127 and ulen(st.input) < 120 then
      st.input = st.input .. uchar(char)
      return true
    end
    return false
  end

  win.onPaste = function(self, text)
    st.input = (st.input .. tostring(text):gsub("%c", "")):sub(1, 120)
    return true
  end

  out("Nitro OS Terminal " .. VERSION, C.accent)
  out(T.tmHelp, C.dim)
  return win
end
