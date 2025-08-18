#!/bin/bash

# ===================================
# Sentinel AK-XL - One Command Setup
# ===================================
# Instalación súper fácil para tus compañeros
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[SETUP]${NC} $1"
}

step() {
    echo -e "${BLUE}[PASO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${CYAN}"
cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
      🛡️ SENTINEL AK-XL - INSTALACIÓN AUTOMÁTICA 🛡️
         Virtual SOC para Entrenamiento Blue Team
EOF
echo -e "${NC}"

echo ""
log "🚀 Instalación automática iniciada..."
echo ""

# Verificar Docker
step "1/5 Verificando Docker..."
if ! docker --version &>/dev/null; then
    error "Docker no está instalado. Por favor instala Docker primero:"
    echo "  https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null; then
    error "Docker no está ejecutándose. Por favor inicia Docker."
    exit 1
fi

log "✅ Docker está funcionando"

# Verificar recursos del sistema
step "2/5 Verificando recursos del sistema..."
mem_gb=$(free -g | grep Mem | awk '{print $2}' 2>/dev/null || echo "0")
disk_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')

if [[ $mem_gb -lt 4 ]]; then
    error "⚠️ Memoria insuficiente: ${mem_gb}GB (se recomienda 8GB+)"
    read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [[ $disk_gb -lt 10 ]]; then
    error "⚠️ Espacio en disco insuficiente: ${disk_gb}GB (se necesita 20GB+)"
    exit 1
fi

log "✅ Recursos del sistema: ${mem_gb}GB RAM, ${disk_gb}GB disco"

# Crear archivos necesarios si no existen
step "3/5 Configurando archivos necesarios..."

# Verificar .env
if [[ ! -f .env ]]; then
    log "Creando archivo .env..."
    cat > .env << 'EOF'
# Sentinel AK-XL Environment Configuration
ELASTIC_PASSWORD=changeme123!
KIBANA_PASSWORD=changeme123!
THEHIVE_SECRET=changeme-secret-key-here
CORTEX_SECRET=changeme-cortex-key-here
ELASTICSEARCH_HEAP=2g
LOGSTASH_HEAP=1g
NETWORK_SUBNET=172.20.0.0/16
ELASTICSEARCH_PORT=9200
KIBANA_PORT=5601
LOGSTASH_PORT=5044
THEHIVE_PORT=9000
CORTEX_PORT=9001
SHUFFLE_PORT=3001
WAZUH_API_PORT=55000
DEFAULT_SCENARIO=basic
EVENT_GENERATION_RATE=100
HEALTH_CHECK_INTERVAL=30s
DEBUG_MODE=true
LOG_LEVEL=INFO
EOF
fi

# Verificar test script
if [[ ! -f test-elk.sh ]]; then
    error "❌ test-elk.sh no encontrado. ¿Estás en el directorio correcto?"
    exit 1
fi

log "✅ Archivos de configuración listos"

# Descargar imágenes Docker (si es necesario)
step "4/5 Preparando imágenes Docker..."

# Solo verificar si las imágenes están disponibles
if ! docker images | grep -q "elasticsearch.*8.11.0"; then
    log "Descargando Elasticsearch (puede tomar algunos minutos)..."
    docker pull docker.elastic.co/elasticsearch/elasticsearch:8.11.0
fi

log "✅ Imágenes Docker preparadas"

# Probar instalación
step "5/5 Probando instalación..."

log "Iniciando Elasticsearch para verificar instalación..."
chmod +x test-elk.sh

# Limpiar cualquier instalación previa
./test-elk.sh clean &>/dev/null || true

# Probar solo Elasticsearch primero
log "Probando Elasticsearch..."
if ./test-elk.sh elasticsearch &>/dev/null; then
    log "✅ Elasticsearch funcionando correctamente"
else
    error "❌ Problemas con Elasticsearch. Revisando logs..."
    docker compose -f docker-compose-test.yml logs elasticsearch | tail -10
    exit 1
fi

# Verificar acceso
if curl -s -u elastic:changeme123! http://localhost:9200 &>/dev/null; then
    log "✅ Autenticación funcionando"
else
    error "❌ Problemas de autenticación"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE! 🎉${NC}"
echo ""
echo -e "${CYAN}📋 Información de Acceso:${NC}"
echo -e "   • Elasticsearch: ${BLUE}http://localhost:9200${NC}"
echo -e "   • Usuario: ${YELLOW}elastic${NC}"
echo -e "   • Contraseña: ${YELLOW}changeme123!${NC}"
echo ""
echo -e "${CYAN}🧪 Comandos Útiles:${NC}"
echo -e "   ${YELLOW}./test-elk.sh status${NC}         # Ver estado actual"
echo -e "   ${YELLOW}./test-elk.sh kibana${NC}         # Iniciar Elasticsearch + Kibana"
echo -e "   ${YELLOW}./test-elk.sh full${NC}           # Iniciar stack completo"
echo -e "   ${YELLOW}./test-elk.sh stop${NC}           # Parar servicios"
echo ""
echo -e "${CYAN}🎯 Verificar que funciona:${NC}"
echo -e "   ${YELLOW}curl -u elastic:changeme123! http://localhost:9200${NC}"
echo ""
echo -e "${CYAN}📖 Próximos pasos:${NC}"
echo -e "1. Revisar ${YELLOW}QUICK-START.md${NC} para uso avanzado"
echo -e "2. Acceder a Kibana: ${YELLOW}./test-elk.sh kibana${NC}"
echo -e "3. Explorar configuraciones en ${YELLOW}configs/elk/${NC}"
echo ""

# Mostrar estado final
echo -e "${CYAN}📊 Estado actual:${NC}"
./test-elk.sh status

echo ""
log "✅ ¡Sentinel AK-XL listo para usar!"
