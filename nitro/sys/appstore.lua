-- AppStore do Nitro OS (nitro/sys/appstore.lua): loja com abas, categorias e cartoes.
-- Baixa o indice do GitHub, analisa cada app com o Antivirus antes de instalar.
-- Recebe A (a API do Nitro OS) e shared (estado do desktop).
return function(A, shared, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub = A.ulen, A.usub
  local makeButtons, drawButtons, hitButton = A.makeButtons, A.drawButtons, A.hitButton
  local C, T, fs = A.C, A.T, A.fs
  local httpGet, avScan, readFile = A.httpGet, A.avScan, A.readFile

  local STORE_BASE = "https://raw.githubusercontent.com/pmiguel10766-stack/nitro-appstore/main/app/"
  local STORE_INDEX = "apps.lua"
  local APPS_DIR = "/apps"
  local CATS = { "all", "jogos", "ferramentas", "sistema", "educacao" }
  local CAT_KEY = {
    all = "asCatAll", jogos = "asCatGames", ferramentas = "asCatTools",
    sistema = "asCatSystem", educacao = "asCatEdu",
  }
  local TABS = {
    { id = "home", key = "asTabHome" }, { id = "apps", key = "asTabApps" },
    { id = "update", key = "asTabUpdate" }, { id = "remove", key = "asTabRemove" },
  }
  local PER_PAGE = 6

  local win = { title = T.mStore }
  setWinGeom(win, 74, 22)
  local ix, iw = win.x + 2, win.w - 4
  local tabY = win.y + 1
  local searchW = 22
  local searchX = ix + iw - searchW
  local catX, catW = ix, 14
  local gridX = ix + 16
  local gridW = iw - 16
  local colW = math.floor((gridW - 2) / 2)
  local gridTop = win.y + 3
  local msgY, footY = win.y + 19, win.y + 20

  local st = {
    tab = "home", cat = 1, search = "", searching = false, page = 1,
    index = nil, msg = "", msgColor = C.dim, confirm = nil,
  }
  local tabBoxes = {}

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function verPath(file)
    return APPS_DIR .. "/" .. file .. ".ver"
  end

  -- nil = nao instalado; "?" = instalado sem versao registrada
  local function installedVer(file)
    if not fs.exists(APPS_DIR .. "/" .. file) then return nil end
    local data = readFile(verPath(file)) or ""
    local v = data:match("^%s*(.-)%s*$")
    if v == "" then return "?" end
    return v
  end

  local function stateOf(a)
    local iv = installedVer(a.file)
    if not iv then return "install" end
    if a.ver and iv ~= a.ver then return "update" end
    return "ok"
  end

  local function parseIndex(data)
    local f = load(data, "=apps", "t", {})
    if not f then return nil end
    local ok, list = pcall(f)
    if not ok or type(list) ~= "table" then return nil end
    local out = {}
    for _, a in ipairs(list) do
      if type(a) == "table" and type(a.name) == "string" and type(a.file) == "string"
          and a.file:match("^[%w_%-]+%.lua$") and #out < 80 then
        local cat = tostring(a.cat or "ferramentas")
        local known = false
        for _, c in ipairs(CATS) do
          if c == cat and c ~= "all" then known = true end
        end
        out[#out + 1] = {
          name = a.name, file = a.file, desc = tostring(a.desc or ""),
          cat = known and cat or "ferramentas",
          ver = a.ver and tostring(a.ver) or nil,
        }
      end
    end
    if #out == 0 then return nil end
    return out
  end

  local function loadIndex()
    local data, err = httpGet(STORE_BASE .. STORE_INDEX, 15)
    if not data then
      st.index = nil
      setMsg(string.format(T.stFail, tostring(err)), C.err)
      return
    end
    local list = parseIndex(data)
    if not list then
      st.index = nil
      setMsg(T.stBad, C.err)
      return
    end
    st.index = list
    setMsg(T.stRepo, C.dim)
  end

  local function writeApp(a, data)
    fs.makeDirectory(APPS_DIR)
    local hnd = fs.open(APPS_DIR .. "/" .. a.file, "w")
    if not hnd then
      setMsg(string.format(T.stFail, "gravar"), C.err)
      return
    end
    fs.write(hnd, data)
    fs.close(hnd)
    local vh = fs.open(verPath(a.file), "w")
    if vh then
      fs.write(vh, a.ver or "1")
      fs.close(vh)
    end
    if shared then shared.refresh = true end
    setMsg(string.format(T.stSaved, a.file), C.ok)
  end

  -- baixa, confere o codigo e analisa; so grava se estiver seguro (ou se o usuario confirmar)
  local function installApp(a)
    setMsg(string.format(T.stScan, a.file), C.dim)
    local data, err = httpGet(STORE_BASE .. a.file, 25)
    if not data then
      setMsg(string.format(T.stFail, tostring(err)), C.err)
      return
    end
    if #data == 0 or data:sub(1, 3) == "404" or not load(data, "=" .. a.file) then
      setMsg(T.stSyntax, C.err)
      return
    end
    local report = avScan(data)
    if report.verdict == "danger" then
      setMsg(string.format(T.stDanger, report.score), C.err)
      return
    end
    if report.verdict == "warn" then
      st.confirm = { app = a, data = data }
      setMsg(string.format(T.stWarn, report.score), C.warn)
      return
    end
    writeApp(a, data)
  end

  local function removeApp(a)
    pcall(fs.remove, APPS_DIR .. "/" .. a.file)
    pcall(fs.remove, verPath(a.file))
    if shared then shared.refresh = true end
    setMsg(string.format(T.asRemoved, a.name), C.ok)
  end

  local function viewList()
    local list = {}
    if not st.index then return list end
    local q = st.search:lower()
    for _, a in ipairs(st.index) do
      local iv = installedVer(a.file)
      local take = false
      if st.tab == "home" then
        local catOk = (CATS[st.cat] == "all") or (a.cat == CATS[st.cat])
        local textOk = (q == "") or (a.name:lower():find(q, 1, true) ~= nil)
          or (a.desc:lower():find(q, 1, true) ~= nil)
        take = catOk and textOk
      elseif st.tab == "apps" or st.tab == "remove" then
        take = (iv ~= nil)
      elseif st.tab == "update" then
        take = (iv ~= nil and a.ver ~= nil and iv ~= a.ver)
      end
      if take then list[#list + 1] = a end
    end
    return list
  end

  local function pageInfo(list)
    local total = math.max(1, math.ceil(#list / PER_PAGE))
    if st.page > total then st.page = total end
    if st.page < 1 then st.page = 1 end
    return total
  end

  local function cardLabel(a)
    if st.tab == "remove" then return T.asRemoveBtn, C.err end
    local s = stateOf(a)
    if s == "install" then return T.asInstall, C.ok end
    if s == "update" then return T.asUpdateBtn, C.warn end
    return T.asInstalled, C.dim
  end

  local function cardPos(k)
    local col = (k - 1) % 2
    local row = math.floor((k - 1) / 2)
    return gridX + col * (colW + 2), gridTop + row * 4
  end

  local function cardAction(a)
    if st.tab == "remove" then
      removeApp(a)
    elseif stateOf(a) ~= "ok" then
      installApp(a)
    else
      setMsg(T.asInstalled, C.dim)
    end
  end

  local function footerButtons()
    return makeButtons(ix, { { "reload", T.asReload }, { "prev", T.asPrev }, { "next", T.asNext } })
  end

  local function confirmButtons()
    return makeButtons(ix, { { "yes", T.stYes, C.warn }, { "no", T.stNo } })
  end

  local function drawCard(a, x, y, idx)
    rect(x, y, colW, 3, C.bg)
    put(x + 1, y, usub(a.name, 1, colW - 2), C.text, C.bg, colW - 2)
    put(x + 1, y + 1, usub(a.desc, 1, colW - 2), C.dim, C.bg, colW - 2)
    local label, col = cardLabel(a)
    drawButtons(makeButtons(x + 1, { { "b:" .. idx, label, col } }), y + 2)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)

    -- abas
    tabBoxes = {}
    local x = ix
    for _, tb in ipairs(TABS) do
      local label = " " .. T[tb.key] .. " "
      local active = (st.tab == tb.id)
      put(x, tabY, label, active and C.bg or C.dim, active and C.accent or C.barbg)
      tabBoxes[#tabBoxes + 1] = { x = x, w = ulen(label), id = tb.id }
      x = x + ulen(label) + 1
    end

    -- busca
    rect(searchX, tabY, searchW, 1, st.searching and C.accent or C.barbg)
    if st.search == "" and not st.searching then
      put(searchX + 1, tabY, T.asSearch, C.dim, C.barbg, searchW - 2)
    else
      local shown = st.search .. (st.searching and "_" or "")
      if ulen(shown) > searchW - 2 then shown = usub(shown, ulen(shown) - searchW + 3) end
      put(searchX + 1, tabY, shown, st.searching and C.bg or C.text, st.searching and C.accent or C.barbg)
    end

    -- categorias (so na aba Inicio)
    if st.tab == "home" then
      for k, c in ipairs(CATS) do
        local y = gridTop + k - 1
        local isSel = (k == st.cat)
        rect(catX, y, catW, 1, isSel and C.accent or C.panel)
        put(catX + 1, y, T[CAT_KEY[c]], isSel and C.bg or C.text, isSel and C.accent or C.panel, catW - 2)
      end
    end

    -- grade de cartoes
    local list = viewList()
    if not st.index then
      put(gridX, gridTop, T.stLoading, C.dim, C.panel, gridW)
    elseif #list == 0 then
      put(gridX, gridTop, T.asNone, C.dim, C.panel, gridW)
    else
      local total = pageInfo(list)
      local start = (st.page - 1) * PER_PAGE + 1
      for k = 1, PER_PAGE do
        local idx = start + k - 1
        local a = list[idx]
        if a then
          local cx, cy = cardPos(k)
          drawCard(a, cx, cy, idx)
        end
      end
      put(ix + 34, footY, string.format(T.asPage, st.page, total), C.dim, C.panel, iw - 34)
    end

    -- rodape (ou confirmacao de instalacao com aviso)
    if st.confirm then
      drawButtons(confirmButtons(), footY)
    else
      drawButtons(footerButtons(), footY)
    end
    if st.msg ~= "" then put(ix, msgY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if st.confirm then
      if y == footY then
        local id = hitButton(confirmButtons(), x)
        if id == "yes" then
          local p = st.confirm
          st.confirm = nil
          writeApp(p.app, p.data)
        elseif id == "no" then
          st.confirm = nil
          setMsg("", C.dim)
        else
          return false
        end
        return true
      end
      return false
    end

    if y == tabY then
      for _, tb in ipairs(tabBoxes) do
        if x >= tb.x and x < tb.x + tb.w then
          st.tab, st.page, st.searching = tb.id, 1, false
          return true
        end
      end
      if x >= searchX and x < searchX + searchW then
        st.searching = true
        return true
      end
      return false
    end

    if st.tab == "home" and x >= catX and x < catX + catW and y >= gridTop and y < gridTop + #CATS then
      st.cat = y - gridTop + 1
      st.page = 1
      return true
    end

    if y == footY then
      local id = hitButton(footerButtons(), x)
      if id == "reload" then
        loadIndex()
      elseif id == "prev" then
        st.page = math.max(1, st.page - 1)
      elseif id == "next" then
        st.page = st.page + 1
      else
        return false
      end
      return true
    end

    if not st.index then return false end
    local list = viewList()
    if #list == 0 then return false end
    pageInfo(list)
    local start = (st.page - 1) * PER_PAGE + 1
    for k = 1, PER_PAGE do
      local idx = start + k - 1
      local a = list[idx]
      if a then
        local cx, cy = cardPos(k)
        if y == cy + 2 then
          local label, col = cardLabel(a)
          if hitButton(makeButtons(cx + 1, { { "b:" .. idx, label, col } }), x) then
            cardAction(a)
            return true
          end
        end
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.confirm then
      if code == 31 or code == 21 then
        local p = st.confirm
        st.confirm = nil
        writeApp(p.app, p.data)
      elseif code == 49 or code == 1 then
        st.confirm = nil
        setMsg("", C.dim)
      end
      return true
    end
    if st.searching then
      if code == 28 or code == 1 then
        st.searching = false
        st.page = 1
        return true
      elseif code == 14 then
        if ulen(st.search) > 0 then st.search = usub(st.search, 1, ulen(st.search) - 1) end
        st.page = 1
        return true
      elseif char and char >= 32 and char < 127 and ulen(st.search) < 30 then
        st.search = st.search .. string.char(char)
        st.page = 1
        return true
      end
      return true
    end
    if code == 203 then
      st.page = math.max(1, st.page - 1)
      return true
    elseif code == 205 then
      st.page = st.page + 1
      return true
    elseif code == 63 then
      loadIndex()
      return true
    end
    return false
  end

  win.onPaste = function(self, text)
    if not st.searching then return false end
    local clean = tostring(text):gsub("[%c]", "")
    st.search = (st.search .. clean):sub(1, 30)
    st.page = 1
    return true
  end

  win.canClose = function(self)
    return true
  end

  loadIndex()
  return win
end
