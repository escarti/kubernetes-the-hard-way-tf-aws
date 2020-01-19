#!/bin/bash

PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress")

PUBLIC_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicDnsName")

PUBLIC_CONTROLLER_IPS=$(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]")

echo $PUBLIC_CONTROLLER_IPS

CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  CLUSTER_SETTING="${CLUSTER_SETTING},$(echo $PUBLIC_DNS_RAW | jq -r '.['${i}']')=$(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2380"
  i=$i+1
  echo $i
done

echo $CLUSTER_SETTING