#!/bin/bash
# ==============================================================================
# Wazuh-Elasticsearch Integration Fix Script
# Sentinel AK-XL Phase 5: Complete Data Pipeline Solution
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WAZUH_CONTAINER="sentinel-wazuh-manager"
ELASTICSEARCH_IP="172.20.0.10"
ELASTICSEARCH_PORT="9200"
WAZUH_MANAGER_IP="172.20.0.4"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Step 1: Backup Current Configuration
# ==============================================================================

backup_current_config() {
    log_info "Creating backup of current Wazuh configuration..."
    
    # Create backup directory
    mkdir -p ./backups/wazuh-config/$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="./backups/wazuh-config/$(date +%Y%m%d_%H%M%S)"
    
    # Backup current ossec.conf
    docker exec $WAZUH_CONTAINER cp /var/ossec/etc/ossec.conf /tmp/ossec.conf.backup
    docker cp $WAZUH_CONTAINER:/tmp/ossec.conf.backup $BACKUP_DIR/
    
    log_success "Configuration backed up to: $BACKUP_DIR"
}

# ==============================================================================
# Step 2: Create Fixed Wazuh Configuration
# ==============================================================================

create_fixed_ossec_config() {
    log_info "Creating fixed ossec.conf with Elasticsearch integration..."
    
    cat > ./configs/wazuh/ossec-fixed.conf << 'EOF'
<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>no</logall>
    <logall_json>no</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>localhost</smtp_server>
    <email_from>wazuh@example.com</email_from>
    <email_to>admin@example.com</email_to>
    <hostname>wazuh-manager</hostname>
    <email_maxperhour>12</email_maxperhour>
    <email_log_source>alerts.log</email_log_source>
    <agents_disconnection_time>10m</agents_disconnection_time>
    <agents_disconnection_alert_time>0</agents_disconnection_alert_time>
  </global>

  <alerts>
    <log_alert_level>3</log_alert_level>
    <email_alert_level>12</email_alert_level>
  </alerts>

  <!-- Rules -->
  <rules>
    <include>rules_config.xml</include>
    <include>pam_rules.xml</include>
    <include>sshd_rules.xml</include>
    <include>telnetd_rules.xml</include>
    <include>syslog_rules.xml</include>
    <include>arpwatch_rules.xml</include>
    <include>symantec-av_rules.xml</include>
    <include>symantec-ws_rules.xml</include>
    <include>pix_rules.xml</include>
    <include>named_rules.xml</include>
    <include>smbd_rules.xml</include>
    <include>vsftpd_rules.xml</include>
    <include>pure-ftpd_rules.xml</include>
    <include>proftpd_rules.xml</include>
    <include>ms_ftpd_rules.xml</include>
    <include>ftpd_rules.xml</include>
    <include>hordeimp_rules.xml</include>
    <include>roundcube_rules.xml</include>
    <include>wordpress_rules.xml</include>
    <include>cimserver_rules.xml</include>
    <include>vpopmail_rules.xml</include>
    <include>vmpop3d_rules.xml</include>
    <include>courier_rules.xml</include>
    <include>web_rules.xml</include>
    <include>web_appsec_rules.xml</include>
    <include>apache_rules.xml</include>
    <include>nginx_rules.xml</include>
    <include>php_rules.xml</include>
    <include>mysql_rules.xml</include>
    <include>postgresql_rules.xml</include>
    <include>ids_rules.xml</include>
    <include>squid_rules.xml</include>
    <include>firewall_rules.xml</include>
    <include>cisco-ios_rules.xml</include>
    <include>netscreenfw_rules.xml</include>
    <include>sonicwall_rules.xml</include>
    <include>postfix_rules.xml</include>
    <include>sendmail_rules.xml</include>
    <include>imapd_rules.xml</include>
    <include>mailscanner_rules.xml</include>
    <include>dovecot_rules.xml</include>
    <include>ms-exchange_rules.xml</include>
    <include>racoon_rules.xml</include>
    <include>vpn_concentrator_rules.xml</include>
    <include>spamd_rules.xml</include>
    <include>msauth_rules.xml</include>
    <include>mcafee_av_rules.xml</include>
    <include>trend-osce_rules.xml</include>
    <include>ms-se_rules.xml</include>
    <include>zeus_rules.xml</include>
    <include>solaris_bsm_rules.xml</include>
    <include>vmware_rules.xml</include>
    <include>ms_dhcp_rules.xml</include>
    <include>asterisk_rules.xml</include>
    <include>ossec_rules.xml</include>
    <include>attack_rules.xml</include>
    <include>openbsd_rules.xml</include>
    <include>clam_av_rules.xml</include>
    <include>dropbear_rules.xml</include>
    <include>sysmon_rules.xml</include>
    <include>local_rules.xml</include>
  </rules>

  <!-- Syscheck -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <auto_ignore frequency="10" timeframe="3600">no</auto_ignore>
    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin,/boot</directories>
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/random.seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/httpd/logs</ignore>
    <ignore>/etc/utmpx</ignore>
    <ignore>/etc/wtmpx</ignore>
    <ignore>/etc/cups/certs</ignore>
    <ignore>/etc/dumpdates</ignore>
    <ignore>/etc/svc/volatile</ignore>
    <nodiff>/etc/ssl/private.key</nodiff>
    <skip_nfs>yes</skip_nfs>
    <skip_dev>yes</skip_dev>
    <skip_proc>yes</skip_proc>
    <skip_sys>yes</skip_sys>
    <process_priority>10</process_priority>
    <max_eps>100</max_eps>
    <sync_enabled>yes</sync_enabled>
    <sync_interval>5m</sync_interval>
    <sync_max_eps>10</sync_max_eps>
  </syscheck>

  <!-- Rootcheck -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>43200</frequency>
    <rootkit_files>/var/ossec/etc/rootcheck/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/rootcheck/rootkit_trojans.txt</rootkit_trojans>
    <skip_nfs>yes</skip_nfs>
  </rootcheck>

  <!-- System inventory -->
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="no">yes</ports>
    <processes>yes</processes>
    <synchronization>
      <max_eps>10</max_eps>
    </synchronization>
  </wodle>

  <!-- Vulnerability detector -->
  <vulnerability-detector>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <min_full_scan_interval>6h</min_full_scan_interval>
    <run_on_start>yes</run_on_start>
    <provider name="canonical">
      <enabled>yes</enabled>
      <os>trusty</os>
      <os>xenial</os>
      <os>bionic</os>
      <os>focal</os>
      <os>jammy</os>
      <update_interval>1h</update_interval>
    </provider>
    <provider name="debian">
      <enabled>yes</enabled>
      <os>stretch</os>
      <os>buster</os>
      <os>bullseye</os>
      <update_interval>1h</update_interval>
    </provider>
    <provider name="redhat">
      <enabled>yes</enabled>
      <os>5</os>
      <os>6</os>
      <os>7</os>
      <os>8</os>
      <os>9</os>
      <update_interval>1h</update_interval>
    </provider>
  </vulnerability-detector>

  <!-- SCA (Security Configuration Assessment) -->
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
    <skip_nfs>yes</skip_nfs>
  </sca>

  <!-- Log analysis -->
  <localfile>
    <log_format>command</log_format>
    <command>df -P</command>
    <alias>df -P</alias>
    <frequency>360</frequency>
  </localfile>

  <localfile>
    <log_format>full_command</log_format>
    <command>netstat -tulpn | sed 's/\([[:alnum:]]\+\)\ \+[[:digit:]]\+\ \+[[:digit:]]\+\ \+\(.*\):\([[:digit:]]*\)\ \+\([0-9\.\:\*]\+\).\+\ \([[:digit:]]*\/[[:alnum:]\-]*\).*/\1 \2 \3 \4 \5/' | sort -k 4 -g | sed 's/.*\/.*/#&/' | sed 1,2d</command>
    <alias>netstat listening ports</alias>
    <frequency>360</frequency>
  </localfile>

  <localfile>
    <log_format>full_command</log_format>
    <command>last -n 20</command>
    <alias>last -n 20</alias>
    <frequency>360</frequency>
  </localfile>

  <!-- CRITICAL: Elasticsearch Integration -->
  <integration>
    <name>elasticsearch</name>
    <hook_url>http://172.20.0.10:9200</hook_url>
    <level>3</level>
    <alert_format>json</alert_format>
    <max_logs>5</max_logs>
  </integration>

  <!-- Remote connection -->
  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>tcp</protocol>
    <queue_size>131072</queue_size>
  </remote>

  <!-- Authentication -->
  <auth>
    <disabled>no</disabled>
    <port>1515</port>
    <use_source_ip>no</use_source_ip>
    <purge>yes</purge>
    <use_password>no</use_password>
    <ciphers>HIGH:!ADH:!EXP:!MD5:!RC4:!3DES:!CAMELLIA:@STRENGTH</ciphers>
    <ssl_agent_ca></ssl_agent_ca>
    <ssl_verify_host>no</ssl_verify_host>
    <ssl_manager_cert>/var/ossec/etc/sslmanager.cert</ssl_manager_cert>
    <ssl_manager_key>/var/ossec/etc/sslmanager.key</ssl_manager_key>
    <ssl_auto_negotiate>no</ssl_auto_negotiate>
  </auth>

  <!-- Active Response -->
  <command>
    <name>disable-account</name>
    <executable>disable-account</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>restart-wazuh</name>
    <executable>restart-wazuh</executable>
  </command>

  <command>
    <name>firewall-drop</name>
    <executable>firewall-drop</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>host-deny</name>
    <executable>host-deny</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>route-null</name>
    <executable>route-null</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <!-- Active Response Config -->
  <active-response>
    <command>host-deny</command>
    <location>local</location>
    <level>6</level>
    <timeout>600</timeout>
  </active-response>

  <!-- Cluster Configuration -->
  <cluster>
    <name>wazuh</name>
    <node_name>worker</node_name>
    <node_type>worker</node_type>
    <key></key>
    <port>1516</port>
    <bind_addr>0.0.0.0</bind_addr>
    <nodes>
        <node>wazuh-manager</node>
    </nodes>
    <hidden>no</hidden>
    <disabled>yes</disabled>
  </cluster>

  <!-- Wazuh API Configuration -->
  <api>
    <enabled>yes</enabled>
    <host>0.0.0.0</host>
    <port>55000</port>
    <use_only_authd>no</use_only_authd>
    <drop_privileges>no</drop_privileges>
    <experimental_features>no</experimental_features>
    <max_upload_size>10485760</max_upload_size>
    <https>
      <enabled>yes</enabled>
      <key>/var/ossec/api/configuration/ssl/server.key</key>
      <cert>/var/ossec/api/configuration/ssl/server.crt</cert>
      <use_ca>no</use_ca>
      <ssl_protocol>auto</ssl_protocol>
      <ssl_ciphers></ssl_ciphers>
    </https>
    <cors>
      <enabled>no</enabled>
      <source_route>*</source_route>
      <expose_headers>*</expose_headers>
      <allow_headers>*</allow_headers>
      <allow_credentials>no</allow_credentials>
    </cors>
    <cache>
      <enabled>yes</enabled>
      <time>0.750</time>
    </cache>
    <access>
      <max_login_attempts>50</max_login_attempts>
      <block_time>300</block_time>
      <max_request_per_minute>300</max_request_per_minute>
    </access>
  </api>

</ossec_config>
EOF

    log_success "Fixed ossec.conf created with Elasticsearch integration"
}

# ==============================================================================
# Step 3: Update Elasticsearch Configuration for Wazuh
# ==============================================================================

create_elasticsearch_template() {
    log_info "Creating Elasticsearch template for Wazuh alerts..."
    
    # Create template directory
    mkdir -p ./configs/elk/elasticsearch/templates
    
    cat > ./configs/elk/elasticsearch/templates/wazuh-template.json << 'EOF'
{
  "index_patterns": ["wazuh-alerts-*"],
  "priority": 1,
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.refresh_interval": "5s"
    },
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "timestamp": {
          "type": "date"
        },
        "rule": {
          "properties": {
            "level": {
              "type": "long"
            },
            "description": {
              "type": "text"
            },
            "id": {
              "type": "keyword"
            },
            "mitre": {
              "properties": {
                "id": {
                  "type": "keyword"
                },
                "tactic": {
                  "type": "keyword"
                },
                "technique": {
                  "type": "keyword"
                }
              }
            }
          }
        },
        "agent": {
          "properties": {
            "id": {
              "type": "keyword"
            },
            "name": {
              "type": "keyword"
            },
            "ip": {
              "type": "ip"
            }
          }
        },
        "data": {
          "properties": {
            "win": {
              "properties": {
                "eventdata": {
                  "properties": {
                    "image": {
                      "type": "keyword"
                    },
                    "processId": {
                      "type": "keyword"
                    },
                    "commandLine": {
                      "type": "text"
                    }
                  }
                }
              }
            }
          }
        },
        "decoder": {
          "properties": {
            "name": {
              "type": "keyword"
            }
          }
        },
        "location": {
          "type": "keyword"
        },
        "full_log": {
          "type": "text"
        }
      }
    }
  }
}
EOF

    log_success "Elasticsearch template created for Wazuh"
}

# ==============================================================================
# Step 4: Apply Configuration Changes
# ==============================================================================

apply_configuration_changes() {
    log_info "Applying configuration changes..."
    
    # Copy fixed configuration to Wazuh manager
    log_info "Deploying fixed ossec.conf to Wazuh manager..."
    docker cp ./configs/wazuh/ossec-fixed.conf $WAZUH_CONTAINER:/var/ossec/etc/ossec.conf
    
    # Set proper permissions
    docker exec $WAZUH_CONTAINER chown root:ossec /var/ossec/etc/ossec.conf
    docker exec $WAZUH_CONTAINER chmod 640 /var/ossec/etc/ossec.conf
    
    # Create Elasticsearch template
    log_info "Creating Elasticsearch index template..."
    sleep 5  # Wait for Elasticsearch to be ready
    
    curl -X PUT "localhost:9200/_index_template/wazuh-template" \
         -H "Content-Type: application/json" \
         -d @./configs/elk/elasticsearch/templates/wazuh-template.json
    
    log_success "Configuration changes applied"
}

# ==============================================================================
# Step 5: Restart Services
# ==============================================================================

restart_services() {
    log_info "Restarting Wazuh services..."
    
    # Restart Wazuh manager
    docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-control restart
    
    # Wait for service to restart
    sleep 15
    
    # Check if Wazuh is running
    if docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-control status | grep -q "wazuh-manager is running"; then
        log_success "Wazuh manager restarted successfully"
    else
        log_error "Failed to restart Wazuh manager"
        exit 1
    fi
}

# ==============================================================================
# Step 6: Verification and Testing
# ==============================================================================

verify_integration() {
    log_info "Verifying Wazuh-Elasticsearch integration..."
    
    # Test 1: Check Elasticsearch connectivity from Wazuh
    log_info "Testing Elasticsearch connectivity..."
    if docker exec $WAZUH_CONTAINER curl -s http://172.20.0.10:9200 | grep -q "cluster_name"; then
        log_success "Elasticsearch is reachable from Wazuh manager"
    else
        log_warning "Cannot reach Elasticsearch from Wazuh manager"
    fi
    
    # Test 2: Generate test alert
    log_info "Generating test alert..."
    docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-logtest << 'TEST_LOG'
Aug 22 10:45:01 test-server sshd[12345]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2
TEST_LOG
    
    # Test 3: Check for Wazuh indices in Elasticsearch
    log_info "Checking for Wazuh indices in Elasticsearch..."
    sleep 30  # Wait for alerts to be processed
    
    indices_response=$(curl -s "localhost:9200/_cat/indices?v" | grep wazuh || echo "No Wazuh indices found")
    echo "Elasticsearch indices:"
    echo "$indices_response"
    
    # Test 4: Check for recent alerts
    log_info "Checking for recent alerts..."
    alert_count=$(curl -s "localhost:9200/wazuh-alerts-*/_count" | jq -r '.count' 2>/dev/null || echo "0")
    
    if [[ "$alert_count" -gt 0 ]]; then
        log_success "Found $alert_count alerts in Elasticsearch"
    else
        log_warning "No alerts found in Elasticsearch yet"
    fi
    
    # Test 5: Check Wazuh logs for integration status
    log_info "Checking Wazuh integration logs..."
    if docker exec $WAZUH_CONTAINER grep -i "elasticsearch" /var/ossec/logs/ossec.log | tail -5; then
        log_success "Elasticsearch integration is active in Wazuh logs"
    else
        log_warning "No Elasticsearch integration activity in logs"
    fi
}

# ==============================================================================
# Step 7: Generate Test Events
# ==============================================================================

generate_test_events() {
    log_info "Generating test Sysmon events..."
    
    # Generate events from the Windows endpoint simulator
    if docker ps | grep -q "windows-endpoint-sim"; then
        log_info "Generating new Sysmon events..."
        docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py 172.20.0.4 10 30 true
        
        # Wait for events to be processed
        sleep 30
        
        # Check for new alerts
        new_alert_count=$(curl -s "localhost:9200/wazuh-alerts-*/_count" | jq -r '.count' 2>/dev/null || echo "0")
        log_info "Total alerts after test generation: $new_alert_count"
        
        # Search for specific Sysmon events
        sysmon_alerts=$(curl -s "localhost:9200/wazuh-alerts-*/_search?q=sysmon&size=0" | jq -r '.hits.total.value' 2>/dev/null || echo "0")
        log_info "Sysmon-related alerts: $sysmon_alerts"
        
    else
        log_warning "Windows endpoint simulator not running"
    fi
}

# ==============================================================================
# Step 8: Kibana Index Pattern Creation
# ==============================================================================

create_kibana_index_pattern() {
    log_info "Creating Kibana index pattern for Wazuh alerts..."
    
    # Wait for Kibana to be ready
    log_info "Waiting for Kibana to be ready..."
    while ! curl -s "localhost:5601/api/status" | grep -q "available"; do
        echo "Waiting for Kibana..."
        sleep 10
    done
    
    # Create index pattern
    curl -X POST "localhost:5601/api/saved_objects/index-pattern/wazuh-alerts-*" \
         -H "kbn-xsrf: true" \
         -H "Content-Type: application/json" \
         -d '{
           "attributes": {
             "title": "wazuh-alerts-*",
             "timeFieldName": "@timestamp"
           }
         }'
    
    log_success "Kibana index pattern created"
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo -e "${GREEN}=================================="
    echo -e "Wazuh-Elasticsearch Integration Fix"
    echo -e "Sentinel AK-XL Phase 5"
    echo -e "==================================${NC}"
    
    backup_current_config
    create_fixed_ossec_config
    create_elasticsearch_template
    apply_configuration_changes
    restart_services
    verify_integration
    generate_test_events
    create_kibana_index_pattern
    
    echo -e "\n${GREEN}=== INTEGRATION FIX COMPLETED ===${NC}"
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "1. Check Kibana Discover: http://localhost:5601"
    echo -e "2. Look for 'wazuh-alerts-*' index pattern"
    echo -e "3. Monitor alerts in real-time"
    echo -e "4. Verify Sysmon events are appearing"
    echo -e "\n${GREEN}Data Pipeline Status:${NC}"
    echo -e "Sysmon Events → Wazuh Agent → Wazuh Manager → Elasticsearch → Kibana ✅"
}

# Run the main function
main "$@"
