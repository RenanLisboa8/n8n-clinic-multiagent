#!/bin/bash

# ========================================
# Script de Importação em Massa de Workflows
# Sistema Multi-Agente para Gestão de Clínicas
# Copyright (c) 2026. Todos os Direitos Reservados.
# ========================================
# 
# Este script importa todos os workflows do projeto
# para uma instância n8n de uma só vez.
#
# Uso:
#   ./scripts/import-workflows.sh
#   ./scripts/import-workflows.sh --container nome_container
#   ./scripts/import-workflows.sh --api http://localhost:5678 --api-key KEY
#
# ========================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrão
N8N_CONTAINER="${N8N_CONTAINER:-clinic_n8n}"
N8N_API_URL="${N8N_API_URL:-}"
N8N_API_KEY="${N8N_API_KEY:-}"
WORKFLOWS_DIR="$(dirname "$0")/../workflows"
METHOD="cli"  # cli ou api

# Contadores
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# ========================================
# Funções de Utilidade
# ========================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================"
    echo "🔄 Importação em Massa de Workflows n8n"
    echo "   Sistema Multi-Agente para Clínicas"
    echo -e "========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}── $1 ──${NC}"
}

print_success() {
    echo -e "   ${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "   ${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "   ${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_help() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  -c, --container NAME    Nome do container Docker do n8n (padrão: clinic_n8n)"
    echo "  -u, --api URL           URL da API do n8n (ex: http://localhost:5678)"
    echo "  -k, --api-key KEY       Chave da API do n8n"
    echo "  -d, --dir PATH          Diretório dos workflows (padrão: ./workflows)"
    echo "  -m, --method METHOD     Método de importação: 'cli' ou 'api' (padrão: cli)"
    echo "  -h, --help              Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                                          # Usa CLI via Docker (padrão)"
    echo "  $0 --container meu_n8n                      # Container personalizado"
    echo "  $0 --api http://localhost:5678 --api-key X  # Via API REST"
    echo ""
}

# ========================================
# Parse de Argumentos
# ========================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            N8N_CONTAINER="$2"
            shift 2
            ;;
        -u|--api)
            N8N_API_URL="$2"
            METHOD="api"
            shift 2
            ;;
        -k|--api-key)
            N8N_API_KEY="$2"
            shift 2
            ;;
        -d|--dir)
            WORKFLOWS_DIR="$2"
            shift 2
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# ========================================
# Verificações
# ========================================

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker não encontrado! Instale o Docker primeiro."
        exit 1
    fi
    
    if ! docker ps | grep -q "$N8N_CONTAINER"; then
        print_error "Container '$N8N_CONTAINER' não está rodando!"
        echo ""
        echo "   Inicie o container com:"
        echo "   docker compose up -d"
        echo ""
        exit 1
    fi
}

check_api() {
    if [ -z "$N8N_API_URL" ]; then
        print_error "URL da API não especificada!"
        echo "   Use: --api http://localhost:5678"
        exit 1
    fi
    
    if [ -z "$N8N_API_KEY" ]; then
        print_error "API Key não especificada!"
        echo "   Use: --api-key SUA_CHAVE"
        echo "   Configure em n8n: Settings > API > Create API Key"
        exit 1
    fi
    
    # Testar conexão
    if ! curl -s -f "$N8N_API_URL/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" > /dev/null 2>&1; then
        print_error "Não foi possível conectar à API do n8n!"
        echo "   URL: $N8N_API_URL"
        exit 1
    fi
}

check_workflows_dir() {
    if [ ! -d "$WORKFLOWS_DIR" ]; then
        print_error "Diretório de workflows não encontrado: $WORKFLOWS_DIR"
        exit 1
    fi
}

# ========================================
# Funções de Importação
# ========================================

import_workflow_cli() {
    local file=$1
    local filename=$(basename "$file")
    
    TOTAL=$((TOTAL + 1))
    
    # Copiar arquivo para container e importar
    if docker cp "$file" "$N8N_CONTAINER:/tmp/$filename" 2>/dev/null; then
        if docker exec "$N8N_CONTAINER" n8n import:workflow --input="/tmp/$filename" 2>/dev/null; then
            print_success "$filename"
            SUCCESS=$((SUCCESS + 1))
            # Limpar arquivo temporário
            docker exec "$N8N_CONTAINER" rm -f "/tmp/$filename" 2>/dev/null || true
            return 0
        else
            # Pode já existir - tentar verificar
            print_warning "$filename (pode já existir)"
            SKIPPED=$((SKIPPED + 1))
            docker exec "$N8N_CONTAINER" rm -f "/tmp/$filename" 2>/dev/null || true
            return 0
        fi
    else
        print_error "$filename (falha ao copiar)"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

import_workflow_api() {
    local file=$1
    local filename=$(basename "$file")
    
    TOTAL=$((TOTAL + 1))
    
    # Ler o workflow e fazer POST na API
    local response=$(curl -s -w "\n%{http_code}" -X POST "$N8N_API_URL/api/v1/workflows" \
        -H "Content-Type: application/json" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -d @"$file" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_success "$filename"
        SUCCESS=$((SUCCESS + 1))
        return 0
    elif [ "$http_code" = "409" ]; then
        print_warning "$filename (já existe)"
        SKIPPED=$((SKIPPED + 1))
        return 0
    else
        print_error "$filename (HTTP $http_code)"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

import_workflow() {
    if [ "$METHOD" = "api" ]; then
        import_workflow_api "$1"
    else
        import_workflow_cli "$1"
    fi
}

import_directory() {
    local dir=$1
    local name=$2
    
    if [ ! -d "$dir" ]; then
        return
    fi
    
    local files=$(find "$dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort)
    
    if [ -n "$files" ]; then
        print_section "$name"
        
        for file in $files; do
            import_workflow "$file"
        done
    fi
}

# ========================================
# Execução Principal
# ========================================

main() {
    print_header
    
    # Verificações
    check_workflows_dir
    
    if [ "$METHOD" = "api" ]; then
        print_info "Método: API REST"
        check_api
    else
        print_info "Método: CLI via Docker"
        check_docker
    fi
    
    # Contar workflows
    local workflow_count=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    print_info "Workflows encontrados: $workflow_count"
    
    echo ""
    echo "Iniciando importação..."
    
    # Importar por categoria
    import_directory "$WORKFLOWS_DIR/main" "📋 Main Workflows (Workflows Principais)"
    import_directory "$WORKFLOWS_DIR/sub" "🔄 Sub-Workflows"
    import_directory "$WORKFLOWS_DIR/tools/calendar" "📅 Calendar Tools (Ferramentas de Agenda)"
    import_directory "$WORKFLOWS_DIR/tools/communication" "💬 Communication Tools (Ferramentas de Comunicação)"
    import_directory "$WORKFLOWS_DIR/tools/ai-processing" "🤖 AI Processing Tools (Processamento de IA)"
    import_directory "$WORKFLOWS_DIR/tools/escalation" "🚨 Escalation Tools (Ferramentas de Escalonamento)"
    
    # Relatório final
    echo ""
    echo -e "${BLUE}========================================"
    echo "📊 Relatório de Importação"
    echo -e "========================================${NC}"
    echo ""
    echo -e "   Total processado:  ${BLUE}$TOTAL${NC}"
    echo -e "   Sucesso:           ${GREEN}$SUCCESS${NC}"
    echo -e "   Já existentes:     ${YELLOW}$SKIPPED${NC}"
    echo -e "   Falhas:            ${RED}$FAILED${NC}"
    echo ""
    
    if [ $FAILED -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Alguns workflows falharam. Verifique os erros acima.${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}✅ Importação concluída!${NC}"
    echo ""
    echo "📋 Próximos passos:"
    echo "   1. Acesse o n8n: http://localhost:5678"
    echo "   2. Vá em 'Workflows'"
    echo "   3. Configure as credenciais em cada workflow:"
    echo "      • Google Gemini API"
    echo "      • PostgreSQL"
    echo "      • Evolution API"
    echo "      • Telegram Bot"
    echo "      • Google OAuth (Calendar/Tasks)"
    echo "   4. Ative os workflows principais"
    echo ""
    
    # Exit code baseado em falhas
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# Executar
main

