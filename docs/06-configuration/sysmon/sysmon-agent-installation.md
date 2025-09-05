📋 Instrucciones de Instalación - Phase 5: Sysmon Deployment
🎯 Para tus compañeros de equipo
⚠️ IMPORTANTE: Pasos Manuales Requeridos
El script automatizado setup-phase5-sysmon.sh configura 95% del sistema, pero hay pasos manuales críticos que deben completarse para el funcionamiento completo.

🚀 MÉTODO 1: Instalación Completa (Recomendado)
Paso 1: Ejecutar Setup Automatizado
bash# Asegúrense de que su stack ELK + Wazuh esté corriendo
docker compose up -d

# Ejecutar el script principal
./setup-phase5-sysmon.sh
Paso 2: Registro Manual del Agente (CRÍTICO)
El script se detiene aquí porque el registro del agente requiere interacción manual:
bash# 1. Agregar agente en Wazuh Manager
docker exec -it sentinel-wazuh-manager /var/ossec/bin/manage_agents

# En el prompt interactivo:
# - Presionar 'A' (Add agent)
# - Name: WIN-ENDPOINT-01
# - IP: any  
# - ID: [Enter] (deja default)
# - Confirmar con 'y'
# - Presionar 'Q' (Quit)
Paso 3: Extraer y Aplicar Key del Agente
bash# 2. Extraer la key del agente (usar ID numérico, no nombre)
docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -e 001

# 3. Copiar la key que aparece (algo como: MDAxIFdJTi1FTkRQT0lOVF...)

# 4. Importar key en el agente
docker exec -it windows-endpoint-sim-01 /var/ossec/bin/manage_agents

# En el prompt:
# - Presionar 'I' (Import key)
# - Pegar la key completa
# - Confirmar con 'y'
# - Presionar 'Q' (Quit)
Paso 4: Reiniciar y Verificar
bash# 5. Reiniciar agente
docker exec windows-endpoint-sim-01 /var/ossec/bin/wazuh-control restart

# 6. Crear directorio de logs
docker exec windows-endpoint-sim-01 mkdir -p /opt/sysmon-simulator/logs

# 7. Verificar conexión (deberían ver "Connected to server")
docker exec windows-endpoint-sim-01 tail /var/ossec/logs/ossec.log

# 8. Verificar registro exitoso
docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -l
Paso 5: Iniciar Generación de Eventos
bash# 9. Generar eventos de prueba
docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py 172.20.0.4 5 60

# 10. Verificar eventos
docker exec windows-endpoint-sim-01 tail -f /var/log/sysmon-simulator.log

🔧 MÉTODO 2: Solo Pasos Manuales (Si ya ejecutaron el script)
Si el script ya fue ejecutado y solo necesitan completar la parte manual:
Script de Pasos Manuales
bash#!/bin/bash
# manual-agent-setup.sh

echo "=== Configuración Manual del Agente Sysmon ==="

# Encontrar IP del Wazuh Manager
WAZUH_IP=$(docker inspect sentinel-wazuh-manager | grep '"IPAddress"' | tail -1 | cut -d'"' -f4)
echo "Wazuh Manager IP: $WAZUH_IP"

echo ""
echo "PASO 1: Registrar agente en Wazuh Manager"
echo "Ejecutar: docker exec -it sentinel-wazuh-manager /var/ossec/bin/manage_agents"
echo "- Presionar 'A'"
echo "- Name: WIN-ENDPOINT-01"
echo "- IP: any"
echo "- ID: [Enter]"
echo "- Confirmar: y"
echo "- Salir: Q"
echo ""

read -p "Presiona Enter cuando hayas completado el registro del agente..."

echo ""
echo "PASO 2: Extraer key del agente"
echo "Ejecutando: docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -e 001"
KEY=$(docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -e 001 | grep -v "Agent key" | tail -1)
echo "Key obtenida: $KEY"
echo ""

echo "PASO 3: Importar key en el agente"
echo "Ejecutar: docker exec -it windows-endpoint-sim-01 /var/ossec/bin/manage_agents"
echo "- Presionar 'I'"
echo "- Pegar: $KEY"
echo "- Confirmar: y" 
echo "- Salir: Q"
echo ""

read -p "Presiona Enter cuando hayas importado la key..."

echo ""
echo "PASO 4: Finalizando configuración..."

# Reiniciar agente
docker exec windows-endpoint-sim-01 /var/ossec/bin/wazuh-control restart

# Crear directorio logs
docker exec windows-endpoint-sim-01 mkdir -p /opt/sysmon-simulator/logs

echo ""
echo "PASO 5: Verificando conexión..."
sleep 5
docker exec windows-endpoint-sim-01 tail -5 /var/ossec/logs/ossec.log | grep -E "(Connected|ERROR)"

echo ""
echo "PASO 6: Verificando registro..."
docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -l

echo ""
echo "✅ Configuración manual completada!"
echo ""
echo "Para probar:"
echo "docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py $WAZUH_IP 5 60"

📝 CHECKLIST PARA TUS COMPAÑEROS
Pre-requisitos:

 Stack ELK + Wazuh corriendo (docker ps muestra todos los contenedores)
 Script setup-phase5-sysmon.sh ejecutado exitosamente
 Contenedor windows-endpoint-sim-01 creado

Pasos Manuales Obligatorios:

 Registro del agente en Wazuh Manager (Interactivo)
 Extracción de la key del agente
 Importación de la key en el contenedor del agente (Interactivo)
 Reinicio del agente Wazuh
 Creación del directorio de logs
 Verificación de conectividad

Verificación Final:

 docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -l muestra el agente
 docker logs windows-endpoint-sim-01 muestra "Connected to server"
 Eventos Sysmon se generan correctamente


🔍 COMANDOS DE TROUBLESHOOTING
Si algo falla:
bash# Verificar estado de contenedores
docker ps | grep -E "(wazuh|windows-endpoint)"

# Ver logs del agente
docker logs windows-endpoint-sim-01

# Ver logs del manager
docker exec sentinel-wazuh-manager tail -20 /var/ossec/logs/ossec.log

# Reiniciar todo si es necesario
docker exec windows-endpoint-sim-01 /var/ossec/bin/wazuh-control restart
docker exec sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart

⏱️ Tiempo Estimado

Script automatizado: 5-10 minutos
Pasos manuales: 5-10 minutos
Verificación: 2-3 minutos
Total: ~20 minutos por persona

🎯 Resultado Esperado
Al completar estos pasos, tus compañeros tendrán:

✅ Contenedor Windows Endpoint Simulator funcionando
✅ Agente Wazuh registrado y conectado
✅ Eventos Sysmon generándose automáticamente
✅ Base completa para continuar con la integración Elasticsearch

Nota: El último paso pendiente (integración con Elasticsearch) se resolverá en la próxima sesión de trabajo.