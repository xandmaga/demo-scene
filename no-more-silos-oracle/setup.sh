#!/bin/bash

echo -e $(date) "Firing up Oracle"
docker-compose up -d oracle

# ---- Wait for Oracle DB to be up (takes several minutes to instantiate) ---
echo -e "\n--\n\n$(date) Waiting for Oracle to be available … ⏳"
grep -q "DATABASE IS READY TO USE!" <(docker logs -f oracle)
echo -e "$(date) Installing rlwrap on Oracle container"
docker exec --interactive --tty --user root --workdir / $(docker ps --filter "name=oracle" --quiet) bash -c 'rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
docker exec --interactive --tty --user root --workdir / $(docker ps --filter "name=oracle" --quiet) bash -c 'yum install -y rlwrap'

echo -e $(date) "Firing up the rest of the stack"
docker-compose up -d

# ---- Set up connectors ---
echo -e "\n\n=============\nWaiting for Kafka Connect to start listening on localhost ⏳\n=============\n"
while [ $(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors) -ne 200 ] ; do
  echo -e "\t" $(date) " Kafka Connect listener HTTP state: " $(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors) " (waiting for 200)"
  sleep 5
done
echo -e $(date) "\n\n--------------\n\o/ Kafka Connect is ready! Listener HTTP state: " $(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors) "\n--------------\n"

echo -e "\n--\n$(date) +> Creating Kafka Connect Oracle source (Logminer)"
curl -i -X POST -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:8083/connectors \
    -d '{
          "name": "ora-src-dbz-connector-2",
          "config": {
            "connector.class": "io.debezium.connector.oracle.OracleConnector",
            "tasks.max" : "1",
            "database.server.name" : "7cfb0dfca363",
            "database.url" : "jdbc:oracle:thin:@172.19.0.2:1521/ORCLCDB",
            "database.user" : "c##dbzuser",
            "database.password" : "dbz",
            "database.dbname" : "ORCLCDB",
            "database.pdb.name" : "ORCLPDB1",
            "database.history.kafka.bootstrap.servers" : "kafka:29092",
            "database.history.kafka.topic": "schema-changes-inventory",
            "include.schema.changes": "true",
            "database.connection.adapter": "logminer",
            "log.mining.strategy": "online_catalog",
            "key.converter": "io.confluent.connect.avro.AvroConverter",
            "key.converter.schema.registry.url": "http://schema-registry:8081",
            "value.converter": "io.confluent.connect.avro.AvroConverter",
            "value.converter.schema.registry.url": "http://schema-registry:8081",            
            "transforms":"unwrap",
            "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
            "transforms.unwrap.add.fields": "op,table,source.ts_ms",
            "transforms.unwrap.add.headers": "db",
            "transforms.unwrap.delete.handling.mode": "rewrite"
          }
    }' 
