# Bootstrapping the Kubernetes Worker Nodes

In this lab you will bootstrap three Kubernetes worker nodes. The following components will be installed on each node: [runc](https://github.com/opencontainers/runc), [gVisor](https://github.com/google/gvisor), [container networking plugins](https://github.com/containernetworking/cni), [containerd](https://github.com/containerd/containerd), [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

You can automate this step by running:
```
cd tmp
../scripts/09-bootstrapping-kubernetes-workers.sh
```

## Prerequisites

Ensure you have the ssh key loaded in the agent and go into the tmp directory:

````
make init
cd tmp
```

The commands in this lab must be run on each worker instance: worker-0, worker-1, and worker-2. Login to each worker instance using the ssh command. Example:

```
{
PUBLIC_WORKER_IPS=($(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_worker_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicIpAddress" | jq -r ".[]"))

for external_ip in $PUBLIC_WORKER_IPS; do
  echo ssh ubuntu@$external_ip
done
}
```

Now ssh into each one of the IP addresses received in last step.

We will use ansible to remotely connect and configure all of them at once.

First create the inventory file by running:

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

Or just
```
./../scripts/00_create_ansible_inventory.sh
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

You 
## Provisioning a Kubernetes Worker Node

Install the OS dependencies:

SSH:
```
{
sudo apt-get update
sudo apt-get -y install socat conntrack ipset
}
```

> The socat binary enables support for the `kubectl port-forward` command.

ANSIBLE:
```
---
- hosts: worker
  remote_user: ubuntu
  tasks:

  - name: Update the repository cache and install socat, conntrack and ipset
    apt:
      pkg:
        - socat
        - conntrack
        - ipset
      update_cache: yes
    become: yes
```

### Download and Install Worker Binaries

SSH: 

```
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
```

Create the installation directories:

```
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

Install the worker binaries:

```
chmod +x kubectl kube-proxy kubelet runc.amd64 runsc
sudo mv runc.amd64 runc
sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
sudo tar -xvf crictl-v1.15.0-linux-amd64.tar.gz -C /usr/local/bin/
sudo tar -xvf cni-plugins-amd64-v0.7.1.tgz -C /opt/cni/bin/
sudo tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C /
```

ANSIBLE:
```
  - name: Create directories
    file:
      path: "{{item}}"
      state: directory
    become: yes
    with_items: 
      - "/etc/cni/net.d"
      - "/opt/cni/bin"
      - "/var/lib/kubelet"
      - "/var/lib/kube-proxy"
      - "/var/lib/kubernetes"
      - "/var/run/kubernetes"
      - "/etc/containerd"

  - name: Download files
    get_url:
      url: "{{ item }}"
      dest: /usr/local/bin/
      mode: a+x
    with_items:
      - "https://storage.googleapis.com/kubernetes-the-hard-way/runsc"
      - "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64"
      - "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
      - "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy"
      - "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet"
    become: yes

  - name: Rename runc.amd64 to runc
    shell: cp /usr/local/bin/runc.amd64 /usr/local/bin/runc
    become: yes

  - name: Download and untar crictl
    unarchive:
      src: "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz"
      dest: /usr/local/bin/
      remote_src: yes
    become: yes
  
  - name: Download and untar containerd
    unarchive:
      src: "https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz"
      dest: /
      remote_src: yes
    become: yes

  - name: Download and untar cni-plugins
    unarchive:
      src: "https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz"
      dest: /opt/cni/
      remote_src: yes
    become: yes
```
### Configure CNI Networking

Retrieve the Pod CIDR range for the current compute instance:

SSH:
```
POD_CIDR=$(curl -s http://169.254.169.254/latest/user-data/ \
  | tr "|" "\n" | grep "^pod-cidr" | cut -d"=" -f2)
echo "${POD_CIDR}"
```

Create the `bridge` network configuration file:

```
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

Create the `loopback` network configuration file:

```
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

ANSIBLE:
```
  - name: Get Pod-Cidr
    shell: |
      curl -s http://169.254.169.254/latest/user-data/ | tr "|" "\n" | grep "^pod-cidr" | cut -d"=" -f2
    args:
      warn: false
    register: pod_cidr
  
  - name: Create CNI bridge file
    template:
      src: "09_bridge_conf.template"
      dest: "/etc/cni/net.d/10-bridge.conf"
    become: yes

  - name: Create CNI loopback service file
    template:
      src: "09_loopback_conf.template"
      dest: "/etc/cni/net.d/99-loopback.conf"
    become: yes
```

### Configure containerd

SSH: 
Create the `containerd` configuration file:

```
sudo mkdir -p /etc/containerd/
```

```
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF
```

> Untrusted workloads will be run using the gVisor (runsc) runtime.

Create the `containerd.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:
```
  - name: Create containerd config file
    template:
      src: "09_containerd_config.template"
      dest: "/etc/containerd/config.toml"
    become: yes

  - name: Create containerd service file
    template:
      src: "09_containerd_service.template"
      dest: "/etc/systemd/system/containerd.service"
    become: yes
```

### Configure the Kubelet

SSH:
```
WORKER_NAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
echo "${WORKER_NAME}"

sudo mv ${WORKER_NAME}-key.pem ${WORKER_NAME}.pem /var/lib/kubelet/
sudo mv ${WORKER_NAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
```

Create the `kubelet-config.yaml` configuration file:

```
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER_NAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER_NAME}-key.pem"
EOF
```

> The `resolvConf` configuration is used to avoid loops when using CoreDNS for service discovery on systems running `systemd-resolved`. 

Create the `kubelet.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --resolv-conf=/run/systemd/resolve/resolv.conf \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:
```
  - name: 09.13 Get DNS-name
    shell: |
      curl -s http://169.254.169.254/latest/meta-data/hostname
    args:
      warn: false
    register: private_dns
  
  - name: 09.14 Copy Kubelet cert files
    shell: |
      cp {{ private_dns.stdout }}-key.pem {{ private_dns.stdout }}.pem /var/lib/kubelet/
      cp {{ private_dns.stdout }}.kubeconfig /var/lib/kubelet/kubeconfig
      cp ca.pem /var/lib/kubernetes/
    args:
      warn: false
    become: yes

  - name: Create kubelet config yaml file
    template:
      src: "09_kubelet_config_yaml.template"
      dest: "/var/lib/kubelet/kubelet-config.yaml"
    become: yes

  - name: Create kubelet service file
    template:
      src: "09_kubelet_service.template"
      dest: "/etc/systemd/system/kubelet.service"
    become: yes
```

### Configure the Kubernetes Proxy

SSH:
```
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

Create the `kube-proxy-config.yaml` configuration file:

```
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

Create the `kube-proxy.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

ANSIBLE:
```
  - name: Move kube proxy kubeconfig
    shell: cp /home/ubuntu/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
    become: yes

  - name: Create kube proxy config yaml file
    template:
      src: "09_kube_proxy_config_yaml.template"
      dest: "/var/lib/kube-proxy/kube-proxy-config.yaml"
    become: yes

  - name: Create kube proxy service file
    template:
      src: "09_kube_proxy_service.template"
      dest: "/etc/systemd/system/kube-proxy.service"
    become: yes
```
### Start the Worker Services

SSH:
```
{
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl restart systemd-resolved
sudo systemctl stop containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
}
```

ANSIBLE:
```
  - name: Start the Worker Services
    shell: |
      systemctl daemon-reload 
      systemctl enable containerd kubelet kube-proxy
      systemctl stop containerd kubelet kube-proxy
      systemctl start containerd kubelet kube-proxy
    become: yes
```
> Remember to run the above commands on each worker node: `worker-0`, `worker-1`, and `worker-2`.

## Verification

> The compute instances created in this tutorial will not have permission to complete this section. Run the following commands from the same machine used to create the compute instances.

List the registered Kubernetes nodes:

```
external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=controller-0" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

ssh -i kubernetes.id_rsa ubuntu@${external_ip}

kubectl get nodes --kubeconfig admin.kubeconfig
```

> output

```
NAME             STATUS   ROLES    AGE   VERSION
ip-10-240-0-20   Ready    <none>   51s   v1.15.3
ip-10-240-0-21   Ready    <none>   51s   v1.15.3
ip-10-240-0-22   Ready    <none>   51s   v1.15.3
```

Next: [Configuring kubectl for Remote Access](10-configuring-kubectl.md)