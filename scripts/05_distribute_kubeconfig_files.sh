#!/bin/bash

echo "-- 05. DISTRIBUTE KUBECONFIG"

# Workers

AWS_WORKER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId') 

for instance in $INSTANCE_IDS; do

  PUBLIC_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
  PRIVATE_DNS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateDnsName' | cut -d'.' -f1) 

  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/kube_the_hard_way ${PRIVATE_DNS}.kubeconfig kube-proxy.kubeconfig ubuntu@${PUBLIC_IP}:~/

done

# Controllers

PUBLIC_DNS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1\
 --query "Reservations[].Instances[].PublicDnsName" | jq -r ".[]")

for instance in $PUBLIC_DNS; do
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/kube_the_hard_way admin.kubeconfig kube-controller-manager.kubeconfig\
 kube-scheduler.kubeconfig ubuntu@${instance}:~/
done