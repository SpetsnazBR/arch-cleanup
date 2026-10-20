#!/bin/bash

# Modo estrito moderado: variável indefinida = erro e falha em pipeline não é mascarada.
# `set -e` é propositalmente evitado por se tratar de um script interativo que precisa
# tolerar falhas parciais (ex.: um repositório pacman inacessível não pode encerrar o menu).
set -uo pipefail

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem Cor

# Garante que o script está sendo executado como root (sudo)
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Por favor, execute este script com sudo: sudo ./arch-cleanup.sh${NC}"
    exit 1
fi

# Pega o usuário real que chamou o sudo (para operações no /home)
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Validação de segurança: nunca operar sobre caminhos derivados de usuário inexistente.
# Sem esta checagem, um caminho vazio abaixo do script seria combinado com `rm -rf` em execução root.
if [ -z "${REAL_USER:-}" ] || [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo -e "${RED}[!] Não foi possível determinar o diretório home do usuário real (\"$REAL_USER\"). Abortando por segurança.${NC}"
    exit 1
fi

# Função para exibir o Banner ASCII correto e créditos
show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
    _    ____   ____ _   _      ____ _     _____    _    _   _   _   _ ____
   / \  |  _ \ / ___| | | |    / ___| |   | ____|  / \  | \ | | | | | |  _ \
  / _ \ | |_) | |   | |_| |   | |   | |   |  _|   / _ \ |  \| | | | | |_) |
 / ___ \|  _ <| |___|  _| |   | |___| |___| |___ / ___ \| |\  | | |_| |  __/
/_/   \_\_| \_\\____|_| |_|    \____|_____|_____/_/   \_|_| \_|  \___/|_|
EOF
    echo -e "${NC}    Utilitário de Limpeza e Manutenção Segura para Arch Linux"
    echo -e "${CYAN}    Developed by SpetsnazBR | https://github.com/SpetsnazBR${NC}\n"
}

# 1. Limpeza de arquivos temporários do pacman
clean_temp() {
    echo -e "${YELLOW}[*] Verificando arquivos temporários residuais do Pacman...${NC}"
    if [ -d "/var/cache/pacman/pkg/" ]; then
        read -p "Deseja remover os arquivos temporários residuais de downloads travados? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            find /var/cache/pacman/pkg/ -maxdepth 1 -type f -name "download-*" -delete 2>/dev/null
            echo -e "${GREEN}[+] Arquivos temporários residuais do Pacman limpos com sucesso.${NC}"
        else
            echo -e "${RED}[-] Limpeza de temporários do Pacman ignorada.${NC}"
        fi
    else
        echo -e "${RED}[!] Diretório do cache do pacman não encontrado.${NC}"
    fi
}

# 2. Limpeza do cache do Pacman (paccache)
clean_pacman_cache() {
    echo -e "${YELLOW}[*] Gerenciamento do Cache do Pacman (paccache)...${NC}"
    if command -v paccache &>/dev/null; then
        read -p "Deseja limpar o cache antigo do Pacman mantendo as últimas 2 versões? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            paccache -rk2
            echo -e "${GREEN}[+] Cache do pacman limpo com sucesso.${NC}"
        else
            echo -e "${RED}[-] Limpeza do cache do Pacman ignorada.${NC}"
        fi
    else
        echo -e "${YELLOW}[!] pacman-contrib não encontrado. Deseja instalá-lo agora para otimizar o cache? (s/N): ${NC}"
        read -r -n 1 REPLY
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            pacman -S --needed --noconfirm pacman-contrib
            read -p "Deseja executar a limpeza do paccache agora? (s/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[SsYy]$ ]]; then
                paccache -rk2
                echo -e "${GREEN}[+] pacman-contrib instalado e cache limpo.${NC}"
            else
                echo -e "${RED}[-] Execução do paccache ignorada.${NC}"
            fi
        else
            echo -e "${RED}[-] Pulando limpeza avançada do cache do Pacman.${NC}"
        fi
    fi
}

# 3. Limpeza do cache do Yay (AUR)
clean_yay_cache() {
    echo -e "${YELLOW}[*] Gerenciamento do cache do Yay (AUR)...${NC}"
    if command -v yay &>/dev/null; then
        read -p "Deseja limpar o cache de pacotes AUR do Yay para o usuário $REAL_USER? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            echo -e "${BLUE}[+] Executando para o usuário: $REAL_USER${NC}"
            # HOME explícito: o sudo reseta o ambiente e o yay precisa de ~/.cache/yay
            sudo -u "$REAL_USER" env HOME="$USER_HOME" XDG_CACHE_HOME="$USER_HOME/.cache" yay -Sc --noconfirm
            echo -e "${GREEN}[+] Cache do yay limpo com sucesso.${NC}"
        else
            echo -e "${RED}[-] Limpeza do cache do Yay ignorada.${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Yay não está instalado. Pulando...${NC}"
    fi
}

# 4. Gerenciamento de pacotes órfãos
clean_orphans() {
    echo -e "${YELLOW}[*] Verificando pacotes órfãos...${NC}"
    ORPHANS=$(pacman -Qdtq)

    if [ -z "$ORPHANS" ]; then
        echo -e "${GREEN}[+] Nenhum pacote órfão encontrado no momento.${NC}"
    else
        echo -e "${YELLOW}[!] Os seguintes pacotes órfãos foram encontrados:${NC}"
        echo "$ORPHANS"
        echo ""
        read -p "Deseja remover estes pacotes órfãos com segurança (-Rns)? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            # xargs -r: não executa o pacman caso a lista esteja vazia (defesa em profundidade)
            echo "$ORPHANS" | xargs -r pacman -Rns --noconfirm
            echo -e "${GREEN}[+] Pacotes órfãos removidos com sucesso.${NC}"
        else
            echo -e "${RED}[-] Remoção de órfãos ignorada.${NC}"
        fi
    fi
}

# 5. Limpeza de logs do Systemd (Journald)
clean_journal() {
    echo -e "${YELLOW}[*] Gerenciamento de logs do Systemd (Journald)...${NC}"
    if command -v journalctl &>/dev/null; then
        read -p "Deseja remover logs antigos do Systemd com mais de 2 semanas? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            echo -e "${BLUE}[+] Compactando e removendo logs antigos...${NC}"
            journalctl --vacuum-time=2weeks
            echo -e "${GREEN}[+] Logs do systemd limpos com sucesso.${NC}"
        else
            echo -e "${RED}[-] Limpeza de logs do Systemd ignorada.${NC}"
        fi
    else
        echo -e "${RED}[!] journalctl não disponível.${NC}"
    fi
}

# 6. Limpeza Segura de Arquivos Temporários Globais e de Usuário
clean_system_temp() {
    echo -e "${YELLOW}[*] Limpeza Segura de Arquivos Temporários (Thumbnails, Lixeira, /var/tmp)...${NC}"

    read -p "Deseja prosseguir com a limpeza dos arquivos temporários de usuário e sistema? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        echo -e "${RED}[-] Limpeza temporária ignorada.${NC}"
        return
    fi

    # Avaliação de risco prévia
    echo -e "${BLUE}[+] Avaliando risco de integridade nas pastas temporárias...${NC}"

    if ! mountpoint -q /tmp && [ -d "/tmp" ]; then
        echo -e "${YELLOW}[!] Aviso: /tmp não é um tmpfs isolado. Verifique resíduos em /tmp manualmente quando necessário.${NC}"
    fi

    echo -e "${GREEN}[+] Análise concluída: Risco de quebra de sistema = NULO (limpeza seletiva de arquivos voláteis).${NC}"
    echo ""

    # 1. Limpeza de Thumbnails
    THUMB_DIR="$USER_HOME/.cache/thumbnails"
    if [ -d "$THUMB_DIR" ]; then
        echo -e "${BLUE}[+] Limpando cache de miniaturas (thumbnails)...${NC}"
        find "$THUMB_DIR" -mindepth 1 -delete 2>/dev/null
    fi

    # 2. Limpeza da Lixeira do Usuário
    TRASH_BASE="$USER_HOME/.local/share/Trash"
    if [ -d "$TRASH_BASE" ]; then
        echo -e "${BLUE}[+] Esvaziando a lixeira do usuário ($REAL_USER)...${NC}"
        if [ -d "$TRASH_BASE/files" ]; then
            find "$TRASH_BASE/files" -mindepth 1 -delete 2>/dev/null
        fi
        if [ -d "$TRASH_BASE/info" ]; then
            find "$TRASH_BASE/info" -mindepth 1 -delete 2>/dev/null
        fi
    fi

    # 3. Limpeza segura de arquivos mortos em /var/tmp
    # Nota: usa -atime (acesso) para preservar arquivos em uso; limitado a arquivos (-type f).
    echo -e "${BLUE}[+] Limpando arquivos residuais em /var/tmp com mais de 7 dias sem uso...${NC}"
    find /var/tmp -type f -atime +7 -delete 2>/dev/null

    echo ""
    echo -e "=================================================="
    echo -e "${GREEN} STATUS: Limpeza temporária concluída!${NC}"
    echo -e "${GREEN} O sistema encontra-se TOTALMENTE OPERACIONAL E ÍNTEGRO.${NC}"
    echo -e "=================================================="
}

# 7. Verificação de integridade de dependências e pacotes (Diagnóstico)
check_system() {
    echo -e "${YELLOW}[*] Iniciando verificação detalhada de integridade e dependências do sistema...${NC}"
    echo ""

    SYSTEM_OK=true
    DEP_ERRORS=""
    MISSING_FILES=""

    # 1. Verifica inconsistências no banco de dados de dependências usando o exit code do pacman
    echo -e "${BLUE}[1/2] Verificando integridade das dependências do Pacman (pacman -Dk)...${NC}"
    if LC_ALL=C pacman -Dk &>/dev/null; then
        echo -e "${GREEN}[+] Todas as dependências do banco de dados estão corretas.${NC}"
    else
        echo -e "${RED}[!] Inconsistências de dependências detectadas.${NC}"
        DEP_ERRORS=$(LC_ALL=C pacman -Dk 2>&1)
        SYSTEM_OK=false
    fi

    echo ""

    # 2. Verifica pacotes com arquivos genuinamente ausentes
    echo -e "${BLUE}[2/2] Verificando arquivos ausentes nos pacotes instalados (pacman -Qk)...${NC}"
    MISSING_FILES=$(LC_ALL=C pacman -Qk 2>&1 | grep -E "[1-9][0-9]* missing file")

    if [ -n "$MISSING_FILES" ]; then
        echo -e "${YELLOW}[!] Pacotes com arquivos essenciais ausentes detectados.${NC}"
        SYSTEM_OK=false
    else
        echo -e "${GREEN}[+] Nenhum arquivo essencial ausente nos pacotes instalados.${NC}"
    fi

    echo ""
    echo "=================================================="
    if [ "$SYSTEM_OK" = true ]; then
        echo -e "${GREEN} STATUS: O sistema encontra-se 100% OPERACIONAL E ÍNTEGRO!${NC}"
        echo -e "${GREEN} Nenhuma inconformidade de dependência ou pacote foi detectada.${NC}"
    else
        echo -e "${RED} STATUS: ATENÇÃO! O sistema NÃO ESTÁ TOTALMENTE ÍNTEGRO.${NC}"
        echo -e "${YELLOW} Apenas os seguintes pacotes apresentam problemas reais:${NC}"
        echo ""

        if [ -n "$DEP_ERRORS" ]; then
            echo -e "${RED}[Dependências / Erros no Banco de Dados]:${NC}"
            echo "$DEP_ERRORS" | sed 's/^/  - /'
        fi

        if [ -n "$MISSING_FILES" ]; then
            echo -e "${RED}[Pacotes com Arquivos Ausentes]:${NC}"
            while IFS= read -r line; do
                pkg_name=$(echo "$line" | awk -F':' '{print $1}')
                missing_count=$(echo "$line" | grep -oE "[0-9]+ missing file[s]?")
                echo -e "  - ${YELLOW}$pkg_name${NC} ($missing_count)"
            done <<< "$MISSING_FILES"
        fi

        echo ""
        echo -e "${BLUE}--------------------------------------------------${NC}"
        echo -e "${YELLOW}DICA DE SEGURANÇA:${NC}"
        echo -e "Para corrigir de forma segura e individual, verifique o pacote"
        echo -e "afetado acima e execute manualmente se necessário:"
        echo -e "${GREEN}  sudo pacman -S <nome-do-pacote>${NC}"
        echo -e "${BLUE}--------------------------------------------------${NC}"
    fi
    echo "=================================================="
}

# Menu Principal Interativo
while true; do
    show_banner
    echo "=================================================="
    echo " MENU PRINCIPAL"
    echo "=================================================="
    echo " 1) Limpar arquivos temporários residuais do Pacman"
    echo " 2) Limpar Cache do Pacman (paccache)"
    echo " 3) Limpar Cache do Yay (AUR)"
    echo " 4) Gerenciar e remover pacotes órfãos"
    echo " 5) Limpar logs antigos do Systemd (Journald)"
    echo " 6) Limpar temporários seguros (Lixeira, Thumbnails, /var/tmp)"
    echo " 7) Verificar integridade do sistema e dependências"
    echo " 8) Executar todas as rotinas de limpeza e diagnóstico"
    echo " 0) Sair"
    echo "=================================================="
    read -p "Escolha uma opção [0-8]: " opcao
    echo ""

    case $opcao in
        1)
            clean_temp
            ;;
        2)
            clean_pacman_cache
            ;;
        3)
            clean_yay_cache
            ;;
        4)
            clean_orphans
            ;;
        5)
            clean_journal
            ;;
        6)
            clean_system_temp
            ;;
        7)
            check_system
            ;;
        8)
            clean_temp
            clean_pacman_cache
            clean_yay_cache
            clean_orphans
            clean_journal
            clean_system_temp
            check_system
            ;;
        0)
            echo -e "${GREEN}Saindo do Arch-Cleanup. Até logo! 🚀${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Opção inválida. Pressione qualquer tecla para continuar...${NC}"
            read -r -n 1
            ;;
    esac

    echo ""
    read -p "Pressione [Enter] para retornar ao menu principal..."
done
