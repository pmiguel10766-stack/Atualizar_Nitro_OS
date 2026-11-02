-- Antivirus (nitro/sys/antivirus.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local avAnalyzeFile = A.avAnalyzeFile
  local avFormat = A.avFormat
  local drawButtons = A.drawButtons
  local fmtSize = A.fmtSize
  local fs = A.fs
  local hitButton = A.hitButton
  local makeButtons = A.makeButtons
  local put = A.put
  local rect = A.rect
  local setWinGeom = A.setWinGeom
  local trimText = A.trimText
  local ulen = A.ulen
local AV_DIR = "/Download"

local function antivirusApp(presetPath)
  local win = { title = T.mAntivirus }
  setWinGeom(win, 62, 16)
  local ix, iw = win.x + 2, win.w - 4
  local pathY, btnY, listY = win.y + 2, win.y + 3, win.y + 5
  local rows = win.h - 9
  local statusY = win.y + win.h - 3
  local st = {
    mode = "main", path = presetPath or "", files = {}, sel = 1, first = 1,
    lines = {}, colors = {}, vfirst = 1, title = "", msg = "", msgColor = C.dim,
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

  local function reload()
    st.files = {}
    local ok, names = pcall(fs.list, AV_DIR)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-1) ~= "/" then
          local path = AV_DIR .. "/" .. n
          st.files[#st.files + 1] = { name = n, path = path, size = fs.size(path) }
        end
      end
    end
    table.sort(st.files, function(p, q) return p.name:lower() < q.name:lower() end)
    st.sel, st.first = 1, 1
  end

  local function analyze()
    local path = trimText(st.path)
    if path == "" then
      setMsg(T.avNoFile, C.err)
      return
    end
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    local report, err = avAnalyzeFile(path)
    if not report then
      setMsg(tostring(err), C.err)
      return
    end
    st.lines, st.colors = avFormat(report, path)
    st.title = string.format(T.avScanned, path:match("([^/]+)$") or path)
    st.vfirst = 1
    st.mode = "result"
    setMsg("", C.dim)
  end

  local function curButtons()
    if st.mode == "result" then
      return makeButtons(ix, { { "back", T.gBack } })
    end
    return makeButtons(ix, { { "scan", T.avScan, C.ok } })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.avPath, C.dim, C.panel, iw)
    rect(ix, pathY, iw, 1, C.barbg)
    local shown = st.path
    if #shown > iw - 3 then shown = shown:sub(#shown - iw + 4) end
    put(ix + 1, pathY, shown .. (st.mode == "main" and "_" or ""), C.text, C.barbg, iw - 2)
    drawButtons(curButtons(), btnY)

    if st.mode == "result" then
      put(ix, listY - 1, st.title, C.accent, C.panel, iw)
      for n = 0, rows - 1 do
        local line = st.lines[st.vfirst + n]
        if line then
          put(ix, listY + n, line, st.colors[st.vfirst + n] or C.text, C.panel, iw)
        end
      end
    else
      put(ix, listY - 1, T.avFiles, C.dim, C.panel, iw)
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
    if st.msg ~= "" then put(ix, statusY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "scan" then
        analyze()
      elseif id == "back" then
        st.mode = "main"
      else
        return false
      end
      return true
    end
    if st.mode == "main" and y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if st.files[idx] then
        st.sel = idx
        st.path = st.files[idx].path
        setMsg("", C.dim)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "result" then
      if code == 200 then
        st.vfirst = math.max(1, st.vfirst - 1)
      elseif code == 208 then
        st.vfirst = math.max(1, math.min(st.vfirst + 1, #st.lines - rows + 1))
      elseif code == 1 or code == 28 then
        st.mode = "main"
      end
      return true
    end
    if code == 28 then
      analyze()
      return true
    elseif code == 14 then
      if #st.path > 0 then st.path = st.path:sub(1, -2) end
      return true
    elseif code == 200 or code == 208 then
      st.sel = st.sel + (code == 208 and 1 or -1)
      keepVisible()
      if st.files[st.sel] then st.path = st.files[st.sel].path end
      return true
    elseif char and char >= 32 and char < 127 and #st.path < 200 then
      st.path = st.path .. string.char(char)
      return true
    end
    return false
  end

  win.onPaste = function(self, text)
    if st.mode ~= "main" then return false end
    text = tostring(text):gsub("%c", "")
    st.path = (st.path .. text):sub(1, 200)
    return true
  end

  reload()
  return win
end

---------------------------------------------------------------- app GitDown
  return antivirusApp(...)
end
