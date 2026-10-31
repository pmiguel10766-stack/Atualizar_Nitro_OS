# 🚀 Nitro OS - OpenComputers (Minecraft 1.7.10)

Sistema Operativo customizado feito em Lua para o mod **OpenComputers** no Minecraft 1.7.10.

---

## 📌 Visão Geral

O **Nitro OS** é um sistema projetado para rodar em arquitetura limitada de hardware (384 KB RAM), trazendo uma interface visual gráfica, terminal nativo e suporte a aplicativos customizados.

---

## 💻 Recursos e Interface

- 🖥️ **Interface Gráfica**: Menu, Gerenciador de Arquivos, Terminal e Apps.
- 🐚 **Shell Nativo**: Prompt de comando integrado (`ls`, `cd`, `pwd`, `mkdir`, `rm`, `cat`, `wget`, `update`, `clear`).
- 🌐 **Navegador Web / Teste de Rede**: Suporte a conexões e downloads.
- 📊 **Monitor de Sistema**: Exibição de RAM livre, energia e tempo ligado em tempo real.

---

## 📱 Apps Nativos (Sistema Principal)

Estes são os aplicativos que vêm embutidos nativamente no sistema:

- **Arquivos (`mFiles`)**: Gestor de ficheiros e unidades do computador.
- **Editor de Texto (`mEditor`)**: Editor de documentos e código.
- **Calculadora (`mCalc`)**: Calculadora com operações básicas e percentagem.
- **Monitor do Sistema (`mMonitor`)**: Monitorização de uso de RAM, energia e tempo ligado (uptime).
- **Notas (`mNotes`)**: Bloco de notas rápido guardado em `/notas`.
- **Impressora 3D (`mPrinter`)**: Controlo para impressoras 3D ligadas ao sistema (modelos como cubo, pilar, placa, escada e texturas de pedra, ferro, etc.).
- **Configurações (`mSettings`)**: Gestão de idioma, tema visual, nome de utilizador, palavra-passe e estado do sistema.
- **Atualizar Nitro OS (`uTitle`)**: Sistema de atualização via GitHub (manifesto de atualização).
- **Trocar Fundo (`wTitle`)**: Alternador de fundo de ecrã (logótipo, preto, imagens ou vídeos em quadros).
- **GitDown (`mGitDown`)**: Descarregador de ficheiros do GitHub com execução restrita ou total.
- **Antivírus (`mAntivirus`)**: Analisador estático de código Lua para detetar ameaças sem executar o ficheiro.
- **AppStore (`stTitle`)**: Loja de aplicações online ligada ao repositório do Nitro OS.
- **Meus Apps (`mMyApps`)**: Gestor de aplicações instaladas na pasta `/apps`.

---

## 🧩 Gestão de Apps Externos e Instalação

O sistema suporta a execução de aplicações externas através de:

- **Pasta de Apps (`/apps` e `/nitro/apps`)**: O sistema procura por ficheiros `.lua` soltos ou pastas de aplicações que contenham um `app.lua`.
- **Leitura de Metadados**: Os apps podem definir o seu próprio nome e descrição através de comentários no início do código (`-- Name:` e `-- Desc:`).
- **AppStore / GitDown**: Permitem transferir novos apps da internet com verificação prévia de segurança através do antivírus integrado.

---

## ⚠️ Códigos de Erro (MX-XXX)

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

## 🔄 Como baixar no nitro OS

No terminal do Nitro OS, execute:
```bash
rm /init.lua
wget https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/installer.lua /init.lua
reboot
```
