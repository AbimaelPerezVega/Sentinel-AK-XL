#!/bin/bash
# Source this script to use the correct Docker Compose version
export COMPOSE_CMD="docker compose"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "✅ Environment configured for Docker Compose v2"
echo "Use: \$COMPOSE_CMD instead of docker-compose"
echo "Example: \$COMPOSE_CMD up -d"
