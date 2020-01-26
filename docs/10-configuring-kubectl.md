# Configuring kubectl for Remote Access

In this lab you will generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user credentials.

> Run the commands in this lab from the same directory used to generate the admin client certificates.


You can automate this step by running:
```
cd tmp
../scripts/10-configuring-kubectl.sh
```

## The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

Generate a kubeconfig file suitable for authenticating as the `admin` user:

```
{
KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --names "kube-loadbalancer"\
 --output text --query 'LoadBalancers[].DNSName' --profile=kube-the-hard-way --region=eu-central-1)

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way
}
```

## Verification

Check the health of the remote Kubernetes cluster:

```
kubectl get componentstatuses
```

> output

```
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```

```
kubectl get componentstatus -o json
```
List the nodes in the remote Kubernetes cluster:

```
kubectl get nodes
```

> output

```
NAME                                                   STATUS   ROLES    AGE   VERSION
ec2-18-185-53-159.eu-central-1.compute.amazonaws.com   Ready    <none>   21m   v1.17.2
ec2-35-158-124-59.eu-central-1.compute.amazonaws.com   Ready    <none>   21m   v1.17.2
ec2-52-58-118-177.eu-central-1.compute.amazonaws.com   Ready    <none>   27m   v1.17.2
```

Next: [Provisioning Pod Network Routes](11-pod-network-routes.md)