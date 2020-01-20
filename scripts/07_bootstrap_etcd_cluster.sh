#!/bin/bash

PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PrivateIpAddress")

PUBLIC_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicDnsName")

PUBLIC_CONTROLLER_IPS=$(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]")

CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  CLUSTER_SETTING="${CLUSTER_SETTING},$(echo $PUBLIC_DNS_RAW | jq -r '.['${i}']')=https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2380"
  i=$i+1
done

CLUSTER_SETTING=${CLUSTER_SETTING:1}

cat <<EOF > aws_master_hosts.yml
---        
all:       
  children:
    
    master:                           
      hosts:                                                          
$(declare -i i=0
for ip in $PUBLIC_CONTROLLER_IPS; do
echo "        "${ip}:
echo "          "priv_ip: $(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']')
echo "          "pub_dns: $(echo $PUBLIC_DNS_RAW | jq -r '.['${i}']')
i=$i+1 
done)

      vars:
        ansible_python_interpreter: /usr/bin/python3
        cluster_setting: $CLUSTER_SETTING
                                                                             
EOF

ansible-playbook -i aws_master_hosts.yml ../scripts/07_bootstrap_etcd_cluster.yml
