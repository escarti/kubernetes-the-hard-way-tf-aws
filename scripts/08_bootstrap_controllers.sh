#!/bin/bash

PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PrivateIpAddress")

PUBLIC_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicDnsName")

PUBLIC_CONTROLLER_IPS=$(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]")

ETCD_CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  ETCD_CLUSTER_SETTING="${ETCD_CLUSTER_SETTING},https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2379"
  i=$i+1
done
ETCD_CLUSTER_SETTING=${ETCD_CLUSTER_SETTING:1}

echo "ETCD_CLUSTER_SETTING="$ETCD_CLUSTER_SETTING
 
cat <<EOF > aws_controller_hosts.yml
---        
all:       
  children:
    
    controller:                           
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
        etcd_cluster: $ETCD_CLUSTER_SETTING
                                                                             
EOF

ansible-playbook -i aws_controller_hosts.yml ../scripts/08_bootstrap_controllers.yml

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=kube-the-hard-way --region=eu-central-1)

curl -k --cacert ca.pem https://"${KUBERNETES_PUBLIC_ADDRESS}"/version
