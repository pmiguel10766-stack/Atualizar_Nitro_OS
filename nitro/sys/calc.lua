-- Calculadora (nitro/sys/calc.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local cp = A.cp
  local h = A.h
  local put = A.put
  local rect = A.rect
  local ulen = A.ulen
  local w = A.w
local CALC_LAYOUT = {
  { { "C", "C" }, { "←", "BS" }, { "%", "%" }, { "÷", "/" } },
  { { "7", "7" }, { "8", "8" }, { "9", "9" }, { "×", "*" } },
  { { "4", "4" }, { "5", "5" }, { "6", "6" }, { "−", "-" } },
  { { "1", "1" }, { "2", "2" }, { "3", "3" }, { "+", "+" } },
  { { "0", "0", 2 }, { ".", "." }, { "=", "=" } },
}
local OPSYM = { ["+"] = "+", ["-"] = "−", ["*"] = "×", ["/"] = "÷" }

local function calcFmt(n)
  if n ~= n or n == math.huge or n == -math.huge then return nil end
  return string.format("%.10g", n)
end

local function calcApply(a, b, o)
  if o == "+" then
    return a + b
  elseif o == "-" then
    return a - b
  elseif o == "*" then
    return a * b
  elseif o == "/" then
    if b == 0 then return nil end
    return a / b
  end
  return nil
end

local function calcApp()
  local win = { title = T.mCalc, w = 34, h = 11 }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)

  local BW, GAP = 6, 1
  local gridW = 4 * BW + 3 * GAP

  local cur, prev, op, expr = "0", nil, nil, ""
  local fresh, isErr = true, false

  local function clearAll()
    cur, prev, op, expr = "0", nil, nil, ""
    fresh, isErr = true, false
  end

  local function setError()
    cur, prev, op, expr = T.calcErr, nil, nil, ""
    fresh, isErr = true, true
  end

  local function digit(d)
    if isErr then clearAll() end
    if fresh then
      cur = "0"
      fresh = false
    end
    if cur == "0" then
      cur = d
    elseif #cur < 12 then
      cur = cur .. d
    end
  end

  local function dot()
    if isErr then clearAll() end
    if fresh then
      cur = "0"
      fresh = false
    end
    if not cur:find(".", 1, true) and #cur < 12 then cur = cur .. "." end
  end

  local function backspace()
    if fresh or isErr then return end
    cur = cur:sub(1, -2)
    if cur == "" or cur == "-" then cur = "0" end
  end

  local function percent()
    if isErr then return end
    local v = tonumber(cur)
    if v then
      cur = calcFmt(v / 100) or cur
      fresh = true
    end
  end

  local function operator(o)
    if isErr then return end
    local val = tonumber(cur) or 0
    if op and not fresh then
      local r = calcApply(prev, val, op)
      if r == nil or not calcFmt(r) then
        setError()
        return
      end
      prev = r
      cur = calcFmt(r)
    else
      prev = val
    end
    op = o
    fresh = true
    expr = calcFmt(prev) .. " " .. OPSYM[o]
  end

  local function equals()
    if isErr or not op then return end
    local val = tonumber(cur) or 0
    local r = calcApply(prev, val, op)
    if r == nil or not calcFmt(r) then
      setError()
      return
    end
    expr = calcFmt(prev) .. " " .. OPSYM[op] .. " " .. calcFmt(val) .. " ="
    cur = calcFmt(r)
    prev, op, fresh = nil, nil, true
  end

  local function press(id)
    if id:match("^%d$") then digit(id)
    elseif id == "." then dot()
    elseif id == "C" then clearAll()
    elseif id == "BS" then backspace()
    elseif id == "%" then percent()
    elseif id == "=" then equals()
    else operator(id) end
  end

  local function rects(self)
    local out = {}
    local gx = self.x + math.floor((self.w - gridW) / 2)
    for r, row in ipairs(CALC_LAYOUT) do
      local c = 0
      for _, b in ipairs(row) do
        local span = b[3] or 1
        out[#out + 1] = {
          label = b[1], id = b[2],
          x = gx + c * (BW + GAP), y = self.y + 3 + r,
          w = span * BW + (span - 1) * GAP,
        }
        c = c + span
      end
    end
    return out
  end

  local function colors(id)
    if id:match("^%d$") or id == "." then return 0x333333, C.text end
    if id == "=" then return C.ok, C.bg end
    if id == "C" then return C.warn, C.bg end
    if id == "BS" or id == "%" then return 0x555555, C.text end
    return C.accent, C.bg
  end

  local function drawButton(b, bg, fg)
    rect(b.x, b.y, b.w, 1, bg)
    put(b.x + math.floor((b.w - ulen(b.label)) / 2), b.y, b.label, fg, bg)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    local ix, iw = self.x + 2, self.w - 4
    put(ix + iw - ulen(expr), self.y + 1, expr, C.dim, C.panel, iw)
    rect(ix, self.y + 2, iw, 1, C.barbg)
    put(ix + iw - 1 - ulen(cur), self.y + 2, cur, isErr and C.err or C.text, C.barbg, iw - 1)
    for _, b in ipairs(rects(self)) do
      local bg, fg = colors(b.id)
      drawButton(b, bg, fg)
    end
  end

  win.onTouch = function(self, x, y)
    for _, b in ipairs(rects(self)) do
      if y == b.y and x >= b.x and x < b.x + b.w then
        drawButton(b, C.text, C.bg)
        cp.pullSignal(0.1)
        press(b.id)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 28 or code == 156 then
      press("=")
      return true
    elseif code == 14 then
      press("BS")
      return true
    end
    if char and char >= 32 and char < 127 then
      local ch = string.char(char)
      if ch:match("%d") then
        press(ch)
        return true
      elseif ch == "." or ch == "," then
        press(".")
        return true
      elseif ch == "+" or ch == "-" or ch == "*" or ch == "/" then
        press(ch)
        return true
      elseif ch == "=" or ch == "%" then
        press(ch)
        return true
      elseif ch == "c" or ch == "C" then
        press("C")
        return true
      end
    end
    return false
  end

  return win
end

---------------------------------------------------------------- apoio para os novos apps
  return calcApp(...)
end
