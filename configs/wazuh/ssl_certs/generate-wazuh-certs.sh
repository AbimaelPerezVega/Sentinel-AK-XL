#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Generating Wazuh SSL Certificates...${NC}"

# We're already in the ssl_certs directory
CERT_DIR="$(pwd)"
echo -e "${YELLOW}📁 Working in: $CERT_DIR${NC}"

# Check if certificates already exist
if [[ -f "root-ca.pem" ]]; then
    echo -e "${YELLOW}⚠️ Certificates already exist in this directory${NC}"
    read -p "Do you want to regenerate them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Using existing certificates${NC}"
        exit 0
    fi
    echo -e "${YELLOW}🔄 Regenerating certificates...${NC}"
fi

# Generate root CA
echo -e "${YELLOW}📋 Generating Root CA...${NC}"
openssl genrsa -out root-ca-key.pem 2048
openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem -days 3650 -subj "/C=US/ST=CA/L=SanFrancisco/O=Wazuh/CN=root-ca"

# Generate certificates for each component
components=("wazuh-manager" "wazuh-indexer" "wazuh-dashboard" "admin")

for component in "${components[@]}"; do
    echo -e "${YELLOW}📋 Generating certificate for ${component}...${NC}"
    
    # Generate private key
    openssl genrsa -out ${component}-key.pem 2048
    
    # Generate certificate signing request
    openssl req -new -key ${component}-key.pem -out ${component}.csr -subj "/C=US/ST=CA/L=SanFrancisco/O=Wazuh/CN=${component}"
    
    # Generate certificate
    openssl x509 -req -in ${component}.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -out ${component}.pem -days 3650 -sha256
    
    # Clean up CSR
    rm ${component}.csr
done

# Create root-ca-manager.pem (copy of root-ca.pem for manager)
cp root-ca.pem root-ca-manager.pem

echo -e "${GREEN}✅ SSL certificates generated successfully!${NC}"
echo -e "${CYAN}📋 Generated files:${NC}"
ls -la *.pem | while read line; do echo "   $line"; done
