#!/bin/bash

# This script retrieves the catalog from a Trento server installation running in a Kubernetes cluster.
# The script expects Trento username to be passed as the only argument (-u)
# and prompts for the corresponding password: then uses them to authenticate and retrieve the catalog.
# The catalog is saved to a file specified by the catalog_file variable.

label_instance="app.kubernetes.io/instance=trento-server"
label_wanda_name="app.kubernetes.io/name=wanda"
label_web_name="app.kubernetes.io/name=web"

catalog_file="/tmp/catalog.json"

DEBUG=0

# Parse command line arguments
while getopts "u:" opt; do
    case $opt in
        u)
            TRENTO_USERNAME=$OPTARG
            ;;
        \?)
            >&2 echo "Invalid option: -$OPTARG" >&2
            >&2 echo "Usage: $0 -u <username>"
            exit 1
            ;;
    esac
done

# Check if TRENTO_USERNAME is empty
if [ -z "$TRENTO_USERNAME" ]; then
    >&2 echo "TRENTO_USERNAME is required."
    >&2 echo "Usage: $0 -u <username>"
    exit 1
fi

# Prompt for password
read -s -p "$0: Enter $TRENTO_USERNAME's password: " TRENTO_PASSWORD
echo

# Check if TRENTO_PASSWORD is empty
if [ -z "$TRENTO_PASSWORD" ]; then
    >&2 echo "TRENTO_PASSWORD is required."
    exit 1
fi

# Get the wanda name using the labels
wanda_name=$(kubectl get pods -l $label_instance,$label_wanda_name -o jsonpath="{.items[0].metadata.name}")

# Check if wanda name is not empty
if [ -z "$wanda_name" ]; then
    >&2 echo "No wanda server found with the specified labels."
    exit 1
fi

# Get the name of the web container using the label web name variable
web_name=$(kubectl get pods -l $label_instance,$label_web_name -o jsonpath="{.items[0].metadata.name}")
# Check if web name is not empty
if [ -z "$web_name" ]; then
    >&2 echo "No web container found with the specified labels."
    exit 1
fi

# Run a basic command from the web container
SESSION_JSON=$(kubectl exec -q $web_name -- curl -s -L 'http://localhost:4000/api/session' --header 'Content-Type: application/json' --data '{ "username": "'"$TRENTO_USERNAME"'", "password": "'"$TRENTO_PASSWORD"'" }' 2>> /dev/null) 
ACCESS_TOKEN=$(echo $SESSION_JSON | jq -r '.access_token')
if [ $DEBUG -eq 1 ]; then
    echo "$0: Access token is $ACCESS_TOKEN"
fi

# Check if the access token is empty
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    >&2 echo "$0: Failed to get the access token; verify the username and password."
    exit 1
fi

# Get the Wanda IP using the wanda name
wanda_ip=$(kubectl get pod $wanda_name -o jsonpath="{.status.podIP}")

# Check if wanda IP is not empty
if [ -z "$wanda_ip" ]; then
    >&2 echo "Failed to get the IP of the wanda."
    exit 1
fi

if [ $DEBUG -eq 1 ]; then
    echo "$0: wanda listens at $wanda_ip"
fi

# Get the catalog using the wanda IP and the session token
kubectl exec -q $web_name -- curl -s -L "http://$wanda_ip:4000/api/checks/catalog" --header "Authorization: Bearer $ACCESS_TOKEN" | jq -r 2>> /dev/null 1> $catalog_file

# Check if the catalog file is not empty
if [ -s $catalog_file ]; then
    echo "$0: Catalog file saved at $catalog_file"
    exit 0
fi
else
    >&2 echo "Failed to retrieve the catalog."
    exit 1
fi