## 03. Compute ressources

We will set up our cloud infrastructure on AWS with a terraform script.

We will deploy the following infrastructure:

1. VPC
2. Internet Gateway
3. As many subnets as different availability zones there are inside the region
4. Public security group that allows incoming connections from 0.0.0.0 on ports 80,443 and 22 (NOT SUITABLE FOR PRODUCTION)
5. Routing table and routing table subnet associations
6. One key pair for all the instances (NOT SUITABLE FOR PRODUCTION)
```
ssh-keygen -t rsa -f ~/.ssh/kube_the_hard_way
```
6. One worker instance per subnet
7. One controller instance per subnet
8. One load balancer instance
9. OUTPUT - One provissioner .yml file with the public IPs of our instances


