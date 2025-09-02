project-root$ chmod 700 ./wazuh-certificates
project-roo$ find ./wazuh-certificates -type f -name '*.pem' -exec chmod 600 {} \;
project-roo$ chmod 600 ./configs/wazuh/indexer/wazuh.indexer.yml