```sh

```


### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/bingolburak/kind-example.git
   ```
2. Install the Prometheus with Helm 3
   ```sh
   helm upgrade --install $YourReleaseNameForPrometheus bitnami/kube-prometheus --values prometheus/prometheus-values.yaml 
   ```
3. Check Pods
   ```sh
   kubectl get pods -l app.kubernetes.io/instance=$YourReleaseNameForPrometheus -w
   ```
4. Install the Grafana
   ```sh
   helm install $YourReleaseNameForGrafana bitnami/grafana
   ```
