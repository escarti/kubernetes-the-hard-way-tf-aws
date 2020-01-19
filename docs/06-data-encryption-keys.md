# Generating the Data Encryption Config and Key

Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to [encrypt](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data) cluster data at rest.

In this lab you will generate an encryption key and an [encryption config](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration) suitable for encrypting Kubernetes Secrets.

You can automate this step by running:
```
cd tmp
../scripts/06_generate_distribute_encryption_keys.sh
```

## The Encryption Key

Generate an encryption key:

```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

## The Encryption Config File

Create the `encryption-config.yaml` encryption config file:

```
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Copy the `encryption-config.yaml` encryption config file to each controller instance:

```
PUBLIC_DNS=($(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_master_*_instance" "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1 --query "Reservations[].Instances[].PublicDnsName" | jq -r ".[]"))

for instance in $PUBLIC_DNS; do
    scp -i ~/.ssh/kube_the_hard_way encryption-config.yaml ubuntu@${instance}:~/
done
```

Next: [Bootstrapping the etcd Cluster](07-bootstrapping-etcd.md)