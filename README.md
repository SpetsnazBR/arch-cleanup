# Arch Cleanup

![Shell](https://img.shields.io/badge/Shell-Bash-blue) ![License](https://img.shields.io/badge/License-MIT-green) ![Arch](https://img.shields.io/badge/OS-Arch%20Linux-1793d1)

Utilitário de **limpeza e manutenção segura** para Arch Linux, com diagnóstico de integridade do sistema.

Desenvolvido por **SpetsnazBR**.

## 🚀 Funcionalidades

| # | Funcionalidade |
|---|----------------|
| 1 | Limpeza de arquivos temporários residuais do Pacman (`download-*`) |
| 2 | Limpeza do cache do Pacman mantendo as últimas **2 versões** (`paccache -rk2`) |
| 3 | Limpeza do cache do Yay (AUR) |
| 4 | Gerenciamento e remoção segura de pacotes órfãos (`pacman -Rns`) |
| 5 | Limpeza de logs antigos do Systemd/Journald (retensão de 2 semanas) |
| 6 | Limpeza seletiva de temporários: thumbnails, lixeira do usuário e `/var/tmp` |
| 7 | **Diagnóstico de integridade**: dependências (`pacman -Dk`) e arquivos ausentes (`pacman -Qk`) |
| 8 | Executar **todas** as rotinas de limpeza e diagnóstico |

Cada operação é **interativa** (confirmação `s/N`) — nada é removido sem o seu consentimento, exceto quando você escolhe a execução automática.

## 📋 Requisitos

- **Arch Linux** (ou derivados baseados no Arch)
- `bash`
- `pacman-contrib` (automaticamente instalado sob confirmação quando ausente — requerido para o `paccache`)
- `yay` (opcional, apenas para a limpeza do cache AUR)

## 🔧 Uso

```bash
sudo ./arch-cleanup.sh
```

O script **deve** ser executado como root e detecta automaticamente o usuário real que invocou o `sudo` para operações no `/home` (thumbnails e lixeira).

## 🛡️ Segurança

- ✅ **Validação do usuário real**: o script aborta caso não consiga determinar o home do usuário invocador — nunca executa `rm` sobre caminhos vazios ou inválidos.
- ✅ **Remoção seletiva**: `find -delete` a partir de caminhos validados; sem `rm -rf` com *globs* dependentes de variáveis.
- ✅ **Defesa em profundidade**: `xargs -r` evita execução de comandos com listas vazias.
- ✅ **Cores TTY-agnostic**: o texto funciona mesmo sem terminal colorido.
- ⚠️ **`/var/tmp`**: remove apenas **arquivos** sem acesso há mais de 7 dias. Caso possui serviços que persistem dados em `/var/tmp`, revise a lista antes de confirmar.

## 🔧 Verificação de integridade

A opção 7 executa:

- `pacman -Dk` — valida a consistência do banco de dados de dependências
- `pacman -Qk` — verifica arquivos ausentes dos pacotes instalados

Em caso de arquivos ausentes, o diagnóstico exibe o pacote afetado e sugere a reinstalação individual:

```bash
sudo pacman -S <nome-do-pacote>
```

## 📄 Licença

Distribuído sob a licença **MIT**. Veja [LICENSE](LICENSE) para mais detalhes.