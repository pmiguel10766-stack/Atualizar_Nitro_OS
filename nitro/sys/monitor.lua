-- Monitor do Sistema (nitro/sys/monitor.lua)
-- Carregado pelo sistema quando o app e aberto. Recebe A (a API do Nitro OS).
return function(A, ...)
  local T = A.T
  local C = A.C
  local cp = A.cp
  local fmtTime = A.fmtTime
  local put = A.put
  local rect = A.rect
  local ulen = A.ulen
local function monitorBody(win)
  local x, bw = win.x + 3, win.w - 6

  local function row(y, label, value, pct, color)
    rect(x, y, bw, 1, C.panel)
    put(x, y, label, C.text, C.panel, bw - ulen(value) - 1)
    put(x + bw - ulen(value), y, value, C.dim, C.panel)
    rect(x, y + 1, bw, 1, C.barbg)
    rect(x, y + 1, math.floor(bw * pct / 100), 1, color)
  end

  local total, free = cp.totalMemory(), cp.freeMemory()
  local usedPct = math.floor((total - free) * 100 / total)
  row(win.y + 2, T.ram,
    string.format("%d/%d KB", math.floor((total - free) / 1024), math.floor(total / 1024)),
    usedPct, usedPct > 85 and C.err or C.accent)

  local e, me = cp.energy(), cp.maxEnergy()
  local epct = (me == math.huge or me <= 0) and 100 or math.floor(e * 100 / me)
  row(win.y + 5, T.energy, epct .. "%", epct, epct < 20 and C.err or C.ok)

  rect(x, win.y + 8, bw, 1, C.panel)
  put(x, win.y + 8, T.uptime .. ": " .. fmtTime(cp.uptime()), C.text, C.panel, bw)
end

---------------------------------------------------------------- app Arquivos
  return A.newWindow(A.T.mMonitor, monitorBody, true)
end
