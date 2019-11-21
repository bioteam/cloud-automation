#!/bin/bash

cd "$(dirname ${BASH_SOURCE[0]})"

gen3 workon bms bms-commons

kubectl delete secret regcred
aws ecr get-login | sed 's/\-e none //g' | source /dev/stdin
kubectl create secret generic regcred --from-file=.dockerconfigjson=/root/.docker/config.json --type=kubernetes.io/dockerconfigjson
