#!/bin/bash
echo -e "#### RESPONSE & LOG ####"

curl --location "https://path/v2?tenant_id=$2&bu_id=$3" --header "Cookie: $1" --form "csvFile=@\"/tmp/nifi/$4\";type=text/csv" --http1.1 -vv

echo -e " "

echo -e "tenant_id: $2"

echo -e "bu_id: $3"

echo -e "Uploaded File: $4"
