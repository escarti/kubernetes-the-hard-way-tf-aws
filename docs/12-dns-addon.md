# Deploying the DNS Cluster Add-on

In this lab you will deploy the [DNS add-on](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) which provides DNS based service discovery, backed by [CoreDNS](https://coredns.io/), to applications running inside the Kubernetes cluster.

## The DNS Cluster Add-on

Deploy the `coredns` cluster add-on:

```
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml
```
or use the provided template
```
kubectl apply -f templates/coredns.yaml
```

You can also use kube-dns
```
kubectl apply -f templates/kube-dns.yaml
```

> output

```
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.extensions/coredns created
service/kube-dns created
```

List the pods created by the `kube-dns` deployment:

```
kubectl get pods -l k8s-app=kube-dns -n kube-system
```

> output

```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-699f8ddd77-94qv9   1/1     Running   0          20s
coredns-699f8ddd77-gtcgb   1/1     Running   0          20s
```
or
```
NAME                       READY   STATUS    RESTARTS   AGE
kube-dns-5ff947fc6-6t68d   3/3     Running   0          7m5s
```
## Verification

Create a `busybox` deployment:

```
kubectl run --generator=run-pod/v1 busybox --image=busybox:1.28 --command -- sleep 3600
```

List the pod created by the `busybox` deployment:

```
kubectl get pods -l run=busybox
```

> output

```
NAME      READY   STATUS    RESTARTS   AGE
busybox   1/1     Running   0          3s
```

Check service
```
kubectl get svc --namespace=kube-system
```

> output

```
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.32.0.10   <none>        53/UDP,53/TCP   2m23s
```

Check endpoints
```
kubectl get ep kube-dns --namespace=kube-system
```

> output

```
NAME       ENDPOINTS                     AGE
kube-dns   10.200.0.2:53,10.200.0.2:53   3m1s
```

Retrieve the full name of the `busybox` pod:

```
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
``

Execute a DNS lookup for the `kubernetes` service inside the `busybox` pod:

```
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

> output

```
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```

Sadly I have no clue why, but I'm getting this error:
```
Server:    10.32.0.10
Address 1: 10.32.0.10

nslookup: can't resolve 'kubernetes'
command terminated with exit code 1
```

Next: [Smoke Test](13-smoke-test.md)



LOOK: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

