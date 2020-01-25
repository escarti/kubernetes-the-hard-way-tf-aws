#!/bin/bash

echo "-- 06. GENERATE AND DISTRIBUTE ENCRYPTION KEY"

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

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

PUBLIC_DNS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=kube_controller_*_instance"\
 "Name=instance-state-name,Values=running" --profile=kube-the-hard-way --region=eu-central-1\
  --query "Reservations[].Instances[].PublicDnsName" | jq -r ".[]")

for instance in $PUBLIC_DNS; do
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/kube_the_hard_way encryption-config.yaml ubuntu@${instance}:~/
done
