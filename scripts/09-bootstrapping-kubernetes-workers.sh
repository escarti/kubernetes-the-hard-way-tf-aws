#!/bin/bash

echo "-- 09. BOOTSTRAP WORKERS"

# Create inventory file just in case
DIRECTORY=$(dirname $0)
$DIRECTORY/00_create_ansible_inventory.sh

ansible-playbook -i kube_full_inventory.yml ../ansible/09-bootstrapping-kubernetes-workers.yml