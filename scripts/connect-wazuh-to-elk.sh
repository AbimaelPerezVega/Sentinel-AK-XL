#!/bin/bash
# ==============================================================================
# SCRIPT DEFINITIVO para Conectar Wazuh a Elasticsearch en WSL
# Método: Inicia Wazuh de forma limpia y luego inyecta la configuración.
# ==============================================================================
set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}--- Iniciando la conexión de Wazuh a ELK (Método Limpio) ---${NC}"

# --- 1. Limpieza Completa ---
echo "✅ Paso 1: Realizando una limpieza completa..."
docker compose down -v
echo -e "${GREEN}Entorno limpio.${NC}"

# --- 2. Iniciar Servicios ---
echo -e "\n✅ Paso 2: Iniciando todos los servicios. Wazuh se auto-inicializará sin conflictos."
docker compose up -d

echo -e "\n${YELLOW}Esperando 90 segundos para que todos los servicios, especialmente Wazuh, se estabilicen...${NC}"
sleep 90

# --- 3. Crear Configuración de Filebeat ---
FILEBEAT_CONFIG="./configs/wazuh/filebeat/filebeat.yml"
echo "✅ Paso 3: Creando configuración de Filebeat..."
mkdir -p ./configs/wazuh/filebeat
cat > "$FILEBEAT_CONFIG" << 'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/ossec/logs/alerts/alerts.json
  json.keys_under_root: true
  json.overwrite_keys: true
output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  protocol: "http"
EOF
echo -e "${GREEN}Archivo filebeat.yml creado.${NC}"

# --- 4. Añadir Integración a ossec.conf ---
# Primero, leemos la configuración por defecto que generó el contenedor
echo -e "\n✅ Paso 4: Modificando la configuración de Wazuh para añadir la integración..."
docker cp sentinel-wazuh-manager:/var/ossec/etc/ossec.conf ./configs/wazuh/ossec.conf.tmp

# Añadimos nuestro bloque de integración antes de la etiqueta de cierre
sed -i '/<\/ossec_config>/i \
  <integration>\
    <name>elasticsearch</name>\
    <hook_url>http:\/\/elasticsearch:9200<\/hook_url>\
    <level>3<\/level>\
    <alert_format>json<\/alert_format>\
  <\/integration>' ./configs/wazuh/ossec.conf.tmp

echo -e "${GREEN}Bloque de integración añadido a ossec.conf.${NC}"

# --- 5. Copiar Ambas Configuraciones al Contenedor ---
echo -e "\n✅ Paso 5: Copiando la configuración finalizada al contenedor..."
docker cp "$FILEBEAT_CONFIG" sentinel-wazuh-manager:/etc/filebeat/filebeat.yml
docker cp ./configs/wazuh/ossec.conf.tmp sentinel-wazuh-manager:/var/ossec/etc/ossec.conf
rm ./configs/wazuh/ossec.conf.tmp # Limpiamos el archivo temporal

# --- 6. Reiniciar solo el Manager para Aplicar Cambios ---
echo -e "\n✅ Paso 6: Reiniciando wazuh-manager para aplicar los cambios..."
docker compose restart wazuh-manager

echo -e "\n${YELLOW}Reinicio completo. Esperando 45 segundos para la verificación final...${NC}"
sleep 45

# --- 7. Verificación Final ---
echo -e "\n${BLUE}--- Verificando la Conexión ---${NC}"
LOG_OUTPUT=$(docker logs sentinel-wazuh-manager 2>&1)

if echo "$LOG_OUTPUT" | grep -q "Connection to http://elasticsearch:9200 established"; then
    echo -e "${GREEN}🎉🎉🎉 ¡VICTORIA! ¡La conexión con Elasticsearch está funcionando! 🎉🎉🎉${NC}"
    echo "La pipeline de datos está activa. Ya puedes registrar agentes."
else
    echo -e "${RED}❌ La conexión aún no se confirma.${NC}"
    echo -e "${YELLOW}Revisa los logs para más detalles. El problema de inicialización debería estar resuelto.${NC}"
    echo "docker logs -f sentinel-wazuh-manager"
fi
