#!/usr/bin/env bash

RED='\033[0;31m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

# do this first, wait 2-3 min before running - GitHub Actions will ensure this is available.
# docker run -d -p 8080:8080 alphora/cqf-ruler:latest

export FHIR="http://localhost:8080/fhir"
# export FHIR="http://ryzen.local:8080/fhir"

export HEADER="Content-Type: application/fhir+json"
export BUNDLES_DIR="./test/scripts/bundles"
export output="$(pwd)/output"
        
echo "Attempting to connect to Test FHIR Server, retrying in 5 seconds..."
for _ in {1..100}; do
    if curl -sSf http://localhost:8080 > /dev/null 2>&1; then
        echo "FHIR Server Connection successful."
        break
    else
        echo "Attempting to connect to Test FHIR Server, retrying in 5 seconds..."
        sleep 5 # Wait for 5 seconds before retrying
    fi
done

function Loader() {
    for FILE in "$output/"$1*.json; do
        # printf "${FILE}"
        local EYED=$(cat ${FILE} | jq -r .id)
        curl -s -X PUT -H "$HEADER" --data @${FILE} $FHIR/$1/${EYED} | jq . > /dev/null 2>&1
        # echo "Uploaded $FILE to test FHIR server"

    done
}

# Check if the output directory exists
if [ ! -d "${output}" ]; then
    echo "Build output directory does not exist. Running build scripts first..."
    ./_updatePublisher.sh
    ./_updateCQFTooling.sh
    ./_runcqf.sh
else
    echo "Build output directory already exists."
fi

Loader Device
Loader CodeSystem
Loader ValueSet
Loader Library
Loader Measure
Loader Organization
Loader Location

# Iterate through JSON files in the folder
for json_file in "$BUNDLES_DIR"/*.json; do
    if [ -f "$json_file" ]; then
        echo "Processing $json_file"
        # Perform the POST request using curl
        curl -X POST -H "Content-Type: application/json" --data-binary @"$json_file" -k "$FHIR" >/dev/null 2>&1
        # curl -X POST -H "Content-Type: application/json" --data-binary @"$json_file" -k "$FHIR"
        echo "Posted data from $json_file"
    fi
done

KEMRTXCURR=$(curl $FHIR'/Measure/KEMRTXCURR/$evaluate-measure?periodStart=2020-01-01&periodEnd=2023-08-31')

# echo "$DAKTXCURR" | jq .
value=$(jq -r '.group[0].population[1].count' <<< "$KEMRTXCURR")

if [ "$value" != "4" ]; then
    echo "Inaccurate TX_CURR value.
            - Expected TX_CURR = 4
            - Current TX_CURR = $value"
    exit 1
else
    echo "TX_CURR value is accurate.
            - Expected TX_CURR = 4
            - Current TX_CURR = $value"
    exit 0
fi