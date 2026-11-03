-- Antivirus do Nitro OS (nitro/sys/antivirus.lua): painel de seguranca sob demanda.
-- Le o texto dos arquivos e confere o sistema. Nunca executa nada do que analisa.
-- Recebe A (a API do Nitro OS) e cfg (usuario e senha, para o cartao Conta).
return function(A, cfg, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub = A.ulen, A.usub
  local makeButtons, drawButtons, hitButton = A.makeButtons, A.drawButtons, A.hitButton
  local C, T, fs, cp = A.C, A.T, A.fs, A.cp
  local readFile, fmtTime = A.readFile, A.fmtTime
  local avAnalyzeFile = A.avAnalyzeFile
  local netInfo, netTest, listInstalledApps = A.netInfo, A.netTest, A.listInstalledApps

  local LOG = "/nitro/antivirus.log"
  local SCAN_DIRS = { "/Download", "/apps", "/nitro/sys" }
  local MAX_FILES = 60

  local win = { title = T.mAntivirus }
  setWinGeom(win, 64, 18)
  local ix, iw = win.x + 2, win.w - 4
  local btnY, detY, msgY = win.y + 15, win.y + 13, win.y + 16

  local st = {
    detail = {}, first = 1, showLog = false,
    scan = nil, apps = nil, integ = nil, net = nil,
    msg = T.svNote, msgColor = C.dim,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function now()
    local ok, t = pcall(os.date, "%d/%m %H:%M")
    return ok and t or fmtTime(cp.uptime())
  end

  -- historico: guarda as ultimas 50 linhas em /nitro/antivirus.log
  local function logAdd(text)
    local lines = {}
    local old = readFile(LOG) or ""
    for line in old:gmatch("[^\n]+") do lines[#lines + 1] = line end
    lines[#lines + 1] = "[" .. now() .. "] " .. text
    while #lines > 50 do table.remove(lines, 1) end
    local hnd = fs.open(LOG, "w")
    if hnd then
      fs.write(hnd, table.concat(lines, "\n") .. "\n")
      fs.close(hnd)
    end
  end

  local function logView()
    local lines = {}
    for line in (readFile(LOG) or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
    if #lines == 0 then return { { text = T.svNoLog, color = C.dim } } end
    local out = {}
    for i = #lines, 1, -1 do out[#out + 1] = { text = lines[i], color = C.text } end
    return out
  end

  -- lista os .lua de uma pasta (e de subpastas de 1 nivel, como ScadaApp.APP/app.lua)
  local function luaFilesIn(dir, out)
    local ok, names = pcall(fs.list, dir)
    if not ok or type(names) ~= "table" then return end
    for _, n in ipairs(names) do
      if #out >= MAX_FILES then return end
      if n:sub(-1) == "/" then
        local sub = dir .. "/" .. n:sub(1, -2)
        local ok2, inner = pcall(fs.list, sub)
        if ok2 and type(inner) == "table" then
          for _, m in ipairs(inner) do
            if #out < MAX_FILES and m:sub(-4) == ".lua" then out[#out + 1] = sub .. "/" .. m end
          end
        end
      elseif n:sub(-4) == ".lua" then
        out[#out + 1] = dir .. "/" .. n
      end
    end
  end

  local function scanFiles(paths)
    local rep = { files = 0, bad = 0, sus = 0, rows = {} }
    for _, p in ipairs(paths) do
      rep.files = rep.files + 1
      local r = avAnalyzeFile(p)
      if not r then
        rep.rows[#rep.rows + 1] = { text = "[ERRO] " .. p, color = C.dim, pri = 0 }
      elseif r.verdict == "danger" then
        rep.bad = rep.bad + 1
        rep.rows[#rep.rows + 1] = { text = "[PERIGOSO] " .. p .. " (" .. r.score .. "/100)", color = C.err, pri = 2 }
      elseif r.verdict == "warn" then
        rep.sus = rep.sus + 1
        rep.rows[#rep.rows + 1] = { text = "[SUSPEITO] " .. p .. " (" .. r.score .. "/100)", color = C.warn, pri = 1 }
      end
    end
    table.sort(rep.rows, function(a, b) return a.pri > b.pri end)
    return rep
  end

  local function showReport(title, rep)
    st.detail, st.first, st.showLog = {}, 1, false
    if #rep.rows == 0 then
      st.detail[1] = { text = string.format(T.svScanned, rep.files) .. " - " .. T.svNoAction, color = C.ok }
    else
      for _, r in ipairs(rep.rows) do st.detail[#st.detail + 1] = r end
    end
    logAdd(title .. ": " .. rep.files .. " arquivo(s), " .. rep.bad .. " perigoso(s), " .. rep.sus .. " suspeito(s)")
    local color = C.ok
    if rep.bad > 0 then color = C.err elseif rep.sus > 0 then color = C.warn end
    setMsg(T.svDone, color)
  end

  local function scanFolders()
    local paths = {}
    for _, d in ipairs(SCAN_DIRS) do luaFilesIn(d, paths) end
    local rep = scanFiles(paths)
    st.scan = { files = rep.files, bad = rep.bad, sus = rep.sus }
    showReport("Scan de pastas", rep)
  end

  local function scanApps()
    local paths = {}
    for _, app in ipairs(listInstalledApps()) do paths[#paths + 1] = app.path end
    local rep = scanFiles(paths)
    st.apps = { count = #paths, bad = rep.bad, sus = rep.sus }
    showReport("Scan de apps", rep)
  end

  local function checkSystem()
    local bad, total = {}, 0
    local function test(path)
      total = total + 1
      local data = readFile(path)
      if not data or #data == 0 then
        bad[#bad + 1] = path .. " (vazio)"
      elseif not load(data, "=" .. path) then
        bad[#bad + 1] = path .. " (erro de codigo)"
      end
    end
    test("/nitro/boot.lua")
    local paths = {}
    luaFilesIn("/nitro/sys", paths)
    for _, p in ipairs(paths) do test(p) end
    st.integ = { total = total, bad = #bad }
    st.detail, st.first, st.showLog = {}, 1, false
    if #bad == 0 then
      st.detail[1] = { text = string.format(T.svScanned, total) .. " - " .. T.svIntOk, color = C.ok }
    else
      for _, b in ipairs(bad) do st.detail[#st.detail + 1] = { text = "[PROBLEMA] " .. b, color = C.err } end
    end
    logAdd("Verificacao do sistema: " .. total .. " arquivo(s), " .. #bad .. " problema(s)")
    if #bad == 0 then setMsg(T.svIntOk, C.ok) else setMsg(string.format(T.svIntBad, #bad), C.err) end
  end

  local function checkNet()
    local info = netInfo()
    st.net = info.state
    local ok, msg = netTest()
    st.detail, st.first, st.showLog = {}, 1, false
    if ok then
      st.detail[1] = { text = T.svNetOk .. " (" .. msg .. ")", color = C.ok }
      setMsg(T.svNetOk, C.ok)
    else
      st.detail[1] = { text = tostring(msg), color = C.err }
      setMsg(tostring(msg), C.err)
    end
    logAdd("Teste de rede: " .. (ok and "ok" or tostring(msg)))
  end

  local function cards()
    local list = {}

    local sc = st.scan
    local vStatus, vColor, vDetail = T.svNoScan, C.dim, T.svBtnFolders
    if sc then
      vDetail = string.format(T.svScanned, sc.files)
      if sc.bad > 0 then
        vStatus, vColor = string.format(T.svThreat, sc.bad), C.err
      elseif sc.sus > 0 then
        vStatus, vColor = string.format(T.svSusp, sc.sus), C.warn
      else
        vStatus, vColor = T.svNoAction, C.ok
      end
    end
    list[#list + 1] = { id = "folders", title = T.svVirusT, status = vStatus, color = vColor, detail = vDetail }

    local hasPass = cfg and cfg.hash
    list[#list + 1] = {
      id = "acc", title = T.svAccT,
      status = hasPass and T.svPassOn or T.svPassOff,
      color = hasPass and C.ok or C.warn,
      detail = (cfg and cfg.user) or "",
    }

    local ni = st.net or netInfo().state
    local nStatus, nColor = T.svNetWarn, C.warn
    if ni == "ok" then
      nStatus, nColor = T.svNetOk, C.ok
    elseif ni == "none" then
      nStatus, nColor = T.svNetNone, C.err
    end
    list[#list + 1] = { id = "net", title = T.svNetT, status = nStatus, color = nColor, detail = T.svTestNet }

    local ap = st.apps
    if not ap then
      list[#list + 1] = { id = "apps", title = T.svAppsT, status = T.svNoScan, color = C.dim,
        detail = string.format(T.svAppsCount, #listInstalledApps()) }
    elseif ap.bad > 0 or ap.sus > 0 then
      list[#list + 1] = { id = "apps", title = T.svAppsT, status = string.format(T.svAppsBad, ap.bad + ap.sus),
        color = (ap.bad > 0) and C.err or C.warn, detail = string.format(T.svAppsCount, ap.count) }
    else
      list[#list + 1] = { id = "apps", title = T.svAppsT, status = T.svNoAction, color = C.ok,
        detail = string.format(T.svAppsCount, ap.count) }
    end

    local ig = st.integ
    if not ig then
      list[#list + 1] = { id = "integ", title = T.svIntT, status = T.svIntNone, color = C.dim, detail = T.svBtnCheck }
    elseif ig.bad > 0 then
      list[#list + 1] = { id = "integ", title = T.svIntT, status = string.format(T.svIntBad, ig.bad),
        color = C.err, detail = string.format(T.svScanned, ig.total) }
    else
      list[#list + 1] = { id = "integ", title = T.svIntT, status = T.svIntOk, color = C.ok,
        detail = string.format(T.svScanned, ig.total) }
    end

    local total, free = cp.totalMemory(), cp.freeMemory()
    local pct = math.floor(free * 100 / total)
    list[#list + 1] = { id = "perf", title = T.svPerfT,
      status = string.format(T.svRam, math.floor(free / 1024)),
      color = (pct < 15 and C.err) or (pct < 30 and C.warn) or C.ok,
      detail = pct .. "%" }
    return list
  end

  local function cardRect(i)
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    return ix + col * 20, (row == 0) and (win.y + 3) or (win.y + 8)
  end

  local function runCard(id)
    if id == "folders" then scanFolders()
    elseif id == "apps" then scanApps()
    elseif id == "integ" then checkSystem()
    elseif id == "net" then checkNet()
    elseif id == "acc" then setMsg(T.svNote, C.dim)
    elseif id == "perf" then setMsg(T.svNote, C.dim)
    end
  end

  local function buttons()
    return makeButtons(ix, {
      { "folders", T.svBtnFolders, C.ok }, { "apps", T.svBtnApps },
      { "check", T.svBtnCheck }, { "hist", T.svBtnHist },
    })
  end

  local function shownLines()
    if st.showLog then return logView() end
    return st.detail
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.svTitle, C.accent, C.panel, iw)

    for i, card in ipairs(cards()) do
      local x, y = cardRect(i)
      rect(x, y, 19, 4, C.bg)
      put(x + 1, y, card.title, C.text, C.bg, 17)
      put(x + 1, y + 1, card.status, card.color, C.bg, 17)
      put(x + 1, y + 2, card.detail, C.dim, C.bg, 17)
    end

    local lines = shownLines()
    for n = 0, 1 do
      local e = lines[st.first + n]
      if e then put(ix, detY + n, e.text, e.color or C.text, C.panel, iw) end
    end

    drawButtons(buttons(), btnY)
    put(ix, msgY, st.msg, st.msgColor, C.panel, iw)
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(buttons(), x)
      if id == "folders" then scanFolders()
      elseif id == "apps" then scanApps()
      elseif id == "check" then checkSystem()
      elseif id == "hist" then
        st.showLog = not st.showLog
        st.first = 1
      else
        return false
      end
      return true
    end
    for i, card in ipairs(cards()) do
      local cx, cy = cardRect(i)
      if x >= cx and x < cx + 19 and y >= cy and y < cy + 4 then
        runCard(card.id)
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    local lines = shownLines()
    if code == 200 then
      st.first = math.max(1, st.first - 1)
      return true
    elseif code == 208 then
      st.first = math.min(math.max(1, #lines - 1), st.first + 1)
      return true
    elseif code == 28 then
      scanFolders()
      return true
    end
    return false
  end

  return win
end
