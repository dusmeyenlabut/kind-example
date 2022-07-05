This README file will explain how to deploy a basic _Traefik Ingress Controller_ on a DHC cluster.

# Install via helm
* https://git.daimler.com/helm/traefik
* https://git.daimler.com/DHC/CaaS/blob/master/technical-docs/ingress/simple-traefik.md
* https://git.daimler.com/DHC/CaaS/blob/master/technical-docs/ingress/traefik-tls.md#option-2-automatically-generate-and-renew-certificates-using-the-daimler-acme-service

## Add the repo

```
helm repo add harbor_dag https://registry.app.corpintra.net/chartrepo/dag
helm repo update
```

## Install the Helm Chart

```shell
kubectl create namespace ingress
helm upgrade --install ingress harbor_dag/traefikv2 -f values-dev-dhc.yaml -n ingress
```