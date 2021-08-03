#!/bin/bash

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
          "name": "ora-src-dbz-connector",
          "config": {
            "connector.class": "io.debezium.connector.oracle.OracleConnector",
            "tasks.max" : "1",
            "database.server.name" : "HMLOLAP2",
            "database.url" : "jdbc:oracle:thin:@10.0.182.232:1521/DBM03.HMLOLAP",
            "database.dbname" : "HMLOLAP",
            "database.pdb.name" : "DBM03",
            "database.history.kafka.bootstrap.servers" : "kafka:29092",
            "database.history.kafka.topic": "schema-changes-inventory",
            "include.schema.changes": "true",
            "database.connection.adapter": "logminer",
            "table.include.list": "SJD_ODS.PE_TB_PROCESSO_TRF",
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
