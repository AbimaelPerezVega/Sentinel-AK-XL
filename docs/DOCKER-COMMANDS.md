If you problem with random networks using the desired ip:
docker network prune

Use this to start the docker compose of ELK stack
./start-elk.sh
or
docker compose up -d

to stop:
./stop-elk.sh

or:
docker compose down

wazuh docker compose start
docker compose -f docker-compose-wazuh.yml up -d

stop:
docker compose -f docker-compose-wazuh.yml down