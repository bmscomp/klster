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
   - Look for the## 🛠️ Makefile Shortcuts

You can use the `Makefile` to manage the lifecycle of the cluster:

- **`make all`**: 🚀 Launch cluster, deploy Kafka, and deploy UI (full setup).
- **`make deploy`**: 📦 Deploy Kafka and Dashboards (updates existing deployment).
- **`make ui`**: 🖥️ Deploy Kafka UI.
- **`make test`**: 🧪 Run the performance test script.
- **`make ports`**: 🔌 Start port forwarding for Grafana, Kafka UI, and Prometheus.
- **`make registry-setup`**: 🐳 Setup local Docker registry and pull all images.
- **`make registry-status`**: 📊 Check registry status and contents.
- **`make registry-clean`**: 🧹 Clean up local registry.
- **`make chaos-install`**: ⚡ Install LitmusChaos operator.
- **`make chaos-ui`**: 🖥️ Open LitmusChaos UI.
- **`make chaos-experiments`**: 🧪 Deploy sample chaos experiments.
- **`make chaos-clean`**: 🧹 Remove LitmusChaos.
- **`make ps`**: 📊 Show cluster status (nodes, pods, CPU, memory).
- **`make destroy`**: 💥 Destroy the cluster.

## Features

-✨ **Local Docker Registry**: All container images are cached locally for faster deployments and offline operation. The registry runs on `localhost:5001` and caches 11 essential images including Kafka, Prometheus, Grafana, and supporting components.

## 🧪 Chaos Engineering with LitmusChaos

This project integrates [LitmusChaos](https://litmuschaos.io/) for comprehensive Kafka cluster resilience testing.

### Quick Setup

```bash
# Install LitmusChaos operator, UI, and experiments (included in make all)
make chaos-install

# Or deploy as part of full stack
make all

# Access the LitmusChaos UI
make chaos-ui
# Open http://localhost:9091
# Default credentials: admin / litmus

# Deploy chaos experiments
make chaos-experiments
```

### Available Chaos Experiments

#### 1. **Pod Delete** (`01-pod-delete-experiment.yaml`)
Randomly deletes Kafka pods to test recovery and replication.
- **Duration**: 30s
- **Interval**: 10s  
- **Affected**: 50% of pods
- **Tests**: StatefulSet recovery, leader election, data replication

#### 2. **Container Kill** (`02-container-kill-experiment.yaml`)
Kills Kafka containers to test restart policies and data consistency.
- **Duration**: 60s
- **Interval**: 10s
- **Target**: kafka container
- **Tests**: Container restart, data persistence, client reconnection

#### 3. **Node Drain** (`03-node-drain-experiment.yaml`)
Drains a Kubernetes node to test pod rescheduling and cluster rebalancing.
- **Duration**: 60s
- **Scope**: Cluster-wide
- **Tests**: Pod rescheduling, zone awareness, partition rebalancing

#### 4. **Network Loss** (`04-network-loss-experiment.yaml`)
Introduces packet loss to test network resilience.
- **Duration**: 60s
- **Packet Loss**: 20%
- **Tests**: Network resilience, replication lag, client timeouts

#### 5. **Disk Fill** (`05-disk-fill-experiment.yaml`)
Fills disk space to test storage monitoring and alerts.
- **Duration**: 60s
- **Fill**: 80%
- **Tests**: Storage pressure, log compaction, disk monitoring

### Running Chaos Experiments

#### Prerequisites

1. **RBAC Setup** (automatically applied by `make chaos-install`):
   ```bash
   kubectl apply -f config/litmus-experiments/00-chaosengine-rbac.yaml
   ```

2. **Verify Kafka is Running**:
   ```bash
   kubectl get kafka krafter -n kafka
   ```

3. **Verify LitmusChaos Operator**:
   ```bash
   kubectl get pods -n litmus
   ```

#### Apply All Experiments

```bash
kubectl apply -f config/litmus-experiments/
```

#### Run Individual Experiment

Create a ChaosEngine to trigger an experiment:

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: kafka-pod-delete-test
  namespace: kafka
spec:
  appinfo:
    appns: kafka
    applabel: 'strimzi.io/cluster=krafter'
    appkind: statefulset
  engineState: active
  chaosServiceAccount: kafka-chaos-sa
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: '30'
            - name: CHAOS_INTERVAL
              value: '10'
```

Apply it:
```bash
kubectl apply -f my-chaos-engine.yaml
```

### Monitoring Chaos Results

#### View Experiment Status
```bash
kubectl get chaosexperiments -n kafka
```

#### View Chaos Results
```bash
kubectl get chaosresults -n kafka
```

#### View Detailed Results
```bash
kubectl describe chaosresult <result-name> -n kafka
```

#### View Chaos Logs
```bash
kubectl logs -n kafka -l job-name=<chaos-job-name>
```

#### Grafana Dashboards

Monitor chaos impact in real-time:
1. Access Grafana: http://localhost:30080
2. Navigate to Dashboards → LitmusChaos
3. Monitor:
   - Experiment success rate
   - Kafka cluster health during chaos
   - Recovery time
   - Message throughput impact
   - Partition replication status

### Best Practices

1. **Start Small**: Begin with short durations and low impact percentages
2. **Monitor Continuously**: Always watch Grafana dashboards during experiments
3. **Document Results**: Record observations and recovery times
4. **Gradual Increase**: Increase chaos intensity gradually
5. **Production-like**: Test scenarios that match real production failures
6. **Baseline First**: Establish normal performance metrics before chaos testing

### Chaos Cleanup

#### Stop Running Experiments
```bash
kubectl delete chaosengine --all -n kafka
```

#### Remove Experiments
```bash
kubectl delete chaosexperiments --all -n kafka
```

#### Clean Results
```bash
kubectl delete chaosresults --all -n kafka
```

#### Uninstall LitmusChaos
```bash
make chaos-clean
```

### Troubleshooting Chaos Experiments

#### Experiment Not Starting
- Check RBAC: `kubectl get sa kafka-chaos-sa -n kafka`
- Check operator logs: `kubectl logs -n litmus -l app.kubernetes.io/component=operator`
- Verify experiment exists: `kubectl get chaosexperiments -n kafka`

#### Experiment Failed
- View result details: `kubectl describe chaosresult <name> -n kafka`
- Check pod logs: `kubectl logs -n kafka -l job-name=<chaos-job>`
- Verify target pods exist: `kubectl get pods -n kafka -l strimzi.io/cluster=krafter`

#### Images Not Found
- Ensure images are loaded: `make ps`
- Check image pull policy is `Never` in experiment definitions
- Verify images in Kind: `docker exec panda-control-plane crictl images | grep litmus`

### Project Structure

The LitmusChaos setup includes:
- **Project Configuration**: `config/litmus-project.yaml` - Namespace, RBAC, project metadata
- **Helm Values**: `config/litmus-values.yaml` - Resource limits, image configs
- **Experiments**: `config/litmus-experiments/` - All chaos experiment definitions
- **Workflows**: `config/litmus-workflows/` - Automated chaos workflows (requires Argo)
- **Documentation**: `config/litmus-experiments/README.md` - Detailed experiment guide
🚀 **Quick Setup**: One-command deployment of full Kafka + monitoring stack  
📊 **Comprehensive Monitoring**: Prometheus, Grafana, and custom Kafka dashboards  
⚡ **Performance Testing**: Built-in Kafka performance test scripts  
🧪 **Chaos Engineering**: LitmusChaos integration for resilience testing  
🖥️ **Kafka UI**: Web-based interface for Kafka cluster management

## 📊 Monitoring & Dashboards
 (all working ✅):
     - **kafka**: ⭐ **User Requested** - All possible metrics + Kubernetes Node Affinity
     - **Kafka - Complete Monitoring**: Primary Dashboard - All metrics, brokers, topics, zones, JVM
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

