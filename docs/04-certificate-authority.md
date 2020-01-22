# Why?

We will generate certificates for:

+ Client certificates: Provide client authentication for various users: admin, kube-controller-manager, kube-proxy, kube-scheduler and kubelet client on each worker node

+ Kubernetes Api Server Certificate: This is the TLS certificate for the Kubernetes API.

+ Service Account Key Pair: Kubernetes uses a certificate to sign service account tokens, so we need to provide a certificate for that purpose

# Provisioning Certificate Authority

Generate a temp folder to put all files
```
mkdir tmp
cd tmp/
```

You can automate this whole step by running:
```
{
  ./../scripts/04_generate_client_certificates.sh
  ./../scripts/04_generate_server_certificates.sh
  ./../scripts/04_distribute_certificate_files.sh
}
```

## Client-Side certificates

If you wish you can jump this part by directly running. [See here](../scripts/04_generate_client_certificates.sh)

```
./../scripts/04_generate_client_certificates.sh
```

### Certificate Authority

Generate CA configuration file

```
{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}
```
Results
```
ca-key.pem
ca.pem
```

### Client and Server Certificates
Ensure you are in the temp folder
```
cd tmp/
```

Generate the admin client certificate and private key

```
{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
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
  admin-csr.json | cfssljson -bare admin

}
```
Results:
```
admin-key.pem
admin.pem
```

### The Kubelet Client Certificates

Kubernetes uses a special-purpose authorization mode called Node Authorizer, that specifically authorizes API requests made by Kubelets. In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the system:nodes group, with a username of system:node:<nodeName>. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.

Generate a certificate and private key for each Kubernetes worker node:

You have a script file you can run under [/scripts/04_generate_worker_cets.sh](../scripts/04_generate_worker_cets.sh)

```
AWS_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
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
```
### The Controller Manager Client Certificate

Generate the kube-controller-manager client certificate and private key:

```
{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
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
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}
```

Results:
```
kube-controller-manager-key.pem
kube-controller-manager.pem
```

### The Kube Proxy Client Certificate

Generate the kube-proxy client certificate and private key:

```
{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
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
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}
```

Results:
```
kube-proxy-key.pem
kube-proxy.pem
```

### The Scheduler Client Certificate

```
{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
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
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}
```

Results:
```
kube-scheduler-key.pem
kube-scheduler.pem
```

## Server side certificates

### The Kubernetes API Server Certificate

The kubernetes-the-hard-way static IP address will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.

Generate the Kubernetes API Server certificate and private key:

```
{

AWS_MASTER_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
MASTER_PRIVATE_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PrivateIpAddress) | join(",")')
MASTER_DNS_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicDnsName) | join(",")')
MASTER_PUBLIC_IP_LIST=$(echo $AWS_MASTER_RESULT | jq -r '.Reservations | map(.Instances[].PublicIpAddress) | join(",")')

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer" --output text --query 'LoadBalancers[].DNSName' --profile=kube-the-hard-way --region=eu-central-1)

CERT_HOSTNAME=10.32.0.1,$MASTER_PRIVATE_IP_LIST,\
$MASTER_DNS_LIST,$MASTER_PUBLIC_IP_LIST,127.0.0.1,localhost,kubernetes,kubernetes.default,\
kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local,\
$KUBERNETES_PUBLIC_ADDRESS

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

}
```
> The Kubernetes API server is automatically assigned the `kubernetes` internal dns name, which will be linked to the first IP address (`10.32.0.1`) from the address range (`10.32.0.0/24`) reserved for internal cluster services during the [control plane bootstrapping](08-bootstrapping-kubernetes-controllers.md#configure-the-kubernetes-api-server) lab.

### The Service Account Key Pair

The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the [managing service](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) accounts documentation.

Generate the service-account certificate and private key:

```
{

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

}
```

### Distribute the Client and Server Certificates

Copy the appropriate certificates and private keys to each worker instance:

You can also use the provided [script](../scripts/04_distribute_certificate_files.sh)

```
{
  AWS_WORKER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=($(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId'))

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 
PUBLIC_DNS=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicDnsName') 
PRIVATE_IP=$(echo $AWS_WORKER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PrivateIpAddress') 

scp -i ~/.ssh/kube_the_hard_way ca.pem $PUBLIC_DNS-key.pem $PUBLIC_DNS.pem ubuntu@$PUBLIC_IP:~/

done
}
```

Copy the appropriate certificates and private keys to each controller instance:

```
{

AWS_CONTROLLER_CLI_RESULT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1)
INSTANCE_IDS=($(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[].InstanceId'))

for instance in $INSTANCE_IDS; do

PUBLIC_IP=$(echo $AWS_CONTROLLER_CLI_RESULT | jq -r '.Reservations[].Instances[] | select(.InstanceId=="'${instance}'") | .PublicIpAddress') 

scp -i ~/.ssh/kube_the_hard_way ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@$PUBLIC_IP:~/

done

}
```
> The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.
Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)
