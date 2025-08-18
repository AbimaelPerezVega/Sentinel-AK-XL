# 🛡️ Sentinel AK-XL - Instalación Súper Fácil

## 📋 Requisitos
- Docker instalado
- 8GB RAM mínimo
- 20GB espacio libre

## 🚀 Instalación en 30 segundos

### Paso 1: Clonar
```bash
git clone [tu-repo-url]
cd sentinel-ak-xl
```

### Paso 2: Instalar (UN SOLO COMANDO)
```bash
./test-elk.sh elasticsearch
```

¡Eso es todo! 🎉

## 🎯 Acceso Rápido

**Si todo funciona verás:**
```
✅ Elasticsearch is ready
```

**Acceder a:**
- **Elasticsearch**: http://localhost:9200
- **Usuario**: `elastic` 
- **Contraseña**: `changeme123!`

## 🧪 Probar que funciona

```bash
# Ver estado
./test-elk.sh status

# Probar conexión
curl -u elastic:changeme123! http://localhost:9200

# Enviar datos de prueba
curl -X POST http://localhost:8080 -H 'Content-Type: application/json' \
  -d '{"message":"¡Hola desde Sentinel!","timestamp":"'$(date)'"}'
```

## 🔧 Comandos Útiles

```bash
./test-elk.sh elasticsearch  # Solo Elasticsearch (más rápido)
./test-elk.sh kibana         # Elasticsearch + Kibana
./test-elk.sh full           # Todo el stack ELK
./test-elk.sh stop           # Parar todo
./test-elk.sh clean          # Limpiar completamente
```

## ❗ Si algo falla

```bash
# Limpiar y empezar de nuevo
./test-elk.sh clean
./test-elk.sh elasticsearch

# Ver logs de errores
docker compose -f docker-compose-test.yml logs elasticsearch
```

## 📁 Estructura del Proyecto

```
sentinel-ak-xl/
├── test-elk.sh                 # 🎯 SCRIPT PRINCIPAL
├── docker-compose-test.yml     # ⚙️ Configuración ELK
├── configs/elk/                # 📝 Configuraciones
├── INSTALL.md                  # 📖 Esta guía
└── backup/                     # 🗂️ Archivos viejos
```

---

**¿Problemas?** Revisa la sección de troubleshooting abajo 👇
