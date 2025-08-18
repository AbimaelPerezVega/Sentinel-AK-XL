#!/bin/bash
# Stop Sentinel ELK Stack

echo "🛑 Stopping Sentinel ELK Stack..."

# Determine compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

$COMPOSE_CMD down
echo "✅ Sentinel ELK Stack stopped"
