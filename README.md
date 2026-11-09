# 🚀 Nitro OS - OpenComputers (Minecraft 1.7.10)

Sistema operacional feito em Lua para o mod **OpenComputers** no Minecraft 1.7.10.
Versão atual: **1.30**.

---

## 📌 Visão Geral

O **Nitro OS** roda em computadores com pouca memória (384 KB de RAM) e traz uma interface gráfica com janelas, menu, área de trabalho, aplicativos próprios e uma loja de apps.

---

## 💻 Recursos

- 🖥️ **Interface gráfica:** área de trabalho com ícones, menu ◆ Nitro, barra de tarefas, janelas que podem ser arrastadas, minimizadas e maximizadas.
- 🎨 **Temas e papéis de parede:** Vermelho Nitro, Azul, Roxo, **Halloween** e **Natal**. Papéis de parede em imagem, cor sólida ou vídeo em quadros.
- 🔒 **Segurança:**
  - Tela de bloqueio (**Ctrl+L**, pelo menu, ou automático depois de X minutos parado).
  - Senha com bloqueio de **5 minutos** depois de 3 tentativas erradas (o tempo dobra a cada novo ciclo, até 30 minutos).
  - Antivírus que analisa o código antes de instalar ou executar, com painel de cartões e histórico.
- 🌐 **Rede Local:** conversa com outros computadores por perto (mensagens e arquivos), com antivírus no recebimento. Compatível com o OpenOS (`openos/rede_local.lua`).
- 🛠️ **Ferramentas de código:** Editor Lua com realce de sintaxe e números de linha, e biblioteca de trechos de código.
- 💾 **Recuperação pela BIOS:** a tela **Nitro BIOS** aceita F9 (menu de recuperação em estilo PhoenixBIOS) e F10 (reparar o sistema).

---

## 📱 Aplicativos Nativos

- **Arquivos:** navega pelo disco, abre, cria, renomeia, move, copia e apaga arquivos e pastas.
- **Editor de Texto:** edita arquivos de texto, com copiar e colar (Ctrl+Insert / Shift+Insert) e colar com o botão do meio.
- **Editor Lua:** edita código com cores por tipo de palavra, números de linha e indentação automática. Não executa o código.
- **Notas:** anotações guardadas em `/notas`.
- **Calculadora:** operações básicas, percentagem e teclado.
- **Monitor do Sistema:** RAM, energia e tempo ligado.
- **Terminal seguro:** comandos de arquivos e rede (`ls`, `cd`, `cat`, `cp`, `mv`, `touch`, `echo`, `tail`, `mkdir`, `rm`, `net`, `ping`, `apps`, `install`, `history`, `help` e outros). Não executa código digitado.
- **Rede Local:** procura computadores, envia mensagens e arquivos, e bloqueia remetentes quando necessário.
- **Impressora 3D:** imprime modelos (cubo, pilar, placa, escada) com texturas de pedra, madeira e ferro.
- **Configurações:** categorias Sistema, Rede, Personalização, Aplicativos, Contas, Hora e idioma, Privacidade e Atualização.
- **Atualizar Nitro OS:** verifica e instala a versão nova a partir do GitHub.
- **Trocar Fundo:** escolhe o papel de parede.
- **GitDown:** baixa arquivos do GitHub para `/Download`. Pode executar com acesso total ou em modo restrito.
- **Antivírus:** analisa arquivos `.lua` em busca de padrões perigosos, sem executá-los. Painel com cartões para vírus, conta, rede, apps, integridade e desempenho.
- **AppStore:** loja com abas (Início, Apps, Atualizar, Remover), busca, categorias e análise de segurança antes de instalar.
- **Meus Apps:** lista os apps instalados em `/apps`.

---

## 🧩 Apps externos e segurança

- **Pastas de apps:** `/apps` e `/nitro/apps`. O sistema aceita arquivos `.lua` soltos ou pastas com um `app.lua` dentro.
- **Nome e descrição:** o app declara no começo do arquivo:
  ```lua
  -- name: Meu App
  -- desc: O que ele faz
  ```
- **Ambiente restrito:** apps instalados não têm acesso ao sistema. Eles usam a API `nitro`, que permite:
  - desenhar na tela e ler o tamanho da tela (`nitro.put`, `nitro.rect`, `nitro.gpu`);
  - ler arquivos só de `/apps` e `/Download`, e gravar só em `/Download`;
  - acessar a internet só em sites do GitHub;
  - esperar eventos com `nitro.pull`.
  Não há acesso a `component`, `computer`, `os`, `debug` nem `load`.
- **Instalação segura:** a AppStore e o Terminal (`install`) analisam o código com o antivírus antes de gravar em `/apps`.

---

## ⚠️ Códigos de erro (MX-XXX)

| Código | Descrição (Português) | Description (English) |
| :--- | :--- | :--- |
| **MX-203** | Sistema corrompido | System corrupted |
| **MX-204** | Sistema sem RAM | System out of RAM |
| **MX-205** | Falha ao atualizar | Update failed |
| **MX-206** | Problema no boot do sistema | System boot problem |
| **MX-207** | Problema em app ou usuário | App or user problem |
| **MX-208** | Erro desconhecido | Unknown error |
| **MX-209** | Falha na interface (GUI) | Interface (GUI) failure |
| **MX-210** | Falha no kernel | Kernel failure |
| **MX-211** | Possível vírus no sistema | Possible virus in the system |

---

## 🔄 Como instalar ou reparar

**Opção 1 – pela Nitro BIOS (recomendada)**
1. Ligue o computador e aperte **F10** (Reparar): baixa `init.lua` e `boot.lua` do GitHub e grava no disco.
2. Ou aperte **F9** (Recuperação) e escolha **Reinstalar** para usar o instalador completo.

**Opção 2 – pelo OpenOS**
```bash
rm /init.lua
wget -f https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/installer.lua /init.lua
Reboot
```
ou
```bash
wget https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/nitro_bios.lua nitro_bios.lua && flash nitro_bios.lua && rm nitro_bios.lua
Reboot
```

**Atualizar um sistema já instalado:** abra **Configurações → Atualizar Nitro OS → Verificar atualização → Atualizar agora**.

---

## 📝 Histórico recente

- **1.30:** apps instalados rodam em ambiente restrito (API `nitro`).
- **1.29:** bloqueio de 5 minutos depois de 3 senhas erradas.
- **1.28:** colar com o botão do meio nos editores.
- **1.27:** Enter e quebra de linha corrigidos nos editores.
- **1.26:** Editor Lua com realce e números de linha.
- **1.25:** temas Halloween e Natal.
- **1.23:** Terminal com `cp`, `mv`, `touch`, `echo`, `tail`, `net`, `ping`, `apps`, `history`, `help` e `install`.
- **1.21:** tela de bloqueio (Ctrl+L, menu e automático).
- **1.19:** AppStore com abas, busca, categorias e atualização.
- **1.17:** copiar e colar no Editor de Texto (Ctrl+Insert e Shift+Insert).
