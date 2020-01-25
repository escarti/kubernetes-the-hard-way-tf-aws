# Bootstrapping the Kubernetes Control Plane

In this lab you will bootstrap the Kubernetes control plane across three compute instances and configure it for high availability. You will also create an external load balancer that exposes the Kubernetes API Servers to remote clients. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

You can automate this step by running:
```
cd tmp
../scripts/08_bootsrap_controllers.sh
```

## Prerequisites

ENSURE YOU ARE ON THE TMP DIRECTORY:

````
cd tmp
```

The commands in this lab must be run on each controller instance: `controller-0`, `controller-1`, and `controller-2`. Login to each controller instance using the `ssh` command. Example:

```
{
PUBLIC_CONTROLLER_IPS=($(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]"))

for external_ip in $PUBLIC_CONTROLLER_IPS; do
  echo ssh -i kubernetes.id_rsa ubuntu@$external_ip
done
}
```

Now ssh into each one of the IP addresses received in last step.

We will use ansible to remotely connect and configure all of them at once.

First create the inventory file in case you don't have it by running:

```
{
PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PrivateIpAddress")

PUBLIC_DNS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicDnsName")

PUBLIC_WORKER_IPS=($(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query\
 "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]"))

PUBLIC_CONTROLLER_IPS=($(echo $PUBLIC_CONTROLLER_IPS_RAW | jq -r ".[]"))

CLUSTER_SETTING=""
ETCD_CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  CLUSTER_SETTING="${CLUSTER_SETTING},$(echo $PUBLIC_DNS_RAW | jq -r '.['${i}']')=https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2380"
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
echo "          "pub_dns: $(echo $PUBLIC_DNS_RAW | jq -r '.['${i}']')
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
}
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Provision the Kubernetes Control Plane

Create the Kubernetes configuration directory:

SSH:

```
sudo mkdir -p /etc/kubernetes/config
```

ANSIBLE:

Create a playbook file and start copying this:

```
---
- hosts: controller
  remote_user: ubuntu
  tasks:

    - name: Creates directory /etc/kubernetes/config
      file:
        path: /etc/kubernetes/config
        state: directory
      become: yes
```

### Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

SSH: 

```
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
```

Install the Kubernetes binaries:

```
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
```

ANSIBLE:

```
    - name: Download kube-apiserver
      get_url:
        url: https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver
        dest: /usr/local/bin/
        mode: a+x
      become: yes

    - name: Download kube-controller-manager
      get_url:
        url: https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager
        dest: /usr/local/bin/
        mode: a+x
      become: yes
    
    - name: Download kube-scheduler
      get_url:
        url: https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler
        dest: /usr/local/bin/
        mode: a+x
      become: yes

    - name: Download kubectl
      get_url:
        url: https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
        dest: /usr/local/bin/
        mode: a+x
      become: yes
```

### Configure the Kubernetes API Server

SSH:
```
sudo mkdir -p /var/lib/kubernetes/

sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/
```

ANSIBLE:
```
    - name: Creates directory /var/lib/kubernetes/
      file:
        path: /var/lib/kubernetes/
        state: directory
      become: yes
    
    - name: Move etcd binaries
      shell: mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem encryption-config.yaml /var/lib/kubernetes/        
      args:
        chdir: /home/ubuntu/
      become: yes
```

The instance internal IP address will be used to advertise the API Server to members of the cluster. Retrieve the internal IP address for the current compute instance:

```
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

And get the ECTD_CLUSTER_SETTING from the snippet at the start of the file running this on your local machine:
```
{
PUBLIC_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicIpAddress")

PRIVATE_CONTROLLER_IPS_RAW=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PrivateIpAddress")

ETCD_CLUSTER_SETTING=""
declare -i i=0
for ip_address in $PUBLIC_CONTROLLER_IPS; do
  ETCD_CLUSTER_SETTING="${ETCD_CLUSTER_SETTING},https://$(echo $PRIVATE_CONTROLLER_IPS_RAW | jq -r '.['${i}']'):2379"
  i=$i+1
done
ETCD_CLUSTER_SETTING=${ETCD_CLUSTER_SETTING:1}

echo "ETCD_CLUSTER_SETTING="$ETCD_CLUSTER_SETTING
}
```

Run the resulting line whithin the instance. It could look something like this

```
ETCD_CLUSTER_SETTING=https://10.0.0.71:2379,https://10.0.2.140:2379,https://10.0.1.119:2379
```

Create the `kube-apiserver.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${ETCD_CLUSTER_SETTING} \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:
```
    - name: Create kube-apiserver service file
      template:
        src: "08_kube_apiserver.template"
        dest: "/etc/systemd/system/kube-apiserver.service"
      become: yes
```

### Configure the Kubernetes Controller Manager

SSH: 

Move the `kube-controller-manager` kubeconfig into place:

```
sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

Create the `kube-controller-manager.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:

```
    - name: Move the 'kube-controller-manager' kubeconfig into place
      shell: cp kube-controller-manager.kubeconfig /var/lib/kubernetes/        
      args:
        chdir: /home/ubuntu/
      become: yes
    
    - name: Create kube-controller-manager service file
      template:
        src: "08_kube_controller_manager.template"
        dest: "/etc/systemd/system/kube-controller-manager.service"
      become: yes
```
### Configure the Kubernetes Scheduler

Move the `kube-scheduler` kubeconfig into place:

SSH:

```
sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
```

Create the `kube-scheduler.yaml` configuration file:

```
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

Create the `kube-scheduler.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:

```
    - name: Move the 'kube-scheduler' kubeconfig into place
      shell: cp kube-scheduler.kubeconfig /var/lib/kubernetes/       
      args:
        chdir: /home/ubuntu/
      become: yes

    - name: Create kube-scheduler.yaml file
      template:
        src: "08_kube_scheduler_yaml.template"
        dest: "/etc/kubernetes/config/kube-scheduler.yaml"
      become: yes
    
    - name: Create kube-scheduler service file
      template:
        src: "08_kube_scheduler_service.template"
        dest: "/etc/systemd/system/kube-scheduler.service"
      become: yes
```
### Start the Controller Services

```
{
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
```

> Allow up to 30 seconds for the Kubernetes API Server to fully initialize.

Now check status of your controller components
```
kubectl get componentstatuses
```

Output: 
```
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
```
Yay !!! - Controllers are up

### Verification of cluster public endpoint - From your laptop

Run this command on the machine from where you started setup (e.g. Your personal laptop)
Retrieve the `kubernetes-the-hard-way` Load Balancer address:

```
KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=kube-the-hard-way --region=eu-central-1)
```

Make a HTTP request for the Kubernetes version info:

```
curl -k --cacert ca.pem https://"${KUBERNETES_PUBLIC_ADDRESS}"/version
```

> output

```
{
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.3",
  "gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
  "gitTreeState": "clean",
  "buildDate": "2019-08-19T11:05:50Z",
  "goVersion": "go1.12.9",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

Next: [Bootstrapping the Kubernetes Worker Nodes](09-bootstrapping-kubernetes-workers.md)