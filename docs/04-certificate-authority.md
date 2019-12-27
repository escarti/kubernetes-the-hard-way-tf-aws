# Why?

We will generate certificates for:

+ Client certificates: Provide client authentication for various users: admin, kube-controller-manager, kube-proxy, kube-scheduler and kubelet client on each worker node

+ Kubernetes Api Server Certificate: This is the TLS certificate for the Kubernetes API.

+ Service Account Key Pair: Kubernetes uses a certificate to sign service account tokens, so we need to provide a certificate for that purpose
