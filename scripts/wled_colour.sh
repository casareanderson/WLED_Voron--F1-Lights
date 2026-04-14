#!/bin/bash
IP=$1
R=$2
G=$3
B=$4
BRI=$5
FX=$6

curl -s -X POST "http://${IP}/json/state" \
     -H "Content-Type: application/json" \
     -d "{\"on\":true,\"bri\":${BRI},\"seg\":[{\"id\":0,\"frz\":false,\"fx\":${FX},\"col\":[[${R},${G},${B}]]}]}" \
     --connect-timeout 3 \
     --max-time 5 \
     -o /dev/null
