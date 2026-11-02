-- Editor de Texto (nitro/sys/editor.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
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
local function textEditorApp()
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

  local function curButtons()
    if st.mode == "prompt" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    elseif st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    end
    return makeButtons(ix, {
      { "new", T.xNew }, { "open", T.bOpen }, { "save", T.xSave, C.ok },
    })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local name = st.path or T.xNoName
    put(ix, self.y + 1, name .. (ta.modified and " *" or ""), C.dim, C.panel, iw)
    drawButtons(curButtons(), btnY)
    taDraw(ta, st.mode == "edit")
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
      else
        return false
      end
      return true
    end
    if st.mode == "edit" then return taClick(ta, x, y) end
    return false
  end

  win.onKey = function(self, char, code)
    if code ~= 1 then st.closeWarn = false end
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
    return taKey(ta, char, code)
  end

  win.canClose = function(self)
    if not ta.modified or st.closeWarn then return true end
    st.closeWarn = true
    setMsg(T.xUnsaved, C.warn)
    return false
  end

  return win
end

---------------------------------------------------------------- app Notas
  return textEditorApp(...)
end
