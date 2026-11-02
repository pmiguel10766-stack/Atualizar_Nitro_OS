-- Explorador de Arquivos do Nitro OS (nitro/sys/arquivos.lua)
-- Recebe a API do sistema (A) e, opcionalmente, a pasta inicial.
return function(A, startDir)
  local put, rect = A.put, A.rect
  local setWinGeom, makeButtons, drawButtons, hitButton = A.setWinGeom, A.makeButtons, A.drawButtons, A.hitButton
  local ulen, usub, uchar = A.ulen, A.usub, A.uchar
  local joinPath, parentPath, fmtSize = A.joinPath, A.parentPath, A.fmtSize
  local C, T, fs, cl, cp = A.C, A.T, A.fs, A.cl, A.cp

local function fxBytes(n)
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  return string.format("%d KB", math.floor(n / 1024))
end

local function fxList(dfs, dir)
  local out = {}
  local ok, names = pcall(dfs.list, dir)
  if not ok or type(names) ~= "table" then return out end
  for _, n in ipairs(names) do
    local isDir = n:sub(-1) == "/"
    local name = isDir and n:sub(1, -2) or n
    local path = joinPath(dir, name)
    out[#out + 1] = {
      kind = "item", name = name, dir = isDir, path = path,
      size = isDir and 0 or dfs.size(path),
    }
  end
  table.sort(out, function(p, q)
    if p.dir ~= q.dir then return p.dir end
    return p.name:lower() < q.name:lower()
  end)
  return out
end

local function fxPreview(dfs, path)
  local hnd = dfs.open(path)
  if not hnd then return nil end
  local data = dfs.read(hnd, 8192) or ""
  dfs.close(hnd)
  return data
end

local function fxCopyFile(srcFs, sp, dstFs, dp)
  local rh = srcFs.open(sp)
  if not rh then return false end
  local wh = dstFs.open(dp, "w")
  if not wh then
    srcFs.close(rh)
    return false
  end
  local ok = true
  while true do
    local chunk = srcFs.read(rh, 4096)
    if not chunk then break end
    if not dstFs.write(wh, chunk) then
      ok = false
      break
    end
  end
  srcFs.close(rh)
  dstFs.close(wh)
  return ok
end

-- copia arquivo ou pasta inteira entre discos (limite de 300 itens)
local function fxCopyTree(srcFs, sp, dstFs, dp, counter)
  counter.n = counter.n + 1
  if counter.n > 300 then return false end
  if srcFs.isDirectory(sp) then
    dstFs.makeDirectory(dp)
    local names = srcFs.list(sp) or {}
    for _, n in ipairs(names) do
      local name = n:gsub("/$", "")
      if not fxCopyTree(srcFs, joinPath(sp, name), dstFs, joinPath(dp, name), counter) then
        return false
      end
    end
    return true
  end
  return fxCopyFile(srcFs, sp, dstFs, dp)
end

local function filesApp(startDir)
  local win = { title = T.mFiles }
  setWinGeom(win, 62, 19)
  local ix, iw = win.x + 2, win.w - 4
  local addrY, btnA, btnB, listY = win.y + 1, win.y + 2, win.y + 3, win.y + 5
  local rows = win.h - 8
  local msgY, statusY = win.y + win.h - 3, win.y + win.h - 2
  local bootAddr = cp.getBootAddress()
  local proxies = {}

  local function proxyOf(addr)
    if not proxies[addr] then proxies[addr] = cl.proxy(addr) end
    return proxies[addr]
  end

  local st = {
    view = "home", drive = bootAddr, dir = "/", items = {}, sel = 1, first = 1,
    mode = "list", msg = "", msgColor = C.warn, input = "", lines = {}, vfirst = 1,
    viewName = "", lastClick = 0, hist = {}, hpos = 0, move = nil, crumbs = {},
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function curFs() return proxyOf(st.drive) end

  local function driveName(addr)
    return proxyOf(addr).getLabel() or addr:sub(1, 4)
  end

  -- /nitro e /init.lua do disco de boot sao protegidos
  local function isProt(drive, path)
    return drive == bootAddr and (path:sub(1, 6) == "/nitro" or path == "/init.lua")
  end

  local function selected()
    local it = st.items[st.sel]
    if it and it.kind ~= "header" then return it end
    return nil
  end

  local function keepVisible()
    if st.sel > #st.items then st.sel = #st.items end
    if st.sel < 1 then st.sel = 1 end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function buildHome()
    local items = {}
    local folders = {}
    local shortcuts = {
      { "fxDl", "/Download" }, { "fxNotes", "/notas" }, { "fxApps", "/apps" },
      { "fxWalls", "/nitro/fundo_imagens" }, { "fxRoot", "/" },
    }
    for _, sc in ipairs(shortcuts) do
      if sc[2] == "/" or fs.exists(sc[2]) then
        folders[#folders + 1] = { kind = "folder", name = T[sc[1]], drive = bootAddr, path = sc[2] }
      end
    end
    local drives = {}
    for addr in cl.list("filesystem") do
      if addr ~= cp.tmpAddress() then
        local d = proxyOf(addr)
        drives[#drives + 1] = {
          kind = "drive", addr = addr, name = driveName(addr),
          used = d.spaceUsed(), total = d.spaceTotal(),
          ro = d.isReadOnly(), boot = (addr == bootAddr),
        }
      end
    end
    items[#items + 1] = { kind = "header", name = T.fxFolders .. " (" .. #folders .. ")" }
    for _, f in ipairs(folders) do items[#items + 1] = f end
    items[#items + 1] = { kind = "header", name = T.fxDrives .. " (" .. #drives .. ")" }
    for _, d in ipairs(drives) do items[#items + 1] = d end
    return items
  end

  local function reload(select)
    if st.view == "home" then
      st.items = buildHome()
    else
      st.items = fxList(curFs(), st.dir)
    end
    st.sel, st.first = 1, 1
    if st.items[1] and st.items[1].kind == "header" then st.sel = 2 end
    if select then
      for i, it in ipairs(st.items) do
        if it.kind ~= "header" and it.name == select then st.sel = i end
      end
    end
    keepVisible()
  end

  local function moveSel(delta)
    local i = st.sel + delta
    while st.items[i] and st.items[i].kind == "header" do i = i + delta end
    if st.items[i] then st.sel = i end
    keepVisible()
  end

  local function applyState(s)
    st.view = s.view
    if s.view == "dir" then
      st.drive, st.dir = s.drive, s.dir
    end
    st.mode = "list"
    reload()
  end

  local function navigate(s)
    for i = #st.hist, st.hpos + 1, -1 do table.remove(st.hist, i) end
    st.hist[#st.hist + 1] = s
    st.hpos = #st.hist
    applyState(s)
  end

  local function goBack()
    if st.hpos > 1 then
      st.hpos = st.hpos - 1
      applyState(st.hist[st.hpos])
    end
  end

  local function goForward()
    if st.hpos < #st.hist then
      st.hpos = st.hpos + 1
      applyState(st.hist[st.hpos])
    end
  end

  local function goUp()
    if st.view == "home" then return end
    if st.dir == "/" then
      navigate({ view = "home" })
    else
      navigate({ view = "dir", drive = st.drive, dir = parentPath(st.dir) })
    end
  end

  local function needDir()
    if st.view ~= "dir" then
      setMsg(T.fxOpenFirst, C.warn)
      return false
    end
    if curFs().isReadOnly() then
      setMsg(T.fxROMsg, C.err)
      return false
    end
    return true
  end

  local function backToList()
    st.mode = "list"
    setMsg("", C.dim)
  end

  local function openItem()
    local it = selected()
    if not it then return end
    if it.kind == "folder" then
      navigate({ view = "dir", drive = it.drive, dir = it.path })
      return
    elseif it.kind == "drive" then
      navigate({ view = "dir", drive = it.addr, dir = "/" })
      return
    elseif it.dir then
      navigate({ view = "dir", drive = st.drive, dir = it.path })
      return
    end
    local data = fxPreview(curFs(), it.path)
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
    setMsg("", C.dim)
  end

  local function startCreate()
    if not needDir() then return end
    st.mode = "create"
    st.input = ""
    setMsg("", C.dim)
  end

  local function startRename()
    if not needDir() then return end
    local it = selected()
    if not it or it.kind ~= "item" then return end
    if isProt(st.drive, it.path) then
      setMsg(T.sysLocked, C.warn)
      return
    end
    st.mode = "rename"
    st.input = it.name
    setMsg("", C.dim)
  end

  local function startDelete()
    if not needDir() then return end
    local it = selected()
    if not it or it.kind ~= "item" then return end
    st.mode = "confirm"
    if isProt(st.drive, it.path) then
      setMsg(string.format(T.sysWarn, it.name), C.err)
    else
      setMsg(string.format(T.confirmDel, it.name), C.warn)
    end
  end

  local function doDelete()
    local it = selected()
    local keep = st.sel
    st.mode = "list"
    if not it or it.kind ~= "item" then return end
    local ok, result = pcall(curFs().remove, it.path)
    if ok and result then
      reload()
      st.sel = keep
      keepVisible()
      setMsg(T.deleted, C.ok)
    else
      setMsg(T.errPrefix .. it.name, C.err)
    end
  end

  local function submitPrompt()
    local name = st.input:match("^%s*(.-)%s*$")
    if name == "" or name:find("/", 1, true) then
      setMsg(T.nameBad, C.err)
      return
    end
    local dfs = curFs()
    local target = joinPath(st.dir, name)
    if st.mode == "create" then
      if dfs.exists(target) then
        setMsg(T.nameExists, C.err)
        return
      end
      local hnd = dfs.open(target, "w")
      st.mode = "list"
      if hnd then
        dfs.write(hnd, "")
        dfs.close(hnd)
        reload(name)
        setMsg(T.fxCreated, C.ok)
      else
        setMsg(T.errPrefix .. name, C.err)
      end
    else
      local it = selected()
      if not it then
        backToList()
        return
      end
      if name == it.name then
        backToList()
        return
      end
      if dfs.exists(target) then
        setMsg(T.nameExists, C.err)
        return
      end
      local ok = pcall(dfs.rename, it.path, target)
      st.mode = "list"
      if ok then
        reload(name)
        setMsg(T.renamed, C.ok)
      else
        setMsg(T.errPrefix .. it.name, C.err)
      end
    end
  end

  -- Mover: escolhe o item, abre a pasta de destino (ate em outro disco) e cola
  local function startMove()
    if st.view ~= "dir" then
      setMsg(T.fxOpenFirst, C.warn)
      return
    end
    local it = selected()
    if not it or it.kind ~= "item" then return end
    if isProt(st.drive, it.path) then
      setMsg(T.sysLocked, C.warn)
      return
    end
    if curFs().isReadOnly() then
      setMsg(T.fxROMsg, C.err)
      return
    end
    st.move = { drive = st.drive, path = it.path, name = it.name, isDir = it.dir }
    setMsg(string.format(T.fxMoving, it.name), C.warn)
  end

  local function cancelMove()
    st.move = nil
    setMsg("", C.dim)
  end

  local function doPaste()
    local mv = st.move
    if not mv then return end
    if st.view ~= "dir" then
      setMsg(T.fxOpenFirst, C.warn)
      return
    end
    local dstFs = curFs()
    if dstFs.isReadOnly() then
      setMsg(T.fxROMsg, C.err)
      return
    end
    local target = joinPath(st.dir, mv.name)
    local sameDrive = (st.drive == mv.drive)
    if sameDrive and st.dir == parentPath(mv.path) then
      setMsg(T.fxSame, C.warn)
      return
    end
    if sameDrive and mv.isDir and (st.dir == mv.path or st.dir:sub(1, #mv.path + 1) == mv.path .. "/") then
      setMsg(T.fxIntoSelf, C.err)
      return
    end
    if dstFs.exists(target) then
      setMsg(T.fxExists, C.err)
      return
    end
    local srcFs = proxyOf(mv.drive)
    local ok = pcall(function()
      if sameDrive then
        if not srcFs.rename(mv.path, target) then error("rename", 0) end
      else
        setMsg(string.format(T.fxCopying, mv.name), C.dim)
        win.body(win)
        if not fxCopyTree(srcFs, mv.path, dstFs, target, { n = 0 }) then
          pcall(dstFs.remove, target)
          error("copy", 0)
        end
        srcFs.remove(mv.path)
      end
    end)
    if ok then
      st.move = nil
      reload(mv.name)
      setMsg(T.fxMoved, C.ok)
    else
      setMsg(T.errPrefix .. mv.name, C.err)
    end
  end

  local function buttonsA()
    if st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    elseif st.mode == "create" or st.mode == "rename" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    elseif st.mode == "view" then
      return makeButtons(ix, { { "closeview", T.bBack } })
    end
    return makeButtons(ix, {
      { "back", "◀" }, { "fwd", "▶" }, { "up", "▲" },
      { "open", T.bOpen, C.ok }, { "create", T.fxCreate },
    })
  end

  local function buttonsB()
    if st.mode ~= "list" then return {} end
    if st.move then
      return makeButtons(ix, { { "paste", T.fxPaste, C.ok }, { "cancelmove", T.bCancel } })
    end
    return makeButtons(ix, {
      { "rename", T.bRename }, { "move", T.fxMove }, { "delete", T.bDelete, C.warn },
    })
  end

  local function drawAddress()
    rect(ix, addrY, iw, 1, C.barbg)
    st.crumbs = {}
    if st.mode == "view" then
      put(ix + 1, addrY, st.viewName, C.text, C.barbg, iw - 2)
      return
    end
    local parts = { { text = T.fxHome, target = { view = "home" } } }
    if st.view == "dir" then
      parts[#parts + 1] = {
        text = driveName(st.drive), target = { view = "dir", drive = st.drive, dir = "/" },
      }
      local acc = ""
      for seg in st.dir:gmatch("[^/]+") do
        acc = acc .. "/" .. seg
        parts[#parts + 1] = { text = seg, target = { view = "dir", drive = st.drive, dir = acc } }
      end
    end
    local function total(from)
      local n = 0
      for i = from, #parts do
        n = n + ulen(parts[i].text) + (i > from and 3 or 0)
      end
      return n
    end
    local from = 1
    while from < #parts and total(from) > iw - 2 do from = from + 1 end
    local x = ix + 1
    for i = from, #parts do
      if i > from then
        put(x, addrY, " > ", C.dim, C.barbg)
        x = x + 3
      end
      local text = parts[i].text
      put(x, addrY, text, (i == #parts) and C.text or C.accent, C.barbg)
      st.crumbs[#st.crumbs + 1] = { x = x, w = ulen(text), target = parts[i].target }
      x = x + ulen(text)
    end
  end

  local function drawRow(y, it, isSel)
    if it.kind == "header" then
      put(ix, y, it.name, C.accent, C.panel, iw)
      return
    end
    local bg = isSel and C.accent or C.panel
    local fg = isSel and C.bg or C.text
    local dim = isSel and C.bg or C.dim
    rect(ix - 1, y, iw + 2, 1, bg)
    local right = ""
    local label
    if it.kind == "drive" then
      label = "▣ " .. it.name .. (it.boot and (" " .. T.fxBoot) or "") .. (it.ro and (" " .. T.fxRO) or "")
      right = string.format(T.fxFree, fxBytes(it.total - it.used), fxBytes(it.total))
    elseif it.kind == "folder" then
      label = "▸ " .. it.name
      right = it.path
      fg = isSel and C.bg or C.accent
    else
      label = (it.dir and "▸ " or "  ") .. it.name .. (it.dir and "/" or "")
      right = it.dir and "" or fmtSize(it.size)
      if it.dir then fg = isSel and C.bg or C.accent end
    end
    put(ix, y, label, fg, bg, iw - ulen(right) - 1)
    if right ~= "" then put(ix + iw - ulen(right), y, right, dim, bg) end
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    drawAddress()
    drawButtons(buttonsA(), btnA)
    drawButtons(buttonsB(), btnB)

    if st.mode == "view" then
      for n = 0, rows - 1 do
        local line = st.lines[st.vfirst + n]
        if line then put(ix, listY + n, line, C.text, C.panel, iw) end
      end
    else
      if st.view == "dir" and #st.items == 0 then put(ix, listY, T.emptyDir, C.dim, C.panel, iw) end
      for n = 0, rows - 1 do
        local it = st.items[st.first + n]
        if it then drawRow(listY + n, it, (st.first + n == st.sel)) end
      end
      if st.first > 1 then put(self.x + self.w - 3, listY, "▲", C.dim, C.panel) end
      if st.first + rows <= #st.items then
        put(self.x + self.w - 3, listY + rows - 1, "▼", C.dim, C.panel)
      end
    end

    if st.mode == "create" or st.mode == "rename" then
      rect(ix, msgY, iw, 1, C.barbg)
      local ask = (st.mode == "create") and T.fxCreatePrompt or T.renamePrompt
      put(ix + 1, msgY, ask .. " " .. st.input .. "_", C.text, C.barbg, iw - 2)
    elseif st.msg ~= "" then
      put(ix, msgY, st.msg, st.msgColor, C.panel, iw)
    end

    local count = 0
    for _, it in ipairs(st.items) do
      if it.kind ~= "header" then count = count + 1 end
    end
    local status
    if st.mode == "view" then
      local last = math.min(#st.lines, st.vfirst + rows - 1)
      status = string.format("%d-%d / %d", st.vfirst, last, #st.lines)
    else
      status = string.format(T.fxItems, count)
      if selected() then status = status .. "   " .. string.format(T.fxSel, 1) end
    end
    put(ix, statusY, status, C.dim, C.panel, iw)
  end

  win.onTouch = function(self, x, y)
    if y == addrY then
      for _, c in ipairs(st.crumbs) do
        if x >= c.x and x < c.x + c.w then
          navigate(c.target)
          return true
        end
      end
      return false
    end
    if y == btnA or y == btnB then
      local id = hitButton(y == btnA and buttonsA() or buttonsB(), x)
      if id == "back" then
        goBack()
      elseif id == "fwd" then
        goForward()
      elseif id == "up" then
        goUp()
      elseif id == "open" then
        openItem()
      elseif id == "create" then
        startCreate()
      elseif id == "rename" then
        startRename()
      elseif id == "move" then
        startMove()
      elseif id == "delete" then
        startDelete()
      elseif id == "paste" then
        doPaste()
      elseif id == "cancelmove" then
        cancelMove()
      elseif id == "ok" then
        submitPrompt()
      elseif id == "cancel" or id == "no" or id == "closeview" then
        backToList()
      elseif id == "yes" then
        doDelete()
      else
        return false
      end
      return true
    end
    if st.mode == "list" and y >= listY and y < listY + rows
        and x >= self.x + 1 and x < self.x + self.w - 1 then
      local idx = st.first + (y - listY)
      local it = st.items[idx]
      if it and it.kind ~= "header" then
        local now = cp.uptime()
        if st.sel == idx and now - st.lastClick < 1.5 then
          openItem()
        else
          st.sel = idx
          st.msg = (st.move and st.msg) or ""
        end
        st.lastClick = now
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "create" or st.mode == "rename" then
      if code == 28 then
        submitPrompt()
      elseif code == 1 then
        backToList()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(st.input) < 40 then
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
    if code == 1 and st.move then
      cancelMove()
      return true
    elseif code == 200 then
      moveSel(-1)
      return true
    elseif code == 208 then
      moveSel(1)
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
    elseif code == 63 then
      reload()
      return true
    end
    return false
  end

  win.onScroll = function(self, dir)
    if st.mode == "view" then
      st.vfirst = math.max(1, math.min(st.vfirst - dir * 3, math.max(1, #st.lines - rows + 1)))
    elseif st.mode == "list" then
      moveSel(-dir)
    end
  end

  -- comeca em "Este Computador"; se veio uma pasta (ex.: /Download), abre ela
  st.hist = { { view = "home" } }
  st.hpos = 1
  if startDir then
    navigate({ view = "dir", drive = bootAddr, dir = startDir })
  else
    applyState(st.hist[1])
  end
  return win
end


  return filesApp(startDir)
end
