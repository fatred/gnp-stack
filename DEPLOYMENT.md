# GNP-Stack

You can deploy the GNP-Stack either via Docker Compose on a single container host for small setups, or via the Helm chart on a Kubernetes cluster if you need more scalability and resilience.

## Docker Compose Deployment
```bash
git clone https://github.com/fatred/gnp-stack.git
cd gnp-stack
docker-compose up -d
```

### Configuration
You can customize the deployment by modifying the `docker-compose.yml` file before starting the stack.
You can find the configuration files for each component in the following directories:
- gNMIc ingestor: `gnmic/`
- gNMIc emitter: `gnmic/`
- NATS: `nats/`
- Prometheus: `prometheus/`
- Grafana: `grafana/`

## Kubernetes Deployment
For Kubernetes deployment, please refer to the [README](install/kubernetes/gnp-stack/README.md) in the `install/kubernetes/gnp-stack` directory for detailed instructions on how to deploy the GNP-Stack using Helm.