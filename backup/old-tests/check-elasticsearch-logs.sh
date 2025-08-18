#!/bin/bash

# ===================================
# Quick Elasticsearch Log Checker
# ===================================
# Just checks what's wrong without downloading anything new
# ===================================

echo "🔍 Checking Elasticsearch failure logs..."
echo "=========================================="

# Check if the failed container still exists
if docker ps -a | grep sentinel-test-elasticsearch >/dev/null; then
    echo "📋 Container status:"
    docker ps -a | grep sentinel-test-elasticsearch
    echo ""
    
    echo "📝 Full Elasticsearch logs:"
    echo "----------------------------------------"
    docker logs sentinel-test-elasticsearch 2>&1
    echo "----------------------------------------"
    
    echo ""
    echo "🔧 Container inspection:"
    docker inspect sentinel-test-elasticsearch --format='{{.State.ExitCode}}: {{.State.Error}}'
    
else
    echo "❌ No failed container found. Starting a temporary one to see the error..."
    
    # Start just elasticsearch to see the error
    docker run --rm --name temp-es-debug \
        -e node.name=elasticsearch \
        -e cluster.name=sentinel-cluster \
        -e discovery.type=single-node \
        -e bootstrap.memory_lock=false \
        -e "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
        -e xpack.security.enabled=true \
        -e ELASTIC_PASSWORD=changeme123! \
        -e xpack.license.self_generated.type=basic \
        -e xpack.security.http.ssl.enabled=false \
        -e xpack.security.transport.ssl.enabled=false \
        -e action.auto_create_index=true \
        docker.elastic.co/elasticsearch/elasticsearch:9.1.2 \
        timeout 30s || echo "Container failed as expected"
fi

echo ""
echo "💡 This will show the exact error without downloading anything new."
