-- Notas (nitro/sys/notas.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local cp = A.cp
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
local NOTES_DIR = "/notas"

local function notesApp()
  local win = { title = T.mNotes }
  setWinGeom(win, 60, 16)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, listY = win.y + 2, win.y + 4
  local statusY = win.y + win.h - 3
  local rows = win.h - 8
  local ta = newTextArea(ix, listY, iw, rows)
  local st = {
    mode = "list", items = {}, sel = 1, first = 1, current = nil,
    input = "", msg = "", msgColor = C.warn, lastClick = 0,
  }
  fs.makeDirectory(NOTES_DIR)

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.warn
  end

  local function notePath(name)
    return NOTES_DIR .. "/" .. name .. ".txt"
  end

  local function keepVisible()
    if st.sel > #st.items then st.sel = #st.items end
    if st.sel < 1 then st.sel = 1 end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function reload(select)
    st.items = {}
    local ok, names = pcall(fs.list, NOTES_DIR)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-4) == ".txt" then st.items[#st.items + 1] = n:sub(1, -5) end
      end
    end
    table.sort(st.items, function(p, q) return p:lower() < q:lower() end)
    st.sel, st.first = 1, 1
    if select then
      for i, name in ipairs(st.items) do
        if name == select then st.sel = i end
      end
    end
    keepVisible()
  end

  local function saveNote()
    if not st.current then return end
    local hnd = fs.open(notePath(st.current), "w")
    if not hnd then
      setMsg(T.errPrefix .. st.current, C.err)
      return
    end
    fs.write(hnd, taText(ta))
    fs.close(hnd)
    ta.modified = false
    setMsg(T.xSaved, C.ok)
  end

  local function openNote(name)
    taSetText(ta, readFile(notePath(name)) or "")
    st.current = name
    st.mode = "edit"
    setMsg("", C.dim)
  end

  local function backToList()
    if st.mode == "edit" and ta.modified then saveNote() end
    local keep = st.current
    st.mode = "list"
    st.current = nil
    reload(keep)
    setMsg("", C.dim)
  end

  local function startNew()
    st.mode = "prompt"
    st.input = ""
    setMsg("", C.dim)
  end

  local function submitNew()
    local name = st.input:match("^%s*(.-)%s*$")
    if name == "" or name:find("[/\\%.]") or ulen(name) > 24 then
      setMsg(T.nameBad, C.err)
      return
    end
    if fs.exists(notePath(name)) then
      setMsg(T.nameExists, C.err)
      return
    end
    local hnd = fs.open(notePath(name), "w")
    if not hnd then
      setMsg(T.errPrefix .. name, C.err)
      return
    end
    fs.write(hnd, "")
    fs.close(hnd)
    openNote(name)
  end

  local function openSelected()
    local name = st.items[st.sel]
    if name then openNote(name) end
  end

  local function startDelete()
    local name = st.items[st.sel]
    if not name then return end
    st.mode = "confirm"
    setMsg(string.format(T.xNoteDel, name), C.warn)
  end

  local function doDelete()
    local name = st.items[st.sel]
    local keep = st.sel
    st.mode = "list"
    if name then
      local ok, result = pcall(fs.remove, notePath(name))
      if ok and result then
        reload()
        st.sel = keep
        keepVisible()
        setMsg(T.deleted, C.ok)
      else
        setMsg(T.errPrefix .. name, C.err)
      end
    end
  end

  local function cancelAsk()
    st.mode = "list"
    setMsg("", C.dim)
  end

  local function curButtons()
    if st.mode == "edit" then
      return makeButtons(ix, { { "save", T.xSave, C.ok }, { "back", T.bBack } })
    elseif st.mode == "prompt" then
      return makeButtons(ix, { { "ok", T.bOk }, { "cancel", T.bCancel } })
    elseif st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    end
    return makeButtons(ix, {
      { "new", T.xNewNote }, { "open", T.bOpen }, { "delete", T.bDelete, C.warn },
    })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local header = NOTES_DIR
    if st.mode == "edit" then header = st.current .. (ta.modified and " *" or "") end
    put(ix, self.y + 1, header, C.dim, C.panel, iw)
    drawButtons(curButtons(), btnY)

    if st.mode == "edit" then
      taDraw(ta, true)
    else
      if #st.items == 0 then put(ix, listY, T.xNoNotes, C.dim, C.panel, iw) end
      for n = 0, rows - 1 do
        local name = st.items[st.first + n]
        if name then
          local y = listY + n
          local isSel = (st.first + n == st.sel)
          local bg = isSel and C.accent or C.panel
          rect(ix - 1, y, iw + 2, 1, bg)
          put(ix, y, "  " .. name, isSel and C.bg or C.text, bg, iw)
        end
      end
    end

    if st.mode == "prompt" then
      rect(ix, statusY, iw, 1, C.barbg)
      put(ix + 1, statusY, T.xNoteAsk .. " " .. st.input .. "_", C.text, C.barbg, iw - 2)
      if st.msg ~= "" then put(ix, statusY - 1, st.msg, st.msgColor, C.panel, iw) end
    elseif st.msg ~= "" then
      put(ix, statusY, st.msg, st.msgColor, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "new" then
        startNew()
      elseif id == "open" then
        openSelected()
      elseif id == "delete" then
        startDelete()
      elseif id == "save" then
        saveNote()
      elseif id == "back" then
        backToList()
      elseif id == "ok" then
        submitNew()
      elseif id == "cancel" or id == "no" then
        cancelAsk()
      elseif id == "yes" then
        doDelete()
      else
        return false
      end
      return true
    end
    if st.mode == "edit" then return taClick(ta, x, y) end
    if st.mode == "list" and y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if st.items[idx] then
        local now = cp.uptime()
        if st.sel == idx and now - st.lastClick < 1.5 then
          openSelected()
        else
          st.sel = idx
          st.msg = ""
        end
        st.lastClick = now
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "prompt" then
      if code == 28 then
        submitNew()
      elseif code == 1 then
        cancelAsk()
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(st.input) < 24 then
        st.input = st.input .. uchar(char)
      end
      return true
    elseif st.mode == "confirm" then
      if code == 31 or code == 21 then
        doDelete()
      elseif code == 49 or code == 1 then
        cancelAsk()
      end
      return true
    elseif st.mode == "edit" then
      if code == 1 then
        backToList()
        return true
      elseif code == 60 then
        saveNote()
        return true
      end
      if st.msg ~= "" then setMsg("", C.dim) end
      return taKey(ta, char, code)
    end
    if code == 200 then
      st.sel = st.sel - 1
      keepVisible()
      return true
    elseif code == 208 then
      st.sel = st.sel + 1
      keepVisible()
      return true
    elseif code == 28 then
      openSelected()
      return true
    elseif code == 211 then
      startDelete()
      return true
    end
    return false
  end

  win.canClose = function(self)
    if st.mode == "edit" and ta.modified then saveNote() end
    return true
  end

  reload()
  return win
end

---------------------------------------------------------------- app Impressora 3D
  return notesApp(...)
end
