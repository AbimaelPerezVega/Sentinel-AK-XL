If you problem with random networks using the desired ip:
docker network prune

To see fields:
curl -s "http://localhost:9200/sentinel-logs-*/_field_caps?fields=*&include_unmapped=true&ignore_unavailable=true&pretty"


Use this to start the docker compose of ELK stack
./start-elk.sh
or
docker compose up -d

other  type
docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-control restart

ver imagenes instaladas:
docker images | grep -E 'elasticsearch|kibana|logstash|wazuh|filebeat'

\\\\\\
example:

$ docker images | grep -E 'elasticsearch|kibana|logstash|wazuh|filebeat'
docker.elastic.co/kibana/kibana                 9.1.2         1178dc6d0a35   2 weeks ago     1.31GB
docker.elastic.co/elasticsearch/elasticsearch   9.1.2         c9ecc2ee2367   2 weeks ago     1.39GB
docker.elastic.co/beats/filebeat                9.1.2         08e6ebb4b821   2 weeks ago     413MB
docker.elastic.co/logstash/logstash             9.1.2         d4b95d2ecb81   3 weeks ago     834MB
wazuh/wazuh-dashboard                           4.12.0        1f81bb89d355   3 months ago    1.17GB
wazuh/wazuh-indexer                             4.12.0        32b09962f7e0   3 months ago    1.35GB
wazuh/wazuh-manager                             4.12.0        a3572c0ec0d8   3 months ago    1.29GB

\\\\\\\


si da un problema con "start-script-lock " usar:
docker compose exec wazuh-manager bash -lc 'rm -rf /var/ossec/var/start-script-lock || true'

docker compose down

wazuh docker compose start
docker compose -f docker-compose-wazuh.yml up -d

stop:
docker compose -f docker-compose-wazuh.yml down


ver logs:
docker compose logs wazuh-manager

Para poner los logs en file si son muchos:

docker compose logs wazuh-manager > logs.txt

docker compose logs --tail=50 wazuh-manager

estado de los containers

docker compose ps

docker compose ps -a


//////////////

Comandos útiles (restart / ciclo de vida)
Levantar / recrear todo
# (opcional) parar y borrar contenedores, redes y volúmenes
docker compose down -v

# levantar todo (el bootstrap si el volumen es nuevo crea rutas/archivos)
docker compose up -d

Reiniciar servicios específicos
# Elasticsearch / Logstash / Kibana
docker compose restart sentinel-elasticsearch
docker compose restart sentinel-logstash
docker compose restart sentinel-kibana

# Wazuh stack
docker compose restart sentinel-wazuh-indexer
docker compose restart sentinel-wazuh-manager
docker compose restart sentinel-wazuh-dashboard

# Filebeat externo
docker compose restart sentinel-filebeat

Recargar cambios de configuración dentro de contenedores
# Wazuh Manager (tras editar ossec.conf / rules):
docker exec -it sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart

# Logstash (si cambiaste pipelines *.conf):
docker compose restart sentinel-logstash

# Filebeat (si cambiaste filebeat.yml):
docker compose restart sentinel-filebeat

Health / verificación rápida
docker compose ps
curl -s localhost:9200/_cluster/health | jq
curl -s localhost:9600/_node/pipelines | jq '.pipelines'
curl -s "localhost:9200/sentinel-logs-*/_count"


///////////////


filebeat
docker logs -f --tail=200 sentinel-wazuh-manager | grep -i filebeat

Otros:

# ¿Filebeat está vivo?
docker compose exec -T wazuh-manager sh -lc 'pgrep -a filebeat || echo "filebeat NO está"'

# ¿Se está generando alerts.json?
docker compose exec -T wazuh-manager ls -l /var/ossec/logs/alerts
docker compose exec -T wazuh-manager tail -n 2 /var/ossec/logs/alerts/alerts.json 2>/dev/null || echo "aún no hay alertas"

# ¿Output OK?
docker compose exec -T wazuh-manager /usr/bin/filebeat test output


Tu <localfile> apunta a /var/ossec/logs/test/sshd.log, pero ese path no existía. Créalo y mete una línea:

# crear el directorio y el archivo con dueño/permisos correctos
docker compose exec -T wazuh-manager sh -lc '
  install -d -o wazuh -g wazuh /var/ossec/logs/test &&
  install -m 660 -o wazuh -g wazuh /dev/null /var/ossec/logs/test/sshd.log
'

# generar un evento "sshd failed password"
docker compose exec -T wazuh-manager sh -lc '
  echo "<13>Aug 28 10:00:00 test sshd[1234]: Failed password for root from 1.2.3.4 port 22" >> /var/ossec/logs/test/sshd.log
'

# ver si apareció en alerts.json
docker compose exec -T wazuh-manager sh -lc 'tail -n 3 /var/ossec/logs/alerts/alerts.json'

--------

docker compose exec -T wazuh-indexer sh -lc \
"curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87105&size=10&pretty'"

Dónde se guardan

Las index templates se guardan dentro del estado del clúster de Elasticsearch, no como archivos sueltos en tu host ni en Logstash.

En Docker, eso termina persistido en el data path del contenedor de Elasticsearch (/usr/share/elasticsearch/data) dentro de un volumen. No es legible como un JSON fácil: se consulta/modifica por API o por Kibana.

Persisten a través de reinicios del contenedor. Solo se pierden si borras el volumen/datos del clúster.

Si quieres ver qué volumen usa tu contenedor ES:

docker inspect sentinel-elasticsearch --format '{{json .Mounts}}' | jq .

Cómo listarlas / verlas / borrar

Comandos útiles (contra tu ES en localhost:9200):

Listar todas las composable index templates:

curl -s 'http://localhost:9200/_index_template?pretty'


Listar en formato “cat”:

curl -s 'http://localhost:9200/_cat/templates?v'
# o filtrando por nombre (prefijo/coincidencia):
curl -s 'http://localhost:9200/_cat/templates/sentinel-logs*?v'


Ver una específica (la que creaste):

curl -s 'http://localhost:9200/_index_template/sentinel-logs?pretty'


Borrarla (si la quieres reemplazar):

curl -s -XDELETE 'http://localhost:9200/_index_template/sentinel-logs'


Volver a crear/actualizarla:

curl -s -XPUT 'http://localhost:9200/_index_template/sentinel-logs' \
  -H 'Content-Type: application/json' -d '{
    "index_patterns": ["sentinel-logs-*"],
    "template": {
      "mappings": {
        "properties": {
          "agent": {
            "properties": {
              "name": {
                "type": "text",
                "fields": { "keyword": { "type": "keyword", "ignore_above": 256 } }
              }
            }
          },
          "geoip": {
            "properties": {
              "location": { "type": "geo_point" },
              "latitude":  { "type": "float"   },
              "longitude": { "type": "float"   }
            }
          }
        }
      }
    }
  }'

Cómo comprobar qué template aplicará a un índice

Usa la simulación de plantillas con el nombre de un índice hipotético que matchee tu patrón:

curl -s 'http://localhost:9200/_index_template/_simulate_index/sentinel-logs-2099.01.01?pretty'


Esto te muestra qué templates se combinarían y qué mappings/settings resultarían.

Ver/editar por Kibana

Con tu Kibana en :5601:

Stack Management → Index Management → Index Templates
Ahí puedes ver, editar y simular la template desde UI.

Backup/export rápido de tu template (a un archivo en el host)
curl -s 'http://localhost:9200/_index_template/sentinel-logs' \
| jq '.' > sentinel-logs-template.json


Luego puedes importarlo en otro ES con un PUT similar al de arriba (ajustando el JSON si hace falta).

Resumen: la template no queda como archivo en el host por defecto; vive en el estado del clúster ES (persistido en el volumen de datos del contenedor). La manera correcta de “verla/gestionar” es por API o Kibana.


