#!/bin/bash
# Cleanup Test Environment

echo "🧹 Cleaning up test environment..."

export COMPOSE_FILE=docker-compose-test.yml

echo "Stopping containers..."
docker-compose down -v

echo "Removing test volumes..."
docker volume rm $(docker volume ls -q | grep test) 2>/dev/null || true

echo "Removing test images..."
docker image prune -f

echo "✅ Cleanup completed"
