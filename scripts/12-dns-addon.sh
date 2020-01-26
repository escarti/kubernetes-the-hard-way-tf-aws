#!/bin/bash

echo "-- 12. DNS ADDON"

kubectl apply -f ../templates/kube-dns.yaml

kubectl get pods -l k8s-app=kube-dns -n kube-system

sleep 20s

kubectl run --generator=run-pod/v1 busybox --image=busybox:1.28 --command -- sleep 3600

kubectl get pods -l run=busybox

POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")

kubectl exec -ti $POD_NAME -- nslookup kubernetes
