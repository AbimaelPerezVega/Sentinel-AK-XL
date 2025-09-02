#!/bin/bash

# ==========================================================
# Sincronizador de Dashboards de Kibana para Sentinel AK-XL
# ==========================================================
# Este script encuentra el dashboard exportado más reciente,
# lo copia al repositorio y prepara los comandos de Git.
# ==========================================================

# --- Configuración ---
# Directorio donde Kibana guarda las descargas (ajustar si es necesario)
DOWNLOADS_DIR="$HOME/Downloads"

# Directorio de destino en el proyecto
DESTINATION_DIR="configs/kibana_dashboards"
DESTINATION_FILE="soc_main_dashboard.ndjson"

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Sincronizador de Dashboards de Kibana iniciado...${NC}"

# --- Verificaciones ---
# 1. Verificar que el directorio de destino exista
if [ ! -d "$DESTINATION_DIR" ]; then
    echo -e "${YELLOW}El directorio de destino '$DESTINATION_DIR' no existe. Creándolo...${NC}"
    mkdir -p "$DESTINATION_DIR"
fi

# 2. Encontrar el archivo .ndjson más reciente en la carpeta de descargas
echo "🔎 Buscando el archivo de dashboard (.ndjson) más reciente en '$DOWNLOADS_DIR'..."
LATEST_FILE=$(ls -t "$DOWNLOADS_DIR"/*.ndjson 2>/dev/null | head -n 1)

if [ -z "$LATEST_FILE" ]; then
    echo -e "${RED}❌ Error: No se encontró ningún archivo .ndjson en '$DOWNLOADS_DIR'.${NC}"
    echo "Por favor, exporta tu dashboard desde Kibana primero."
    exit 1
fi

echo -e "${GREEN}✅ Archivo encontrado: $(basename "$LATEST_FILE")${NC}"

# --- Proceso de Copia ---
echo "🔄 Copiando y renombrando a '$DESTINATION_DIR/$DESTINATION_FILE'..."
cp "$LATEST_FILE" "$DESTINATION_DIR/$DESTINATION_FILE"

echo -e "${GREEN}🎉 ¡Dashboard actualizado en el repositorio!${NC}"
echo ""

# --- Instrucciones para Git ---
echo -e "${CYAN}--- Próximos Pasos: Sube tus cambios a Git ---${NC}"
echo "Ejecuta los siguientes comandos en tu terminal para compartir tu trabajo:"
echo ""
echo -e "${YELLOW}# 1. Añade el archivo al área de preparación de Git${NC}"
echo -e "git add $DESTINATION_DIR/$DESTINATION_FILE"
echo ""
echo -e "${YELLOW}# 2. Crea un commit con un mensaje descriptivo${NC}"
echo -e 'git commit -m "feat(kibana): Actualiza dashboards del SOC con nuevos gráficos"'
echo ""
echo -e "${YELLOW}# 3. Sube los cambios al repositorio remoto${NC}"
echo -e "git push"
echo ""
