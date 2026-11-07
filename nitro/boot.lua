-- Nitro OS - /nitro/boot.lua
-- Primeiro boot: idioma, usuario e senha opcional. Depois: login (se tiver senha) e area de trabalho.

local cl, cp = component, computer
local gpu = cl.proxy(cl.list("gpu")())
local screenAddr = cl.list("screen")()
if screenAddr and not gpu.getScreen() then gpu.bind(screenAddr) end
local w, h = gpu.getResolution()

local ulen = (unicode and unicode.len) or string.len
local usub = (unicode and unicode.sub) or string.sub
local uchar = (unicode and unicode.char) or string.char

local fs = cl.proxy(cp.getBootAddress())
local CONFIG = "/nitro/config.lua"
local VERSION = "1.27"

-- edicao instalada: "pro" (completa) ou "go" (leve). O instalador grava /nitro/edition.
local function detectEdition()
  local hnd = fs.open("/nitro/edition")
  if not hnd then return "pro" end
  local data = fs.read(hnd, 16) or ""
  fs.close(hnd)
  return data:match("%a+") or "pro"
end

local EDITION = detectEdition()
local GO = (EDITION == "go")

---------------------------------------------------------------- cores e desenho
local C = {
  bg = 0x050505, panel = 0x1A1A1A, accent = 0xFF2D2D, text = 0xFFFFFF,
  dim = 0xA0A0A0, ok = 0x3DDC84, warn = 0xFFB300, err = 0xFF8A8A,
  barbg = 0x3A3A3A,
}

local THEMES = {
  { id = "red", key = "sThemeRed", accent = 0xFF2D2D, bg = 0x050505, panel = 0x1A1A1A },
  { id = "blue", key = "sThemeBlue", accent = 0x2D9CFF, bg = 0x050505, panel = 0x1A1A1A },
  { id = "purple", key = "sThemePurple", accent = 0xB06BFF, bg = 0x050505, panel = 0x1A1A1A },
  { id = "halloween", key = "sThemeHalloween", accent = 0xFF7A00, bg = 0x0D0712, panel = 0x1E1026 },
  { id = "natal", key = "sThemeNatal", accent = 0xD32F2F, bg = 0x06130B, panel = 0x10261A },
}

local function themeIndex(id)
  for i, th in ipairs(THEMES) do
    if th.id == id then return i end
  end
  return 1
end

local function applyTheme(id)
  local th = THEMES[themeIndex(id)]
  C.accent = th.accent
  C.bg = th.bg
  C.panel = th.panel
end

local function rect(x, y, rw, rh, bg)
  gpu.setBackground(bg)
  gpu.fill(x, y, rw, rh, " ")
end

local function put(x, y, s, fg, bg, maxw)
  s = tostring(s)
  if maxw and ulen(s) > maxw then s = usub(s, 1, maxw) end
  gpu.setBackground(bg)
  gpu.setForeground(fg)
  gpu.set(x, y, s)
end

local function key()
  while true do
    local ev, _, _, code = cp.pullSignal()
    if ev == "key_down" then return code end
  end
end

local pw = math.min(w - 4, 64)
local px = math.floor((w - pw) / 2) + 1
local py = 4
local ph = math.max(9, math.min(h - 5, 22))
local cx = px + 3
local cw = pw - 6

local function center(y, s, fg, bg)
  put(px + math.floor((pw - ulen(s)) / 2), y, s, fg, bg)
end

local function footer(text)
  rect(1, h, w, 1, C.panel)
  put(2, h, text, C.dim, C.panel, w - 2)
end

---------------------------------------------------------------- logo Nitro OS
-- C listrado + rosto vermelho. x,y = canto superior esquerdo; size = altura em linhas.
local function logoSize()
  return (h >= 24) and 14 or 8
end

local function logoWidth(size)
  return math.floor(size * 1.75 + 0.5)
end

local function drawLogo(x, y, size, bg, stripe)
  local R = size
  local r = math.floor(R * 0.64 + 0.5)
  local arm = math.floor(R * 0.65 + 0.5)

  -- C listrado (uma listra fina por linha)
  gpu.setBackground(bg)
  gpu.setForeground(stripe)
  for ry = 0, R - 1 do
    local dy = (ry + 0.5) * 2 - R
    local left = math.floor(R - math.sqrt(R * R - dy * dy) + 0.5)
    local right
    if math.abs(dy) >= r then
      right = R + arm
    else
      right = math.floor(R - math.sqrt(r * r - dy * dy) + 0.5)
    end
    if right > left then
      gpu.set(x + left, y + ry, string.rep("▀", right - left))
    end
  end

  -- rosto vermelho
  local Rf = math.floor(R * 0.43 + 0.5)
  local fcx = R + math.floor(R * 0.28 + 0.5)
  local red, black = 0xD01818, 0x000000
  local frows = {}
  gpu.setBackground(red)
  for ry = 0, R - 1 do
    local dy = (ry + 0.5) * 2 - R
    if math.abs(dy) < Rf then
      local hw = math.floor(math.sqrt(Rf * Rf - dy * dy) + 0.5)
      if hw > 0 then
        gpu.fill(x + fcx - hw, y + ry, hw * 2, 1, " ")
        frows[#frows + 1] = ry
      end
    end
  end

  local nF = #frows
  if nF >= 2 then
    local eyeRow = frows[nF >= 5 and 2 or 1]
    gpu.setBackground(red)
    gpu.setForeground(black)
    gpu.set(x + fcx - 3, y + eyeRow, ">")
    gpu.set(x + fcx + 2, y + eyeRow, "<")
    gpu.setBackground(black)
    if nF >= 5 then
      gpu.fill(x + fcx - 3, y + frows[4], 7, 1, " ")
      gpu.fill(x + fcx - 2, y + frows[5], 5, 1, " ")
    else
      gpu.fill(x + fcx - 1, y + frows[nF], 3, 1, " ")
    end
  end
end

local function pause(t)
  local deadline = cp.uptime() + t
  repeat
    cp.pullSignal(deadline - cp.uptime())
  until cp.uptime() >= deadline
end

local bootBar = { x = 1, y = 1, w = 1 }

-- tela de carregamento: logo + nome (desenhados uma vez)
local function bootBase()
  rect(1, 1, w, h, C.bg)
  local size = logoSize()
  local ly = math.floor((h - (size + 6)) / 2) + 1
  drawLogo(math.floor((w - logoWidth(size)) / 2) + 1, ly, size, C.bg, 0xE6E6E6)
  local name = "NITRO OS"
  put(math.floor((w - ulen(name)) / 2) + 1, ly + size + 1, name, C.text, C.bg)
  bootBar.w = math.min(w - 10, 40)
  bootBar.x = math.floor((w - bootBar.w) / 2) + 1
  bootBar.y = ly + size + 4
end

-- atualiza so o texto e a barra de carregamento
local function bootProgress(pct, text)
  local label = string.format("[Carregado %d%%]", pct)
  rect(1, bootBar.y - 1, w, 1, C.bg)
  put(math.floor((w - ulen(label)) / 2) + 1, bootBar.y - 1, label, C.text, C.bg)
  rect(bootBar.x, bootBar.y, bootBar.w, 1, C.barbg)
  rect(bootBar.x, bootBar.y, math.floor(bootBar.w * pct / 100), 1, C.accent)
end

---------------------------------------------------------------- idiomas
local langs = {
  { name = "Português", t = {
    steps = { "Idioma", "Usuário", "Senha" },
    userTitle = "Criar usuário",
    userAsk = "Nome de usuário:",
    userEmpty = "Digite um nome",
    prepHello = "Olá, %s",
    prepPreparing = "Estamos preparando tudo para você",
    prepMinutes = "Isso pode levar alguns minutos.",
    prepWarn = "Aviso: Não desligue o computador",
    passTitle = "Senha (opcional)",
    passAsk = "Senha (Enter para pular):",
    passConfirm = "Repita a senha:",
    passMismatch = "As senhas não são iguais",
    keysInput = "Enter OK    Esc Voltar",
    loginTitle = "Entrar",
    loginHello = "Olá, %s",
    loginAsk = "Senha:",
    loginWrong = "Senha incorreta",
    loginKeys = "Enter Entrar",
    welcome = "Bem-vindo, %s!",
    ready = "O Nitro OS está pronto.",
    cont = " Enter  Continuar ",
    empty = "Nenhum app instalado ainda",
    hint = "Clique em ◆ Nitro para abrir o Menu",
    soon = "Em breve",
    mFiles = "Arquivos",
    mEditor = "Editor de Texto",
    mCalc = "Calculadora",
    mMonitor = "Monitor do Sistema",
    mNotes = "Notas",
    mPrinter = "Impressora 3D",
    mRestart = "Reiniciar",
    mShutdown = "Desligar",
    ram = "RAM",
    energy = "Energia",
    uptime = "Tempo ligado",
    bUp = "↑ Subir",
    bOpen = "Abrir",
    bRename = "Renomear",
    bDelete = "Excluir",
    bBack = "Voltar",
    bYes = "Sim",
    bNo = "Não",
    bOk = "OK",
    bCancel = "Cancelar",
    emptyDir = "(pasta vazia)",
    confirmDel = "Excluir %s?  [S/N]",
    sysWarn = "SISTEMA: %s - excluir mesmo assim?  [S/N]",
    sysLocked = "Arquivo do sistema: não pode renomear",
    renamePrompt = "Novo nome:",
    deleted = "Excluído",
    renamed = "Renomeado",
    nameExists = "Esse nome já existe",
    nameBad = "Nome inválido",
    binaryFile = "Arquivo binário, não dá para mostrar",
    errPrefix = "Erro: ",
    truncated = "(arquivo cortado)",
    calcErr = "Erro",
    loadSys = "Carregando sistema...",
    loadUser = "Carregando usuário...",
    loadDesk = "Preparando a área de trabalho...",
    loadDone = "Pronto!",
    loaded = "Carregado",
    errTitle = "ERRO FATAL DO SISTEMA",
    errTitleApp = "ERRO NO SISTEMA",
    errContinue = "Enter Continuar",
    errRestart = "Enter Reiniciar",
    e203 = "Sistema corrompido",
    e204 = "Sistema sem RAM",
    e205 = "Falha ao atualizar",
    e206 = "Problema no boot do sistema",
    e207 = "Problema em app ou usuário",
    e208 = "Erro desconhecido",
    e209 = "Falha na interface (GUI)",
    e210 = "Falha no kernel",
    e211 = "Possivel virus no sistema",
    wifi = "Rede",
    wifiType = "Tipo",
    wifiStatus = "Status",
    wifiOk = "Conectado",
    wifiWarn = "Placa sem HTTP",
    wifiNone = "Sem placa de rede",
    wifiWireless = "Sem fio ativo, sem Internet Card",
    wifiWired = "Rede local, sem internet",
    wifiTest = "Testar conexão",
    wifiTesting = "Testando...",
    wifiTestOk = "Conexão OK (%s)",
    wifiTestFail = "Falhou: %s",
    wifiRange = "Alcance do sinal",
    wifiNoCard = "Sem Internet Card",
    mSettings = "Configurações",
    xNew = "Novo",
    xNewNote = "Nova",
    xSave = "Salvar",
    xNoName = "(sem nome)",
    xPathAsk = "Abrir arquivo:",
    xSaveAsk = "Salvar como:",
    xUnsaved = "Alterações não salvas! Feche de novo",
    xDiscard = "Descartar alterações? [S/N]",
    xTooBig = "Arquivo grande demais (máx. 16 KB)",
    xNotFound = "Arquivo não encontrado",
    xIsDir = "Isso é uma pasta",
    xPos = "Ln %d, Col %d   (%d linhas)",
    xSaved = "Salvo!",
    xNoteAsk = "Nome da nota:",
    xNoNotes = "(nenhuma nota ainda)",
    xNoteDel = "Excluir a nota %s? [S/N]",
    pNone = "Impressora 3D não encontrada",
    pHint = "Conecte uma impressora 3D ao computador",
    pState = "Estado",
    pIdle = "Ociosa",
    pBusy = "Imprimindo",
    pModel = "Modelo",
    pTex = "Textura",
    pQty = "Qtd",
    pPrint = "Imprimir",
    pStarted = "Impressão iniciada!",
    pFail = "Falhou: %s",
    pCube = "Cubo",
    pPillar = "Pilar",
    pSlab = "Placa",
    pStairs = "Escada",
    pStone = "Pedra",
    pCobble = "Pedreg.",
    pWood = "Madeira",
    pIron = "Ferro",
    sLang = "Idioma",
    sTheme = "Tema",
    sUser = "Usuário",
    sPass = "Senha",
    sStatus = "Estado do Sistema",
    sAbout = "Sobre",
    sThemeRed = "Vermelho Nitro",
    sThemeBlue = "Azul",
    sThemePurple = "Roxo",
    sThemeHalloween = "Halloween",
    sThemeNatal = "Natal",
    sNewUser = "Novo nome de usuário:",
    sCurPass = "Senha atual:",
    sNewPass = "Nova senha (vazio = sem senha):",
    sRepeat = "Repita a nova senha:",
    sWrongPass = "Senha atual incorreta",
    sPassSet = "Senha alterada",
    sPassOff = "Senha removida",
    sUserSet = "Usuário alterado",
    sPassOn = "(com senha)",
    sPassNone = "(sem senha)",
    sFree = "RAM livre",
    sNet = "Internet",
    sTestNet = "Testar internet",
    sTesting = "Testando...",
    sTitle = "CONFIGURAÇÕES",
    sVersion = "Versão %s",
    sFor = "Para OpenComputers",
    sEdition = "Edição",
    sUpdate = "Atualizar Nitro OS",
    sWallpaper = "Trocar fundo",
    uTitle = "Atualizar Nitro OS",
    uInstalled = "Versão instalada",
    uOnline = "Versão no GitHub",
    uCheck = "Verificar atualização",
    uNow = "Atualizar agora",
    uRestart = "Reiniciar",
    uChecking = "Verificando...",
    uUpToDate = "Seu Nitro OS está atualizado",
    uAvailable = "Atualização disponível!",
    uDownloading = "Baixando %d/%d: %s",
    uApplying = "Aplicando a atualização...",
    uDone = "Atualizado! Reinicie o computador",
    uFail = "Falhou: %s",
    uBadManifest = "NitroOS_atualizar.lua inválido",
    uLowRam = "Pouca RAM livre para atualizar",
    wTitle = "Trocar fundo",
    wDefault = "Padrão (logo Nitro)",
    wNone = "Preto (sem imagem)",
    wImage = "Imagem",
    wVideo = "Vídeo (quadros)",
    wApplied = "Fundo aplicado",
    wHint = "Clique ou Enter para aplicar",
    mGitDown = "GitDown",
    gUrl = "Link do GitHub (cole com o botão do meio):",
    gDownload = "Baixar",
    gOpenFolder = "Pasta",
    gRun = "Executar",
    gRunSafe = "Restrito",
    gBadUrl = "Link inválido (use um link do GitHub)",
    gDownloading = "Baixando... %d KB",
    gSaved = "Salvo em %s",
    gEmpty = "(pasta /Download vazia)",
    gNeedLua = "Só arquivos .lua podem ser executados",
    gWarn1 = "ATENÇÃO: este modo tem acesso TOTAL ao computador.",
    gWarn2 = "Só execute arquivos em que você confia.",
    gRunAnyway = "Executar mesmo assim",
    gOutput = "Resultado de %s",
    gDelAsk = "Excluir %s? Não dá para desfazer [S/N]",
    gFail = "Falhou: %s",
    gTooBig = "Arquivo grande demais (máx. 128 KB)",
    gNoOutput = "(terminou sem mostrar nada)",
    gRunErr = "Erro: %s",
    gSafeNote = "Restrito: sem acesso ao computador",
    gBack = "Voltar",
    mAntivirus = "Antivírus",
    mStore = "AppStore",
    stTitle = "NITRO APPSTORE",
    stLoading = "Carregando lista de apps...",
    stEmpty = "Nenhum app na lista",
    stInstall = "Instalar",
    stInstalling = "Baixando %s...",
    stScan = "Analisando %s...",
    stSaved = "Instalado em /apps/%s",
    stDanger = "BLOQUEADO: análise perigosa (%d/100)",
    stWarn = "Análise suspeita (%d/100). Instalar mesmo assim?",
    stYes = "Instalar",
    mMyApps = "Meus Apps",
    maTitle = "Apps instalados (/apps)",
    maEmpty = "(nenhum app instalado)",
    maHint = "Instale pela AppStore ou copie para /apps",
    maBlocked = "BLOQUEADO pelo Antivírus (%d/100)",
    maRunErr = "Erro: %s",
    maOutput = "Saída de %s",
    maDelAsk = "Excluir o app %s? [S/N]",
    fxHome = "Este Computador",
    fxFolders = "Pastas",
    fxDrives = "Unidades",
    fxDl = "Downloads",
    fxNotes = "Notas",
    fxApps = "Apps",
    fxWalls = "Fundos",
    fxRoot = "Raiz do disco",
    fxBoot = "(sistema)",
    fxRO = "(somente leitura)",
    fxROMsg = "Disco somente leitura",
    fxItems = "%d itens",
    fxSel = "%d selecionado",
    fxMove = "Mover",
    fxPaste = "Colar aqui",
    fxMoving = "Mover '%s': abra a pasta de destino e clique em Colar aqui",
    fxMoved = "Movido!",
    fxCopying = "Copiando %s...",
    fxExists = "Já existe no destino",
    fxSame = "Já está nesta pasta",
    fxIntoSelf = "Uma pasta não pode ir para dentro dela mesma",
    fxFree = "%s livres de %s",
    fxOpenFirst = "Abra uma pasta primeiro",
    fxCreate = "+ Criar",
    fxCreatePrompt = "Nome do novo arquivo:",
    fxCreated = "Criado",
    xLib = "Biblioteca",
    xInsert = "Inserir",
    xLibEmpty = "Biblioteca vazia (pasta /nitro/biblioteca)",
    xInserted = "Trecho inserido",
    svTitle = "Segurança do Nitro OS",
    svVirusT = "Vírus e ameaças",
    svAccT = "Conta",
    svNetT = "Rede e firewall",
    svAppsT = "Controle de apps",
    svIntT = "Integridade",
    svPerfT = "Desempenho",
    svNoAction = "Nenhuma ação necessária",
    svNoScan = "Nenhum scan ainda",
    svThreat = "%d perigoso(s)",
    svSusp = "%d suspeito(s)",
    svScanned = "%d arquivo(s)",
    svPassOn = "Senha ativa",
    svPassOff = "Sem senha",
    svNetOk = "Internet pronta",
    svNetWarn = "Sem HTTP ativo",
    svNetNone = "Sem placa de rede",
    svTestNet = "Clique para testar",
    svAppsCount = "%d app(s)",
    svAppsBad = "%d com alerta",
    svIntOk = "Arquivos do sistema OK",
    svIntNone = "Clique para verificar",
    svIntBad = "%d com problema",
    svRam = "RAM livre: %d KB",
    svBtnFolders = "Pastas",
    svBtnApps = "Apps",
    svBtnCheck = "Sistema",
    svBtnHist = "Histórico",
    svDone = "Análise concluída",
    svNoLog = "Histórico vazio",
    svNote = "Análise sob demanda, não proteção contínua. Indício, não prova.",
    mRedeLocal = "Rede Local",
    rlSearch = "Procurar",
    rlSearching = "Procurando computadores...",
    rlNoCard = "Sem Wireless Network Card",
    rlMsg = "Mensagem",
    rlFile = "Arquivo",
    rlNoPeers = "Nenhum computador por perto (clique em Procurar)",
    rlFrom = "%s: %s",
    rlNewMsg = "Nova mensagem recebida",
    rlAsk = "%s quer enviar %s (%s)",
    rlAccept = "Aceitar",
    rlReject = "Recusar",
    rlSending = "Enviando %d/%d...",
    rlSent = "Enviado",
    rlTooBig = "Arquivo grande demais (máx. 128 KB)",
    rlPickFile = "Escolha um arquivo de /Download",
    rlNoDownloads = "(pasta /Download vazia)",
    rlNeedPeer = "Escolha um computador da lista",
    rlInput = "Mensagem:",
    rlRecv = "Recebido: %s",
    rlBlocked = "Bloqueado pelo antivírus: %s",
    rlIncomplete = "Arquivo incompleto: %s",
    rlStrength = "Alcance: %d",
    rlSend = "Enviar",
    edCopied = "Copiado",
    mEditorLua = "Editor Lua",
    bSave = "Salvar",
    mLock = "Bloquear",
    lkPress = "Pressione uma tecla ou clique para entrar",
    lkEnter = "Digite a senha",
    lkWrong = "Senha incorreta",
    lkAuto = "Bloquear após",
    lkNever = "Nunca",
    lkMin = "%d min",
    lkEsc = "Esc voltar",
    rlAll = "Todos na rede",
    rlYou = "Você",
    rlEmptyChat = "Nenhuma mensagem ainda",
    rlComputers = "Computadores",
    rlPlaceholder = "Digite uma mensagem...",
    asTabHome = "Início",
    asTabApps = "Apps",
    asTabUpdate = "Atualizar",
    asTabRemove = "Remover",
    asCatAll = "Tudo",
    asCatGames = "Jogos",
    asCatTools = "Ferramentas",
    asCatSystem = "Sistema",
    asCatEdu = "Educação",
    asSearch = "Pesquisar...",
    asInstall = "Instalar",
    asInstalled = "Instalado",
    asUpdateBtn = "Atualizar",
    asRemoveBtn = "Remover",
    asPrev = "< Ant",
    asNext = "Prox >",
    asPage = "Página %d de %d",
    asNone = "Nenhum app aqui",
    asReload = "Recarregar",
    asRemoved = "Removido: %s",
    edPasted = "Colado",
    cSys = "Sistema",
    cNet = "Rede",
    cLook = "Personalização",
    cApps = "Aplicativos",
    cAcc = "Contas",
    cTime = "Hora e idioma",
    cPriv = "Privacidade",
    cUpd = "Atualização",
    cLocal = "Rede Local",
    cLocalHint = "Procurar e enviar",
    cClock = "Data e hora",
    cHidden = "Ícones ocultos",
    cHiddenStatus = "%d oculto(s)",
    cSecLog = "Histórico de segurança",
    cShownOk = "Ícones mostrados",
    ctxOpen = "Abrir",
    ctxHide = "Ocultar (remove o ícone só da tela, não apaga nada)",
    ctxShortcut = "Criar atalho",
    ctxWhere = "Abrir local do arquivo",
    ctxShowHidden = "Mostrar ícones ocultos",
    mTerm = "Terminal",
    tmHelp = "Comandos: help ls cd pwd cat tail mkdir touch echo rm cp mv date net ping apps history install mem uptime ver clear exit",
    tmVer = "Nitro OS %s - Terminal seguro",
    tmNoCmd = "Comando desconhecido: %s  (digite help)",
    tmNoFile = "Não encontrado: %s",
    tmIsDir = "É uma pasta: %s",
    tmNoDir = "Pasta não encontrada: %s",
    tmUsage = "Uso: %s <nome>",
    tmBadName = "Nome inválido",
    tmCatBig = "(mostrando só os primeiros 2 KB)",
    tmBin = "(arquivo binário)",
    tmDone = "Feito.",
    tmProt = "Protegido: %s",
    tmCopied = "Copiado",
    tmMoved = "Movido",
    tmWritten = "Gravado",
    tmNoApp = "App não encontrado: %s",
    tmInstalling = "Instalando %s...",
    tmInstalled = "Instalado: %s",
    tmBlocked = "Bloqueado pelo antivírus (%d/100)",
    tmSuspect = "Suspeito (%d/100). Instale pela AppStore para confirmar.",
    tmNetState = "Internet: %s",
    tmPingOk = "Resposta em %s",
    tmHistEmpty = "(sem histórico)",
    stNo = "Não",
    stRefresh = "Atualizar",
    stRefreshing = "Atualizando a lista...",
    stRefreshed = "Lista atualizada (%d)",
    stBad = "Lista inválida (app/apps.lua)",
    stSyntax = "Código Lua inválido",
    stFail = "Falhou: %s",
    stRepo = "github.com/pmiguel10766-stack/nitro-appstore",
    avPath = "Arquivo para analisar:",
    avScan = "Analisar",
    avFiles = "Arquivos em /Download",
    avSafe = "SEGURO",
    avWarn = "SUSPEITO",
    avDanger = "PERIGOSO",
    avVerdict = "Veredito: %s (%d/100)",
    avWarnLine = "Análise: %s (%d/100)",
    avNone = "Nenhum indício encontrado",
    avNote = "Só lê o texto do código, não executa nada. Não é garantia.",
    avNoFile = "Arquivo não encontrado",
    avBig = "Arquivo grande demais para analisar",
    avScanned = "Análise de %s",
    avLineWord = "linha",
    avCatWipe = "APAGAR",
    avCatCrash = "TRAVAR",
    avCatSpy = "ESPIONAR",
    avCatWorm = "ESPALHAR",
    avCatHide = "ESCONDER",
    avRRemove = "apaga arquivos do sistema",
    avREeprom = "mexe na EEPROM",
    avRWipeLoop = "lista a raiz e apaga",
    avRInit = "reescreve o init.lua",
    avRLoop = "laço sem pausa",
    avRRep = "texto gigante (string.rep)",
    avRSpy = "lê dados e usa internet",
    avRHost = "fala com site fora do GitHub",
    avRNet = "usa internet",
    avRWorm = "envia por rede e se instala",
    avRLoad = "executa texto como código",
    avRObf = "texto muito codificado",
    avRLong = "linha muito longa",
    avRB64 = "texto parece codificado",
  } },
  { name = "English", t = {
    steps = { "Language", "User", "Password" },
    userTitle = "Create user",
    userAsk = "Username:",
    userEmpty = "Type a name",
    prepHello = "Hello, %s",
    prepPreparing = "We are getting everything ready for you",
    prepMinutes = "This may take a few minutes.",
    prepWarn = "Warning: Do not turn off the computer",
    passTitle = "Password (optional)",
    passAsk = "Password (Enter to skip):",
    passConfirm = "Repeat the password:",
    passMismatch = "Passwords do not match",
    keysInput = "Enter OK    Esc Back",
    loginTitle = "Sign in",
    loginHello = "Hello, %s",
    loginAsk = "Password:",
    loginWrong = "Wrong password",
    loginKeys = "Enter Sign in",
    welcome = "Welcome, %s!",
    ready = "Nitro OS is ready.",
    cont = " Enter  Continue ",
    empty = "No apps installed yet",
    hint = "Click ◆ Nitro to open the Menu",
    soon = "Coming soon",
    mFiles = "Files",
    mEditor = "Text Editor",
    mCalc = "Calculator",
    mMonitor = "System Monitor",
    mNotes = "Notes",
    mPrinter = "3D Printer",
    mRestart = "Restart",
    mShutdown = "Shut down",
    ram = "RAM",
    energy = "Energy",
    uptime = "Uptime",
    bUp = "↑ Up",
    bOpen = "Open",
    bRename = "Rename",
    bDelete = "Delete",
    bBack = "Back",
    bYes = "Yes",
    bNo = "No",
    bOk = "OK",
    bCancel = "Cancel",
    emptyDir = "(empty folder)",
    confirmDel = "Delete %s?  [Y/N]",
    sysWarn = "SYSTEM: %s - delete anyway?  [Y/N]",
    sysLocked = "System file: cannot be renamed",
    renamePrompt = "New name:",
    deleted = "Deleted",
    renamed = "Renamed",
    nameExists = "That name already exists",
    nameBad = "Invalid name",
    binaryFile = "Binary file, cannot display",
    errPrefix = "Error: ",
    truncated = "(file truncated)",
    calcErr = "Error",
    loadSys = "Loading system...",
    loadUser = "Loading user...",
    loadDesk = "Preparing the desktop...",
    loadDone = "Done!",
    loaded = "Loaded",
    errTitle = "FATAL SYSTEM ERROR",
    errTitleApp = "SYSTEM ERROR",
    errContinue = "Enter Continue",
    errRestart = "Enter Restart",
    e203 = "System corrupted",
    e204 = "System out of RAM",
    e205 = "Update failed",
    e206 = "System boot problem",
    e207 = "App or user problem",
    e208 = "Unknown error",
    e209 = "Interface (GUI) failure",
    e210 = "Kernel failure",
    e211 = "Possible virus in the system",
    wifi = "Network",
    wifiType = "Type",
    wifiStatus = "Status",
    wifiOk = "Connected",
    wifiWarn = "Card without HTTP",
    wifiNone = "No network card",
    wifiWireless = "Wireless on, no Internet Card",
    wifiWired = "Local network, no internet",
    wifiTest = "Test connection",
    wifiTesting = "Testing...",
    wifiTestOk = "Connection OK (%s)",
    wifiTestFail = "Failed: %s",
    wifiRange = "Signal range",
    wifiNoCard = "No Internet Card",
    mSettings = "Settings",
    xNew = "New",
    xNewNote = "New",
    xSave = "Save",
    xNoName = "(no name)",
    xPathAsk = "Open file:",
    xSaveAsk = "Save as:",
    xUnsaved = "Unsaved changes! Close again",
    xDiscard = "Discard changes? [Y/N]",
    xTooBig = "File too large (max. 16 KB)",
    xNotFound = "File not found",
    xIsDir = "That is a folder",
    xPos = "Ln %d, Col %d   (%d lines)",
    xSaved = "Saved!",
    xNoteAsk = "Note name:",
    xNoNotes = "(no notes yet)",
    xNoteDel = "Delete note %s? [Y/N]",
    pNone = "3D printer not found",
    pHint = "Connect a 3D printer to the computer",
    pState = "Status",
    pIdle = "Idle",
    pBusy = "Printing",
    pModel = "Model",
    pTex = "Texture",
    pQty = "Qty",
    pPrint = "Print",
    pStarted = "Printing started!",
    pFail = "Failed: %s",
    pCube = "Cube",
    pPillar = "Pillar",
    pSlab = "Slab",
    pStairs = "Stairs",
    pStone = "Stone",
    pCobble = "Cobble",
    pWood = "Wood",
    pIron = "Iron",
    sLang = "Language",
    sTheme = "Theme",
    sUser = "User",
    sPass = "Password",
    sStatus = "System Status",
    sAbout = "About",
    sThemeRed = "Nitro Red",
    sThemeBlue = "Blue",
    sThemePurple = "Purple",
    sThemeHalloween = "Halloween",
    sThemeNatal = "Christmas",
    sNewUser = "New username:",
    sCurPass = "Current password:",
    sNewPass = "New password (empty = none):",
    sRepeat = "Repeat the new password:",
    sWrongPass = "Wrong current password",
    sPassSet = "Password changed",
    sPassOff = "Password removed",
    sUserSet = "Username changed",
    sPassOn = "(set)",
    sPassNone = "(none)",
    sFree = "Free RAM",
    sNet = "Internet",
    sTestNet = "Test internet",
    sTesting = "Testing...",
    sTitle = "SETTINGS",
    sVersion = "Version %s",
    sFor = "For OpenComputers",
    sEdition = "Edition",
    sUpdate = "Update Nitro OS",
    sWallpaper = "Change wallpaper",
    uTitle = "Update Nitro OS",
    uInstalled = "Installed version",
    uOnline = "Version on GitHub",
    uCheck = "Check for updates",
    uNow = "Update now",
    uRestart = "Restart",
    uChecking = "Checking...",
    uUpToDate = "Your Nitro OS is up to date",
    uAvailable = "Update available!",
    uDownloading = "Downloading %d/%d: %s",
    uApplying = "Applying the update...",
    uDone = "Updated! Restart the computer",
    uFail = "Failed: %s",
    uBadManifest = "NitroOS_atualizar.lua is invalid",
    uLowRam = "Not enough free RAM to update",
    wTitle = "Change wallpaper",
    wDefault = "Default (Nitro logo)",
    wNone = "Black (no image)",
    wImage = "Image",
    wVideo = "Video (frames)",
    wApplied = "Wallpaper applied",
    wHint = "Click or Enter to apply",
    mGitDown = "GitDown",
    gUrl = "GitHub link (paste with middle click):",
    gDownload = "Download",
    gOpenFolder = "Folder",
    gRun = "Run",
    gRunSafe = "Restricted",
    gBadUrl = "Invalid link (use a GitHub link)",
    gDownloading = "Downloading... %d KB",
    gSaved = "Saved to %s",
    gEmpty = "(/Download folder is empty)",
    gNeedLua = "Only .lua files can be run",
    gWarn1 = "WARNING: this mode has FULL access to the computer.",
    gWarn2 = "Only run files you trust.",
    gRunAnyway = "Run anyway",
    gOutput = "Result of %s",
    gDelAsk = "Delete %s? This cannot be undone [Y/N]",
    gFail = "Failed: %s",
    gTooBig = "File too large (max. 128 KB)",
    gNoOutput = "(finished without output)",
    gRunErr = "Error: %s",
    gSafeNote = "Restricted: no access to the computer",
    gBack = "Back",
    mAntivirus = "Antivirus",
    mStore = "AppStore",
    stTitle = "NITRO APPSTORE",
    stLoading = "Loading app list...",
    stEmpty = "No apps in the list",
    stInstall = "Install",
    stInstalling = "Downloading %s...",
    stScan = "Scanning %s...",
    stSaved = "Installed to /apps/%s",
    stDanger = "BLOCKED: dangerous analysis (%d/100)",
    stWarn = "Suspicious analysis (%d/100). Install anyway?",
    stYes = "Install",
    mMyApps = "My Apps",
    maTitle = "Installed apps (/apps)",
    maEmpty = "(no apps installed)",
    maHint = "Install from the AppStore or copy to /apps",
    maBlocked = "BLOCKED by the Antivirus (%d/100)",
    maRunErr = "Error: %s",
    maOutput = "Output of %s",
    maDelAsk = "Delete the app %s? [Y/N]",
    fxHome = "This Computer",
    fxFolders = "Folders",
    fxDrives = "Drives",
    fxDl = "Downloads",
    fxNotes = "Notes",
    fxApps = "Apps",
    fxWalls = "Wallpapers",
    fxRoot = "Disk root",
    fxBoot = "(system)",
    fxRO = "(read-only)",
    fxROMsg = "Read-only disk",
    fxItems = "%d items",
    fxSel = "%d selected",
    fxMove = "Move",
    fxPaste = "Paste here",
    fxMoving = "Move '%s': open the destination folder and click Paste here",
    fxMoved = "Moved!",
    fxCopying = "Copying %s...",
    fxExists = "Already exists in the destination",
    fxSame = "Already in this folder",
    fxIntoSelf = "A folder cannot go inside itself",
    fxFree = "%s free of %s",
    fxOpenFirst = "Open a folder first",
    fxCreate = "+ New",
    fxCreatePrompt = "New file name:",
    fxCreated = "Created",
    xLib = "Library",
    xInsert = "Insert",
    xLibEmpty = "Library is empty (folder /nitro/biblioteca)",
    xInserted = "Snippet inserted",
    svTitle = "Nitro OS Security",
    svVirusT = "Virus & threats",
    svAccT = "Account",
    svNetT = "Network",
    svAppsT = "App control",
    svIntT = "Integrity",
    svPerfT = "Performance",
    svNoAction = "No action needed",
    svNoScan = "No scan yet",
    svThreat = "%d dangerous",
    svSusp = "%d suspicious",
    svScanned = "%d file(s)",
    svPassOn = "Password on",
    svPassOff = "No password",
    svNetOk = "Internet ready",
    svNetWarn = "HTTP not enabled",
    svNetNone = "No network card",
    svTestNet = "Click to test",
    svAppsCount = "%d app(s)",
    svAppsBad = "%d flagged",
    svIntOk = "System files OK",
    svIntNone = "Click to check",
    svIntBad = "%d with issues",
    svRam = "Free RAM: %d KB",
    svBtnFolders = "Folders",
    svBtnApps = "Apps",
    svBtnCheck = "System",
    svBtnHist = "History",
    svDone = "Scan finished",
    svNoLog = "History is empty",
    svNote = "On-demand scan, not continuous protection. Indication, not proof.",
    mRedeLocal = "Local Network",
    rlSearch = "Search",
    rlSearching = "Searching for computers...",
    rlNoCard = "No Wireless Network Card",
    rlMsg = "Message",
    rlFile = "File",
    rlNoPeers = "No computers nearby (click Search)",
    rlFrom = "%s: %s",
    rlNewMsg = "New message received",
    rlAsk = "%s wants to send %s (%s)",
    rlAccept = "Accept",
    rlReject = "Reject",
    rlSending = "Sending %d/%d...",
    rlSent = "Sent",
    rlTooBig = "File too large (max. 128 KB)",
    rlPickFile = "Pick a file from /Download",
    rlNoDownloads = "(/Download is empty)",
    rlNeedPeer = "Pick a computer from the list",
    rlInput = "Message:",
    rlRecv = "Received: %s",
    rlBlocked = "Blocked by antivirus: %s",
    rlIncomplete = "Incomplete file: %s",
    rlStrength = "Range: %d",
    rlSend = "Send",
    edCopied = "Copied",
    mEditorLua = "Lua Editor",
    bSave = "Save",
    mLock = "Lock",
    lkPress = "Press a key or click to sign in",
    lkEnter = "Enter password",
    lkWrong = "Wrong password",
    lkAuto = "Lock after",
    lkNever = "Never",
    lkMin = "%d min",
    lkEsc = "Esc back",
    rlAll = "All in network",
    rlYou = "You",
    rlEmptyChat = "No messages yet",
    rlComputers = "Computers",
    rlPlaceholder = "Type a message...",
    asTabHome = "Home",
    asTabApps = "Apps",
    asTabUpdate = "Update",
    asTabRemove = "Remove",
    asCatAll = "All",
    asCatGames = "Games",
    asCatTools = "Tools",
    asCatSystem = "System",
    asCatEdu = "Education",
    asSearch = "Search...",
    asInstall = "Install",
    asInstalled = "Installed",
    asUpdateBtn = "Update",
    asRemoveBtn = "Remove",
    asPrev = "< Prev",
    asNext = "Next >",
    asPage = "Page %d of %d",
    asNone = "No apps here",
    asReload = "Reload",
    asRemoved = "Removed: %s",
    edPasted = "Pasted",
    cSys = "System",
    cNet = "Network",
    cLook = "Personalization",
    cApps = "Apps",
    cAcc = "Accounts",
    cTime = "Time & language",
    cPriv = "Privacy",
    cUpd = "Update",
    cLocal = "Local network",
    cLocalHint = "Search and send",
    cClock = "Date & time",
    cHidden = "Hidden icons",
    cHiddenStatus = "%d hidden",
    cSecLog = "Security history",
    cShownOk = "Icons shown",
    ctxOpen = "Open",
    ctxHide = "Hide (removes the icon from the screen only, deletes nothing)",
    ctxShortcut = "Create shortcut",
    ctxWhere = "Open file location",
    ctxShowHidden = "Show hidden icons",
    mTerm = "Terminal",
    tmHelp = "Commands: help ls cd pwd cat tail mkdir touch echo rm cp mv date net ping apps history install mem uptime ver clear exit",
    tmVer = "Nitro OS %s - Safe Terminal",
    tmNoCmd = "Unknown command: %s  (type help)",
    tmNoFile = "Not found: %s",
    tmIsDir = "It is a folder: %s",
    tmNoDir = "Folder not found: %s",
    tmUsage = "Usage: %s <name>",
    tmBadName = "Invalid name",
    tmCatBig = "(showing only the first 2 KB)",
    tmBin = "(binary file)",
    tmDone = "Done.",
    tmProt = "Protected: %s",
    tmCopied = "Copied",
    tmMoved = "Moved",
    tmWritten = "Written",
    tmNoApp = "App not found: %s",
    tmInstalling = "Installing %s...",
    tmInstalled = "Installed: %s",
    tmBlocked = "Blocked by antivirus (%d/100)",
    tmSuspect = "Suspicious (%d/100). Install from the AppStore to confirm.",
    tmNetState = "Internet: %s",
    tmPingOk = "Reply in %s",
    tmHistEmpty = "(no history)",
    stNo = "No",
    stRefresh = "Refresh",
    stRefreshing = "Refreshing the list...",
    stRefreshed = "List refreshed (%d)",
    stBad = "Invalid list (app/apps.lua)",
    stSyntax = "Invalid Lua code",
    stFail = "Failed: %s",
    stRepo = "github.com/pmiguel10766-stack/nitro-appstore",
    avPath = "File to analyze:",
    avScan = "Analyze",
    avFiles = "Files in /Download",
    avSafe = "SAFE",
    avWarn = "SUSPICIOUS",
    avDanger = "DANGEROUS",
    avVerdict = "Verdict: %s (%d/100)",
    avWarnLine = "Analysis: %s (%d/100)",
    avNone = "No signs found",
    avNote = "Only reads the code text, runs nothing. Not a guarantee.",
    avNoFile = "File not found",
    avBig = "File too large to analyze",
    avScanned = "Analysis of %s",
    avLineWord = "line",
    avCatWipe = "WIPE",
    avCatCrash = "CRASH",
    avCatSpy = "SPY",
    avCatWorm = "SPREAD",
    avCatHide = "HIDE",
    avRRemove = "deletes system files",
    avREeprom = "touches the EEPROM",
    avRWipeLoop = "lists the root and deletes",
    avRInit = "rewrites init.lua",
    avRLoop = "loop without pause",
    avRRep = "huge text (string.rep)",
    avRSpy = "reads data and uses internet",
    avRHost = "talks to a non-GitHub site",
    avRNet = "uses internet",
    avRWorm = "sends over network and installs itself",
    avRLoad = "runs text as code",
    avRObf = "heavily encoded text",
    avRLong = "very long line",
    avRB64 = "text looks encoded",
  } },
}

local T = langs[1].t

---------------------------------------------------------------- tela de erro (codigo MX)
local function classify(err, default)
  local s = tostring(err):lower()
  if s:find("not enough memory", 1, true) or s:find("out of memory", 1, true) then
    return 204
  end
  return default
end

-- fundo preto, moldura vermelha, icone [X], codigo MX e detalhe tecnico.
-- canContinue = true: Enter continua. false: Enter reinicia o computador.
local function errorScreen(code, detail, canContinue)
  local ew = math.min(w - 4, 60)
  local eh = math.min(h - 4, 12)
  local ex = math.floor((w - ew) / 2) + 1
  local ey = math.floor((h - eh) / 2) + 1
  rect(1, 1, w, h, C.bg)
  local line = string.rep("─", ew - 2)
  put(ex, ey, "╭" .. line .. "╮", C.accent, C.bg)
  for r = 1, eh - 2 do
    put(ex, ey + r, "│", C.accent, C.bg)
    put(ex + ew - 1, ey + r, "│", C.accent, C.bg)
  end
  put(ex, ey + eh - 1, "╰" .. line .. "╯", C.accent, C.bg)

  local ix = ex + 3
  local icon = { "┏━     ━┓", "┃ ╲   ╱ ┃", "┃   ╳   ┃", "┃ ╱   ╲ ┃", "┗━     ━┛" }
  for i, row in ipairs(icon) do put(ix, ey + 1 + i, row, C.accent, C.bg) end

  local tx, tw = ix + 12, ew - 17
  put(tx, ey + 2, canContinue and T.errTitleApp or T.errTitle, C.accent, C.bg, tw)
  put(tx, ey + 3, string.rep("─", tw), C.accent, C.bg)
  put(tx, ey + 4, string.format("MX-%d  %s", code, T["e" .. code] or T.e208),
    C.text, C.bg, tw)
  local text = tostring(detail or ""):gsub("%s+", " ")
  for n = 0, 2 do
    local part = usub(text, n * tw + 1, (n + 1) * tw)
    if ulen(part) > 0 then put(tx, ey + 5 + n, part, C.dim, C.bg, tw) end
  end
  put(ix, ey + eh - 4, string.rep("▞", ew - 6), C.accent, C.bg)
  put(ix, ey + eh - 2, canContinue and T.errContinue or T.errRestart, C.dim, C.bg)

  while true do
    if key() == 28 then break end
  end
  if not canContinue then cp.shutdown(true) end
end


---------------------------------------------------------------- moldura
local function frame(step, title)
  rect(1, 1, w, h, C.bg)
  rect(1, 1, w, 1, C.panel)
  put(2, 1, "◆ NITRO OS", C.accent, C.panel)

  if step then
    local x = px
    for i, name in ipairs(T.steps) do
      local label = " " .. i .. " " .. name .. " "
      if i == step then
        put(x, 2, label, C.bg, C.accent)
      elseif i < step then
        put(x, 2, label, C.ok, C.bg)
      else
        put(x, 2, label, C.dim, C.bg)
      end
      x = x + ulen(label) + 1
    end
  end

  rect(px, py, pw, ph, C.panel)
  local line = string.rep("─", pw - 2)
  put(px, py, "╭" .. line .. "╮", C.accent, C.panel)
  for r = 1, ph - 2 do
    put(px, py + r, "│", C.accent, C.panel)
    put(px + pw - 1, py + r, "│", C.accent, C.panel)
  end
  put(px, py + ph - 1, "╰" .. line .. "╯", C.accent, C.panel)
  if title then put(px + 2, py, " " .. title .. " ", C.text, C.panel, pw - 6) end
end

local function message(text, color)
  rect(px + 1, py + ph - 3, pw - 2, 1, C.panel)
  if text and text ~= "" then put(cx, py + ph - 3, text, color or C.warn, C.panel, cw) end
end

---------------------------------------------------------------- utilitarios
local function readFile(path)
  local hnd = fs.open(path)
  if not hnd then return nil end
  local data = ""
  repeat
    local c = fs.read(hnd, math.huge)
    data = data .. (c or "")
  until not c
  fs.close(hnd)
  return data
end

-- hash simples, so para nao guardar a senha em texto puro (nao e seguranca real)
local function hash(s)
  s = "nitro:" .. s
  local x = 5381
  for i = 1, #s do x = (x * 33 + s:byte(i)) % 4294967296 end
  return string.format("%08x", x)
end

local configBad = false

local function loadConfig()
  if not fs.exists(CONFIG) then return nil end
  local data = readFile(CONFIG)
  local f = data and load(data, "=config", "t", {})
  if f then
    local ok, cfg = pcall(f)
    if ok and type(cfg) == "table" and cfg.user then return cfg end
  end
  configBad = true
  return nil
end

local function saveConfig(cfg)
  fs.makeDirectory("/nitro")
  local hnd = fs.open(CONFIG, "w")
  local hashText = cfg.hash and string.format("%q", cfg.hash) or "nil"
  local hid = "{"
  for k in pairs(cfg.hidden or {}) do hid = hid .. string.format("[%q]=true,", k) end
  hid = hid .. "}"
  fs.write(hnd, string.format("return {user=%q,lang=%d,hash=%s,theme=%q,wallpaper=%q,hidden=%s,lockMin=%d}",
    cfg.user, cfg.lang, hashText, cfg.theme or "red", cfg.wallpaper or "default", hid, cfg.lockMin or 0))
  fs.close(hnd)
end

-- caixa de texto. Devolve (texto, "enter") ou (texto, "back") se apertar Esc
local function input(y, masked, maxLen)
  local text = ""
  local function draw()
    rect(cx, y, cw, 1, C.barbg)
    local shown = masked and string.rep("*", ulen(text)) or text
    put(cx + 1, y, shown .. "_", C.text, C.barbg, cw - 2)
  end
  draw()
  while true do
    local ev, _, char, code = cp.pullSignal()
    if ev == "key_down" then
      if code == 28 then
        return text, "enter"
      elseif code == 1 then
        return text, "back"
      elseif code == 14 then
        if ulen(text) > 0 then text = usub(text, 1, ulen(text) - 1) end
      elseif char and char >= 32 and char ~= 127 and ulen(text) < maxLen then
        text = text .. uchar(char)
      end
      draw()
    end
  end
end

---------------------------------------------------------------- primeiro boot
local function chooseLanguage()
  local sel = 1
  local function draw()
    frame(1, "Language / Idioma")
    put(cx, py + 2, "Escolha o idioma / Choose your language", C.dim, C.panel, cw)
    for i, l in ipairs(langs) do
      local y = py + 4 + (i - 1) * 2
      if i == sel then
        rect(cx - 1, y, cw + 2, 1, C.accent)
        put(cx, y, "▶ " .. l.name, C.bg, C.accent, cw)
      else
        put(cx, y, "  " .. l.name, C.text, C.panel, cw)
      end
    end
    footer("↑↓ Select / Escolher    Enter OK")
  end
  draw()
  while true do
    local code = key()
    if code == 200 and sel > 1 then
      sel = sel - 1
      draw()
    elseif code == 208 and sel < #langs then
      sel = sel + 1
      draw()
    elseif code == 28 then
      T = langs[sel].t
      return sel
    end
  end
end

local function ccenter(y, text, fg)
  put(math.floor((w - ulen(text)) / 2) + 1, y, text, fg, C.bg)
end

-- tela de preparo do primeiro boot: fundo preto, texto no centro e barra vermelha e preta
local function prepareUserScreen(cfg)
  rect(1, 1, w, h, C.bg)
  local y0 = math.max(2, math.floor(h / 2) - 4)
  ccenter(y0, string.format(T.prepHello, cfg.user), C.text)
  ccenter(y0 + 2, T.prepPreparing, C.dim)
  local barW = math.min(w - 10, 40)
  local barX = math.floor((w - barW) / 2) + 1
  local barY = y0 + 4
  ccenter(y0 + 5, T.prepMinutes, C.dim)
  ccenter(h - 1, T.prepWarn, C.warn)
  for pct = 0, 100, 4 do
    local filled = math.floor(barW * pct / 100)
    for x = 0, barW - 1 do
      local color = C.bg
      if x < filled and x % 2 == 0 then color = C.accent end
      rect(barX + x, barY, 1, 1, color)
    end
    pause(0.08)
  end
  pause(0.4)
end

local function setup()
  local cfg = {}
  local step, pending = 1, nil
  while true do
    if step == 1 then
      cfg.lang = chooseLanguage()
      step = 2

    elseif step == 2 then
      frame(2, T.userTitle)
      put(cx, py + 2, T.userAsk, C.dim, C.panel, cw)
      footer(T.keysInput)
      local name, how = input(py + 4, false, 16)
      name = name:match("^%s*(.-)%s*$")
      if how == "back" then
        step = 1
      elseif #name == 0 then
        message(T.userEmpty, C.warn)
        cp.pullSignal(1)
      else
        cfg.user = name
        step = 3
      end

    elseif step == 3 then
      frame(3, T.passTitle)
      put(cx, py + 2, T.passAsk, C.dim, C.panel, cw)
      footer(T.keysInput)
      local pass, how = input(py + 4, true, 32)
      if how == "back" then
        step = 2
      elseif pass == "" then
        cfg.hash = nil
        prepareUserScreen(cfg)
        return cfg
      else
        pending = pass
        step = 4
      end

    elseif step == 4 then
      frame(3, T.passTitle)
      put(cx, py + 2, T.passConfirm, C.dim, C.panel, cw)
      footer(T.keysInput)
      local again, how = input(py + 4, true, 32)
      if how == "back" then
        step = 3
      elseif again == pending then
        cfg.hash = hash(pending)
        prepareUserScreen(cfg)
        return cfg
      else
        message(T.passMismatch, C.err)
        cp.pullSignal(1)
        step = 3
      end
    end
  end
end

---------------------------------------------------------------- login
local function login(cfg)
  local wrong = false
  while true do
    frame(nil, T.loginTitle)
    center(py + 2, string.format(T.loginHello, cfg.user), C.text, C.panel)
    put(cx, py + 4, T.loginAsk, C.dim, C.panel, cw)
    footer(T.loginKeys)
    if wrong then message(T.loginWrong, C.err) end
    local pass = input(py + 6, true, 32)
    if hash(pass) == cfg.hash then return end
    wrong = true
  end
end

---------------------------------------------------------------- area de trabalho
local function clock()
  local ok, text = pcall(os.date, "%H:%M", os.time())
  return ok and text or "--:--"
end

local function fmtTime(s)
  s = math.floor(s)
  local hh, mm, ss = math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60
  if hh > 0 then return string.format("%dh %02dm", hh, mm) end
  return string.format("%dm %02ds", mm, ss)
end

local function inside(x, y, bx, by, bw, bh)
  return x >= bx and x < bx + bw and y >= by and y < by + bh
end

local function drawBox(x, y, bw, bh, title)
  rect(x, y, bw, bh, C.panel)
  local line = string.rep("─", bw - 2)
  put(x, y, "╭" .. line .. "╮", C.accent, C.panel)
  for r = 1, bh - 2 do
    put(x, y + r, "│", C.accent, C.panel)
    put(x + bw - 1, y + r, "│", C.accent, C.panel)
  end
  put(x, y + bh - 1, "╰" .. line .. "╯", C.accent, C.panel)
  if title then put(x + 2, y, " " .. title .. " ", C.text, C.panel, bw - 8) end
end

---------------------------------------------------------------- rede (Internet Card / Wireless Network Card)
local NET_TEST = "https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/files.txt"

-- descobre quais placas de rede existem e em que estado estao
local function netInfo()
  local info = { types = {}, state = "none", modem = nil, wireless = false }
  local netAddr = cl.list("internet")()
  local modemAddr = cl.list("modem")()
  if netAddr then
    info.types[#info.types + 1] = "Internet Card"
    local okH, http = pcall(cl.invoke, netAddr, "isHttpEnabled")
    info.state = (okH and http) and "ok" or "warn"
  end
  if modemAddr then
    local m = cl.proxy(modemAddr)
    local okW, isW = pcall(m.isWireless)
    if okW and isW then
      info.wireless = true
      info.modem = m
      info.types[#info.types + 1] = "Wireless Network Card"
      if not netAddr then info.state = "wireless" end
    else
      info.types[#info.types + 1] = "Network Card"
      if not netAddr then info.state = "wired" end
    end
  end
  return info
end

-- icone da barra: 3 barrinhas + 1 simbolo (barras, simbolo, cor das barras, cor do simbolo)
local function wifiGlyph(info)
  local s = info.state
  if s == "ok" then
    return "▂▄▆", " ", C.ok, C.ok
  elseif s == "warn" then
    return "▂▄▆", "!", C.warn, C.warn
  elseif s == "wireless" then
    return "▂▄▆", "▼", C.ok, C.accent
  elseif s == "wired" then
    return "▂▄▆", " ", C.dim, C.dim
  end
  return "▂▄▆", "×", C.dim, C.err
end

-- testa de verdade: abre uma conexao HTTP e mede o tempo
local function netTest()
  local addr = cl.list("internet")()
  if not addr then return false, T.wifiNoCard end
  local net = cl.proxy(addr)
  local t0 = cp.uptime()
  local req, err = net.request(NET_TEST)
  if not req then return false, tostring(err) end
  local limit = t0 + 8
  local ok, e = pcall(function()
    while not req.finishConnect() do
      if cp.uptime() > limit then error("timeout") end
      cp.pullSignal(0)
    end
    local code = req.response()
    if code and code >= 400 then error("HTTP " .. code) end
  end)
  pcall(req.close)
  if not ok then return false, tostring(e) end
  return true, string.format("%d ms", math.floor((cp.uptime() - t0) * 1000))
end

local wifiBox = { x = 0, w = 4 }
local netCache, netCacheT = nil, 0
local MENU_BTN = " ◆ Nitro "
local MENU_W = 26

local function drawTaskbar(cfg, menuOpen)
  rect(1, h, w, 1, C.panel)
  if menuOpen then
    put(1, h, MENU_BTN, C.bg, C.accent)
  else
    put(1, h, MENU_BTN, C.accent, C.panel)
  end
  local right = cfg.user .. "  " .. clock()
  put(w - ulen(right), h, right, C.text, C.panel)

  local info
  if GO then
    if not netCache or cp.uptime() - netCacheT > 10 then
      netCache = netInfo()
      netCacheT = cp.uptime()
    end
    info = netCache
  else
    info = netInfo()
  end
  local bars, suffix, barColor, sufColor = wifiGlyph(info)
  wifiBox.x = w - ulen(right) - 5
  put(wifiBox.x, h, bars, barColor, C.panel)
  put(wifiBox.x + 3, h, suffix, sufColor, C.panel)
end

local function menuGeometry(items)
  local mh = #items + 2
  return 1, h - mh, MENU_W, mh
end

local function drawMenu(items)
  local mx, my, mw, mh = menuGeometry(items)
  drawBox(mx, my, mw, mh)
  for i, it in ipairs(items) do
    local y = my + i
    if it.sep then
      put(mx + 1, y, string.rep("─", mw - 2), C.dim, C.panel)
    else
      put(mx + 2, y, it.label, it.color or C.text, C.panel, mw - 4)
    end
  end
end

---------------------------------------------------------------- janelas
local function newWindow(title, body, live)
  local ww = math.min(w - 4, 46)
  local wh = math.min(h - 3, 11)
  return {
    title = title, body = body, live = live, w = ww, h = wh,
    x = math.floor((w - ww) / 2) + 1,
    y = math.floor((h - 1 - wh) / 2) + 1,
  }
end

local function drawWindow(win)
  drawBox(win.x, win.y, win.w, win.h, win.title)
  put(win.x + win.w - 5, win.y, "[X]", C.bg, C.accent)
  win.body(win)
end

local function closeHit(win, x, y)
  return y == win.y and x >= win.x + win.w - 5 and x <= win.x + win.w - 3
end

local function soonBody(win)
  local s = T.soon
  put(win.x + math.floor((win.w - ulen(s)) / 2), win.y + math.floor(win.h / 2),
    s, C.dim, C.panel)
end

local function joinPath(dir, name)
  if dir == "/" then return "/" .. name end
  return dir .. "/" .. name
end

local function parentPath(dir)
  local p = dir:match("^(.*)/[^/]+$")
  if not p or p == "" then return "/" end
  return p
end

local function fmtSize(n)
  if n < 1024 then return n .. "B" end
  return string.format("%.1fK", n / 1024)
end

---------------------------------------------------------------- apoio de janelas (usado pelos apps)
local function setWinGeom(win, ww, wh)
  win.w = math.min(w - 2, ww)
  win.h = math.min(h - 2, wh)
  win.x = math.floor((w - win.w) / 2) + 1
  win.y = math.max(1, math.floor((h - 1 - win.h) / 2) + 1)
end

local function makeButtons(x, defs)
  local out = {}
  for _, d in ipairs(defs) do
    local label = " " .. d[2] .. " "
    out[#out + 1] = { id = d[1], x = x, label = label, color = d[3] }
    x = x + ulen(label) + 1
  end
  return out
end

local function drawButtons(list, y)
  for _, b in ipairs(list) do
    put(b.x, y, b.label, C.bg, b.color or C.accent)
  end
end

local function hitButton(list, x)
  for _, b in ipairs(list) do
    if x >= b.x and x < b.x + ulen(b.label) then return b.id end
  end
  return nil
end

---------------------------------------------------------------- app Calculadora
local function newTextArea(x, y, tw, th)
  return {
    x = x, y = y, w = tw, h = th, lines = { "" },
    cy = 1, cx = 0, top = 1, left = 0, modified = false,
  }
end

local function taClamp(ta)
  if ta.cy < 1 then ta.cy = 1 end
  if ta.cy > #ta.lines then ta.cy = #ta.lines end
  local len = ulen(ta.lines[ta.cy])
  if ta.cx > len then ta.cx = len end
  if ta.cx < 0 then ta.cx = 0 end
  if ta.cy < ta.top then ta.top = ta.cy end
  if ta.cy >= ta.top + ta.h then ta.top = ta.cy - ta.h + 1 end
  if ta.cx < ta.left then ta.left = ta.cx end
  if ta.cx > ta.left + ta.w - 1 then ta.left = ta.cx - ta.w + 1 end
end

local function taSetText(ta, text)
  ta.lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r", "")
    line = line:gsub("\t", "  ")
    ta.lines[#ta.lines + 1] = line
  end
  if #ta.lines == 0 then ta.lines = { "" } end
  ta.cy, ta.cx, ta.top, ta.left = 1, 0, 1, 0
  ta.anchor = nil
  ta.modified = false
end

local function taText(ta)
  return table.concat(ta.lines, "\n")
end

local function taDraw(ta, showCursor)
  for n = 0, ta.h - 1 do
    local row = ta.y + n
    rect(ta.x, row, ta.w, 1, C.panel)
    local line = ta.lines[ta.top + n]
    if line then
      put(ta.x, row, usub(line, ta.left + 1, ta.left + ta.w), C.text, C.panel, ta.w)
    end
  end
  -- trecho selecionado (ta.anchor = inicio da selecao, cursor = fim)
  if ta.anchor then
    local a, b = ta.anchor, { y = ta.cy, x = ta.cx }
    if a.y > b.y or (a.y == b.y and a.x > b.x) then a, b = b, a end
    if not (a.y == b.y and a.x == b.x) then
      for n = 0, ta.h - 1 do
        local idx = ta.top + n
        if idx >= a.y and idx <= b.y and ta.lines[idx] then
          local line = ta.lines[idx]
          local c1 = (idx == a.y) and a.x or 0
          local c2 = (idx == b.y) and b.x or ulen(line)
          local v1 = math.max(c1, ta.left)
          local v2 = math.min(c2, ta.left + ta.w)
          if v2 > v1 then
            put(ta.x + v1 - ta.left, ta.y + n, usub(line, v1 + 1, v2), C.bg, C.accent)
          end
        end
      end
    end
  end
  if showCursor then
    local line = ta.lines[ta.cy]
    local ch = usub(line, ta.cx + 1, ta.cx + 1)
    if ch == "" then ch = " " end
    put(ta.x + ta.cx - ta.left, ta.y + ta.cy - ta.top, ch, C.bg, C.accent)
  end
end

local function taKey(ta, char, code)
  local line = ta.lines[ta.cy]
  local len = ulen(line)
  if code == 200 then
    ta.cy = ta.cy - 1
  elseif code == 208 then
    ta.cy = ta.cy + 1
  elseif code == 203 then
    if ta.cx > 0 then
      ta.cx = ta.cx - 1
    elseif ta.cy > 1 then
      ta.cy = ta.cy - 1
      ta.cx = ulen(ta.lines[ta.cy])
    end
  elseif code == 205 then
    if ta.cx < len then
      ta.cx = ta.cx + 1
    elseif ta.cy < #ta.lines then
      ta.cy = ta.cy + 1
      ta.cx = 0
    end
  elseif code == 199 then
    ta.cx = 0
  elseif code == 207 then
    ta.cx = len
  elseif code == 201 then
    ta.cy = ta.cy - ta.h
  elseif code == 209 then
    ta.cy = ta.cy + ta.h
  elseif code == 28 or code == 156 or char == 13 or char == 10 then
    -- nova linha com a mesma indentacao; abre um nivel a mais depois de then/do/function...
    local indent = line:match("^(%s*)") or ""
    local t = line:match("^%s*(.-)%s*$")
    if t:match("then$") or t:match("do$") or t:match("else$") or t:match("repeat$")
        or t:match("function%s*[%w_.:]*%s*%b()$") or t:match("[%{%(]$") then
      indent = indent .. "  "
    end
    ta.lines[ta.cy] = usub(line, 1, ta.cx)
    table.insert(ta.lines, ta.cy + 1, indent .. usub(line, ta.cx + 1))
    ta.cy = ta.cy + 1
    ta.cx = ulen(indent)
    ta.modified = true
  elseif code == 14 then
    if ta.cx > 0 then
      ta.lines[ta.cy] = usub(line, 1, ta.cx - 1) .. usub(line, ta.cx + 1)
      ta.cx = ta.cx - 1
      ta.modified = true
    elseif ta.cy > 1 then
      local prev = ta.lines[ta.cy - 1]
      ta.cx = ulen(prev)
      ta.lines[ta.cy - 1] = prev .. line
      table.remove(ta.lines, ta.cy)
      ta.cy = ta.cy - 1
      ta.modified = true
    end
  elseif code == 211 then
    if ta.cx < len then
      ta.lines[ta.cy] = usub(line, 1, ta.cx) .. usub(line, ta.cx + 2)
      ta.modified = true
    elseif ta.cy < #ta.lines then
      ta.lines[ta.cy] = line .. ta.lines[ta.cy + 1]
      table.remove(ta.lines, ta.cy + 1)
      ta.modified = true
    end
  elseif code == 15 then
    ta.lines[ta.cy] = usub(line, 1, ta.cx) .. "  " .. usub(line, ta.cx + 1)
    ta.cx = ta.cx + 2
    ta.modified = true
  elseif char and char >= 32 and char ~= 127 then
    ta.lines[ta.cy] = usub(line, 1, ta.cx) .. uchar(char) .. usub(line, ta.cx + 1)
    ta.cx = ta.cx + 1
    ta.modified = true
  else
    return false
  end
  taClamp(ta)
  return true
end

local function taClick(ta, x, y)
  if x < ta.x or x >= ta.x + ta.w or y < ta.y or y >= ta.y + ta.h then return false end
  ta.cy = ta.top + (y - ta.y)
  ta.cx = ta.left + (x - ta.x)
  taClamp(ta)
  return true
end

---------------------------------------------------------------- app Editor de Texto
local function httpGet(url, timeout)
  local addr = cl.list("internet")()
  if not addr then return nil, T.wifiNoCard end
  local net = cl.proxy(addr)
  local req, err = net.request(url)
  if not req then return nil, tostring(err) end
  local limit = cp.uptime() + (timeout or 20)
  local data = ""
  local ok, e = pcall(function()
    while not req.finishConnect() do
      if cp.uptime() > limit then error("timeout", 0) end
      cp.pullSignal(0)
    end
    local code = req.response()
    if code and code >= 400 then error("HTTP " .. code, 0) end
    while true do
      local chunk = req.read(math.huge)
      if not chunk then break end
      data = data .. chunk
    end
  end)
  pcall(req.close)
  if not ok then return nil, tostring(e) end
  return data
end

-- o manifesto e so dados (versao + lista de arquivos): roda sem acesso a nada do sistema
local WALL_DIR = "/nitro/fundo_imagens"

local function loadWallFile(name)
  local path = WALL_DIR .. "/" .. name .. ".lua"
  if not fs.exists(path) then return nil end
  local data = readFile(path)
  local f = data and load(data, "=" .. name, "t", {})
  if not f then return nil end
  local ok, t = pcall(f)
  if ok and type(t) == "table" then return t end
  return nil
end

-- cada celula mostra 2 "pixels" (um em cima, outro embaixo) usando o bloco ▀
local function drawPixels(rows, palette, ox, oy, areaW, areaH)
  local cols = 0
  for _, r in ipairs(rows) do
    if #r > cols then cols = #r end
  end
  local cellRows = math.ceil(#rows / 2)
  local drawW = math.min(cols, areaW)
  local drawH = math.min(cellRows, areaH)
  local x0 = ox + math.floor((areaW - drawW) / 2)
  local y0 = oy + math.floor((areaH - drawH) / 2)
  for cy = 1, drawH do
    local top = rows[cy * 2 - 1] or ""
    local bot = rows[cy * 2] or ""
    local runX, runFg, runBg, runLen = 0, nil, nil, 0
    for cx = 1, drawW + 1 do
      local fg, bg
      if cx <= drawW then
        fg = palette[top:sub(cx, cx)] or C.bg
        bg = palette[bot:sub(cx, cx)] or C.bg
      end
      if fg ~= nil and fg == runFg and bg == runBg then
        runLen = runLen + 1
      else
        if runLen > 0 then
          gpu.setForeground(runFg)
          gpu.setBackground(runBg)
          gpu.set(x0 + runX, y0 + cy - 1, string.rep("▀", runLen))
        end
        runX, runFg, runBg, runLen = cx - 1, fg, bg, (fg ~= nil) and 1 or 0
      end
    end
  end
end

local function drawWallpaper(wall)
  if wall.kind == "none" then return end
  local data = wall.data
  local rows = (wall.kind == "video") and data.frames[wall.frame] or data.rows
  if type(rows) ~= "table" then return end
  drawPixels(rows, data.palette or {}, 1, 1, w, h - 1)
end

local AV_MAX = 131072
local AV_RULES = {
  remove_root = { cat = "avCatWipe", pts = 40, label = "avRRemove" },
  eeprom = { cat = "avCatWipe", pts = 40, label = "avREeprom" },
  wipeloop = { cat = "avCatWipe", pts = 40, label = "avRWipeLoop" },
  initw = { cat = "avCatWipe", pts = 35, label = "avRInit" },
  loop = { cat = "avCatCrash", pts = 30, label = "avRLoop" },
  rep = { cat = "avCatCrash", pts = 25, label = "avRRep" },
  spyfile = { cat = "avCatSpy", pts = 45, label = "avRSpy" },
  host = { cat = "avCatSpy", pts = 25, label = "avRHost" },
  net = { cat = "avCatSpy", pts = 5, label = "avRNet" },
  worm = { cat = "avCatWorm", pts = 45, label = "avRWorm" },
  load = { cat = "avCatHide", pts = 10, label = "avRLoad" },
  obf = { cat = "avCatHide", pts = 25, label = "avRObf" },
  long = { cat = "avCatHide", pts = 10, label = "avRLong" },
  b64 = { cat = "avCatHide", pts = 15, label = "avRB64" },
}

local AV_OK_HOSTS = {
  ["github.com"] = true, ["www.github.com"] = true,
  ["raw.githubusercontent.com"] = true, ["api.github.com"] = true,
}

local function countMatches(l, pattern)
  local _, n = l:gsub(pattern, "")
  return n
end

local function trimText(s)
  return (s:match("^%s*(.-)%s*$"))
end

-- o "while true" tem alguma pausa (pullSignal, sleep, yield...) dentro do proprio bloco?
local function avBlockHasPause(clean, start)
  local depth = 0
  local last = math.min(#clean, start + 300)
  for j = start, last do
    local l = clean[j]:lower()
    if l:find("pullsignal", 1, true) or l:find("sleep", 1, true) or l:find("yield", 1, true)
        or l:find("event.pull", 1, true) then
      return true
    end
    depth = depth + countMatches(l, "%f[%w_]function%f[^%w_]") + countMatches(l, "%f[%w_]if%f[^%w_]")
      + countMatches(l, "%f[%w_]do%f[^%w_]") + countMatches(l, "%f[%w_]repeat%f[^%w_]")
      - countMatches(l, "%f[%w_]end%f[^%w_]") - countMatches(l, "%f[%w_]until%f[^%w_]")
    if j > start and depth <= 0 then return false end
  end
  return false
end

local function avScan(text)
  local raw, clean = {}, {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    raw[#raw + 1] = line
    clean[#clean + 1] = (line:gsub("%-%-.*$", ""))
  end

  local found, order = {}, {}
  local function hit(rule, ln, snippet)
    local f = found[rule]
    if not f then
      f = { items = {} }
      found[rule] = f
      order[#order + 1] = rule
    end
    if #f.items < 3 then f.items[#f.items + 1] = { line = ln, text = snippet } end
  end

  local lowerAll = table.concat(clean, "\n"):lower()
  local usesNet = lowerAll:find("internet", 1, true) ~= nil
  local usesModem = (lowerAll:find("modem", 1, true) or lowerAll:find("tunnel", 1, true)) ~= nil
  local readsFiles = (lowerAll:find("fs.open", 1, true) or lowerAll:find("io.open", 1, true)
    or lowerAll:find("readfile", 1, true) or lowerAll:find(".read", 1, true)) ~= nil
  local escapes = countMatches(lowerAll, "\\%d%d%d")
  local firstSecret, firstNet, firstListRoot, firstSend

  for i, line in ipairs(clean) do
    local l = line:lower()
    if l ~= "" then
      local r = trimText(raw[i])
      if l:find("remove", 1, true) and (l:find("[\"']/[\"']") or l:find("/init.lua", 1, true)
          or l:find("/nitro", 1, true) or l:find("/boot", 1, true)) then
        hit("remove_root", i, r)
      end
      if l:find("eeprom", 1, true) and (l:find("%.set%s*%(") or l:find("makereadonly", 1, true)) then
        hit("eeprom", i, r)
      end
      if l:find("/init.lua", 1, true) and (l:find("open%s*%(") or l:find("rename%s*%("))
          and (l:find("[\"']w[\"']") or l:find("[\"']wb[\"']") or l:find("rename", 1, true)) then
        hit("initw", i, r)
      end
      if (l:find("string.rep", 1, true) or l:find(":rep", 1, true))
          and (l:find("%d%d%d%d%d%d%d") or l:find("math.huge", 1, true) or l:find("1e[6-9]")) then
        hit("rep", i, r)
      end
      for host in l:gmatch("https?://([%w%.%-]+)") do
        if not AV_OK_HOSTS[host] then hit("host", i, host) end
      end
      if l:find("%f[%w_]load%s*%(") or l:find("loadstring", 1, true) or l:find("dofile", 1, true) then
        hit("load", i, r)
      end
      if #raw[i] > 500 then hit("long", i, usub(r, 1, 50) .. "...") end
      for s in line:gmatch("[\"']([A-Za-z0-9+/=]+)[\"']") do
        if #s >= 80 then hit("b64", i, usub(s, 1, 30) .. "...") end
      end
      if not firstSecret and (l:find("senha", 1, true) or l:find("password", 1, true)
          or l:find("token", 1, true) or l:find("config.lua", 1, true) or l:find("api_key", 1, true)) then
        firstSecret = i
      end
      if not firstNet and l:find("internet", 1, true) then firstNet = i end
      if not firstListRoot and l:find("list%s*%(%s*[\"']/[\"']%s*%)") then firstListRoot = i end
      if not firstSend and (l:find("broadcast", 1, true) or l:find(".send", 1, true)) then
        firstSend = i
      end
      if l:find("while%s+true%s+do") and not avBlockHasPause(clean, i) then
        hit("loop", i, r)
      end
    end
  end

  if firstSecret and usesNet and readsFiles then
    hit("spyfile", firstSecret, trimText(raw[firstSecret]))
  end
  if usesNet and not found.spyfile and not found.host then
    hit("net", firstNet or 1, trimText(raw[firstNet or 1] or ""))
  end
  if firstListRoot and lowerAll:find("remove", 1, true) then
    hit("wipeloop", firstListRoot, trimText(raw[firstListRoot]))
  end
  if usesModem and firstSend
      and (lowerAll:find("autorun", 1, true) or lowerAll:find("init.lua", 1, true)) then
    hit("worm", firstSend, trimText(raw[firstSend]))
  end
  if found.load and (lowerAll:find("string.char", 1, true) or escapes >= 20) then
    hit("obf", found.load.items[1].line, "string.char / \\ddd")
  end

  table.sort(order, function(a, b) return AV_RULES[a].pts > AV_RULES[b].pts end)
  local score, entries = 0, {}
  for _, rule in ipairs(order) do
    local def = AV_RULES[rule]
    score = score + def.pts
    for _, it in ipairs(found[rule].items) do
      entries[#entries + 1] = {
        cat = def.cat, label = def.label, line = it.line, text = it.text, pts = def.pts,
      }
    end
  end
  if score > 100 then score = 100 end
  local verdict = "safe"
  if score >= 50 then
    verdict = "danger"
  elseif score >= 20 then
    verdict = "warn"
  end
  return { score = score, verdict = verdict, entries = entries }
end

local function avVerdictName(report)
  local names = { safe = T.avSafe, warn = T.avWarn, danger = T.avDanger }
  return names[report.verdict]
end

local function avVerdictColor(report)
  local colors = { safe = C.ok, warn = C.warn, danger = C.err }
  return colors[report.verdict]
end

-- transforma o relatorio em linhas de texto (com cor) para mostrar na tela
local function avFormat(report, path)
  local lines, colors = {}, {}
  lines[1] = string.format(T.avVerdict, avVerdictName(report), report.score)
  colors[1] = avVerdictColor(report)
  local isSystem = path and (path:sub(1, 6) == "/nitro" or path == "/init.lua")
  if report.verdict == "danger" and isSystem then
    lines[#lines + 1] = "MX-211  " .. T.e211 .. " (" .. path .. ")"
    colors[#lines] = C.err
  end
  if #report.entries == 0 then
    lines[2] = T.avNone
    colors[2] = C.dim
  end
  for _, e in ipairs(report.entries) do
    local snippet = e.text
    if ulen(snippet) > 40 then snippet = usub(snippet, 1, 40) .. "..." end
    lines[#lines + 1] = string.format("[%s] %s (%s %d): %s",
      T[e.cat], T[e.label], T.avLineWord, e.line, snippet)
    colors[#lines] = (e.pts >= 30) and C.err or ((e.pts >= 10) and C.warn or C.dim)
  end
  lines[#lines + 1] = T.avNote
  colors[#lines] = C.dim
  return lines, colors
end

local function avAnalyzeFile(path)
  if not fs.exists(path) or fs.isDirectory(path) then return nil, T.avNoFile end
  if fs.size(path) > AV_MAX then return nil, T.avBig end
  local data = readFile(path)
  if not data then return nil, T.avNoFile end
  if data:find("\0", 1, true) then return nil, T.binaryFile end
  return avScan(data)
end

local function copyTable(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- restricted = true: so matematica, texto e tabelas (sem component, computer, os, io, load...)
local function makeEnv(restricted, out)
  local function capture(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    if #out < 200 then out[#out + 1] = table.concat(parts, "  ") end
  end
  if not restricted then
    return setmetatable({ print = capture }, { __index = _G })
  end
  local env = { print = capture, _VERSION = _VERSION }
  for _, name in ipairs({ "assert", "error", "ipairs", "next", "pairs", "select", "tonumber", "tostring", "type" }) do
    env[name] = _G[name]
  end
  env.math = copyTable(math)
  env.table = copyTable(table)
  env.string = copyTable(string)
  local realRep = string.rep
  env.string.rep = function(s, n, sep)
    if #tostring(s) * (tonumber(n) or 0) > 65536 then error("string.rep limitado", 0) end
    return realRep(s, n, sep)
  end
  env.unpack = table.unpack or unpack
  return env
end

local APP_DIRS = { "/apps", "/nitro/apps" }

-- janela simples que mostra linhas de texto (resultado de scripts, erros, bloqueios)
local function textWindow(title, lines, colors)
  local win = { title = title }
  setWinGeom(win, 62, 16)
  local ix, iw = win.x + 2, win.w - 4
  local rows = win.h - 5
  local vfirst = 1

  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    for n = 0, rows - 1 do
      local line = lines[vfirst + n]
      if line then
        put(ix, self.y + 2 + n, line, (colors and colors[vfirst + n]) or C.text, C.panel, iw)
      end
    end
  end

  win.onKey = function(self, char, code)
    if code == 200 then
      vfirst = math.max(1, vfirst - 1)
      return true
    elseif code == 208 then
      vfirst = math.max(1, math.min(vfirst + 1, #lines - rows + 1))
      return true
    end
    return false
  end

  win.onScroll = function(self, dir)
    vfirst = math.max(1, math.min(vfirst - dir * 3, math.max(1, #lines - rows + 1)))
  end

  return win
end

-- nome e descricao vem de comentarios no comeco do arquivo: "-- name: X" e "-- desc: Y"
local function appHeader(path, fallback)
  local name, desc = fallback, ""
  local hnd = fs.open(path)
  if hnd then
    local head = fs.read(hnd, 400) or ""
    fs.close(hnd)
    local nm = head:match("%-%-%s*[Nn]ame:%s*([^\r\n]+)") or head:match("%-%-%s*[Nn]ome:%s*([^\r\n]+)")
    local ds = head:match("%-%-%s*[Dd]esc[%a]*:%s*([^\r\n]+)")
    if nm then name = trimText(nm) end
    if ds then desc = trimText(ds) end
  end
  return name, desc
end

-- apps soltos (/apps/x.lua) ou em pasta (/apps/X.APP/app.lua)
local function listInstalledApps()
  local out, seen = {}, {}
  local function add(path, key, fallback, removePath)
    if seen[key] then return end
    seen[key] = true
    local name, desc = appHeader(path, fallback)
    out[#out + 1] = {
      name = name, desc = desc, path = path, rm = removePath, size = fs.size(path),
    }
  end
  for _, dir in ipairs(APP_DIRS) do
    local ok, names = pcall(fs.list, dir)
    if ok and type(names) == "table" then
      for _, n in ipairs(names) do
        if n:sub(-4) == ".lua" then
          add(dir .. "/" .. n, n, n:sub(1, -5), dir .. "/" .. n)
        elseif n:sub(-1) == "/" then
          local entry = dir .. "/" .. n .. "app.lua"
          if fs.exists(entry) then
            add(entry, n, n:sub(1, -2), dir .. "/" .. n:sub(1, -2))
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

-- o que o app recebe como "nitro": funcoes de desenho e as cores do sistema
local function makeAppUi()
  return {
    put = function(x, y, s, fg, bg, maxw) put(x, y, s, fg or C.text, bg or C.panel, maxw) end,
    rect = function(x, y, rw, rh, bg) rect(x, y, rw, rh, bg or C.panel) end,
    box = drawBox,
    colors = copyTable(C),
    width = w,
    height = h,
    uptime = cp.uptime,
  }
end

-- app em formato janela: o arquivo devolve { title, w, h, body, onKey, onTouch, onScroll }
local function appWindow(def, ui, fname)
  local win = { title = tostring(def.title or fname) }
  setWinGeom(win, tonumber(def.w) or 50, tonumber(def.h) or 14)
  win.live = def.live and true or false
  win.body = function(self)
    rect(self.x + 1, self.y + 1, self.w - 2, self.h - 2, C.panel)
    def.body(self, ui)
  end
  if type(def.onKey) == "function" then
    win.onKey = function(self, char, code) return def.onKey(self, char, code, ui) end
  end
  if type(def.onTouch) == "function" then
    win.onTouch = function(self, x, y) return def.onTouch(self, x, y, ui) end
  end
  if type(def.onScroll) == "function" then
    win.onScroll = function(self, dir) return def.onScroll(self, dir, ui) end
  end
  return win
end

local function runInstalledApp(path)
  local fname = path:match("([^/]+)$") or path
  local data = readFile(path)
  if not data then
    return textWindow(fname, { string.format(T.maRunErr, T.avNoFile) }, { C.err })
  end

  -- analisa de novo na hora de abrir (o arquivo pode ter mudado depois da instalacao)
  local report = avScan(data)
  if report.verdict == "danger" then
    local lines, colors = avFormat(report)
    table.insert(lines, 1, string.format(T.maBlocked, report.score))
    table.insert(colors, 1, C.err)
    return textWindow(fname, lines, colors)
  end

  local out = {}
  local env = makeEnv(false, out)
  env.nitro = makeAppUi()
  local fn, err = load(data, "=" .. fname, "t", env)
  if not fn then
    return textWindow(fname, { string.format(T.maRunErr, tostring(err)) }, { C.err })
  end
  local ok, result = pcall(fn)
  if not ok then
    out[#out + 1] = string.format(T.maRunErr, tostring(result))
    local colors = {}
    colors[#out] = C.err
    return textWindow(fname, out, colors)
  end
  if type(result) == "table" and type(result.body) == "function" then
    return appWindow(result, env.nitro, fname)
  end
  -- app/jogo que tem o proprio laco (devolve uma funcao): recebe { gpu = gpu } e volta quando o jogador sai
  if type(result) == "function" then
    local okRun, errRun = pcall(result, { gpu = gpu, nitro = env.nitro })
    if not okRun then
      return textWindow(fname, { string.format(T.maRunErr, tostring(errRun)) }, { C.err })
    end
    return nil
  end
  if #out == 0 then out[1] = T.gNoOutput end
  return textWindow(string.format(T.maOutput, fname), out, nil)
end

---------------------------------------------------------------- apps do sistema em /nitro/sys
local SYS_DIR = "/nitro/sys"
local SAFE_ENV = {
  math = math, string = string, table = table, tostring = tostring, tonumber = tonumber,
  pairs = pairs, ipairs = ipairs, type = type, select = select, pcall = pcall, error = error,
  assert = assert, next = next, print = print, unpack = unpack, load = load, debug = debug,
  os = os, unicode = unicode, rawget = rawget, rawset = rawset, setmetatable = setmetatable,
  getmetatable = getmetatable, _G = _G,
}

local function setLangIdx(i)
  T = langs[i].t
end

-- a API que os apps recebem (tudo o que eles usam do nucleo)
-- area de transferencia interna (Ctrl+Insert copia, Shift+Insert cola)
local CLIP = { text = "" }

local NITRO_API = {
  C = C,
  GO = GO,
  THEMES = THEMES,
  VERSION = VERSION,
  WALL_DIR = WALL_DIR,
  applyTheme = applyTheme,
  avAnalyzeFile = avAnalyzeFile,
  avFormat = avFormat,
  avScan = avScan,
  avVerdictColor = avVerdictColor,
  avVerdictName = avVerdictName,
  cl = cl,
  cp = cp,
  drawButtons = drawButtons,
  fmtSize = fmtSize,
  fmtTime = fmtTime,
  fs = fs,
  h = h,
  hash = hash,
  hitButton = hitButton,
  httpGet = httpGet,
  input = input,
  key = key,
  langs = langs,
  listInstalledApps = listInstalledApps,
  loadWallFile = loadWallFile,
  makeButtons = makeButtons,
  makeEnv = makeEnv,
  netInfo = netInfo,
  netTest = netTest,
  newTextArea = newTextArea,
  newWindow = newWindow,
  put = put,
  readFile = readFile,
  rect = rect,
  saveConfig = saveConfig,
  setWinGeom = setWinGeom,
  taClick = taClick,
  taDraw = taDraw,
  taKey = taKey,
  taSetText = taSetText,
  taText = taText,
  themeIndex = themeIndex,
  trimText = trimText,
  uchar = uchar,
  ulen = ulen,
  usub = usub,
  w = w,
  joinPath = joinPath, parentPath = parentPath,
  taClamp = taClamp,
  CLIP = CLIP,
  setLang = setLangIdx,
  T = nil,
}

local function openSys(name, ...)
  NITRO_API.T = T
  local path = SYS_DIR .. "/" .. name .. ".lua"
  local data = readFile(path)
  if not data then
    return textWindow(name, { string.format(T.maRunErr, T.avNoFile .. " (" .. path .. ")") }, { C.err })
  end
  local chunk, err = load(data, "=" .. name, "t", SAFE_ENV)
  if not chunk then
    return textWindow(name, { string.format(T.maRunErr, tostring(err)) }, { C.err })
  end
  local okF, factory = pcall(chunk)
  if not okF or type(factory) ~= "function" then
    return textWindow(name, { string.format(T.maRunErr, tostring(factory)) }, { C.err })
  end
  local okW, win = pcall(factory, NITRO_API, ...)
  if not okW or type(win) ~= "table" then
    return textWindow(name, { string.format(T.maRunErr, tostring(win)) }, { C.err })
  end
  return win
end

---------------------------------------------------------------- boas-vindas
local function welcome(cfg)
  local bw = math.min(w - 6, 40)
  local bh = 7
  local bx = math.floor((w - bw) / 2) + 1
  local by = math.floor((h - bh) / 2)
  drawBox(bx, by, bw, bh)

  local function mid(y, s, fg, bg)
    put(bx + math.floor((bw - ulen(s)) / 2), y, s, fg, bg)
  end
  mid(by + 2, string.format(T.welcome, cfg.user), C.text, C.panel)
  mid(by + 3, T.ready, C.dim, C.panel)

  local label = T.cont
  local lx = bx + math.floor((bw - ulen(label)) / 2)
  local ly = by + 5
  put(lx, ly, label, C.bg, C.accent)

  while true do
    local ev, _, a, b = cp.pullSignal()
    if ev == "key_down" and b == 28 then return end
    if ev == "touch" and inside(a, b, lx, ly, ulen(label), 1) then return end
  end
end

---------------------------------------------------------------- desktop
local function desktop(cfg)
  local shared = { refresh = false }

  local function buildItems()
    -- se sobrar espaco na tela, mostra os apps instalados direto no menu (antes da linha de separacao)
    local function withApps(list)
      local apps = listInstalledApps()
      local cap = (h - 2) - (#list + 2) - 1
      if cap <= 0 or #apps == 0 then return list end
      local out, added = {}, false
      for _, it in ipairs(list) do
        if it.sep and not added then
          for i = 1, math.min(cap, #apps) do
            out[#out + 1] = { id = "app:" .. apps[i].path, label = "▸ " .. apps[i].name }
          end
          added = true
        end
        out[#out + 1] = it
      end
      return out
    end

    local all = {
      { id = "files", label = T.mFiles },
      { id = "editor", label = T.mEditor },
      { id = "editorlua", label = T.mEditorLua },
      { id = "notes", label = T.mNotes },
      { id = "calc", label = T.mCalc },
      { id = "monitor", label = T.mMonitor },
      { id = "printer", label = T.mPrinter },
      { id = "gitdown", label = T.mGitDown },
      { id = "term", label = T.mTerm },
      { id = "redelocal", label = T.mRedeLocal },
      { id = "antivirus", label = T.mAntivirus },
      { id = "store", label = T.mStore },
      { id = "myapps", label = T.mMyApps },
      { id = "settings", label = T.mSettings },
      { id = "lock", label = T.mLock },
      { sep = true },
      { id = "restart", label = T.mRestart, color = C.warn },
      { id = "shutdown", label = T.mShutdown, color = C.err },
    }
    if not GO then return withApps(all) end
    local keep = { files = true, calc = true, monitor = true, myapps = true, settings = true, restart = true, shutdown = true }
    local out = {}
    for _, it in ipairs(all) do
      if it.sep or keep[it.id] then out[#out + 1] = it end
    end
    return out
  end

  local items = buildItems()
  local menuOpen, win = false, nil
  local guard
  local wall = nil

  local function applyWallpaper(id)
    wall = nil
    if GO then return end
    if id == "none" then
      wall = { kind = "none" }
    elseif type(id) == "string" and id:sub(1, 5) == "file:" then
      local data = loadWallFile(id:sub(6))
      if data then
        wall = { kind = data.frames and "video" or "image", data = data, frame = 1 }
      end
    end
  end

  local ext = {}
  local mods = { ctrl = false, shift = false }

  local function render()
    rect(1, 1, w, h - 1, C.bg)
    if GO then
      put(math.floor((w - ulen(T.hint)) / 2), math.floor(h / 2), T.hint, C.dim, C.bg)
    elseif wall then
      drawWallpaper(wall)
    else
      local size = logoSize()
      local ly = math.floor((h - 1 - (size + 3)) / 2) + 1
      drawLogo(math.floor((w - logoWidth(size)) / 2) + 1, ly, size, C.bg, 0x666666)
      put(math.floor((w - ulen(T.empty)) / 2), ly + size + 1, T.empty, C.dim, C.bg)
      put(math.floor((w - ulen(T.hint)) / 2), ly + size + 2, T.hint, C.dim, C.bg)
    end
    if ext.drawIcons then ext.drawIcons() end
    if win then guard(drawWindow, win) end
    drawTaskbar(cfg, menuOpen)
    if menuOpen then drawMenu(items) end
    if ext.drawCtx then ext.drawCtx() end
  end

  guard = function(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    win = nil
    menuOpen = false
    errorScreen(classify(res, 209), res, true)
    render()
    return nil
  end

  local function tryClose()
    if win and win.canClose then
      local okClose = guard(win.canClose, win)
      if not okClose then
        if win then guard(drawWindow, win) end
        return
      end
    end
    win = nil
    render()
  end

  local function activate(it)
    menuOpen = false
    if it.id == "restart" then
      cp.shutdown(true)
    elseif it.id == "shutdown" then
      cp.shutdown()
    elseif it.id == "monitor" then
      win = guard(openSys, "monitor")
    elseif it.id == "files" then
      win = guard(openSys, "arquivos", it.arg)
    elseif it.id == "calc" then
      win = guard(openSys, "calc")
    elseif it.id == "editorlua" then
      win = guard(openSys, "editorlua")
    elseif it.id == "editor" then
      win = guard(openSys, "editor")
    elseif it.id == "notes" then
      win = guard(openSys, "notas")
    elseif it.id == "printer" then
      win = guard(openSys, "impressora")
    elseif it.id == "settings" then
      win = guard(openSys, "config", cfg, shared)
    elseif it.id == "update" then
      win = guard(openSys, "atualizar")
    elseif it.id == "wallpaper" then
      win = guard(openSys, "fundo", cfg, shared)
    elseif it.id == "gitdown" then
      win = guard(openSys, "gitdown", shared)
    elseif it.id == "term" then
      win = guard(openSys, "terminal")
    elseif it.id == "lock" then
      ext.lock()
    elseif it.id == "redelocal" then
      win = guard(openSys, "redelocal", cfg)
    elseif it.id == "antivirus" then
      win = guard(openSys, "antivirus", cfg)
    elseif it.id == "store" then
      win = guard(openSys, "appstore", shared)
    elseif it.id == "myapps" then
      win = guard(openSys, "meusapps", shared)
    elseif type(it.id) == "string" and it.id:sub(1, 4) == "app:" then
      win = guard(runInstalledApp, it.id:sub(5))
    else
      win = newWindow(it.label, soonBody, false)
    end
    render()
  end

  -- ---------------- tela de bloqueio (Ctrl+L, menu, ou depois de X minutos parado)
  local lastAct = cp.uptime()

  local function lockTime()
    local ok1, hm = pcall(os.date, "%H:%M")
    local ok2, dt = pcall(os.date, "%d/%m/%Y")
    return (ok1 and hm) or "--:--", (ok2 and dt) or ""
  end

  local function lockBackground()
    rect(1, 1, w, h, C.bg)
    if wall and not GO then drawWallpaper(wall) end
  end

  -- devolve quando o usuario entra (senha certa, ou sem senha)
  local function lockScreen()
    local phase, input, msg = "lock", "", ""
    while true do
      lockBackground()
      if phase == "lock" then
        local hm, dt = lockTime()
        put(3, h - 8, hm, C.text, C.bg)
        put(3, h - 6, dt, C.text, C.bg)
        put(3, h - 3, T.lkPress, C.dim, C.bg, w - 6)
      else
        local cxm = math.floor(w / 2)
        local ax = cxm - 4
        rect(ax, 4, 9, 5, C.panel)
        put(ax + 3, 5, "(o)", C.text, C.panel)
        put(ax + 2, 6, "/_\\", C.text, C.panel)
        local name = string.upper(cfg.user or "")
        put(math.floor((w - ulen(name)) / 2) + 1, 10, name, C.text, C.bg)
        local boxW = 24
        local bx = cxm - math.floor(boxW / 2)
        rect(bx, 12, boxW, 1, C.barbg)
        if input == "" then
          put(bx + 1, 12, T.lkEnter, C.dim, C.barbg, boxW - 2)
        else
          put(bx + 1, 12, string.rep("*", ulen(input)) .. "_", C.text, C.barbg, boxW - 2)
        end
        if msg ~= "" then
          put(math.floor((w - ulen(msg)) / 2) + 1, 14, msg, C.err, C.bg)
        end
        put(3, h - 2, T.lkEsc, C.dim, C.bg)
      end
      local ev, _, a, b = cp.pullSignal(1)
      if phase == "lock" then
        if ev == "key_down" or ev == "touch" then
          if cfg.hash then
            phase, input, msg = "pass", "", ""
          else
            return
          end
        end
      elseif ev == "key_down" then
        if b == 28 then
          if not cfg.hash or hash(input) == cfg.hash then return end
          msg, input = T.lkWrong, ""
        elseif b == 1 then
          phase, input, msg = "lock", "", ""
        elseif b == 14 then
          input = usub(input, 1, math.max(0, ulen(input) - 1))
        elseif a and a >= 32 and a < 127 and ulen(input) < 32 then
          input = input .. string.char(a)
        end
      end
    end
  end

  local function lockNow()
    lockScreen()
    lastAct = cp.uptime()
    render()
  end
  ext.lock = lockNow

  -- ---------------- icones do desktop, atalhos e menu de contexto (botao direito)
  local ctx, iconCache = nil, nil
  local DESK_DIR = "/Desktop"
  cfg.hidden = cfg.hidden or {}

  local function appIcons()
    local list = {
      { id = "files", label = T.mFiles }, { id = "editor", label = T.mEditor },
      { id = "notes", label = T.mNotes }, { id = "calc", label = T.mCalc },
      { id = "monitor", label = T.mMonitor }, { id = "printer", label = T.mPrinter },
      { id = "gitdown", label = T.mGitDown }, { id = "term", label = T.mTerm },
      { id = "antivirus", label = T.mAntivirus }, { id = "store", label = T.mStore },
      { id = "myapps", label = T.mMyApps }, { id = "settings", label = T.mSettings },
    }
    if not GO then return list end
    local keep = { files = true, calc = true, monitor = true, myapps = true, settings = true }
    local out = {}
    for _, it in ipairs(list) do
      if keep[it.id] then out[#out + 1] = it end
    end
    return out
  end

  local function readShortcuts()
    local out = {}
    if not fs.exists(DESK_DIR) then return out end
    local ok, names = pcall(fs.list, DESK_DIR)
    if not ok or type(names) ~= "table" then return out end
    for _, n in ipairs(names) do
      if n:sub(-4) == ".lnk" then
        local data = readFile(DESK_DIR .. "/" .. n) or ""
        local target = data:match("target=([%w_]+)")
        if target then
          out[#out + 1] = { kind = "lnk", id = target, label = n:sub(1, -5), key = "lnk:" .. n }
        end
      end
    end
    table.sort(out, function(p, q) return p.label:lower() < q.label:lower() end)
    return out
  end

  local function getIcons()
    if iconCache then return iconCache end
    local list = {}
    for _, it in ipairs(appIcons()) do
      local key = "app:" .. it.id
      if not cfg.hidden[key] then
        list[#list + 1] = { kind = "app", id = it.id, label = it.label, key = key }
      end
    end
    for _, sc in ipairs(readShortcuts()) do
      if not cfg.hidden[sc.key] then list[#list + 1] = sc end
    end
    local per = math.max(1, math.floor((h - 3) / 4))
    for i, ic in ipairs(list) do
      ic.x = 2 + math.floor((i - 1) / per) * 14
      ic.y = 2 + ((i - 1) % per) * 4
    end
    iconCache = list
    return list
  end

  local function iconAt(x, y)
    for _, ic in ipairs(getIcons()) do
      if y >= ic.y and y <= ic.y + 3 and x >= ic.x and x < ic.x + 12 then return ic end
    end
    return nil
  end

  local function createShortcut(icon)
    fs.makeDirectory(DESK_DIR)
    local name, n = icon.label, 2
    while fs.exists(DESK_DIR .. "/" .. name .. ".lnk") do
      name = icon.label .. " (" .. n .. ")"
      n = n + 1
    end
    local hnd = fs.open(DESK_DIR .. "/" .. name .. ".lnk", "w")
    if hnd then
      fs.write(hnd, "target=" .. icon.id .. "\n")
      fs.close(hnd)
    end
    iconCache = nil
  end

  local function saveHidden()
    saveConfig(cfg)
    iconCache = nil
  end

  local function ctxItemsFor(icon)
    if icon then
      return {
        { id = "open", label = T.ctxOpen },
        { id = "hide", label = T.ctxHide },
        { id = "shortcut", label = T.ctxShortcut },
        { id = "where", label = T.ctxWhere },
      }
    end
    return { { id = "showhidden", label = T.ctxShowHidden } }
  end

  local function ctxRunItem(item, icon)
    if item.id == "open" and icon then
      activate({ id = icon.id, label = icon.label })
    elseif item.id == "hide" and icon then
      cfg.hidden[icon.key] = true
      saveHidden()
    elseif item.id == "shortcut" and icon then
      createShortcut(icon)
    elseif item.id == "where" and icon then
      local dir = (icon.kind == "lnk") and DESK_DIR or "/nitro/sys"
      win = guard(openSys, "arquivos", dir)
    elseif item.id == "showhidden" then
      cfg.hidden = {}
      saveHidden()
    end
    render()
  end

  local function ctxOpenAt(x, y, icon)
    local items = ctxItemsFor(icon)
    local width = 6
    for _, it in ipairs(items) do width = math.max(width, ulen(it.label) + 4) end
    local height = #items + 2
    local cx = math.max(1, math.min(x, w - width + 1))
    local cy = math.max(1, math.min(y, h - height))
    ctx = { x = cx, y = cy, w = width, h = height, items = items, icon = icon }
  end

  -- arte dos icones: nitro/sys/icon/<id>.lua (carregada uma vez e guardada)
  local iconArt = {}
  local function loadIconArt(name)
    if iconArt[name] == nil then
      local data = readFile(SYS_DIR .. "/icon/" .. name .. ".lua")
      local f = data and load(data, "=icon", "t", {})
      local okI, t = false, nil
      if f then okI, t = pcall(f) end
      iconArt[name] = (okI and type(t) == "table" and t.rows) and t or false
    end
    -- icone faltando ou com erro: mostra o icone de erro (X vermelho)
    if not iconArt[name] and name ~= "erro" then
      return loadIconArt("erro")
    end
    return iconArt[name] or nil
  end

  ext.drawIcons = function()
    for _, ic in ipairs(getIcons()) do
      local art = loadIconArt(ic.kind == "lnk" and "lnk" or ic.id)
      rect(ic.x, ic.y, 12, 3, C.panel)
      if art then
        drawPixels(art.rows, art.palette or {}, ic.x + 2, ic.y, 8, 3)
      end
      rect(ic.x, ic.y + 3, 12, 1, C.panel)
      local label = ic.label
      if ulen(label) > 12 then label = usub(label, 1, 12) end
      put(ic.x + math.floor((12 - ulen(label)) / 2), ic.y + 3, label, C.text, C.panel)
    end
  end

  ext.drawCtx = function()
    if not ctx then return end
    drawBox(ctx.x, ctx.y, ctx.w, ctx.h)
    for i, it in ipairs(ctx.items) do
      put(ctx.x + 2, ctx.y + i, it.label, C.text, C.panel, ctx.w - 4)
    end
  end

  -- devolve true quando o evento ja foi tratado aqui (o laco principal nao processa de novo)
  ext.pre = function(ev, a, b, c, d)
    if ev == "key_down" or ev == "key_up" then
      local down = (ev == "key_down")
      if b == 29 or b == 157 then mods.ctrl = down end
      if b == 42 or b == 54 then mods.shift = down end
      if ev == "key_up" then return true end
    end
    if ev == "key_down" and b == 38 and mods.ctrl then
      lockNow()
      return true
    end
    -- mensagens da rede (modem_message): so o app Rede Local aberto as recebe
    if ev == "modem_message" then
      if win and win.onModem and not menuOpen then
        guard(win.onModem, win, a, b, c, d)
        if win then guard(drawWindow, win) end
      end
      return true
    end
    if ev == "key_down" then
      if ctx and b == 1 then
        ctx = nil
        render()
        return true
      end
      return false
    end
    if ev ~= "touch" then return false end
    if ctx then
      local cur = ctx
      ctx = nil
      if inside(a, b, cur.x, cur.y, cur.w, cur.h) then
        local item = cur.items[b - cur.y]
        if item then ctxRunItem(item, cur.icon) else render() end
      else
        render()
      end
      return true
    end
    local overWin = win and inside(a, b, win.x, win.y, win.w, win.h)
    if c == 1 then
      if menuOpen or b >= h or overWin then return false end
      ctxOpenAt(a, b, iconAt(a, b))
      render()
      return true
    end
    if not menuOpen and b < h and not overWin then
      local icon = iconAt(a, b)
      if icon then
        activate({ id = icon.id, label = icon.label })
        return true
      end
    end
    return false
  end

  shared.applyWallpaper = applyWallpaper
  applyWallpaper(cfg.wallpaper)

  rect(1, 1, w, h, C.bg)
  drawTaskbar(cfg, false)
  welcome(cfg)
  render()

  while true do
    local ev, _, a, b, c, d = cp.pullSignal(GO and 2 or 1)
    if ev then lastAct = cp.uptime() end
    if (cfg.lockMin or 0) > 0 and cp.uptime() - lastAct >= cfg.lockMin * 60 then lockNow() end
    local consumed = ext.pre(ev, a, b, c, d)
    if consumed then
    elseif ev == "touch" then
      if b == h and a <= ulen(MENU_BTN) then
        menuOpen = not menuOpen
        if menuOpen then items = buildItems() end
        render()
      elseif b == h and a >= wifiBox.x and a < wifiBox.x + wifiBox.w then
        menuOpen = false
        win = guard(openSys, "rede")
        render()
      elseif menuOpen then
        local mx, my, mw, mh = menuGeometry(items)
        if inside(a, b, mx, my, mw, mh) then
          local it = items[b - my]
          if it and not it.sep then
            put(mx + 1, b, string.rep(" ", mw - 2), C.bg, C.accent)
            put(mx + 2, b, it.label, C.bg, C.accent, mw - 4)
            cp.pullSignal(0.15)
            activate(it)
          end
        else
          menuOpen = false
          render()
        end
      elseif win and closeHit(win, a, b) then
        tryClose()
      elseif win and win.onTouch and inside(a, b, win.x, win.y, win.w, win.h) then
        local handled = guard(win.onTouch, win, a, b)
        if handled and win then guard(drawWindow, win) end
      end
    elseif ev == "scroll" then
      if win and win.onScroll and not menuOpen then
        guard(win.onScroll, win, c)
        if win then guard(drawWindow, win) end
      end
    elseif ev == "clipboard" then
      if win and win.onPaste and not menuOpen and not win.minimized then
        local pasted = guard(win.onPaste, win, a)
        if pasted and win then guard(drawWindow, win) end
      end
    elseif ev == "key_down" then
      local handled = false
      if win and win.onKey and not menuOpen then
        handled = guard(win.onKey, win, a, b, mods)
        if handled == "close" then
          handled = true
          win = nil
          render()
        elseif handled and win then
          guard(drawWindow, win)
        end
      end
      if not handled and b == 1 then
        if menuOpen then
          menuOpen = false
          render()
        elseif win then
          tryClose()
        end
      end
    else
      drawTaskbar(cfg, menuOpen)
      if win and win.live and not menuOpen then guard(win.body, win) end
      if wall and wall.kind == "video" and not win and not menuOpen and #wall.data.frames > 0 then
        wall.frame = wall.frame % #wall.data.frames + 1
        render()
      end
    end

    if shared.open then
      local openId, openArg = shared.open, shared.openArg
      shared.open, shared.openArg = nil, nil
      activate({ id = openId, label = openId, arg = openArg })
    end

    if shared.refresh then
      shared.refresh = false
      items = buildItems()
      render()
    end
  end
end

---------------------------------------------------------------- inicio
local stage = "boot"

local function wait(t)
  if not GO then pause(t) end
end

local function main()
  bootBase()
  bootProgress(15, T.loadSys)
  wait(0.4)
  local cfg = loadConfig()
  if cfg then
    T = (langs[cfg.lang] or langs[1]).t
    applyTheme(cfg.theme)
  end
  bootProgress(45, T.loadUser)
  wait(0.4)
  bootProgress(75, T.loadDesk)
  wait(0.4)
  bootProgress(100, T.loadDone)
  wait(0.3)
  if not cfg then
    if configBad then errorScreen(207, CONFIG, true) end
    cfg = setup()
    saveConfig(cfg)
  end
  if cfg.hash then login(cfg) end
  stage = "desktop"
  desktop(cfg)
end

local ok, err = pcall(main)
if not ok then
  errorScreen(classify(err, stage == "boot" and 210 or 208), err, false)
end
