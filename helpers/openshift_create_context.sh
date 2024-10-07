#! /bin/sh

RHCS_TOKEN=$1
ROSA_CLUSTER_ID=$2
ROSA_USERNAME=$3
ROSA_USER_PASSWORD=$4

if [ -z "$RHCS_TOKEN" ] || [ -z "$ROSA_CLUSTER_ID" ] || [ -z "$ROSA_USERNAME" ] || [ -z "$ROSA_USER_PASSWORD" ]; then
    echo "ERROR: Required arguments were not given."
    exit -1
fi

rosa login --token=$RHCS_TOKEN &> /dev/null

if [ $? -ne 0 ]; then
    echo "ERROR: Not able to login on RHCS"
    exit -1
fi

ROSA_API_URL=$(rosa describe cluster --cluster=$ROSA_CLUSTER_ID -o json | jq -r .api.url)

oc login $ROSA_API_URL -u $ROSA_USERNAME -p $ROSA_USER_PASSWORD &> /dev/null

if [ $? -ne 0 ]; then
    echo "ERROR: Not able to login on OpenShift cluster"
    exit -1
fi

oc config view --raw -o json | jq -r '{server: .clusters[0].cluster.server, token: .users[0].user.token}'
