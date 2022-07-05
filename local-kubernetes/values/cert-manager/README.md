This README file will explain how to deploy a basic _Cert-Manager_ on a DHC cluster for automatic certificate renewal.

# Install via helm

## Add the repo

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

## Install the Helm Chart

Please use official DHC [documentation](https://git.daimler.com/DHC/CaaS/blob/master/technical-docs/ingress/traefik-tls.md#option-2-automatically-generate-and-renew-certificates-using-the-daimler-acme-service)

* `values.yaml` files are provided in the same directory as this README 