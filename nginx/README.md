
### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/bingolburak/kind-example.git
   ```
2. Install the Nginx with Nginx Prometheus Export Sidecar Containers
   ```sh
   kubectl apply -f nginx     
   ```
4. Check Pods
   ```sh
   kubectl get pods -l app=nginx -w
   ```
