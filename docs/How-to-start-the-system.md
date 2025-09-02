How to start the system in a Healthy way?

Order:
1) docker compose up -d wazuh-ossec-templater
2) docker compose up -d wazuh-bootstrap
3) docker compose up -d wazuh-indexer elasticsearch
4) docker compose up -d wazuh-manager logstash
5) docker compose up -d wazuh-dashboard kibana filebeat

templater: genera el ossec.conf con tu API key antes de que el manager lo monte.

bootstrap: crea carpetas/archivos en volúmenes vacíos (evita que Wazuh empiece sin rutas).

indexer + elasticsearch: levanta los backends (Wazuh Indexer y ES) para que el manager y Logstash tengan a dónde conectarse.

manager + logstash: el manager empieza a producir alerts.json; Logstash queda listo para recibir de Filebeat.

dashboard + kibana + filebeat: UIs al final, y Filebeat de último para no “apuntar” a Logstash/manager si aún no están listos. (Filebeat reintenta, pero así evitas ruido.)

Nota: depends_on no espera a que el servicio esté “listo”, solo a que esté “arrancado”. Por eso añadimos healthchecks (ya los tienes en ES/Logstash) y dejamos los one-shot primero.