#!/bin/bash

echo "-- 08. BOOTSTRAP CONTROLLERS"

# Create inventory file just in case
DIRECTORY=$(dirname $0)
$DIRECTORY/00_create_ansible_inventory.sh

ansible-playbook -i kube_full_inventory.yml ../ansible/08_bootstrap_controllers.yml

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=kube-the-hard-way --region=eu-central-1)

echo "08. !!! - WAIT 30s FOR THE CLUSTER TO INIT - !!!"
sleep 30s

curl -k --cacert ca.pem https://"${KUBERNETES_PUBLIC_ADDRESS}"/version
