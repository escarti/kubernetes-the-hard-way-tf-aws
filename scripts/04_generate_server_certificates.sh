#!/bin/bash

AWS_MASTER_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 --profile=kube-the-hard-way --region=eu-central-1)
PRIVATE_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PrivateIpAddress) | join(",")')
DNS_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicDnsName) | join(",")')
PUBLIC_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicIpAddress) | join(",")')

CERT_HOSTNAME=10.32.0.1,,10.240.0.10,10.240.0.11,10.240.0.12,$PRIVATE_IP_LIST,\
$DNS_LIST,$PUBLIC_IP_LIST,127.0.0.1,localhost,kubernetes,kubernetes.default,\
kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

echo $CERT_HOSTNAME