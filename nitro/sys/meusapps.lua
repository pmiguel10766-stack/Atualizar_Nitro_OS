-- Meus Apps (nitro/sys/meusapps.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local cp = A.cp
  local drawButtons = A.drawButtons
  local fmtSize = A.fmtSize
  local fs = A.fs
  local hitButton = A.hitButton
  local listInstalledApps = A.listInstalledApps
  local makeButtons = A.makeButtons
  local put = A.put
  local rect = A.rect
  local setWinGeom = A.setWinGeom
  local ulen = A.ulen
local function myAppsApp(shared)
  local win = { title = T.mMyApps }
  setWinGeom(win, 60, 16)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, listY = win.y + 2, win.y + 4
  local rows = win.h - 9
  local statusY = win.y + win.h - 3
  local st = {
    apps = {}, sel = 1, first = 1, mode = "list",
    msg = "", msgColor = C.dim, lastClick = 0,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function keepVisible()
    if st.sel > #st.apps then st.sel = #st.apps end
    if st.sel < 1 then st.sel = 1 end
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end

  local function reload()
    st.apps = listInstalledApps()
    st.sel, st.first = 1, 1
  end

  local function openSelected()
    local app = st.apps[st.sel]
    if app then shared.open = "app:" .. app.path end
  end

  local function startDelete()
    local app = st.apps[st.sel]
    if not app then return end
    st.mode = "confirm"
    setMsg(string.format(T.maDelAsk, app.name), C.warn)
  end

  local function doDelete()
    local app = st.apps[st.sel]
    local keep = st.sel
    st.mode = "list"
    if not app then return end
    local ok, result = pcall(fs.remove, app.rm)
    if ok and result then
      reload()
      st.sel = keep
      keepVisible()
      shared.refresh = true
      setMsg(T.deleted, C.ok)
    else
      setMsg(T.errPrefix .. app.name, C.err)
    end
  end

  local function cancelAsk()
    st.mode = "list"
    setMsg("", C.dim)
  end

  local function curButtons()
    if st.mode == "confirm" then
      return makeButtons(ix, { { "yes", T.bYes, C.warn }, { "no", T.bNo } })
    end
    return makeButtons(ix, {
      { "open", T.bOpen, C.ok }, { "folder", T.gOpenFolder }, { "del", T.bDelete, C.warn },
      { "refresh", T.stRefresh },
    })
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.maTitle, C.accent, C.panel, iw)
    drawButtons(curButtons(), btnY)
    if #st.apps == 0 then
      put(ix, listY, T.maEmpty, C.dim, C.panel, iw)
      put(ix, listY + 1, T.maHint, C.dim, C.panel, iw)
    end
    for n = 0, rows - 1 do
      local app = st.apps[st.first + n]
      if app then
        local y = listY + n
        local isSel = (st.first + n == st.sel)
        local bg = isSel and C.accent or C.panel
        rect(ix - 1, y, iw + 2, 1, bg)
        local size = fmtSize(app.size)
        put(ix, y, "  " .. app.name, isSel and C.bg or C.text, bg, iw - ulen(size) - 1)
        put(ix + iw - ulen(size), y, size, isSel and C.bg or C.dim, bg)
      end
    end
    local sel = st.apps[st.sel]
    if sel and st.mode == "list" and sel.desc ~= "" then
      put(ix, statusY - 1, sel.desc, C.dim, C.panel, iw)
    end
    if st.msg ~= "" then put(ix, statusY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "open" then
        openSelected()
      elseif id == "folder" then
        shared.open = "files"
        shared.openArg = "/apps"
      elseif id == "del" then
        startDelete()
      elseif id == "refresh" then
        reload()
        shared.refresh = true
        setMsg(string.format(T.stRefreshed, #st.apps), C.ok)
      elseif id == "yes" then
        doDelete()
      elseif id == "no" then
        cancelAsk()
      else
        return false
      end
      return true
    end
    if st.mode == "list" and y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if st.apps[idx] then
        local now = cp.uptime()
        if st.sel == idx and now - st.lastClick < 1.5 then
          openSelected()
        else
          st.sel = idx
          setMsg("", C.dim)
        end
        st.lastClick = now
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
        cancelAsk()
      end
      return true
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

  reload()
  return win
end

---------------------------------------------------------------- apps do sistema em /nitro/sys (carregados so ao abrir)
  return myAppsApp(...)
end
