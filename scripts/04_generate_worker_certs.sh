#!/bin/bash

echo "-- 04. GENERATE WORKER CERTIFICATES"

AWS_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId') 

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
PUBLIC_DNS=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicDnsName') 
PRIVATE_IP=$(echo $AWS_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateIpAddress') 

cat > ${PUBLIC_DNS}-csr.json <<EOF
{
  "CN": "system:node:${PUBLIC_DNS}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${PUBLIC_DNS},${PUBLIC_IP},${PRIVATE_IP} \
  -profile=kubernetes \
  ${PUBLIC_DNS}-csr.json | cfssljson -bare ${PUBLIC_DNS}

done
