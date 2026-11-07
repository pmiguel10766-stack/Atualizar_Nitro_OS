-- Editor Lua do Nitro OS (nitro/sys/editorlua.lua): edita codigo com realce e numeros de linha.
-- Nao executa nada. Recebe A (a API do Nitro OS).
-- Copiar: Ctrl+Insert (sem selecao copia o script inteiro). Colar: Shift+Insert.
return function(A, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub, uchar = A.ulen, A.usub, A.uchar
  local makeButtons, drawButtons, hitButton = A.makeButtons, A.drawButtons, A.hitButton
  local C, T, fs, readFile = A.C, A.T, A.fs, A.readFile
  local newTextArea, taKey, taClamp, taSetText, taText, taClick =
    A.newTextArea, A.taKey, A.taClamp, A.taSetText, A.taText, A.taClick
  local CLIP = A.CLIP

  local KW = {}
  for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do
    KW[w] = true
  end
  local COL = { kw = 0xFF5555, str = 0x6DDC6D, com = 0x7A7A8A, num = 0xFFB300 }
  local DEFAULT_PATH = "/Download/novo.lua"

  local win = { title = T.mEditorLua }
  setWinGeom(win, 66, 19)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, pathY, msgY = win.y + 2, win.y + 1, win.y + 16
  local gutterW = 5
  local areaY = win.y + 4
  local rows = win.h - 8
  local ta = newTextArea(ix + gutterW + 1, areaY, iw - gutterW - 1, rows)

  local st = { path = nil, mode = "edit", prompt = "save", input = "", msg = "", msgColor = C.dim }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  -- cor de cada caractere (so para linhas ASCII)
  local function colorsOf(s)
    local cols, i, n = {}, 1, #s
    while i <= n do
      local c = s:sub(i, i)
      if s:sub(i, i + 1) == "--" then
        for k = i, n do cols[k] = COL.com end
        break
      elseif c == '"' or c == "'" then
        local j = i + 1
        while j <= n and s:sub(j, j) ~= c do
          if s:sub(j, j) == "\\" then j = j + 1 end
          j = j + 1
        end
        for k = i, math.min(j, n) do cols[k] = COL.str end
        i = j + 1
      elseif c:match("[%a_]") then
        local w = s:match("^[%w_]+", i)
        local col = KW[w] and COL.kw or nil
        if col then for k = i, i + #w - 1 do cols[k] = col end end
        i = i + #w
      elseif c:match("%d") then
        local w = s:match("^[%w%.]+", i)
        for k = i, i + #w - 1 do cols[k] = COL.num end
        i = i + #w
      else
        i = i + 1
      end
    end
    return cols
  end

  local function selBounds()
    if not ta.anchor then return nil end
    local a, b = ta.anchor, { y = ta.cy, x = ta.cx }
    if a.y > b.y or (a.y == b.y and a.x > b.x) then a, b = b, a end
    if a.y == b.y and a.x == b.x then return nil end
    return a, b
  end

  local function inSelection(idx, k0)
    local a, b = selBounds()
    if not a then return false end
    if idx < a.y or idx > b.y then return false end
    local from = (idx == a.y) and a.x or 0
    local to = (idx == b.y) and b.x or math.huge
    return k0 >= from and k0 < to
  end

  local function selText()
    local a, b = selBounds()
    if not a then return nil end
    if a.y == b.y then return usub(ta.lines[a.y], a.x + 1, b.x) end
    local parts = { usub(ta.lines[a.y], a.x + 1) }
    for i = a.y + 1, b.y - 1 do parts[#parts + 1] = ta.lines[i] end
    parts[#parts + 1] = usub(ta.lines[b.y], 1, b.x)
    return table.concat(parts, "\n")
  end

  local function deleteSel()
    local a, b = selBounds()
    if not a then return false end
    local first = usub(ta.lines[a.y], 1, a.x) .. usub(ta.lines[b.y], b.x + 1)
    for _ = a.y + 1, b.y do table.remove(ta.lines, a.y + 1) end
    ta.lines[a.y] = first
    ta.cy, ta.cx = a.y, a.x
    ta.anchor = nil
    ta.modified = true
    taClamp(ta)
    return true
  end

  local function insertText(text)
    local ins = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      ins[#ins + 1] = (line:gsub("\r", ""):gsub("\t", "  "))
    end
    if #ins > 0 and ins[#ins] == "" then table.remove(ins) end
    if #ins == 0 then return end
    local cur = ta.lines[ta.cy]
    local before = usub(cur, 1, ta.cx)
    local after = usub(cur, ta.cx + 1)
    ta.lines[ta.cy] = before .. ins[1]
    local idx = ta.cy
    for i = 2, #ins do
      idx = idx + 1
      table.insert(ta.lines, idx, ins[i])
    end
    ta.lines[idx] = ta.lines[idx] .. after
    ta.cy = idx
    ta.cx = ulen(ta.lines[idx]) - ulen(after)
    ta.modified = true
    taClamp(ta)
  end

  local function copySel()
    local text = selText() or taText(ta)
    CLIP.text = text
    setMsg(T.edCopied, C.ok)
  end

  local function pasteText(text)
    if not text or text == "" then return end
    deleteSel()
    ta.anchor = nil
    insertText(text)
    setMsg(T.edPasted, C.ok)
  end

  local function doSave(path)
    local hnd = fs.open(path, "w")
    if not hnd then
      setMsg(T.errPrefix .. path, C.err)
      return
    end
    fs.write(hnd, taText(ta))
    fs.close(hnd)
    st.path = path
    ta.modified = false
    setMsg(T.xSaved, C.ok)
  end

  local function doOpen(path)
    if not fs.exists(path) then setMsg(T.xNotFound, C.err) return end
    if fs.isDirectory(path) then setMsg(T.xIsDir, C.err) return end
    if fs.size(path) > 16384 then setMsg(T.xTooBig, C.err) return end
    local data = readFile(path)
    if not data then setMsg(T.errPrefix .. path, C.err) return end
    if data:find("\0", 1, true) then setMsg(T.binaryFile, C.warn) return end
    taSetText(ta, data)
    st.path = path
    setMsg("", C.dim)
  end

  local function normPath(p)
    p = p:match("^%s*(.-)%s*$")
    if p == "" then return nil end
    if p:sub(1, 1) ~= "/" then p = "/" .. p end
    return p
  end

  local function submitPrompt()
    local path = normPath(st.input)
    if not path then setMsg(T.nameBad, C.err) return end
    local kind = st.prompt
    st.mode = "edit"
    if kind == "open" then doOpen(path) else doSave(path) end
  end

  local function startPrompt(kind)
    st.mode, st.prompt = "prompt", kind
    st.input = st.path or DEFAULT_PATH
    setMsg("", C.dim)
  end

  local function curButtons()
    if st.mode == "prompt" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    end
    return makeButtons(ix, { { "new", T.xNew }, { "open", T.bOpen }, { "save", T.bSave, C.ok } })
  end

  local function drawLine(idx, y)
    local line = ta.lines[idx]
    rect(ta.x, y, ta.w, 1, C.panel)
    if not line then return end
    if line:find("[\128-\255]") then
      put(ta.x, y, usub(line, ta.left + 1, ta.left + ta.w), C.text, C.panel, ta.w)
      return
    end
    local cols = colorsOf(line)
    for k = ta.left + 1, math.min(#line, ta.left + ta.w) do
      local k0 = k - 1
      local sel = inSelection(idx, k0)
      local bg = sel and C.accent or C.panel
      local fg = sel and C.bg or (cols[k] or C.text)
      put(ta.x + k0 - ta.left, y, line:sub(k, k), fg, bg)
    end
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, pathY, st.path or T.xNoName, C.dim, C.panel, iw)
    drawButtons(curButtons(), btnY)

    for n = 0, ta.h - 1 do
      local idx = ta.top + n
      local y = ta.y + n
      rect(ix, y, gutterW, 1, C.panel)
      if ta.lines[idx] then
        put(ix, y, string.format("%4d", idx), (idx == ta.cy) and C.accent or C.dim, C.panel)
      end
      drawLine(idx, y)
    end
    -- cursor
    if st.mode == "edit" and ta.cy >= ta.top and ta.cy < ta.top + ta.h then
      local line = ta.lines[ta.cy] or ""
      local ch = usub(line, ta.cx + 1, ta.cx + 1)
      if ch == "" then ch = " " end
      put(ta.x + ta.cx - ta.left, ta.y + ta.cy - ta.top, ch, C.bg, C.accent)
    end

    local statusY = win.y + win.h - 3
    if st.mode == "prompt" then
      rect(ix, msgY, iw, 1, C.barbg)
      local ask = (st.prompt == "open") and T.xPathAsk or T.xSaveAsk
      put(ix + 1, msgY, ask .. " " .. st.input .. "_", C.text, C.barbg, iw - 2)
    elseif st.msg ~= "" then
      put(ix, msgY, st.msg, st.msgColor, C.panel, iw)
    end
    put(ix, statusY, string.format(T.xPos, ta.cy, ta.cx + 1, #ta.lines), C.dim, C.panel, iw)
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "new" then
        taSetText(ta, "")
        st.path = nil
        setMsg("", C.dim)
      elseif id == "open" then startPrompt("open")
      elseif id == "save" then
        if st.path then doSave(st.path) else startPrompt("save") end
      elseif id == "ok" then submitPrompt()
      elseif id == "cancel" then st.mode = "edit"
      else return false end
      return true
    end
    if st.mode == "edit" then return taClick(ta, x, y) end
    return false
  end

  win.onKey = function(self, char, code, mods)
    local shift = mods and mods.shift
    local ctrl = mods and mods.ctrl
    if st.mode == "prompt" then
      if code == 28 then submitPrompt()
      elseif code == 1 then st.mode = "edit"
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char < 127 and ulen(st.input) < 60 then
        st.input = st.input .. string.char(char)
      end
      return true
    end
    if code == 1 then return false end                      -- Esc fecha
    if code == 60 then                                       -- F2 salva
      if st.path then doSave(st.path) else startPrompt("save") end
      return true
    end
    if code == 210 and ctrl then copySel() return true end   -- Ctrl+Insert
    if code == 210 and shift then pasteText(CLIP.text or "") return true end
    if code == 15 then                                       -- Tab: dois espacos
      deleteSel()
      ta.lines[ta.cy] = usub(ta.lines[ta.cy], 1, ta.cx) .. "  " .. usub(ta.lines[ta.cy], ta.cx + 1)
      ta.cx = ta.cx + 2
      ta.modified = true
      taClamp(ta)
      return true
    end
    local arrow = (code == 200 or code == 208 or code == 203 or code == 205
      or code == 199 or code == 207 or code == 201 or code == 209)
    if arrow then
      if shift then
        if not ta.anchor then ta.anchor = { y = ta.cy, x = ta.cx } end
      else
        ta.anchor = nil
      end
      return taKey(ta, char, code)
    end
    if ta.anchor and ((char and char >= 32) or code == 14 or code == 28 or char == 13 or code == 211) then
      deleteSel()
      if code == 14 or code == 211 then return true end
    end
    return taKey(ta, char, code)
  end

  win.onPaste = function(self, text)
    if st.mode == "prompt" then
      st.input = (st.input .. tostring(text):gsub("%c", "")):sub(1, 60)
      return true
    end
    local clean = (tostring(text):gsub("\r", ""):gsub("\t", "  "))
    pasteText(clean)
    return true
  end

  return win
end
