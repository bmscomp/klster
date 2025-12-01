# Local Kubernetes Cluster with Monitoring

This project provides scripts to launch a local Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/) with 3 nodes simulating different availability zones, and sets up monitoring with Prometheus and Grafana.

## Prerequisites

Ensure you have the following installed:
- [Docker](https://www.docker.com/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Quick Start

1. **Launch the cluster:**
   ```bash
   ./launch.sh
   ```
   This script will:
   - Create a Kind cluster named `panda`.
   - Provision 3 nodes (1 control-plane, 2 workers) with zone labels (`alpha`, `sigma`, `gamma`).
   - Install `kube-prometheus-stack` (Prometheus + Grafana).

2. **Access Grafana:**
   - URL: http://localhost:30080
   - Username: `admin`
   - Password: `admin`

   *Note: If you cannot access the URL directly, run the following command to forward the port:*
   ```bash
   kubectl port-forward svc/monitoring-grafana 30080:80 -n monitoring
   ```

3. **Destroy the cluster:**
   ```bash
   ./destroy.sh
   ```

## Kafka Deployment

To deploy a Kafka Strimzi cluster with KRaft mode and monitoring:

1. **Run the deployment script:**
   ```bash
   ./deploy-kafka.sh
   ```
   This will:
   - Install the Strimzi Cluster Operator via Helm.
   - Deploy a Kafka cluster with 3 brokers (one per zone).
   - Configure Prometheus metrics and a custom Grafana dashboard.

2. **Access the Dashboards:**
   - Go to Grafana (http://localhost:30080).
   - Look for the following dashboards (all working ✅):
     - **Kafka - Complete Monitoring**: ⭐ **Primary Dashboard** - All metrics, brokers, topics, zones, JVM
     - **Kafka Cluster Health**: ✅ Broker status, offline partitions, zone distribution
     - **Kafka Performance Metrics**: ✅ Topic size growth, partitions, broker count
     - **Kafka Performance Test Results**: ✅ perf-test topic metrics, message counts, data sizes
     - **Kafka JVM Metrics**: ✅ Heap memory, GC rate, thread count (with zones)
     - **Kafka Cluster Metrics (Working)**: Simplified view of broker status and topics

## Performance Testing

To test Kafka cluster performance with 1 million messages:

1. **Run the performance test:**
   ```bash
   ./test-kafka-performance.sh
   ```
   This will:
   - Create a `performance` namespace
   - Create a test topic with 3 partitions
   - Deploy a producer that sends 1 million messages
   - Deploy a consumer that reads those messages
   - Display throughput and latency metrics

2. **Cleanup after testing:**
   ```bash
   kubectl delete namespace performance
   ```

## Kafka UI

A web-based UI to manage and browse your Kafka cluster:

1. **Deploy Kafka UI:**
   ```bash
   ./deploy-kafka-ui.sh
   ```

2. **Access the UI:**
   - URL: http://localhost:30081
   - Features:
     - Browse topics and partitions
     - View message content and headers
     - Monitor consumer groups and lag
     - View broker configurations
     - Full KRaft mode support

## Configuration

- **`config/cluster.yaml`**: Defines the Kind cluster topology.
    - Node 1 (Control Plane): Name `alpha`, Zone `alpha`
    - Node 2 (Worker): Name `sigma`, Zone `sigma`
    - Node 3 (Worker): Name `gamma`, Zone `gamma`
    - *Note: Resource limits (3CPU/6GB/10GB Storage) are defined as instance types labels for simulation, as Kind relies on host Docker resources.*

- **`config/monitoring.yaml`**: Helm values for `kube-prometheus-stack`.
    - Configures Grafana admin password and NodePort.

- **`config/custom-dashboard.yaml`**: ConfigMap containing a custom "Global Resource Vision" dashboard.

