-- Trocar fundo (nitro/sys/fundo.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local WALL_DIR = A.WALL_DIR
  local fs = A.fs
  local loadWallFile = A.loadWallFile
  local put = A.put
  local rect = A.rect
  local saveConfig = A.saveConfig
  local setWinGeom = A.setWinGeom
local function wallpaperApp(cfg, shared)
  local win = { title = T.wTitle }
  setWinGeom(win, 52, 14)
  local ix, iw = win.x + 2, win.w - 4
  local listY = win.y + 3
  local rows = win.h - 7
  local statusY = win.y + win.h - 3
  local options = {
    { id = "default", label = T.wDefault },
    { id = "none", label = T.wNone },
  }
  local okList, names = pcall(fs.list, WALL_DIR)
  if okList and type(names) == "table" then
    table.sort(names)
    for _, n in ipairs(names) do
      if n:sub(-4) == ".lua" then
        local name = n:sub(1, -5)
        local data = loadWallFile(name)
        if data then
          local kind = data.frames and T.wVideo or T.wImage
          options[#options + 1] = { id = "file:" .. name, label = kind .. ": " .. tostring(data.name or name) }
        end
      end
    end
  end

  local st = { sel = 1, first = 1, msg = "" }
  local current = cfg.wallpaper or "default"
  for i, o in ipairs(options) do
    if o.id == current then st.sel = i end
  end

  local function keepVisible()
    if st.sel < st.first then st.first = st.sel end
    if st.sel >= st.first + rows then st.first = st.sel - rows + 1 end
  end
  keepVisible()

  local function apply()
    local o = options[st.sel]
    if not o then return end
    cfg.wallpaper = o.id
    saveConfig(cfg)
    if shared.applyWallpaper then shared.applyWallpaper(o.id) end
    shared.refresh = true
    st.msg = T.wApplied
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, WALL_DIR, C.dim, C.panel, iw)
    for n = 0, rows - 1 do
      local o = options[st.first + n]
      if o then
        local y = listY + n
        local isSel = (st.first + n == st.sel)
        local isCur = (o.id == (cfg.wallpaper or "default"))
        local bg = isSel and C.accent or C.panel
        rect(ix - 1, y, iw + 2, 1, bg)
        put(ix, y, (isCur and "● " or "  ") .. o.label, isSel and C.bg or C.text, bg, iw)
      end
    end
    if st.msg ~= "" then
      put(ix, statusY, st.msg, C.ok, C.panel, iw)
    else
      put(ix, statusY, T.wHint, C.dim, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y >= listY and y < listY + rows then
      local idx = st.first + (y - listY)
      if options[idx] then
        st.sel = idx
        apply()
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 200 and st.sel > 1 then
      st.sel = st.sel - 1
      keepVisible()
      st.msg = ""
      return true
    elseif code == 208 and st.sel < #options then
      st.sel = st.sel + 1
      keepVisible()
      st.msg = ""
      return true
    elseif code == 28 then
      apply()
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- Antivirus (le o texto, nunca executa)
  return wallpaperApp(...)
end
