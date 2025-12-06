# LitmusChaos Experiments for Kafka

This directory contains chaos experiments designed to test Kafka cluster resilience.

## Available Experiments

### 1. Pod Delete (`01-pod-delete-experiment.yaml`)
Randomly deletes Kafka pods to test recovery and replication.
- **Duration**: 30s
- **Interval**: 10s
- **Affected**: 50% of pods

### 2. Container Kill (`02-container-kill-experiment.yaml`)
Kills Kafka containers to test restart policies and data consistency.
- **Duration**: 60s
- **Interval**: 10s
- **Target**: kafka container

### 3. Node Drain (`03-node-drain-experiment.yaml`)
Drains a Kubernetes node to test pod rescheduling and cluster rebalancing.
- **Duration**: 60s
- **Scope**: Cluster-wide

### 4. Network Loss (`04-network-loss-experiment.yaml`)
Introduces packet loss to test network resilience.
- **Duration**: 60s
- **Packet Loss**: 20%

### 5. Disk Fill (`05-disk-fill-experiment.yaml`)
Fills disk space to test storage monitoring and alerts.
- **Duration**: 60s
- **Fill**: 80%

## Prerequisites

1. **RBAC Setup**: Apply the RBAC configuration first:
   ```bash
   kubectl apply -f 00-chaosengine-rbac.yaml
   ```

2. **Kafka Running**: Ensure Kafka cluster is deployed:
   ```bash
   kubectl get kafka krafter -n kafka
   ```

3. **LitmusChaos Operator**: Verify operator is running:
   ```bash
   kubectl get pods -n litmus
   ```

## Running Experiments

### Apply All Experiments
```bash
kubectl apply -f config/litmus-experiments/
```

### Run Individual Experiment
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

## Monitoring Results

### View Experiment Status
```bash
kubectl get chaosexperiments -n kafka
```

### View Chaos Results
```bash
kubectl get chaosresults -n kafka
```

### View Detailed Results
```bash
kubectl describe chaosresult <result-name> -n kafka
```

### View Chaos Logs
```bash
kubectl logs -n kafka -l job-name=<chaos-job-name>
```

## Grafana Dashboards

View chaos metrics in Grafana:
1. Access Grafana: http://localhost:30080
2. Navigate to Dashboards → LitmusChaos
3. Monitor:
   - Experiment success rate
   - Kafka cluster health during chaos
   - Recovery time
   - Message throughput impact

## Best Practices

1. **Start Small**: Begin with short durations and low impact
2. **Monitor**: Always watch Grafana dashboards during experiments
3. **Document**: Record results and observations
4. **Gradual Increase**: Increase chaos intensity gradually
5. **Production-like**: Test scenarios that match production failures

## Cleanup

### Stop Running Experiments
```bash
kubectl delete chaosengine --all -n kafka
```

### Remove Experiments
```bash
kubectl delete chaosexperiments --all -n kafka
```

### Clean Results
```bash
kubectl delete chaosresults --all -n kafka
```

## Troubleshooting

### Experiment Not Starting
- Check RBAC: `kubectl get sa kafka-chaos-sa -n kafka`
- Check operator logs: `kubectl logs -n litmus -l app.kubernetes.io/component=operator`

### Experiment Failed
- View result: `kubectl describe chaosresult <name> -n kafka`
- Check pod logs: `kubectl logs -n kafka -l job-name=<chaos-job>`

### Images Not Found
- Ensure images are loaded: `make ps`
- Check image pull policy is `Never` in experiment definitions
