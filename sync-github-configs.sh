#!/bin/bash

# ===================================
# Sync Working Configs to GitHub Files
# ===================================
# Updates the GitHub-ready files with the actual working configuration
# ===================================

echo "🔄 Syncing working configuration to GitHub-ready files..."

# Copy the ACTUAL working configs that are running now
mkdir -p config-patches/github-updates/configs/elk/{elasticsearch,kibana}

# Copy the actual working elasticsearch.yml
cp configs/elk/elasticsearch/elasticsearch.yml config-patches/github-updates/configs/elk/elasticsearch/

# Copy the actual working kibana.yml  
cp configs/elk/kibana/kibana.yml config-patches/github-updates/configs/elk/kibana/

# Copy the actual working docker-compose
cp docker-compose-test.yml config-patches/github-updates/docker-compose.yml

echo "✅ Synced actual working configurations"

# Create updated instructions
cat > config-patches/GITHUB_UPDATE_INSTRUCTIONS.md << 'EOF'
# GitHub Repository Update Instructions

## What This Fixes
These configuration changes fix Elasticsearch 9.1.2 compatibility issues and authentication problems.

## Key Changes Made

### 1. Elasticsearch Configuration
- **Fixed:** `cluster.routing.allocation.disk.threshold_enabled: false` (was using dots instead of underscore)
- **Simplified:** Disabled security for development (xpack.security.enabled: false)

### 2. Kibana Configuration  
- **Removed:** elasticsearch.username and elasticsearch.password (causes authentication errors in v9.1.2)
- **Simplified:** No authentication required for development setup
- **Fixed:** Logging configuration for v9.1.2

### 3. Docker Compose
- **Removed:** ELASTICSEARCH_USERNAME and ELASTICSEARCH_PASSWORD from Kibana environment
- **Simplified:** No authentication environment variables
- **Improved:** Health checks and service dependencies

## Files to Update in Your GitHub Repository

### Replace these files with the working versions:

```bash
# 1. Copy the fixed files to your repository
cp config-patches/github-updates/configs/elk/elasticsearch/elasticsearch.yml configs/elk/elasticsearch/
cp config-patches/github-updates/configs/elk/kibana/kibana.yml configs/elk/kibana/  
cp config-patches/github-updates/docker-compose.yml ./

# 2. Commit the fixes
git add configs/elk/elasticsearch/elasticsearch.yml configs/elk/kibana/kibana.yml docker-compose.yml
git commit -m "fix: ELK Stack 9.1.2 compatibility

Key fixes:
- Fix cluster.routing.allocation.disk.threshold setting name (underscore not dot)
- Remove authentication for development setup (Kibana 9.1.2 forbids elastic user)
- Disable security for simpler development environment
- Update health checks and service dependencies

Users can now run 'docker-compose up -d' and get working ELK Stack 9.1.2"

# 3. Push to GitHub
git push origin main
```

## Verification Steps for Users

After cloning your repository, users should be able to:

1. Run: `docker-compose up -d`
2. Wait 2-3 minutes for services to start
3. Test Elasticsearch: `curl http://localhost:9200`
4. Test Kibana: `curl http://localhost:5601/api/status`
5. Access Kibana web UI: `http://localhost:5601`

## What Users Will Get

- ✅ Working Elasticsearch 9.1.2 (no authentication)
- ✅ Working Kibana 9.1.2 (no authentication)  
- ✅ Simple development environment
- ✅ No additional troubleshooting needed

## Development vs Production

**Note:** This configuration is optimized for development/testing with security disabled.
For production use, you'll need to:
- Enable authentication (xpack.security.enabled: true)
- Create proper service accounts for Kibana
- Configure SSL/TLS
- Set strong passwords

## Rollback Plan

If needed, you can rollback with:
```bash
git revert HEAD
```
EOF

echo "📝 Updated GitHub instructions"

# Show what we're ready to commit
echo ""
echo "📋 Ready to update GitHub with these working files:"
echo "• configs/elk/elasticsearch/elasticsearch.yml"
echo "• configs/elk/kibana/kibana.yml" 
echo "• docker-compose.yml"
echo ""
echo "🔍 Quick verification - check the files match what's working:"
echo "Current working Elasticsearch config:"
grep -E "(xpack.security.enabled|cluster.routing.allocation.disk.threshold)" configs/elk/elasticsearch/elasticsearch.yml
echo ""
echo "Current working Kibana config:"
grep -E "(elasticsearch.username|elasticsearch.password)" configs/elk/kibana/kibana.yml || echo "No authentication settings (correct for v9.1.2)"
echo ""
echo "✅ Ready to commit to GitHub!"
