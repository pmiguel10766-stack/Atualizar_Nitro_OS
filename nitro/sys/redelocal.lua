-- Rede Local do Nitro OS (nitro/sys/redelocal.lua): conversa com os computadores por perto.
-- Lista de computadores a direita, conversa a esquerda, campo de texto embaixo.
-- Procura, mensagens e arquivos (com Antivirus). So recebe com o app aberto.
-- Protocolo compativel com o openos/rede_local.lua (porta 4242).
-- Recebe A (a API do Nitro OS) e cfg (usuario).
return function(A, cfg, ...)
  local put, rect, setWinGeom = A.put, A.rect, A.setWinGeom
  local ulen, usub = A.ulen, A.usub
  local makeButtons, drawButtons, hitButton = A.makeButtons, A.drawButtons, A.hitButton
  local C, T, fs, cl, cp = A.C, A.T, A.fs, A.cl, A.cp
  local readFile, fmtSize = A.readFile, A.fmtSize
  local avAnalyzeFile = A.avAnalyzeFile

  local PORT = 4242
  local LOG = "/nitro/rede.log"
  local DL = "/Download"
  local MAX_FILE = 131072
  local CHUNK = 1800
  local PEER_TTL = 60
  local ALL = "__all"
  local TEXT_W = 36

  local win = { title = T.mRedeLocal, live = true }
  setWinGeom(win, 64, 18)
  local ix, iw = win.x + 2, win.w - 4
  local chatW = 38
  local userX = ix + chatW + 2
  local userW = iw - chatW - 2
  local chatTop, chatRows = win.y + 2, 10
  local inputY = win.y + 13
  local toolY = win.y + 15
  local msgY = win.y + 16

  local modem, selfAddr = nil, nil
  do
    local addr = cl.list("modem")()
    if addr then
      local m = cl.proxy(addr)
      local okW, isW = pcall(m.isWireless)
      if okW and isW then
        modem, selfAddr = m, addr
        pcall(m.open, PORT)
      end
    end
  end

  local st = {
    target = ALL, conv = { [ALL] = {} }, unread = {}, peers = {}, input = "",
    mode = "chat", files = {}, fsel = 1, incoming = nil,
    msg = "", msgColor = C.dim,
  }
  if not modem then st.msg, st.msgColor = T.rlNoCard, C.err end

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function now()
    local ok, t = pcall(os.date, "%d/%m %H:%M")
    return ok and t or ""
  end

  -- historico geral em /nitro/rede.log (as ultimas 80 linhas)
  local function logLine(text)
    local lines = {}
    for line in (readFile(LOG) or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
    lines[#lines + 1] = "[" .. now() .. "] " .. text
    while #lines > 80 do table.remove(lines, 1) end
    local hnd = fs.open(LOG, "w")
    if hnd then
      fs.write(hnd, table.concat(lines, "\n") .. "\n")
      fs.close(hnd)
    end
  end

  local function addConv(key, text, color)
    local list = st.conv[key]
    if not list then
      list = {}
      st.conv[key] = list
    end
    list[#list + 1] = { text = text, color = color or C.text }
    while #list > 200 do table.remove(list, 1) end
  end

  -- separa a mensagem em no maximo n campos; o ultimo leva o resto (pode ter "|")
  local function fields(s, n)
    local out, pos = {}, 1
    for _ = 1, n - 1 do
      local j = s:find("|", pos, true)
      if not j then break end
      out[#out + 1] = s:sub(pos, j - 1)
      pos = j + 1
    end
    out[#out + 1] = s:sub(pos)
    return out
  end

  local function clean(s)
    return (tostring(s):gsub("[|\r\n]", "_"))
  end

  local function safeName(n)
    if not n or n == "" or #n > 64 then return nil end
    if n:sub(1, 1) == "." or not n:match("^[%w_%-%. ]+$") then return nil end
    return n
  end

  local function myName()
    return clean((cfg and cfg.user) or "Nitro")
  end

  local function sendTo(addr, text)
    if not modem then return false end
    return pcall(modem.send, addr, PORT, text)
  end

  local function seePeer(addr, name, dist)
    if addr == selfAddr then return end
    for _, p in ipairs(st.peers) do
      if p.addr == addr then
        p.name, p.dist, p.seen = name, dist, cp.uptime()
        return
      end
    end
    st.peers[#st.peers + 1] = { addr = addr, name = name, dist = dist, seen = cp.uptime() }
  end

  local function livePeers()
    local out, t = {}, cp.uptime()
    for _, p in ipairs(st.peers) do
      if t - p.seen <= PEER_TTL then out[#out + 1] = p end
    end
    st.peers = out
    return out
  end

  local function findPeer(addr)
    for _, p in ipairs(livePeers()) do
      if p.addr == addr then return p end
    end
    return nil
  end

  local function uniquePath(dir, name)
    local p = dir .. "/" .. name
    if not fs.exists(p) then return p end
    local base, ext = name:match("^(.*)(%.[^.]*)$")
    if not base then base, ext = name, "" end
    local n = 2
    while fs.exists(dir .. "/" .. base .. " (" .. n .. ")" .. ext) do n = n + 1 end
    return dir .. "/" .. base .. " (" .. n .. ")" .. ext
  end

  local function search()
    if not modem then
      setMsg(T.rlNoCard, C.err)
      return
    end
    pcall(modem.broadcast, PORT, "HELLO|" .. myName())
    setMsg(T.rlSearching, C.dim)
  end

  local function finishIncoming()
    local inc = st.incoming
    st.incoming = nil
    if not inc or not inc.accepted then return end
    if inc.got < inc.total then
      addConv(inc.addr, string.format(T.rlIncomplete, inc.name), C.err)
      setMsg(string.format(T.rlIncomplete, inc.name), C.err)
      return
    end
    local pieces = {}
    for i = 1, inc.total do pieces[i] = inc.parts[i] or "" end
    local data = table.concat(pieces)
    fs.makeDirectory(DL)
    local tmp = DL .. "/" .. inc.name .. ".part"
    local hnd = fs.open(tmp, "w")
    if not hnd then
      setMsg(T.errPrefix .. inc.name, C.err)
      return
    end
    fs.write(hnd, data)
    fs.close(hnd)
    local rep = avAnalyzeFile(tmp)
    if rep and rep.verdict == "danger" then
      fs.remove(tmp)
      addConv(inc.addr, string.format(T.rlBlocked, inc.name), C.err)
      logLine(string.format(T.rlBlocked, inc.name))
      setMsg(string.format(T.rlBlocked, inc.name), C.err)
      return
    end
    local final = uniquePath(DL, inc.name)
    fs.rename(tmp, final)
    addConv(inc.addr, string.format(T.rlRecv, final), C.ok)
    logLine(string.format(T.rlRecv, final))
    setMsg(string.format(T.rlRecv, inc.name), C.ok)
  end

  local function acceptIncoming(yes)
    local inc = st.incoming
    if not inc then return end
    if yes then
      inc.accepted = true
      setMsg(T.rlSearching, C.dim)
    else
      st.incoming = nil
      addConv(inc.addr, T.rlReject .. ": " .. inc.name, C.warn)
      logLine("Recusado: " .. inc.name)
      setMsg(T.rlReject, C.warn)
    end
  end

  -- envia um arquivo de /Download para o computador selecionado
  local function sendFileTo(peer, name)
    local path = DL .. "/" .. name
    if not fs.exists(path) or fs.isDirectory(path) then
      setMsg(T.errPrefix .. name, C.err)
      return
    end
    local data = readFile(path) or ""
    if #data > MAX_FILE then
      setMsg(T.rlTooBig, C.err)
      return
    end
    local total = math.max(1, math.ceil(#data / CHUNK))
    sendTo(peer.addr, "FILE|" .. myName() .. "|" .. clean(name) .. "|" .. #data .. "|" .. total)
    for i = 1, total do
      sendTo(peer.addr, "CHUNK|" .. i .. "|" .. data:sub((i - 1) * CHUNK + 1, i * CHUNK))
      cp.pullSignal(0.05)
      setMsg(string.format(T.rlSending, i, total), C.dim)
    end
    sendTo(peer.addr, "END|" .. clean(name))
    addConv(peer.addr, T.rlSent .. ": " .. name, C.ok)
    logLine(T.rlSent .. ": " .. name .. " -> " .. peer.name)
    setMsg(T.rlSent, C.ok)
  end

  local function sendText()
    local text = st.input
    if text == "" then return end
    if st.target == ALL then
      local peers = livePeers()
      if #peers == 0 then
        setMsg(T.rlNeedPeer, C.warn)
        return
      end
      for _, p in ipairs(peers) do sendTo(p.addr, "MSG|" .. myName() .. "|" .. text) end
      addConv(ALL, T.rlYou .. ": " .. text, C.text)
      logLine("-> " .. T.rlAll .. ": " .. text)
    else
      local p = findPeer(st.target)
      if not p then
        setMsg(T.rlNeedPeer, C.warn)
        return
      end
      sendTo(p.addr, "MSG|" .. myName() .. "|" .. text)
      addConv(p.addr, T.rlYou .. ": " .. text, C.text)
      logLine("-> " .. p.name .. ": " .. text)
    end
    st.input = ""
    setMsg("", C.dim)
  end

  local function startFile()
    if st.target == ALL then
      setMsg(T.rlNeedPeer, C.warn)
      return
    end
    st.files = {}
    local ok, names = pcall(fs.list, DL)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-1) ~= "/" then st.files[#st.files + 1] = n end
      end
    end
    table.sort(st.files)
    st.fsel, st.mode = 1, "pick"
    setMsg(T.rlPickFile, C.dim)
  end

  local function sendSelectedFile()
    local peer = findPeer(st.target)
    st.mode = "chat"
    if not peer then
      setMsg(T.rlNeedPeer, C.warn)
      return
    end
    local name = st.files[st.fsel]
    if name then sendFileTo(peer, name) else setMsg(T.rlNoDownloads, C.warn) end
  end

  local function changeRange(delta)
    if not modem then return end
    local okS, cur = pcall(modem.getStrength)
    local new = math.max(0, math.min(400, ((okS and tonumber(cur)) or 0) + delta))
    pcall(modem.setStrength, new)
  end

  local function strengthText()
    if not modem then return "" end
    local okS, cur = pcall(modem.getStrength)
    return string.format(T.rlStrength, (okS and tonumber(cur)) or 0)
  end

  -- mensagens que chegam pela rede (chamado pelo desktop)
  win.onModem = function(self, addr, port, dist, msg)
    if port ~= PORT or type(msg) ~= "string" then return end
    local kind = msg:match("^(%u+)|") or ""
    if kind == "HELLO" then
      local f = fields(msg, 2)
      seePeer(addr, clean(f[2] or "?"), dist)
      sendTo(addr, "HERE|" .. myName())
    elseif kind == "HERE" then
      local f = fields(msg, 2)
      seePeer(addr, clean(f[2] or "?"), dist)
    elseif kind == "MSG" then
      local f = fields(msg, 3)
      local from = clean(f[2] or "?")
      seePeer(addr, from, dist)
      addConv(addr, from .. ": " .. (f[3] or ""), C.text)
      if st.target ~= addr then st.unread[addr] = true end
      logLine(from .. ": " .. (f[3] or ""))
      setMsg(T.rlNewMsg, C.accent)
    elseif kind == "FILE" then
      local f = fields(msg, 5)
      local name = safeName(f[3])
      local size, total = tonumber(f[4]) or 0, tonumber(f[5]) or 0
      if not name or size > MAX_FILE or total <= 0 or total > 80 then return end
      local from = clean(f[2] or "?")
      seePeer(addr, from, dist)
      st.incoming = {
        addr = addr, from = from, name = name, size = size,
        total = total, parts = {}, got = 0, accepted = false,
      }
      addConv(addr, string.format(T.rlAsk, from, name, fmtSize(size)), C.warn)
      if st.target ~= addr then st.unread[addr] = true end
      setMsg(string.format(T.rlAsk, from, name, fmtSize(size)), C.warn)
    elseif kind == "CHUNK" then
      local inc = st.incoming
      if inc and addr == inc.addr then
        local f = fields(msg, 3)
        local idx = tonumber(f[2])
        if idx and idx >= 1 and idx <= inc.total and not inc.parts[idx] then
          inc.parts[idx] = f[3] or ""
          inc.got = inc.got + 1
        end
      end
    elseif kind == "END" then
      local inc = st.incoming
      if inc and addr == inc.addr then finishIncoming() end
    end
  end

  -- ---------------- desenho

  local function targetName()
    if st.target == ALL then return T.rlAll end
    local p = findPeer(st.target)
    return p and p.name or "?"
  end

  local function wrap(text, width)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      if line == "" then out[#out + 1] = "" end
      while ulen(line) > width do
        out[#out + 1] = usub(line, 1, width)
        line = usub(line, width + 1)
      end
      out[#out + 1] = line
    end
    return out
  end

  local function chatLines()
    local out = {}
    for _, e in ipairs(st.conv[st.target] or {}) do
      for _, ln in ipairs(wrap(e.text, TEXT_W)) do
        out[#out + 1] = { text = ln, color = e.color }
      end
    end
    return out
  end

  local function toolButtons()
    if st.mode == "pick" then
      return makeButtons(ix, { { "sendfile", T.rlSend, C.ok }, { "cancel", T.bCancel } })
    end
    if st.incoming and not st.incoming.accepted then
      return makeButtons(ix, { { "accept", T.rlAccept, C.ok }, { "reject", T.rlReject, C.warn } })
    end
    return makeButtons(ix, {
      { "search", T.rlSearch, C.ok }, { "file", T.rlFile },
      { "minus", "-" }, { "plus", "+" },
    })
  end

  local function sendButtons()
    return makeButtons(ix + chatW - 8, { { "sendtxt", T.rlSend, C.ok } })
  end

  local function drawChat()
    local lines = chatLines()
    if #lines == 0 then
      put(ix, chatTop + 1, T.rlEmptyChat, C.dim, C.panel, chatW)
      return
    end
    local first = math.max(1, #lines - chatRows + 1)
    for n = 0, chatRows - 1 do
      local e = lines[first + n]
      if e then put(ix, chatTop + 1 + n, e.text, e.color, C.panel, chatW) end
    end
  end

  local function drawPick()
    if #st.files == 0 then
      put(ix, chatTop + 1, T.rlNoDownloads, C.dim, C.panel, chatW)
      return
    end
    for n = 0, chatRows - 1 do
      local name = st.files[n + 1]
      if name then
        local y = chatTop + 1 + n
        local isSel = (n + 1 == st.fsel)
        rect(ix, y, chatW, 1, isSel and C.accent or C.panel)
        put(ix + 1, y, usub(name, 1, chatW - 2), isSel and C.bg or C.text, isSel and C.accent or C.panel)
      end
    end
  end

  local function drawUsers()
    put(userX, chatTop, T.rlComputers, C.dim, C.panel, userW)
    local rowY = chatTop + 1
    local selAll = st.target == ALL
    rect(userX, rowY, userW, 1, selAll and C.accent or C.panel)
    put(userX + 1, rowY, T.rlAll, selAll and C.bg or C.text, selAll and C.accent or C.panel, userW - 2)
    for i, p in ipairs(livePeers()) do
      local y = rowY + i
      if y >= chatTop + 1 + chatRows then break end
      local sel = st.target == p.addr
      local bg = sel and C.accent or C.panel
      rect(userX, y, userW, 1, bg)
      local mark = st.unread[p.addr] and "* " or "  "
      put(userX + 1, y, mark .. p.name, sel and C.bg or C.text, bg, userW - 8)
      local right = "~" .. math.floor(p.dist or 0) .. "m"
      put(userX + userW - ulen(right), y, right, sel and C.bg or C.dim, bg)
    end
  end

  local function drawInput()
    local boxW = chatW - 10
    rect(ix, inputY, boxW, 1, C.barbg)
    local shown = st.input
    if ulen(shown) > boxW - 3 then shown = usub(shown, ulen(shown) - (boxW - 3) + 1) end
    if shown == "" then
      put(ix + 1, inputY, T.rlPlaceholder, C.dim, C.barbg, boxW - 2)
    else
      put(ix + 1, inputY, shown .. "_", C.text, C.barbg, boxW - 2)
    end
    drawButtons(sendButtons(), inputY)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.mRedeLocal, C.accent, C.panel, iw - 12)
    put(ix + iw - ulen(strengthText()), self.y + 1, strengthText(), C.dim, C.panel)

    put(ix, chatTop, targetName(), C.text, C.panel, chatW)
    if st.mode == "pick" then drawPick() else drawChat() end
    drawUsers()
    drawInput()
    drawButtons(toolButtons(), toolY)
    if st.msg ~= "" then put(ix, msgY, st.msg, st.msgColor, C.panel, iw) end
  end

  win.onTouch = function(self, x, y)
    if y == toolY then
      local id = hitButton(toolButtons(), x)
      if id == "search" then search()
      elseif id == "file" then startFile()
      elseif id == "minus" then changeRange(-50)
      elseif id == "plus" then changeRange(50)
      elseif id == "accept" then acceptIncoming(true)
      elseif id == "reject" then acceptIncoming(false)
      elseif id == "sendfile" then sendSelectedFile()
      elseif id == "cancel" then st.mode = "chat"
      else return false end
      return true
    end
    if y == inputY then
      if hitButton(sendButtons(), x) == "sendtxt" then sendText() return true end
      return false
    end
    local rowTop = chatTop + 1
    local rowBottom = chatTop + chatRows
    if st.mode == "pick" and y >= rowTop and y <= rowBottom and x >= ix and x < ix + chatW then
      local idx = y - rowTop + 1
      if st.files[idx] then st.fsel = idx return true end
      return false
    end
    if x >= userX and x < userX + userW and y >= rowTop and y <= rowBottom then
      local idx = y - rowTop + 1
      if idx == 1 then
        st.target = ALL
        return true
      end
      local p = livePeers()[idx - 1]
      if p then
        st.target = p.addr
        st.unread[p.addr] = nil
        return true
      end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "pick" then
      if code == 200 then st.fsel = math.max(1, st.fsel - 1)
      elseif code == 208 then st.fsel = math.min(math.max(1, #st.files), st.fsel + 1)
      elseif code == 28 then sendSelectedFile()
      elseif code == 1 then st.mode = "chat"
      end
      return true
    end
    if code == 28 then
      sendText()
      return true
    elseif code == 14 then
      if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      return true
    elseif code == 1 then
      return false
    elseif char and char >= 32 and char < 127 and ulen(st.input) < 120 then
      st.input = st.input .. string.char(char)
      return true
    end
    return false
  end

  win.onPaste = function(self, text)
    local clean_ = tostring(text):gsub("[%c]", "")
    st.input = (st.input .. clean_):sub(1, 120)
    return true
  end

  search()
  return win
end
