#!/bin/bash

# Workers

AWS_WORKER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId') 

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
PUBLIC_DNS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicDnsName') 
PRIVATE_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateIpAddress') 

scp -i ~/.ssh/kube_the_hard_way ca.pem $PUBLIC_DNS-key.pem $PUBLIC_DNS.pem ubuntu@$PUBLIC_IP:~/

done

# Controllers

AWS_CONTROLLER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=$(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId')

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 

scp -i ~/.ssh/kube_the_hard_way ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@$PUBLIC_IP:~/

done
