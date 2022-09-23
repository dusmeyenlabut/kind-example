
### Installation

1. Get the kind command line [here](https://kind.sigs.k8s.io/)
2. Clone the repo
   ```sh
   git clone https://github.com/bingolburak/kind-example.git
   ```
3. Install the Cluster
   ```sh
   kind create cluster --config kind-local.config
   ```
4. Check your cluster
   ```sh
   kind get clusters
   ```
