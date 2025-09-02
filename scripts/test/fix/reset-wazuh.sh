#!/bin/bash
# ==============================================================================
# Script para Resetear y Reparar la Instancia de Wazuh Manager (V2)
# Limpia volúmenes corruptos y reinicia con la configuración correcta de Filebeat
# ==============================================================================
set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}--- Iniciando el reseteo y reparación de Wazuh Manager ---${NC}"

# --- 1. Detener todos los servicios ---
echo "✅ Paso 1: Deteniendo todos los contenedores..."
docker compose down

# --- 2. Limpiar volúmenes problemáticos de Wazuh ---
echo -e "\n${YELLOW}⚠️  Paso 2: Se eliminarán los volúmenes de Wazuh para empezar de cero.${NC}"
echo "Esto borrará los datos de agente y reglas DENTRO del contenedor, pero es necesario."
docker volume rm sentinel-soc_wazuh-etc 2>/dev/null || true
docker volume rm sentinel-soc_wazuh-logs 2>/dev/null || true
echo -e "${GREEN}Volúmenes de Wazuh eliminados.${NC}"

# --- 3. Crear la configuración correcta de Filebeat ---
FILEBEAT_CONFIG="./configs/wazuh/filebeat/filebeat.yml"
echo -e "\n✅ Paso 3: Creando la configuración de Filebeat..."
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
# IMPORTANTE: NO usamos "sudo chown" aquí. El archivo pertenecerá a tu usuario.
echo -e "${GREEN}Configuración de Filebeat creada (propiedad de tu usuario).${NC}"

# --- 4. Iniciar todo de nuevo ---
echo -e "\n✅ Paso 4: Iniciando todos los servicios con la configuración limpia..."
docker compose up -d

echo -e "\n${GREEN}🚀 Servicios iniciados. Esperando 60 segundos para que se estabilicen...${NC}"
sleep 60

# --- 5. Verificación final ---
echo -e "\n${BLUE}--- Paso 5: Verificando la conexión ---${NC}"
if docker logs sentinel-wazuh-manager 2>&1 | grep -q "Connection to http://elasticsearch:9200 established"; then
    echo -e "${GREEN}🎉 ¡ÉXITO! La conexión entre Wazuh y Elasticsearch está funcionando.${NC}"
    echo "Ya puedes volver a registrar tu agente de Sysmon. Las alertas aparecerán en Kibana."
else
    echo -e "${YELLOW}⚠️ La conexión aún no se confirma. Revisa los logs para más detalles:${NC}"
    echo "docker logs sentinel-wazuh-manager"
fi