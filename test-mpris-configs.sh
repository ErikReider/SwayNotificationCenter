#!/bin/bash
# Script para testar diferentes configurações do MPRIS

CONFIG_FILE="$HOME/.config/hypr/swaync/config.json"
BACKUP_FILE="$HOME/.config/hypr/swaync/config.json.backup"

# Função para aplicar uma configuração
apply_config() {
    local config_name=$1
    echo "📝 Aplicando configuração: $config_name"

    # Backup da config atual
    cp "$CONFIG_FILE" "$BACKUP_FILE"

    # Aplicar nova configuração MPRIS
    case $config_name in
        "ultra-compact")
            cat > /tmp/mpris_config.json << 'EOF'
{
  "show-album-art": "never",
  "show-title": false,
  "show-subtitle": false,
  "show-background": false,
  "show-shuffle": false,
  "show-repeat": false
}
EOF
            ;;

        "minimal")
            cat > /tmp/mpris_config.json << 'EOF'
{
  "show-album-art": "when-available",
  "show-title": true,
  "show-subtitle": false,
  "show-background": true,
  "show-shuffle": false,
  "show-repeat": false
}
EOF
            ;;

        "complete")
            cat > /tmp/mpris_config.json << 'EOF'
{
  "show-album-art": "always",
  "show-title": true,
  "show-subtitle": true,
  "show-background": true,
  "show-shuffle": true,
  "show-repeat": true
}
EOF
            ;;

        "no-art")
            cat > /tmp/mpris_config.json << 'EOF'
{
  "show-album-art": "never",
  "show-title": true,
  "show-subtitle": true,
  "show-background": false,
  "show-shuffle": true,
  "show-repeat": true
}
EOF
            ;;

        "restore")
            echo "♻️  Restaurando backup..."
            cp "$BACKUP_FILE" "$CONFIG_FILE"
            swaync-client --reload-config
            echo "✅ Configuração restaurada!"
            return
            ;;

        *)
            echo "❌ Configuração desconhecida: $config_name"
            echo "Opções: ultra-compact, minimal, complete, no-art, restore"
            return 1
            ;;
    esac

    # Validar JSON gerado
    if ! jq empty /tmp/mpris_config.json 2>/dev/null; then
        echo "❌ Erro: JSON inválido gerado"
        return 1
    fi

    # Atualizar o config.json com a nova configuração mpris
    if ! jq --slurpfile mpris /tmp/mpris_config.json \
       '.["widget-config"]["mpris"] = $mpris[0]' \
       "$CONFIG_FILE" > /tmp/config_new.json; then
        echo "❌ Erro ao processar configuração"
        return 1
    fi

    # Validar JSON final
    if ! jq empty /tmp/config_new.json 2>/dev/null; then
        echo "❌ Erro: Configuração final inválida"
        echo "🔄 Restaurando backup..."
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        return 1
    fi

    mv /tmp/config_new.json "$CONFIG_FILE"

    # Recarregar SwayNC
    swaync-client --reload-config

    echo "✅ Configuração '$config_name' aplicada!"
    echo "📱 Teste reproduzindo música para ver as mudanças"
}

# Menu interativo
show_menu() {
    echo ""
    echo "🎵 MPRIS Configuration Tester"
    echo "=============================="
    echo ""
    echo "Escolha uma configuração:"
    echo ""
    echo "  1) Ultra-Compact    - Apenas 3 botões (⏮️ ⏯️ ⏭️)"
    echo "  2) Minimal          - Capa + título + 3 botões"
    echo "  3) Complete         - Todos os elementos"
    echo "  4) No-Art           - Sem imagens, todos os botões"
    echo "  5) Restore          - Restaurar backup"
    echo "  q) Sair"
    echo ""
    read -p "Opção: " choice

    case $choice in
        1) apply_config "ultra-compact" ;;
        2) apply_config "minimal" ;;
        3) apply_config "complete" ;;
        4) apply_config "no-art" ;;
        5) apply_config "restore" ;;
        q|Q) exit 0 ;;
        *) echo "❌ Opção inválida"; show_menu ;;
    esac
}

# Verificar dependências
if ! command -v jq &> /dev/null; then
    echo "❌ Erro: jq não está instalado"
    echo "Instale com: sudo pacman -S jq"
    exit 1
fi

if ! command -v swaync-client &> /dev/null; then
    echo "❌ Erro: swaync-client não encontrado"
    exit 1
fi

# Verificar se config existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erro: $CONFIG_FILE não existe"
    exit 1
fi

# Se argumento foi passado, aplicar diretamente
if [ $# -eq 1 ]; then
    apply_config "$1"
else
    # Modo interativo
    show_menu
fi
