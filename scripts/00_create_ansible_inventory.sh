#!/bin/bash

PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PrivateIpAddress")

PRIVATE_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PrivateDnsName")

PUBLIC_WORKER_IPS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]")

PUBLIC_CONTROLLER_IPS=$(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]")

CLUSTER_SETTING=""
ETCD_CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  CLUSTER_SETTING="${CLUSTER_SETTING},$(echo $PRIVATE_DNS_RAW | jq -r '.['${i}']' | cut -d'.' -f1)=https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2380"
  ETCD_CLUSTER_SETTING="${ETCD_CLUSTER_SETTING},https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2379"
  i=$i+1
done

ETCD_CLUSTER_SETTING=${ETCD_CLUSTER_SETTING:1}
CLUSTER_SETTING=${CLUSTER_SETTING:1}

cat <<EOF > kube_full_inventory.yml
---        
all:       
  children:
    
    controller:                           
      hosts:                                                          
$(declare -i i=0
for ip in $PUBLIC_CONTROLLER_IPS; do
echo "        "${ip}:
echo "          "priv_ip: $(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']')
i=$i+1 
done)
      vars:
        ansible_python_interpreter: /usr/bin/python3
        cluster_setting: $CLUSTER_SETTING
        etcd_cluster: $ETCD_CLUSTER_SETTING

    worker:                           
      hosts:                                                          
$(for ip in $PUBLIC_WORKER_IPS; do
echo "        "${ip}:
done)
      vars:
        ansible_python_interpreter: /usr/bin/python3
                                                                             
EOF
