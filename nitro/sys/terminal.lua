-- Terminal seguro do Nitro OS (nitro/sys/terminal.lua)
-- So comandos fixos. Nunca executa codigo digitado.
-- O sistema chama esta funcao passando A (a API do Nitro OS) e recebe a janela.
return function(A)
  local put, rect = A.put, A.rect
  local setWinGeom, ulen, usub, uchar = A.setWinGeom, A.ulen, A.usub, A.uchar
  local joinPath, parentPath = A.joinPath, A.parentPath
  local readFile, fmtSize, fmtTime = A.readFile, A.fmtSize, A.fmtTime
  local C, fs, cp, VERSION, T = A.C, A.fs, A.cp, A.VERSION, A.T

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

  local cmds = {}

  cmds.help = function() out(T.tmHelp, C.dim) end
  cmds.ver = function() out(string.format(T.tmVer, VERSION), C.dim) end
  cmds.pwd = function() out(st.cwd, C.text) end
  cmds.clear = function() st.lines, st.colors = {}, {} end
  cmds.exit = function() st.exit = true end
  cmds.uptime = function() out(fmtTime(cp.uptime()), C.text) end

  cmds.mem = function()
    local total, free = cp.totalMemory(), cp.freeMemory()
    out(string.format("RAM: %d KB livres de %d KB", math.floor(free / 1024), math.floor(total / 1024)), C.text)
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
      line = line:gsub("\r", ""):gsub("\t", "  ")
      out(line, C.text)
    end
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

  local function runLine(line)
    st.hist[#st.hist + 1] = line
    st.hpos = #st.hist + 1
    out(st.cwd .. "> " .. line, C.accent)
    local parts = {}
    for word in line:gmatch("%S+") do parts[#parts + 1] = word end
    local name = (parts[1] or ""):lower()
    local fn = cmds[name]
    if fn then
      local ok, err = pcall(fn, parts[2])
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
    if code == 28 then
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
