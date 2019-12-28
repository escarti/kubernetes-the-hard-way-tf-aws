#!/bin/bash

# Workers

PUBLIC_DNS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicDnsName" | jq -r ".[]")

for instance in $PUBLIC_DNS; do
  scp -i ~/.ssh/kube_the_hard_way ${instance}.kubeconfig kube-proxy.kubeconfig ubuntu@${instance}:~/
done

# Controllers

PUBLIC_DNS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicDnsName" | jq -r ".[]")

for instance in $PUBLIC_DNS; do
    scp -i ~/.ssh/kube_the_hard_way admin.kubeconfig kube-controller-manager.kubeconfig\
 kube-scheduler.kubeconfig ubuntu@${instance}:~/
done