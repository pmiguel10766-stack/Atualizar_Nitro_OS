-- Editor de Texto (nitro/sys/editor.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local taClamp = A.taClamp
  local CLIP = A.CLIP
  local C = A.C
  local drawButtons = A.drawButtons
  local fs = A.fs
  local hitButton = A.hitButton
  local input = A.input
  local makeButtons = A.makeButtons
  local newTextArea = A.newTextArea
  local put = A.put
  local readFile = A.readFile
  local rect = A.rect
  local setWinGeom = A.setWinGeom
  local taClick = A.taClick
  local taDraw = A.taDraw
  local taKey = A.taKey
  local taSetText = A.taSetText
  local taText = A.taText
  local uchar = A.uchar
  local ulen = A.ulen
  local usub = A.usub
local function isProtected(path)
  return path:sub(1, 6) == "/nitro" or path == "/init.lua"
end

---------------------------------------------------------------- area de texto (Editor de Texto e Notas)
  local win = { title = T.mEditor }
  setWinGeom(win, 64, 18)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, areaY = win.y + 2, win.y + 4
  local statusY = win.y + win.h - 3
  local ta = newTextArea(ix, areaY, iw, win.h - 8)
  local st = {
    path = nil, mode = "edit", prompt = "open", input = "",
    msg = "", msgColor = C.warn, pending = nil, closeWarn = false,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function normPath(p)
    p = p:match("^%s*(.-)%s*$")
    if p == "" then return nil end
    if p:sub(1, 1) ~= "/" then p = "/" .. p end
    return p
  end

  local function doSave(path)
    if isProtected(path) then
      setMsg(T.sysLocked, C.err)
      return
    end
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
    if not fs.exists(path) then
      setMsg(T.xNotFound, C.err)
      return
    end
    if fs.isDirectory(path) then
      setMsg(T.xIsDir, C.err)
      return
    end
    if fs.size(path) > 16384 then
      setMsg(T.xTooBig, C.err)
      return
    end
    local data = readFile(path)
    if not data then
      setMsg(T.errPrefix .. path, C.err)
      return
    end
    if data:find("\0", 1, true) then
      setMsg(T.binaryFile, C.warn)
      return
    end
    taSetText(ta, data)
    st.path = path
    setMsg("", C.dim)
  end

  local function startSave()
    if st.path then
      doSave(st.path)
    else
      st.mode = "prompt"
      st.prompt = "save"
      st.input = "/"
      setMsg("", C.dim)
    end
  end

  local function startOpen()
    st.mode = "prompt"
    st.prompt = "open"
    st.input = st.path or "/"
    setMsg("", C.dim)
  end

  local function actionNew()
    taSetText(ta, "")
    st.path = nil
    setMsg("", C.dim)
  end

  local function guardDiscard(action)
    if ta.modified then
      st.mode = "confirm"
      st.pending = action
      setMsg(T.xDiscard, C.warn)
    else
      action()
    end
  end

  local function backToEdit()
    st.mode = "edit"
    st.pending = nil
    setMsg("", C.dim)
  end

  local function submitPrompt()
    local path = normPath(st.input)
    if not path then
      setMsg(T.nameBad, C.err)
      return
    end
    local kind = st.prompt
    st.mode = "edit"
    if kind == "open" then doOpen(path) else doSave(path) end
  end

  local function answerYes()
    local act = st.pending
    backToEdit()
    if act then act() end
  end

  -- ---------------- biblioteca de trechos (pasta /nitro/biblioteca)
  local LIB_DIR = "/nitro/biblioteca"
  local lib = { items = {}, sel = 1, first = 1 }

  local function libLoad()
    lib.items = {}
    local ok, names = pcall(fs.list, LIB_DIR)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-4) == ".lua" then
          local path = LIB_DIR .. "/" .. n
          local data = readFile(path) or ""
          local title = data:match("%-%-%s*titulo:%s*([^\r\n]+)") or n:sub(1, -5)
          title = title:match("^%s*(.-)%s*$")
          lib.items[#lib.items + 1] = { title = title, path = path }
        end
      end
    end
    table.sort(lib.items, function(p, q) return p.title:lower() < q.title:lower() end)
    lib.sel, lib.first = 1, 1
  end

  local function libKeep()
    if lib.sel < 1 then lib.sel = 1 end
    if lib.sel > #lib.items then lib.sel = #lib.items end
    if lib.sel < lib.first then lib.first = lib.sel end
    if lib.sel >= lib.first + ta.h then lib.first = lib.sel - ta.h + 1 end
  end

  -- insere o texto na posicao do cursor (varias linhas)
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

  local function openLib()
    libLoad()
    st.mode = "lib"
    setMsg("", C.dim)
  end

  local function insertSelected()
    local it = lib.items[lib.sel]
    if not it then return end
    local data = readFile(it.path)
    if not data then
      setMsg(T.errPrefix .. it.title, C.err)
      return
    end
    insertText(data)
    st.mode = "edit"
    setMsg(T.xInserted, C.ok)
  end

  local function libDraw()
    if #lib.items == 0 then
      put(ix, areaY, T.xLibEmpty, C.dim, C.panel, iw)
      return
    end
    for n = 0, ta.h - 1 do
      local it = lib.items[lib.first + n]
      if it then
        local y = areaY + n
        local isSel = (lib.first + n == lib.sel)
        local bg = isSel and C.accent or C.panel
        rect(ix - 1, y, iw + 2, 1, bg)
        put(ix, y, "  " .. it.title, isSel and C.bg or C.text, bg, iw)
      end
    end
  end

  local function curButtons()
    if st.mode == "prompt" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    elseif st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    elseif st.mode == "lib" then
      return makeButtons(ix, { { "insert", T.xInsert, C.ok }, { "back", T.bBack } })
    end
    return makeButtons(ix, {
      { "new", T.xNew }, { "open", T.bOpen }, { "save", T.xSave, C.ok }, { "lib", T.xLib },
    })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local name = st.path or T.xNoName
    put(ix, self.y + 1, name .. (ta.modified and " *" or ""), C.dim, C.panel, iw)
    drawButtons(curButtons(), btnY)
    if st.mode == "lib" then libDraw() else taDraw(ta, st.mode == "edit") end
    if st.mode == "prompt" then
      rect(ix, statusY, iw, 1, C.barbg)
      local ask = (st.prompt == "open") and T.xPathAsk or T.xSaveAsk
      put(ix + 1, statusY, ask .. " " .. st.input .. "_", C.text, C.barbg, iw - 2)
      if st.msg ~= "" then put(ix, statusY - 1, st.msg, st.msgColor, C.panel, iw) end
    elseif st.msg ~= "" then
      put(ix, statusY, st.msg, st.msgColor, C.panel, iw)
    else
      put(ix, statusY, string.format(T.xPos, ta.cy, ta.cx + 1, #ta.lines), C.dim, C.panel, iw)
    end
  end

  -- ---------------- selecao e area de transferencia (Ctrl+Insert copia, Shift+Insert cola)
  local function selBounds()
    if not ta.anchor then return nil end
    local a, b = ta.anchor, { y = ta.cy, x = ta.cx }
    if a.y > b.y or (a.y == b.y and a.x > b.x) then a, b = b, a end
    if a.y == b.y and a.x == b.x then return nil end
    return a, b
  end

  local function selText()
    local s, e = selBounds()
    if not s then return nil end
    if s.y == e.y then return usub(ta.lines[s.y], s.x + 1, e.x) end
    local parts = { usub(ta.lines[s.y], s.x + 1) }
    for i = s.y + 1, e.y - 1 do parts[#parts + 1] = ta.lines[i] end
    parts[#parts + 1] = usub(ta.lines[e.y], 1, e.x)
    return table.concat(parts, "\n")
  end

  local function deleteSel()
    local s, e = selBounds()
    if not s then return false end
    local first = usub(ta.lines[s.y], 1, s.x) .. usub(ta.lines[e.y], e.x + 1)
    for _ = s.y + 1, e.y do table.remove(ta.lines, s.y + 1) end
    ta.lines[s.y] = first
    ta.cy, ta.cx = s.y, s.x
    ta.anchor = nil
    ta.modified = true
    taClamp(ta)
    return true
  end

  local function copySel()
    local text = selText()
    if not text then text = taText(ta) end
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

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "new" then
        guardDiscard(actionNew)
      elseif id == "open" then
        guardDiscard(startOpen)
      elseif id == "save" then
        startSave()
      elseif id == "ok" then
        submitPrompt()
      elseif id == "cancel" or id == "no" then
        backToEdit()
      elseif id == "yes" then
        answerYes()
      elseif id == "lib" then
        guardDiscard(openLib)
      elseif id == "insert" then
        insertSelected()
      elseif id == "back" then
        st.mode = "edit"
        setMsg("", C.dim)
      else
        return false
      end
      return true
    end
    if st.mode == "lib" then
      if y >= areaY and y < areaY + ta.h then
        local idx = lib.first + (y - areaY)
        if lib.items[idx] then
          lib.sel = idx
          return true
        end
      end
      return false
    end
    if st.mode == "edit" then return taClick(ta, x, y) end
    return false
  end

  win.onKey = function(self, char, code, mods)
    if code ~= 1 then st.closeWarn = false end
    if st.mode == "lib" then
      if code == 200 then
        lib.sel = lib.sel - 1
        libKeep()
      elseif code == 208 then
        lib.sel = lib.sel + 1
        libKeep()
      elseif code == 28 then
        insertSelected()
      elseif code == 1 then
        st.mode = "edit"
        setMsg("", C.dim)
      end
      return true
    end
    if st.mode == "prompt" then
      if code == 28 then
        submitPrompt()
      elseif code == 1 then
        backToEdit()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(st.input) < 60 then
        st.input = st.input .. uchar(char)
      end
      return true
    elseif st.mode == "confirm" then
      if code == 31 or code == 21 then
        answerYes()
      elseif code == 49 or code == 1 then
        backToEdit()
      end
      return true
    end
    if code == 60 then
      startSave()
      return true
    end
    if st.msg ~= "" then setMsg("", C.dim) end
    local shift = mods and mods.shift
    local ctrl = mods and mods.ctrl
    if code == 210 and ctrl then           -- Ctrl+Insert: copiar
      copySel()
      return true
    end
    if code == 210 and shift then          -- Shift+Insert: colar
      pasteText(CLIP.text or "")
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
    -- digitar, apagar ou Enter com trecho selecionado: apaga a selecao antes
    if ta.anchor and ((char and char >= 32) or code == 14 or code == 28 or char == 13 or code == 211) then
      deleteSel()
      if code == 14 or code == 211 then return true end
    end
    return taKey(ta, char, code)
  end

  win.canClose = function(self)
    if not ta.modified or st.closeWarn then return true end
    st.closeWarn = true
    setMsg(T.xUnsaved, C.warn)
    return false
  end

  win.onPaste = function(self, text)
    if st.mode ~= "edit" then return false end
    local clean = (tostring(text):gsub("\r", ""):gsub("\t", "  "))
    pasteText(clean)
    return true
  end

  return win
end
