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

## 🔄 Como Atualizar no OpenComputers

No terminal do Nitro OS, execute:
```bash
rm /init.lua
wget https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/installer.lua](https://raw.githubusercontent.com/pmiguel10766-stack/-opencomputers-script/refs/heads/main/installer.lua /init.lua
reboot
