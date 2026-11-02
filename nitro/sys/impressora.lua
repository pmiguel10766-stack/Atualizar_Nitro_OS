-- Impressora 3D (nitro/sys/impressora.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local cl = A.cl
  local key = A.key
  local put = A.put
  local rect = A.rect
  local setWinGeom = A.setWinGeom
  local ulen = A.ulen
local PRINT_MODELS = {
  { key = "pCube", boxes = { { 0, 0, 0, 16, 16, 16 } } },
  { key = "pPillar", boxes = { { 5, 0, 5, 11, 16, 11 } } },
  { key = "pSlab", boxes = { { 0, 0, 0, 16, 4, 16 } } },
  { key = "pStairs", boxes = { { 0, 0, 0, 16, 8, 16 }, { 0, 8, 8, 16, 16, 16 } } },
}
local PRINT_TEXTURES = {
  { key = "pStone", name = "stone" },
  { key = "pCobble", name = "cobblestone" },
  { key = "pWood", name = "planks_oak" },
  { key = "pIron", name = "iron_block" },
}

local function printerApp()
  local win = { title = T.mPrinter, live = true }
  setWinGeom(win, 52, 14)
  local ix, iw = win.x + 2, win.w - 4
  local st = { model = 1, tex = 1, qty = 1, msg = "", msgColor = C.warn }
  local OPT_X = ix + 9

  local function getPrinter()
    local addr = cl.list("printer3d")()
    return addr and cl.proxy(addr) or nil
  end

  local function printerState(p)
    local ok, status, progress = pcall(p.status)
    if not ok then return "idle", 0 end
    local prog = tonumber(progress) or 0
    if prog > 1 then prog = prog / 100 end
    if prog < 0 then prog = 0 end
    return status, prog
  end

  local function rowRects(list)
    local out, x = {}, OPT_X
    for i, item in ipairs(list) do
      local text = " " .. T[item.key] .. " "
      out[#out + 1] = { idx = i, x = x, text = text }
      x = x + ulen(text) + 1
    end
    return out
  end

  local function drawRow(y, label, list, selected)
    put(ix, y, label .. ":", C.dim, C.panel)
    for _, r in ipairs(rowRects(list)) do
      if r.idx == selected then
        put(r.x, y, r.text, C.bg, C.accent)
      else
        put(r.x, y, r.text, C.text, 0x333333)
      end
    end
  end

  local function printLabel() return " " .. T.pPrint .. " " end

  local function doPrint()
    local p = getPrinter()
    if not p then return end
    local model, tex = PRINT_MODELS[st.model], PRINT_TEXTURES[st.tex]
    local ok, err = pcall(function()
      p.reset()
      p.setLabel(T[model.key])
      for _, b in ipairs(model.boxes) do
        local added, reason = p.addShape(b[1], b[2], b[3], b[4], b[5], b[6], tex.name)
        if not added then error(tostring(reason or "addShape"), 0) end
      end
      local started, reason = p.commit(st.qty)
      if not started then error(tostring(reason or "commit"), 0) end
    end)
    if ok then
      st.msg, st.msgColor = T.pStarted, C.ok
    else
      st.msg, st.msgColor = string.format(T.pFail, tostring(err)), C.err
    end
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local p = getPrinter()
    if not p then
      put(ix, self.y + 3, T.pNone, C.err, C.panel, iw)
      put(ix, self.y + 5, T.pHint, C.dim, C.panel, iw)
      return
    end
    local status, prog = printerState(p)
    local busy = (status == "busy")
    local stateText = busy and string.format("%s %d%%", T.pBusy, math.floor(prog * 100)) or T.pIdle
    put(ix, self.y + 2, T.pState .. ": " .. stateText, busy and C.warn or C.ok, C.panel, iw)
    rect(ix, self.y + 3, iw, 1, C.barbg)
    if busy then rect(ix, self.y + 3, math.floor(iw * prog), 1, C.accent) end

    drawRow(self.y + 5, T.pModel, PRINT_MODELS, st.model)
    drawRow(self.y + 6, T.pTex, PRINT_TEXTURES, st.tex)
    put(ix, self.y + 7, T.pQty .. ":", C.dim, C.panel)
    put(OPT_X, self.y + 7, " - ", C.bg, C.accent)
    put(OPT_X + 4, self.y + 7, string.format("%2d", st.qty), C.text, C.panel)
    put(OPT_X + 8, self.y + 7, " + ", C.bg, C.accent)

    put(ix, self.y + 9, printLabel(), C.bg, C.ok)
    if st.msg ~= "" then put(ix, self.y + 10, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if not getPrinter() then return false end
    if y == self.y + 5 then
      for _, r in ipairs(rowRects(PRINT_MODELS)) do
        if x >= r.x and x < r.x + ulen(r.text) then
          st.model = r.idx
          return true
        end
      end
    elseif y == self.y + 6 then
      for _, r in ipairs(rowRects(PRINT_TEXTURES)) do
        if x >= r.x and x < r.x + ulen(r.text) then
          st.tex = r.idx
          return true
        end
      end
    elseif y == self.y + 7 then
      if x >= OPT_X and x < OPT_X + 3 then
        st.qty = math.max(1, st.qty - 1)
        return true
      elseif x >= OPT_X + 8 and x < OPT_X + 11 then
        st.qty = math.min(16, st.qty + 1)
        return true
      end
    elseif y == self.y + 9 and x >= ix and x < ix + ulen(printLabel()) then
      doPrint()
      return true
    end
    return false
  end

  win.onKey = function(self, char, code)
    if not getPrinter() then return false end
    if code == 28 then
      doPrint()
      return true
    elseif char == 43 or char == 61 then
      st.qty = math.min(16, st.qty + 1)
      return true
    elseif char == 45 then
      st.qty = math.max(1, st.qty - 1)
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- app Configuracoes
  return printerApp(...)
end
