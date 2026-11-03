-- Rede Local do Nitro OS (nitro/sys/redelocal.lua): procura computadores por perto,
-- envia mensagens e arquivos pela Wireless Network Card. So recebe com o app aberto.
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

  local win = { title = T.mRedeLocal, live = true }
  setWinGeom(win, 60, 18)
  local ix, iw = win.x + 2, win.w - 4
  local listY, logY, btnY, msgY = win.y + 3, win.y + 10, win.y + 15, win.y + 16

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
    mode = "main", peers = {}, sel = 1, log = {}, incoming = nil,
    input = "", files = {}, fsel = 1, msg = "", msgColor = C.dim,
  }

  local function setMsg(text, color)
    st.msg, st.msgColor = text, color or C.dim
  end

  local function now()
    local ok, t = pcall(os.date, "%d/%m %H:%M")
    return ok and t or fmtSize(0)
  end

  local function logAdd(text, color)
    table.insert(st.log, 1, { text = text, color = color or C.text })
    while #st.log > 40 do table.remove(st.log) end
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

  -- separa a mensagem em no maximo n campos; o ultimo campo leva o resto (pode ter "|")
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
    if st.sel > #out then st.sel = math.max(1, #out) end
    return out
  end

  local function peerName(addr)
    for _, p in ipairs(st.peers) do
      if p.addr == addr then return p.name end
    end
    return tostring(addr):sub(1, 8)
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
    if not modem then setMsg(T.rlNoCard, C.err) return end
    pcall(modem.broadcast, PORT, "HELLO|" .. myName())
    setMsg(T.rlSearching, C.dim)
  end

  -- chegou o arquivo completo: analisa e so depois guarda em /Download
  local function finishIncoming()
    local inc = st.incoming
    st.incoming = nil
    if not inc or not inc.accepted then return end
    if inc.got < inc.total then
      logAdd(string.format(T.rlIncomplete, inc.name), C.err)
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
      logAdd(string.format(T.rlBlocked, inc.name), C.err)
      setMsg(string.format(T.rlBlocked, inc.name), C.err)
      return
    end
    local final = uniquePath(DL, inc.name)
    fs.rename(tmp, final)
    logAdd(string.format(T.rlRecv, final), C.ok)
    setMsg(string.format(T.rlRecv, inc.name), C.ok)
  end

  local function sendFile(peer, name)
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
    logAdd(T.rlSent .. ": " .. name .. " -> " .. peer.name, C.ok)
    setMsg(T.rlSent, C.ok)
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
      local text = string.format(T.rlFrom, clean(f[2] or "?"), f[3] or "")
      logAdd(text, C.text)
      setMsg(T.rlNewMsg, C.accent)
    elseif kind == "FILE" then
      local f = fields(msg, 5)
      local name = safeName(f[3])
      local size, total = tonumber(f[4]) or 0, tonumber(f[5]) or 0
      if not name or size > MAX_FILE or total <= 0 or total > 80 then return end
      st.incoming = {
        addr = addr, from = clean(f[2] or "?"), name = name, size = size,
        total = total, parts = {}, got = 0, accepted = false,
      }
      st.mode = "incoming"
      setMsg(string.format(T.rlAsk, st.incoming.from, name, fmtSize(size)), C.warn)
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
      if inc and addr == inc.addr then
        finishIncoming()
        if st.mode == "incoming" then st.mode = "main" end
      end
    end
  end

  local function curButtons()
    if st.mode == "input" or st.mode == "pick" then
      return makeButtons(ix, { { "send", T.rlSend, C.ok }, { "cancel", T.bCancel } })
    elseif st.mode == "incoming" then
      return makeButtons(ix, { { "accept", T.rlAccept, C.ok }, { "reject", T.rlReject, C.warn } })
    end
    return makeButtons(ix, {
      { "search", T.rlSearch, C.ok }, { "msg", T.rlMsg }, { "file", T.rlFile },
      { "minus", "-" }, { "plus", "+" },
    })
  end

  local function strengthText()
    if not modem then return "" end
    local okS, cur = pcall(modem.getStrength)
    return string.format(T.rlStrength, (okS and tonumber(cur)) or 0)
  end

  local function startMsg()
    local peers = livePeers()
    if #peers == 0 then setMsg(T.rlNeedPeer, C.warn) return end
    st.mode, st.input = "input", ""
    setMsg(T.rlInput, C.dim)
  end

  local function startFile()
    local peers = livePeers()
    if #peers == 0 then setMsg(T.rlNeedPeer, C.warn) return end
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

  local function doSend()
    local peers = livePeers()
    local peer = peers[st.sel]
    if not peer then setMsg(T.rlNeedPeer, C.warn) return end
    if st.mode == "input" then
      if st.input ~= "" then
        sendTo(peer.addr, "MSG|" .. myName() .. "|" .. st.input)
        logAdd("-> " .. peer.name .. ": " .. st.input, C.dim)
      end
      st.mode = "main"
      setMsg(T.rlSent, C.ok)
    elseif st.mode == "pick" then
      local name = st.files[st.fsel]
      st.mode = "main"
      if name then sendFile(peer, name) else setMsg(T.rlNoDownloads, C.warn) end
    end
  end

  local function accept(yes)
    local inc = st.incoming
    st.mode = "main"
    if not inc then return end
    if yes then
      inc.accepted = true
      setMsg(T.rlSearching, C.dim)
    else
      st.incoming = nil
      logAdd("Recusado: " .. inc.name, C.warn)
      setMsg(T.rlReject, C.warn)
    end
  end

  local function changeRange(delta)
    if not modem then return end
    local okS, cur = pcall(modem.getStrength)
    local new = math.max(0, math.min(400, ((okS and tonumber(cur)) or 0) + delta))
    pcall(modem.setStrength, new)
  end

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    put(ix, self.y + 1, T.mRedeLocal, C.accent, C.panel, iw - 14)
    put(ix + iw - ulen(strengthText()), self.y + 1, strengthText(), C.dim, C.panel)

    if st.mode == "pick" then
      if #st.files == 0 then put(ix, listY, T.rlNoDownloads, C.dim, C.panel, iw) end
      for n = 0, 5 do
        local name = st.files[n + 1]
        if name then
          local y = listY + n
          local isSel = (n + 1 == st.fsel)
          rect(ix - 1, y, iw + 2, 1, isSel and C.accent or C.panel)
          put(ix, y, "  " .. name, isSel and C.bg or C.text, isSel and C.accent or C.panel, iw)
        end
      end
    elseif st.mode == "input" then
      put(ix, listY, T.rlInput, C.dim, C.panel, iw)
      rect(ix, listY + 1, iw, 1, C.barbg)
      put(ix + 1, listY + 1, st.input .. "_", C.text, C.barbg, iw - 2)
    else
      local peers = livePeers()
      if #peers == 0 then put(ix, listY, T.rlNoPeers, C.dim, C.panel, iw) end
      for n = 0, 5 do
        local p = peers[n + 1]
        if p then
          local y = listY + n
          local isSel = (n + 1 == st.sel)
          rect(ix - 1, y, iw + 2, 1, isSel and C.accent or C.panel)
          local right = "~" .. math.floor(p.dist or 0) .. "m"
          put(ix, y, "  " .. p.name, isSel and C.bg or C.text, isSel and C.accent or C.panel, iw - 8)
          put(ix + iw - ulen(right), y, right, isSel and C.bg or C.dim, isSel and C.accent or C.panel)
        end
      end
    end

    for n = 0, 3 do
      local e = st.log[n + 1]
      if e then put(ix, logY + n, e.text, e.color, C.panel, iw) end
    end

    drawButtons(curButtons(), btnY)
    if st.mode == "incoming" and st.incoming then
      put(ix, msgY, st.msg, st.msgColor, C.panel, iw)
    elseif st.msg ~= "" then
      put(ix, msgY, st.msg, st.msgColor, C.panel, iw)
    end
  end

  win.onTouch = function(self, x, y)
    if y == btnY then
      local id = hitButton(curButtons(), x)
      if id == "search" then search()
      elseif id == "msg" then startMsg()
      elseif id == "file" then startFile()
      elseif id == "minus" then changeRange(-50)
      elseif id == "plus" then changeRange(50)
      elseif id == "send" then doSend()
      elseif id == "cancel" then st.mode = "main"
      elseif id == "accept" then accept(true)
      elseif id == "reject" then accept(false)
      else return false end
      return true
    end
    if st.mode == "pick" and y >= listY and y < listY + 6 then
      local idx = y - listY + 1
      if st.files[idx] then st.fsel = idx return true end
    elseif st.mode == "main" and y >= listY and y < listY + 6 then
      local idx = y - listY + 1
      if livePeers()[idx] then st.sel = idx return true end
    end
    return false
  end

  win.onKey = function(self, char, code)
    if st.mode == "input" then
      if code == 28 then doSend()
      elseif code == 1 then st.mode = "main"
      elseif code == 14 then
        if ulen(st.input) > 0 then st.input = usub(st.input, 1, ulen(st.input) - 1) end
      elseif char and char >= 32 and char < 127 and ulen(st.input) < 120 then
        st.input = st.input .. string.char(char)
      end
      return true
    elseif st.mode == "pick" then
      if code == 200 then st.fsel = math.max(1, st.fsel - 1)
      elseif code == 208 then st.fsel = math.min(math.max(1, #st.files), st.fsel + 1)
      elseif code == 28 then doSend()
      elseif code == 1 then st.mode = "main"
      end
      return true
    elseif st.mode == "incoming" then
      if code == 28 then accept(true)
      elseif code == 1 then accept(false)
      end
      return true
    end
    if code == 200 then st.sel = math.max(1, st.sel - 1) return true
    elseif code == 208 then st.sel = math.min(math.max(1, #livePeers()), st.sel + 1) return true
    elseif code == 28 then search() return true
    end
    return false
  end

  if not modem then setMsg(T.rlNoCard, C.err) end
  return win
end
