-- Rede / Wi-Fi (nitro/sys/rede.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local h = A.h
  local netInfo = A.netInfo
  local netTest = A.netTest
  local put = A.put
  local rect = A.rect
  local ulen = A.ulen
  local w = A.w
local function wifiApp()
  local win = { title = T.wifi, w = 40, h = 10 }
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)

  local ix, iw = win.x + 2, win.w - 4
  local testY, rangeY = win.y + 6, win.y + 8
  local result, resultColor = "", C.dim

  local function testLabel() return " " .. T.wifiTest .. " " end

  local function strength(info)
    local okS, cur = pcall(info.modem.getStrength)
    return (okS and tonumber(cur)) or 0
  end

  local function adjust(info, delta)
    local new = math.max(0, math.min(400, strength(info) + delta))
    pcall(info.modem.setStrength, new)
  end

  local function doTest()
    result, resultColor = T.wifiTesting, C.dim
    win.body(win)
    local ok, msg = netTest()
    if ok then
      result, resultColor = string.format(T.wifiTestOk, msg), C.ok
    else
      result, resultColor = string.format(T.wifiTestFail, msg), C.err
    end
  end

  win.body = function(self)
    local info = netInfo()
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)

    -- tipo(s) de placa
    put(ix, self.y + 2, T.wifiType .. ":", C.dim, C.panel)
    if #info.types == 0 then
      put(ix + 9, self.y + 2, "-", C.text, C.panel)
    end
    for i, name in ipairs(info.types) do
      put(ix + 9, self.y + 1 + i, name, C.text, C.panel, iw - 9)
    end

    -- status
    local text, color = T.wifiNone, C.err
    if info.state == "ok" then
      text, color = T.wifiOk, C.ok
    elseif info.state == "warn" then
      text, color = T.wifiWarn, C.warn
    elseif info.state == "wireless" then
      text, color = T.wifiWireless, C.ok
    elseif info.state == "wired" then
      text, color = T.wifiWired, C.warn
    end
    put(ix, self.y + 4, T.wifiStatus .. ":", C.dim, C.panel)
    put(ix + 9, self.y + 4, text, color, C.panel, iw - 9)

    -- resultado do teste e botao
    if result ~= "" then put(ix, self.y + 5, result, resultColor, C.panel, iw) end
    local label = testLabel()
    rect(ix, testY, ulen(label), 1, C.accent)
    put(ix, testY, label, C.bg, C.accent)

    -- alcance do sinal (so Wireless Network Card)
    if info.wireless then
      local cur = strength(info)
      put(ix, rangeY - 1, T.wifiRange .. ": " .. cur .. "/400", C.dim, C.panel, iw)
      local bx, bw = ix + 4, iw - 13
      put(ix, rangeY, "[-]", C.bg, C.accent)
      rect(bx, rangeY, bw, 1, C.barbg)
      rect(bx, rangeY, math.floor(bw * cur / 400), 1, C.accent)
      put(bx + bw + 1, rangeY, "[+]", C.bg, C.accent)
    end
  end

  win.onTouch = function(self, x, y)
    if y == testY and x >= ix and x < ix + ulen(testLabel()) then
      doTest()
      return true
    end
    local info = netInfo()
    if info.wireless and y == rangeY then
      if x >= ix and x < ix + 3 then
        adjust(info, -50)
        return true
      elseif x >= ix + iw - 12 and x < ix + iw - 9 then
        adjust(info, 50)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if code == 28 then
      doTest()
      return true
    end
    local info = netInfo()
    if info.wireless and (char == 43 or char == 61) then
      adjust(info, 50)
      return true
    elseif info.wireless and char == 45 then
      adjust(info, -50)
      return true
    end
    return false
  end

  return win
end

---------------------------------------------------------------- barra de tarefas e menu
  return wifiApp(...)
end
