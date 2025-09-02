#!/bin/bash
# Run specific attack scenarios for testing

SCENARIO=${1:-"malware_execution"}
DURATION=${2:-60}

echo "Running attack scenario: $SCENARIO for $DURATION seconds"

# Run scenario mode
docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py 172.20.0.13 10 $DURATION true

echo "Attack scenario completed"
echo "Check Kibana for alerts: http://localhost:5601"
