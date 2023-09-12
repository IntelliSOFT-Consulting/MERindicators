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


function Loader() {
    for FILE in "$output/"$1*.json
    do 
        # printf "${FILE}"
        local EYED=$(cat ${FILE}| jq -r .id)
        curl -s -X PUT -H "$HEADER" --data @${FILE} $FHIR/$1/${EYED} | jq .

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
        # curl -X POST -H "Content-Type: application/json" --data-binary @"$json_file" -k "$FHIR" >/dev/null 2>&1
        curl -X POST -H "Content-Type: application/json" --data-binary @"$json_file" -k "$FHIR"    
        echo "Posted data from $json_file"
    fi
done


DAKTXCURR=$(curl $FHIR'/Measure/DAKTXCURR/$evaluate-measure?periodStart=2000-01-01&periodEnd=2023-12-31')
KEMRTXCURR=$(curl $FHIR'/Measure/KEMRTXCURR/$evaluate-measure?periodStart=2000-01-01&periodEnd=2023-12-31')



echo "$DAKTXCURR" | jq .
echo "$KEMRTXCURR" | jq .

# # Extract relevant values from the curl output
# numerator=$(echo "$curl_output" | jq -r '.numerator')
# denominator=$(echo "$curl_output" | jq -r '.denominator')
# TX_CURR=$(echo "$curl_output" | jq -r '.TX_CURR')


# # Create a JSON object
# json_output=$(cat <<EOF
# {
#   "numerator": $numerator,
#   "denominator": $denominator,
#   "TX_CURR": "$TX_CURR"
# }
# EOF
# )

# Save the JSON object to a file
# echo "$json_output"
# echo "$json_output" > output.json




# cat measurereports/MERTXCURR.json | jq -r '.group[] | .stratifier[] | .stratum | (. | map(leaf_paths) | unique) as $cols | map (. as $row | ($cols | map(. as $col | $row | getpath($col)))) as $rows | ([($cols | map(. | tostring))] + $rows) | map(@csv) | .[]' > measurereports/MERTXCURR.csv
