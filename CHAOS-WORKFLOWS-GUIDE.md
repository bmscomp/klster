# Kafka Chaos Workflow Management Guide

## Overview

This guide covers the advanced chaos workflow management system for Kafka resilience testing using Argo Workflows.

## Quick Start

```bash
# 1. Ensure Argo Workflows is installed
make argo-install

# 2. Deploy chaos workflows
make chaos-workflows-deploy

# 3. Run your first chaos test
make chaos-workflows-run

# 4. View results in Argo UI
make argo-ui
# Open https://localhost:2746
```

## Available Workflows

### 1. Kafka Chaos Suite (`kafka-chaos-suite`)

**Purpose**: Comprehensive progressive chaos testing

**Phases**:
1. **Baseline** - Collect initial metrics
2. **Pod Delete** - Test pod recovery (low impact)
3. **Container Kill** - Test container restart (medium impact)
4. **Network Chaos** - Test network resilience (medium-high impact)
   - Packet loss (20%)
   - Latency injection (100ms)
5. **Resource Chaos** - Test resource constraints (high impact)
   - CPU stress (80%)
   - Memory stress (500MB)
6. **Disk Fill** - Test storage pressure (critical impact)
7. **Node Drain** - Test node failure (highest impact)
8. **Report Generation** - Comprehensive results

**Duration**: ~8-10 minutes (60s per experiment)

**Run Command**:
```bash
make chaos-workflows-run
# or
./manage-chaos-workflows.sh run-suite
```

**Customization**:
```bash
# Edit parameters in the workflow file
vim config/litmus-workflows/kafka-chaos-suite.yaml

# Key parameters:
# - kafka-namespace: Target namespace (default: kafka)
# - kafka-cluster: Cluster name (default: krafter)
# - chaos-duration: Duration per experiment (default: 60s)
# - chaos-interval: Interval between chaos injections (default: 10s)
```

### 2. Load Testing with Chaos (`kafka-load-chaos`)

**Purpose**: Performance testing under chaos conditions

**Phases**:
1. **Baseline Load** - Normal performance metrics
2. **Load + Pod Chaos** - Performance with pod failures
3. **Load + Network Chaos** - Performance with network issues
4. **Load + Resource Chaos** - Performance under resource pressure
5. **Performance Report** - Comparative analysis

**Metrics Collected**:
- Throughput (messages/sec)
- Latency (p50, p95, p99)
- Error rates
- Recovery times

**Run Command**:
```bash
make chaos-workflows-load
# or
./manage-chaos-workflows.sh run-load-chaos
```

**Configuration**:
```bash
# Parameters:
# - message-count: Number of messages (default: 100000)
# - message-size: Message size in bytes (default: 1024)
# - throughput: Target msgs/sec (default: 1000)
```

### 3. Scheduled Chaos (`kafka-chaos-schedule`)

**Purpose**: Automated daily chaos testing

**Schedule**: Daily at 2 AM UTC

**Behavior**:
- Randomly selects one chaos experiment
- Runs for 30 seconds
- Verifies recovery automatically
- Maintains history of last 3 runs

**Enable**:
```bash
make chaos-workflows-schedule
# or
./manage-chaos-workflows.sh enable-schedule
```

**Disable**:
```bash
./manage-chaos-workflows.sh disable-schedule
```

**View Schedule**:
```bash
kubectl get cronworkflow kafka-chaos-schedule -n argo
```

## Workflow Management

### Deploy Workflows

```bash
# Deploy all workflow definitions
make chaos-workflows-deploy

# Verify deployment
kubectl get workflows -n argo
kubectl get cronworkflows -n argo
```

### Monitor Workflows

```bash
# Check status
make chaos-workflows-status

# List all workflows
./manage-chaos-workflows.sh list

# Watch workflow execution
argo watch <workflow-name> -n argo
```

### View Logs

```bash
# View logs for specific workflow
./manage-chaos-workflows.sh logs kafka-chaos-suite

# Follow logs in real-time
argo logs kafka-chaos-suite -n argo --follow

# View specific step logs
kubectl logs -n argo -l workflows.argoproj.io/workflow=kafka-chaos-suite
```

### Cleanup

```bash
# Delete specific workflow
./manage-chaos-workflows.sh delete kafka-chaos-suite

# Clean all workflows
make chaos-workflows-clean

# Clean everything (workflows + Argo)
make argo-clean
```

## Viewing Results

### Argo UI

1. Start port-forward: `make argo-ui`
2. Open: https://localhost:2746
3. Accept self-signed certificate
4. Features:
   - Visual workflow DAG
   - Step-by-step execution
   - Real-time logs
   - Artifact viewing

### Grafana Dashboards

1. Open: http://localhost:30080
2. Navigate to Kafka dashboards
3. Key metrics to monitor:
   - Broker availability
   - Under-replicated partitions
   - Leader election rate
   - Request latency
   - Throughput
   - JVM metrics

### Command Line

```bash
# Workflow status
kubectl get workflow kafka-chaos-suite -n argo

# Detailed info
kubectl describe workflow kafka-chaos-suite -n argo

# Step status
kubectl get pods -n argo -l workflows.argoproj.io/workflow=kafka-chaos-suite

# Metrics from Prometheus
curl -s "http://localhost:30090/api/v1/query?query=kafka_server_replicamanager_leadercount"
```

## Best Practices

### 1. Progressive Testing

Start with low-impact tests and gradually increase:
1. Pod delete (recoverable)
2. Network issues (temporary)
3. Resource constraints (reversible)
4. Node failures (highest impact)

### 2. Monitoring

Always monitor during chaos tests:
- Keep Grafana open
- Watch Argo workflow progress
- Monitor Kafka cluster health
- Check application logs

### 3. Baseline Metrics

Collect baseline metrics before chaos:
```bash
# Run baseline collection
kubectl get kafka krafter -n kafka
kubectl get pods -n kafka
kubectl top pods -n kafka
```

### 4. Scheduled Testing

Use scheduled workflows for:
- Regular resilience validation
- Regression testing
- Continuous chaos engineering
- Team confidence building

### 5. Documentation

Document your findings:
- Recovery times
- Impact on throughput
- Error patterns
- Configuration changes needed

## Troubleshooting

### Workflow Won't Start

```bash
# Check Argo server
kubectl get pods -n argo

# Check RBAC
kubectl get sa argo -n argo

# View workflow events
kubectl describe workflow <name> -n argo
```

### Workflow Stuck

```bash
# Check pod status
kubectl get pods -n argo -l workflows.argoproj.io/workflow=<name>

# View pod logs
kubectl logs -n argo <pod-name>

# Delete and retry
kubectl delete workflow <name> -n argo
```

### Metrics Not Collected

```bash
# Verify Prometheus is running
kubectl get pods -n monitoring

# Test Prometheus query
curl "http://localhost:30090/api/v1/query?query=up"

# Check service connectivity
kubectl get svc -n monitoring
```

### Kafka Not Recovering

```bash
# Check broker status
kubectl get pods -n kafka

# View broker logs
kubectl logs -n kafka krafter-pool-alpha-0

# Check Strimzi operator
kubectl logs -n kafka -l strimzi.io/kind=cluster-operator
```

## Advanced Usage

### Custom Workflows

Create your own workflow:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: my-custom-chaos
  namespace: argo
spec:
  entrypoint: my-test
  serviceAccountName: argo
  templates:
    - name: my-test
      steps:
        - - name: custom-chaos
            template: my-chaos-step
    
    - name: my-chaos-step
      container:
        image: curlimages/curl:latest
        command: [sh, -c]
        args:
          - |
            echo "Running custom chaos test"
            # Your chaos logic here
```

### Parameterized Execution

Run with custom parameters:

```bash
argo submit config/litmus-workflows/kafka-chaos-suite.yaml \
  -n argo \
  -p kafka-namespace=my-kafka \
  -p chaos-duration=120 \
  --watch
```

### Workflow Templates

Reuse workflow logic:

```bash
# Create template
kubectl apply -f my-workflow-template.yaml

# Submit from template
argo submit --from workflowtemplate/my-template -n argo
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Chaos Testing
on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  chaos-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Chaos Suite
        run: |
          kubectl apply -f config/litmus-workflows/
          argo submit config/litmus-workflows/kafka-chaos-suite.yaml -n argo --wait
```

## Metrics and KPIs

Track these key indicators:

1. **Recovery Time Objective (RTO)**
   - Time to restore service after chaos
   - Target: < 30 seconds

2. **Recovery Point Objective (RPO)**
   - Data loss tolerance
   - Target: 0 messages lost

3. **Availability**
   - Uptime during chaos
   - Target: > 99.9%

4. **Performance Degradation**
   - Throughput impact
   - Target: < 20% reduction

5. **Error Rate**
   - Failed requests during chaos
   - Target: < 1%

## Resources

- **Argo Workflows Docs**: https://argoproj.github.io/argo-workflows/
- **LitmusChaos Docs**: https://docs.litmuschaos.io/
- **Kafka Monitoring**: https://kafka.apache.org/documentation/#monitoring
- **Chaos Engineering Principles**: https://principlesofchaos.org/

## Support

For issues or questions:
1. Check workflow logs: `./manage-chaos-workflows.sh logs <workflow>`
2. Review Argo UI: https://localhost:2746
3. Check Kafka health: `kubectl get kafka -n kafka`
4. View this guide: `cat CHAOS-WORKFLOWS-GUIDE.md`
