PUBLIC_WORKER_IPS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]")
 
cat <<EOF > aws_worker_hosts.yml
---        
all:       
  children:
    
    worker:                           
      hosts:                                                          
$(for ip in $PUBLIC_WORKER_IPS; do
echo "        "${ip}:
done)

      vars:
        ansible_python_interpreter: /usr/bin/python3
                                                                             
EOF

ansible-playbook -i aws_worker_hosts.yml ../scripts/09-bootstrapping-kubernetes-workers.yml