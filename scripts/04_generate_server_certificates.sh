#!/bin/bash

AWS_MASTER_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance"\
 --profile=kube-the-hard-way --region=eu-central-1)
MASTER_PRIVATE_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PrivateIpAddress) | join(",")')
MASTER_DNS_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicDnsName) | join(",")')
MASTER_PUBLIC_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicIpAddress) | join(",")')

AWS_ALB_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_api_load_balancer_*instance"\
 --profile=kube-the-hard-way --region=eu-central-1)
ALB_PRIVATE_IP_LIST=$(echo $AWS_ALB_RESULT | jq -r '.Reservations | map(.Instances[].PrivateIpAddress) | join(",")')
ALB_DNS_LIST=$(echo $AWS_ALB_RESULT | jq -r '.Reservations | map(.Instances[].PublicDnsName) | join(",")')
ALB_PUBLIC_IP_LIST=$(echo $AWS_ALB_RESULT | jq -r '.Reservations | map(.Instances[].PublicIpAddress) | join(",")')


CERT_HOSTNAME=10.32.0.1,,10.240.0.10,10.240.0.11,10.240.0.12,$MASTER_PRIVATE_IP_LIST,\
$MASTER_DNS_LIST,$MASTER_PUBLIC_IP_LIST,127.0.0.1,localhost,kubernetes,kubernetes.default,\
kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local,\
$ALB_PRIVATE_IP_LIST,$ALB_DNS_LIST,$ALB_PUBLIC_IP_LIST

cat > kubernetes-csr.json << EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
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
  -hostname=${CERT_HOSTNAME} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
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
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account